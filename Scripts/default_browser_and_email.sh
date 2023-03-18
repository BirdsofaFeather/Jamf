#!/bin/zsh

temp_directory=$(mktemp -d) 

# If you change your daemon file name, update the following line
launch_daemon_plist_name='com.leanix.setdefaultbrowser.plist'

# Base paths
launch_daemon_base_path='/Library/LaunchDaemons/'

# Current user information
loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
loggedInUserID=$(id -u "$loggedInUser")

/bin/echo "Creating default browser and mail client LaunchDaemons ${launch_daemon_base_path}${launch_daemon_plist_name}"
# Jamf Connect App LaunchAgent Setup
/bin/cat > "/Library/LaunchDaemons/com.leanix.setdefaultbrowser.plist" << 'Jamf_Pro_Inventory_LaunchDaemons'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
	<string>com.leanix.setdefaultbrowser</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>/var/tmp/setdefaultbrowser.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>120</integer>
</dict>
</plist>
Jamf_Pro_Inventory_LaunchDaemons
sleep 1

# Create the setdefaultbrowser script by using cat input redirection
# to write the shell script contained below to a new file.

/bin/cat > "$temp_directory/setdefaultbrowser.sh" << 'JAMF_PRO_INVENTORY_UPDATE_SCRIPT'
#!/bin/bash

# If you change your agent file name, update the following line
launch_daemon_plist_name='com.leanix.setdefaultbrowser.plist'

# Base paths
launch_daemon_base_path='/Library/LaunchDaemons/'

setDefaultBrowser (){
 
# Only enable the LaunchAgent if there is a user logged in, otherwise rely on built in LaunchAgent behavior

loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
loggedInUserHome=$(/usr/bin/dscl . -read "/Users/$loggedInUser" NFSHomeDirectory | /usr/bin/awk '{print $NF}')
launchServicesPlistFolder="$loggedInUserHome/Library/Preferences/com.apple.LaunchServices"
launchServicesPlist="$launchServicesPlistFolder/com.apple.launchservices.secure.plist"

if [[ -z "$loggedInUser" ]]; then
    echo "Did not detect user"
    exit 1
elif [[ "$loggedInUser" == "loginwindow" ]]; then
    echo "Detected Loginwindow Environment"
    exit 1
elif [[ "$loggedInUser" == "_mbsetupuser" ]]; then
    echo "Detect SetupAssistant Environment"
    exit 1
elif [[ "$loggedInUser" == "root" ]]; then
    echo "Detect root as currently logged-in user"
    exit 1
else
# Should be in the format domain.vendor.app (e.g. com.apple.safari).
browserAgentString="com.google.chrome"
# Jamf Pro script parameter "Email Agent String"
# Should be in the format domain.vendor.app (e.g. com.apple.mail).
emailAgentString="com.microsoft.outlook"

plistbuddyPath="/usr/libexec/PlistBuddy"
plistbuddyPreferences=(
  "Add :LSHandlers:0:LSHandlerRoleAll string $browserAgentString"
  "Add :LSHandlers:0:LSHandlerURLScheme string http"
  "Add :LSHandlers:1:LSHandlerRoleAll string $browserAgentString"
  "Add :LSHandlers:1:LSHandlerURLScheme string https"
  "Add :LSHandlers:2:LSHandlerRoleViewer string $browserAgentString"
  "Add :LSHandlers:2:LSHandlerContentType string public.html"
  "Add :LSHandlers:3:LSHandlerRoleViewer string $browserAgentString"
  "Add :LSHandlers:3:LSHandlerContentType string public.url"
  "Add :LSHandlers:4:LSHandlerRoleViewer string $browserAgentString"
  "Add :LSHandlers:4:LSHandlerContentType string public.xhtml"
  "Add :LSHandlers:5:LSHandlerRoleAll string $emailAgentString"
  "Add :LSHandlers:5:LSHandlerURLScheme string mailto"
  "Add :LSHandlers:6:LSHandlerRoleAll string $emailAgentString"
  "Add :LSHandlers:6:LSHandlerContentType string com.apple.ical.ics"
  "Add :LSHandlers:7:LSHandlerRoleAll string $emailAgentString"
  "Add :LSHandlers:7:LSHandlerContentType string com.apple.mail.email"
  "Add :LSHandlers:8:LSHandlerRoleAll string $emailAgentString"
  "Add :LSHandlers:8:LSHandlerContentType string public.vcard"
)
lsregisterPath="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    # Clear out LSHandlers array data from $launchServicesPlist, or create new plist if file does not exist.
    if [[ -e "$launchServicesPlist" ]]; then
    "$plistbuddyPath" -c "Delete :LSHandlers" "$launchServicesPlist"
    echo "Reset LSHandlers array from $launchServicesPlist."
    else
    /bin/mkdir -p "$launchServicesPlistFolder"
    "$plistbuddyPath" -c "Save" "$launchServicesPlist"
    echo "Created $launchServicesPlist."
    fi

    # Add new LSHandlers array.
    "$plistbuddyPath" -c "Add :LSHandlers array" "$launchServicesPlist"
    echo "Initialized LSHandlers array."

    # Set handler for each URL scheme and content type to specified browser and email client.
    for plistbuddyCommand in "${plistbuddyPreferences[@]}"; do
    "$plistbuddyPath" -c "$plistbuddyCommand" "$launchServicesPlist"
    if [[ "$plistbuddyCommand" = *"$browserAgentString"* ]] || [[ "$plistbuddyCommand" = *"$emailAgentString"* ]]; then
        arrayEntry=$(echo "$plistbuddyCommand" | /usr/bin/awk -F: '{print $2 ":" $3 ":" $4}' | /usr/bin/sed 's/ .*//')
        prefLabel=$(echo "$plistbuddyCommand" | /usr/bin/awk '{print $4}')
        echo "Set $arrayEntry to $prefLabel."
    fi
    done

    # Fix permissions on $launchServicesPlistFolder.
    /usr/sbin/chown -R "$loggedInUser" "$launchServicesPlistFolder"
    echo "Fixed permissions on $launchServicesPlistFolder."

    # Kill any running launchservice processes
    /usr/bin/killall lsd

    # Reset Launch Services database.
    "$lsregisterPath" -kill -r -domain local -domain system -domain user
    echo "Reset Launch Services database. A restart may also be required for these new default client changes to take effect."
    /usr/local/bin/jamf policy -trigger "basicdock"
fi
}
 
SelfDestruct (){
 
# Removes script and associated LaunchAgent

#/bin/echo "Checking to see if the LaunchAgent is Loaded"
#launchctl list | grep com.leanix.setdefaultbrowser && quikResults=true || quikResults=false

#if [ $quikResults = true ] ; then
if [[ -f ${launch_daemon_base_path}${launch_daemon_plist_name} ]]; then
  rm -rf "${launch_daemon_base_path}${launch_daemon_plist_name}"
	sleep 1
fi

/bin/echo "Deleting script"
rm -rf $0

  /Applications/LeanIX\ Notifier.app/Contents/MacOS/LeanIX\ Notifier -type popup -title "Laptop Restart Required" -subtitle "Your laptop will restart in 60 seconds to complete your computer setup.\n\nTo restart now, click Restart now." -accessory_view_type timer -accessory_view_payload "Time left: %@" -timeout 60 -main_button_label "Restart now"  -always_on_top -force_light_mode
  shutdown -r now

	/bin/echo "Bootout ${launch_daemon_plist_name}"
  # Unload the agent
  if [[ -n $(/bin/launchctl list | grep "com.leanix.setdefaultbrowser") ]]; then
    /bin/launchctl bootout system/com.leanix.setdefaultbrowser
  fi
}

  setDefaultBrowser
  SelfDestruct
  sleep 3
exit 0
JAMF_PRO_INVENTORY_UPDATE_SCRIPT

# Set the permissions and ownership
/usr/sbin/chown root:wheel "${launch_daemon_base_path}${launch_daemon_plist_name}"
/bin/chmod 644 "${launch_daemon_base_path}${launch_daemon_plist_name}"
chmod +x "${launch_daemon_base_path}${launch_daemon_plist_name}"

/usr/sbin/chown root:wheel "$temp_directory/setdefaultbrowser.sh"
/bin/chmod 644 "$temp_directory/setdefaultbrowser.sh"
/bin/chmod a+x "$temp_directory/setdefaultbrowser.sh"
/bin/mv "$temp_directory/setdefaultbrowser.sh" "/var/tmp/setdefaultbrowser.sh"

sleep 1

# Load the launchagents
    # Unload the agent so it can be triggered on re-install
    /bin/launchctl bootout system/com.leanix.setdefaultbrowser.plist
    # Load the launch agent
    /bin/launchctl bootstrap system "${launch_daemon_base_path}${launch_daemon_plist_name}"

exit
