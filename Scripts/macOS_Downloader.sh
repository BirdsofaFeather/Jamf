#!/bin/bash

######################
# Script Name: macOS_Downloader.sh
# Author: Seyha Soun
# Date: 02/18/2023
# Enhancements:
# Comments: Download macOS Installer PKG for Install.app for latest build as of $scriptUpdateDate, $macOSVersion Build $macOSBuild
# Commented 
######################

# Jamf Pro script parameter 
scriptUpdateDate=$4
macOSFamily=$5
macOSVersion=$6
macOSInstallerVersion=$7
macOSBuild=$8
macOSDownloadLink=$9
macOSLocalLocation="/private/tmp/macOS$macOSFamily$macOSBuild.pkg"
macOSInstaller="/Applications/Install macOS $macOSFamily.app"

if [[ -e "/Applications/Install macOS $macOSFamily.app" ]]; then
    InstallerVersion=`mdls "/Applications/Install macOS $macOSFamily.app" -name kMDItemVersion | awk -F'"' '{print $2}'`
	if [[ $InstallerVersion != "$macOSInstallerVersion" ]]; then
		echo "Incorrect $macOSFamily Installer version, required "${macOSInstallerVersion}" and found "${$macOSFamilyInstallerVersion}.""
        echo "Deleting macOS $macOSFamily Installer "${$macOSFamilyInstallerVersion}.""
        rm -rf "/Applications/Install macOS $macOSFamily.app"
		curl -f $macOSDownloadLink --output $macOSLocalLocation -C - && installer -pkg $macOSLocalLocation -target /
		sleep 5
	else
        echo "Correct $macOSFamily Installer version, found macOS $macOSFamily "${$macOSFamilyInstallerVersion}.""
    fi
else
	echo "macOS $macOSFamily Installer not found. Downloading..."
    curl -f $macOSDownloadLink --output $macOSLocalLocation -C - && installer -pkg $macOSLocalLocation -target /
	sleep 5
fi

if [ -e "$macOSInstaller" ] ; then
	echo "Removing downloaded pkg file from $macOSLocalLocation"
	rm -rf $macOSLocalLocation
else
	echo "macOS Installer not found in $macOSInstaller"
	exit 1
fi

exit 0
