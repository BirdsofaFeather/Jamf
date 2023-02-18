#!/bin/zsh

######################
# Script Name: set_zoom_sso.sh
# Author: Seyha Soun
# Date: 02/18/2023
# Enhancements:
# Comments: Sets SSO Host and removes Google, Facebook, and Apple login
# Commented 
######################

# Jamf Pro script parameter 
ssoHost="$4"

if [[ -e "/Library/Preferences/us.zoom.config.plist" ]]; then
  echo "Removing existing config"
  rm "/Library/Preferences/us.zoom.config.plist"
fi

cat >> /Library/Preferences/us.zoom.config.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>nogoogle</key>
	<true/>
	<key>nofacebook</key>
	<true/>
	<key>EnableAppleLogin</key>
	<false/>
 	<key>ZAutoSSOLogin</key>
 	<true/>
	<key>zSSOHost</key>
 	<string>$ssoHost</string>
	<key>ForceSSOURL</key>
 	<string>$ssoHost</string>
	<key>EnableEmbedBrowserForSSO</key>
	<true/>
</dict>
</plist>
EOF
