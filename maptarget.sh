#!/bin/bash
MSP=""          # this is the first part of the MSP URL (e.g. if your MMSP URL is "foo.firewalla.net" put foo here
token=""        # This is the MSP token
backuppath=""   # the path you wat to use to save the Target lists

if [[ -z "$MSP" ]] ; then
	echo "You need an MSP!" 
	exit
elif [[ -z "$token" ]] ; then
	echo "You need your MSP token"
	exit
fi


# Fetch all target lists once
json=$(curl -s "https://${MSP}.firewalla.net/v2/target-lists?owner=${owner}" \
	-H "Authorization: ${token}")

if [ "$1" = "-b" ]; then
    # Backup all target lists
	if [[ -z "$backuppath" ]] ; then
		echo "You need to define the backuppath."
		exit
	fi
if [ ! -d "$backuppath" ] ; then
    read -p "Directory '$backuppath' does not exist. Create it? (y/n): " -n 1 -r response
    echo # Add a newline after the read
    if [[ "$response" =~ ^[Yy]$ ]]; then
        mkdir -p "$backuppath"
        echo "Directory created."
    else
        echo "Directory not created. Exiting."
        # Optional: exit 1
    fi
fi

    json=$(curl -s "https://${MSP}.firewalla.net/v2/target-lists?owner=${owner}" \
                -H "Authorization: ${token}")

    # Check if the JSON is empty (e.g., curl failed or returned nothing)
    if [ -z "$json" ]; then
        echo "Error: API call returned empty or failed. Check MSP/token/network."
        exit 1
    fi

    # Check for a specific API error message in the JSON
    if echo "$json" | grep -q "error"; then
        echo "Error: API returned an error response. Response was:"
        echo "$json"
        exit 1
    fi

elif [ "$1" = "-s" ]; then
    json=$(curl -s "https://${MSP}.firewalla.net/v2/target-lists?owner=${owner}" \
                -H "Authorization: ${token}")

    if [ "$2" ]; then
        # Search for specific ID
        content=$(echo "$json" | jq -r '.[] | select(.id=="'"$2"'") | .targets[]')
        [ -z "$content" ] && content="EMPTY"
        echo "$content"
    else
        # No ID provided → print all IDs
        echo "$json" | jq -r '.[] | .id'
    fi

else
    echo "Usage:"
    echo "  $0 -b          # backup all target lists"
    echo "  $0 -s <id>     # show targets for a specific list ID"
    echo "  $0 -s          # list all IDs"
fi
