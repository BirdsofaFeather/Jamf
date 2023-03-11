#!/bin/zsh

######################
# Script Name: enable_sudo_touchid.sh
# Author: Seyha Soun
# Date: 03/10/2023
# Enhancements:
# Comments: Enable Touch ID for sudo
# Commented 
######################

# Get the current user and their UID
currentUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
currentUserID=$( id -u "$currentUser" )

# This is the line we need to add to enable TID
enableTouchID="auth       sufficient     pam_tid.so"

# Original sudo file location
sudoFile="/etc/pam.d/sudo"

# If TouchID is already enabled exit. Otherwise modify the sudo file
if fgrep -q "$enableTouchID" "$sudoFile"; then
	echo "TouchID for sudo is already enabled. Doing nothing..."
else
	echo "TouchID not enabled for sudo. Enabling now..."
	# Write new file with line to enable touch ID
	awk 'NR==2 {print "auth       sufficient     pam_tid.so"} 1' $sudoFile > $sudoFile.new

	# Make a backup of the current sudo file
	cp $sudoFile $sudoFile.bak

	# Replace the current file with the new file
	mv $sudoFile.new $sudoFile
fi

# If iTerm is installed, tell the user what they need to change to enable this setting
if [ -d '/Applications/iTerm.app' ]; then
	# Read iTerm preference key
	iTermPref=$( launchctl asuser "$currentUserID" sudo -u "$currentUser" defaults read com.googlecode.iterm2 BootstrapDaemon 2>/dev/null )
	
	# If preference needs to be set, show Jamf Helper window with instructions
	if [[ "$iTermPref" == "0" ]]; then
		echo "iTerm preference is already set properly. Doing nothing..."
	else
		echo "Notifying user which iTerm setting needs to be changed..."
		# Set notification description
		description="We have detected that you have iTerm installed. There is an additional step needed to enable this functionality.

To enable TouchID for iTerm: Navigate to Preferences » Advanced » Session, then ensure \"Allow sessions to survive logging out and back in\" is set to \"No\""
		
		# Display notification
		"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
		-windowType utility \
		-title "Tech Services Notification" \
		-heading "Additional Step Required for iTerm" \
		-description "$description" \
		-alignDescription left \
		-icon "/Applications/iTerm.app/Contents/Resources/AppIcon.icns" \
		-button1 "OK" \
		-defaultButton 1
	fi
fi
