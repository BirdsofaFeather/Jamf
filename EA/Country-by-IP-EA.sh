#!/bin/zsh

######################
# Script Name: Country-by-IP-EA.sh
# Author: Seyha Soun
# Date: 02/03/2022
# Enhancements:
# Comments: Determines users location country from their public IP address
# Commented 
######################

##
## SCRIPT CONTENTS, DO NOT MODIFY BELOW THESE LINES (Unless you know what you're doing)
##

publicIPAddress=$(curl -sk -4 icanhazip.com)

if [[ $publicIPAddress ]]; then
  ## Geolocation based on IP Address from public IP
  geoLocationData=$(curl -s -H "User-Agent: keycdn-tools:https://icanhazip.com" "https://tools.keycdn.com/geo.json?host=${publicIPAddress}" 2>&1)  

  ## Get country from the Geolocation
  country=$(echo ${geoLocationData} | plutil -extract "data"."geo"."country_name" raw -o - -)
else
  results="ERROR - IP Address lookup failed"
fi

## If data exists show the country, otherwise come back with an error
if [[ ${country} ]]; then
	results=${country}
fi

echo "<result>${results}</result>"
