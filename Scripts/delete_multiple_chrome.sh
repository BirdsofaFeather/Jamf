#!/bin/bash

######################
# Script Name: delete_multiple_chrome.sh
# Author: Seyha Soun
# Date: 01/25/2022
# Enhancements:
# Comments: Used to delete multiple instances of Google Chrome found in the Applications folder.
# Commented 
######################

######################
# Exit Codes
# 0 - Success: General Success
# 1 - Failed: User clicked on cancel when asked to close Chrome to start the deletion process
###################### 

IFS=$'\n'

loggedInUser=$(ls -l /dev/console | awk '{print $3}')
loggedInUserID=$(id -u "$loggedInUser")

## finds all Google Chrome in the Application folder and creates an array
ChromeNames=( $(find /Applications -name "Google Chrome*.app" -maxdepth 1 -type d2) )

## Checks to see if there are more than 1 Chrome in the Applications folder
if [[ ${#ChromeNames[@]} > 1 ]] ; then
    echo "Found multiple instances of Chrome"
    return=`/bin/launchctl asuser $loggedInUserID /usr/bin/osascript <<-EOS
    tell me to display dialog "You have multiple instances of Chrome installed.

Please complete any tasks pending tasks in Chrome.

Then click OK to close Chrome so that the other Chrome can be removed."
EOS`
        if [[ "button returned:OK" = $return ]] ; then
            /bin/launchctl asuser "$loggedInUserID" /usr/bin/osascript -e 'tell application "Google Chrome" to quit'
            sleep 3

            ## Delete all instances of Chrome besides the correct one.
            for i in "${ChromeNames[@]}"
                do :
                    if [[ $i != "/Applications/Google Chrome.app" ]] ; then
                        echo "Deleting $i"
                        rm -rf $i
                    fi
            done
            sleep 3
            /bin/launchctl asuser $loggedInUserID /usr/bin/osascript <<-EOS
tell me to display dialog "The other instances of Chrome have been deleted.

You can now re-open Chrome."
EOS
        else
            echo "User clicked Cancel"
            exit 1
        fi
else
    echo "Multiple instances of Chrome not found."
fi

######################
# Clean up
###################### 

echo "Script completed"

exit 0
