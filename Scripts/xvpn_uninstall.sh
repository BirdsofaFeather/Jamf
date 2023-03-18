#!/usr/bin/env bash

#----------------------------------------------------------------------
# Functions
#----------------------------------------------------------------------
# Exits the script with the given exit code after waiting
# for a keypress.
#
# @param [Integer] $1 exit code.
function key_exit() {
    echo "Press any key to exit."
    read
    exit $1
}

# Appends a value to an array.
#
# @param [String] $1 Name of the variable to modify
# @param [String] $2 Value to append
function append() {
    eval $1[\${#$1[*]}]=$2
}

if (( $EUID != 0 )); then
echo "Please run as root"
exit
fi

#----------------------------------------------------------------------
# Script
#----------------------------------------------------------------------
IS_BIGSUR=1
majorVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{ print $1; }')
minorVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{ print $2; }')
if [[ $majorVersion -eq 10 && $minorVersion -le 15 ]]; then
  IS_BIGSUR=0
fi

# if the application didn't exit on its own force quit now
if /usr/bin/pgrep -x ExpressVPN > /dev/null; then
	/usr/bin/pkill -9 -x ExpressVPN
	# wait until ExpressVPN process quit or timeout(15s)
	i=0
	while /usr/bin/pgrep -x ExpressVPN > /dev/null && [[ "$i" -lt 15 ]]; do
		/bin/sleep 1
		i=$(( i + 1 ))
	done
fi

# stop all browser extension helpers
CHROMEEXT="/Library/Google/Chrome/NativeMessagingHosts/com.expressvpn.helper.json"
if [ -e "${CHROMEEXT}" ]; then
	/bin/rm -f "${CHROMEEXT}" > /dev/null 2>&1
fi

MSEDGEEXT="/Library/Microsoft/Edge/NativeMessagingHosts/com.expressvpn.helper.json"
if [ -e "${MSEDGEEXT}" ]; then
	/bin/rm -f "${MSEDGEEXT}" > /dev/null 2>&1
fi

FIREFOXEXT="/Library/Application Support/Mozilla/NativeMessagingHosts/com.expressvpn.helper.json"
if [ -e "${FIREFOXEXT}" ]; then
	/bin/rm -f "${FIREFOXEXT}" > /dev/null 2>&1
fi

# Clean up any localy installed browser helpers and engines
CHROMELOCEXT="/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.expressvpn.helper.json"
MSEDGELOCEXT="/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.expressvpn.helper.json"
FIREFOXLOCEXT="/Library/Application Support/Mozilla/NativeMessagingHosts/com.expressvpn.helper.json"
LEGACYENGINE="/Library/LaunchAgents/com.expressvpn.ExpressVPN.agent.plist"

/usr/bin/find /Users -type d -maxdepth 1 -mindepth 1 -print0 | 
	while IFS= read -r -d '' user_folder; do
		echo "Checking: $user_folder"
		if [ -e "$user_folder$CHROMELOCEXT" ]; then
			echo "FOUND: $user_folder$CHROMELOCEXT"
			/bin/rm -f "$user_folder$CHROMELOCEXT" > /dev/null 2>&1
		fi
		if [ -e "$user_folder$MSEDGELOCEXT" ]; then
			echo "FOUND: $user_folder$MSEDGELOCEXT"
			/bin/rm -f "$user_folder$MSEDGELOCEXT" > /dev/null 2>&1
		fi
		if [ -e "$user_folder$FIREFOXLOCEXT" ]; then
			echo "FOUND: $user_folder$FIREFOXLOCEXT"
			/bin/rm -f "$user_folder$FIREFOXLOCEXT" > /dev/null 2>&1
		fi
		if [ -e "$user_folder$LEGACYENGINE" ]; then
			echo "FOUND: $user_folder$LEGACYENGINE"
			sudo -u "${user_folder##*/}" /bin/launchctl unload -w -F "$user_folder$LEGACYENGINE" > /dev/null 2>&1
			/bin/rm -f "$user_folder$LEGACYENGINE" > /dev/null 2>&1
		fi
	done

# Kill all browser native helper processes
if /usr/bin/pgrep -x expressvpn-browser-helper > /dev/null; then
	echo "Stopping expressvpn-browser-helper..."
	/usr/bin/pkill -9 -x expressvpn-browser-helper
fi

# Clean up engine Launch Daemon
if [ -f "/Library/LaunchDaemons/com.expressvpn.expressvpnd.plist" ]; then
	# unload engine launch daemon
	/bin/launchctl unload -w "/Library/LaunchDaemons/com.expressvpn.expressvpnd.plist" > /dev/null 2>&1

	# wait until engine process exit or timeout(15s)
	while /usr/bin/pgrep -x expressvpnd > /dev/null && [[ "$i" -lt 15 ]]; do
		sleep 1
		i=$(( i + 1 ))
	done
fi

# Force kill engine just incase it didn't stop
if /usr/bin/pgrep -x expressvpnd > /dev/null; then
	kill -9 "$(/usr/bin/pgrep -x expressvpnd)"
fi

# Unload updater, note that we should always quit the updater first since
# it might interrupt the uninstallation process if it tries to install update
# when ExpressVPN.app is quiting
if [ -f "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.update.plist" ]; then
    /bin/launchctl unload -w "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.update.plist" > /dev/null 2>&1

    # wait until updater process exit
    while /usr/bin/pgrep -x "ExpressVPN Update Checker" > /dev/null; do sleep 1; done
fi

if [ -f "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.updated.plist" ]; then
    /bin/launchctl unload -w "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.updated.plist" > /dev/null 2>&1

    # wait until updater process exit
    while /usr/bin/pgrep -x "expressvpnupdatedlauncher" > /dev/null; do sleep 1; done
fi


if /usr/bin/pgrep -x ExpressVPN > /dev/null; then
	# quit app
	echo "Quitting ExpressVPN..."
	/usr/bin/osascript -e 'tell app "ExpressVPN" to quit'
fi

# Remove application firewall exceptions for our processes
/usr/libexec/ApplicationFirewall/socketfilterfw --remove /Applications/ExpressVPN.app/Contents/MacOS/lightway
/usr/libexec/ApplicationFirewall/socketfilterfw --remove /Applications/ExpressVPN.app/Contents/MacOS/openvpn
/usr/libexec/ApplicationFirewall/socketfilterfw --remove /Applications/ExpressVPN.app/Contents/MacOS/expressvpnd

if [ "$IS_BIGSUR" -eq "0" ]; then
    /sbin/kextunload /Library/Extensions/tun.kext > /dev/null 2>&1
    /sbin/kextunload /Library/Extensions/tap.kext > /dev/null 2>&1
    /sbin/kextunload /Library/Extensions/ExpressVPNSplitTunnel.kext > /dev/null 2>&1
fi

# Collect the directories and files to remove
system_files=()
user_files=()
append system_files "/Applications/ExpressVPN.app"

# data files
append system_files "$HOME/Library/Application\ Support/com.expressvpn.ExpressVPN"
append system_files "/Library/Application\ Support/com.expressvpn.ExpressVPN"

# staging files
append system_files "$HOME/Library/Application\ Support/com.expressvpn.ExpressVPN-staging"

# kexts
append system_files "/Library/Extensions/tun.kext"
append system_files "/Library/Extensions/tap.kext"
append system_files "/Library/Extensions/ExpressVPNSplitTunnel.kext"

# markers
append system_files "/Library/Caches/com.expressvpn.ExpressVPN-Update.marker.plist"
append system_files "/Library/Caches/com.expressvpn.ExpressVPN.marker.plist"
append system_files "/Library/Caches/com.expressvpn.Updater.marker.plist"

# launch agent
append system_files "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.agent.plist"
append system_files "$HOME/Library/LaunchAgents/com.expressvpn.ExpressVPN.update.plist"

# launch daemon
append system_files "/Library/LaunchDaemons/com.expressvpn.expressvpnd.plist"

# 3.x files
append user_files "$HOME/Library/Application\ Support/ExpressVPN"

# preferences
append user_files "$HOME/Library/Preferences/com.expressvpn.ExpressVPN.plist"
append user_files "$HOME/Library/Preferences/com.expressvpn.ExpressVPNGroup.plist"
append user_files "$HOME/Library/Preferences/group.com.expressvpn.ExpressVPN.plist"

# logs
append user_files "$HOME/Library/Logs/ExpressVPN"
append user_files "$HOME/Library/Logs/ExpressVPN\ Launcher"
append user_files "$HOME/Library/Logs/ExpressVPN\ Update"
append system_files "/EV.script.log"
append system_files "/var/log/EV.script.log"
append system_files "/var/log/xvpn.postinstall.log"

# shortcuts
append user_files "$HOME/Documents/ExpressVPN\ Shortcuts"

# config files
append user_files "$HOME/.expressvpn.conf"

my_files=("${system_files[@]}" "${user_files[@]}")

for file in "${my_files[@]}"; do
if [ -e "$file" ]; then
    /bin/rm -rf "$file"
fi
done

# Remove ikev2 configurations
"/Applications/ExpressVPN.app/Contents/MacOS/ExpressVPN IKEv2.app/Contents/MacOS/expressvpn-ikehelper" --remove > /dev/null 2>&1

# remove all preferences
users=$(/usr/bin/dscl . list /Users | /usr/bin/grep -v '_') 
for user in $users; do
    echo "User: $user"
    /usr/bin/sudo -u "$user" /usr/bin/defaults delete com.expressvpn.ExpressVPN
done

# delete previous client certificates
/usr/bin/security delete-certificate -Z 'BDE98D55300F49FC535A37286FA8871924971683' > /dev/null 2>&1

/usr/bin/security delete-certificate -Z '0F846F6BA98D2A5ADFECADD029C55BB589DB0301' > /dev/null 2>&1

/usr/bin/security delete-certificate -c 'ExpressVPN Client' > /dev/null 2>&1

# Kill all Safari companion processes
/usr/bin/pkill -9 -f 'ExpressVPN mini' > /dev/null 2>&1

# remove all preferences
/usr/bin/defaults delete com.expressvpn.ExpressVPN
/usr/bin/defaults delete com.expressvpn.ExpressVPN-Update

# Verify that the uninstall succeeded by checking whether every file
# we meant to remove is actually removed.
for file in "${my_files[@]}"; do
    if [ -e "${file}" ]; then
        echo "An error must have occurred since a file that was supposed to be"
        echo "removed still exists: ${file}"
        echo ""
        echo "Please try again."
        key_exit 1
    fi
done

echo "Successfully uninstalled ExpressVPN."
echo "Done."

# cleanup
if [ -e $tmpfile ]; then
    /bin/rm -f $tmpfile
fi

exit 0