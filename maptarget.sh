#!/bin/bash
version="3.6"

# --- Configuration Variables ---
MSP="kaleb" # The first part of the MSP URL
token="Token e476910e98b7b71d0c94e3054d8177f3" # The MSP token
owner="25509ec0-b512-413e-bf5a-d75b7c88f191" # The owner ID for fetching lists
backuppath="/Users/michael/Documents/Applications/Firewalla/target lists" # The path to save the Target lists
# --- End Configuration Variables ---

# Global variable to hold the fetched JSON data
json="" 

# Function to handle API connection and data validation
fetch_data() {
    # Check for essential variables
    if [[ -z "$MSP" ]] ; then
        echo "Error: You need an MSP!"
        exit 1
    elif [[ -z "$token" ]] ; then
        echo "Error: You need your MSP token"
        exit 1
    fi

    echo "Fetching target lists from https://${MSP}.firewalla.net..."
    # Use -sk for security bypass and silent output
    json=$(curl -sk "https://${MSP}.firewalla.net/v2/target-lists?owner=${owner}" \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json")
    
    # --- API Error and JSON Validation ---

    if [ -z "$json" ]; then
        echo "Error: API call returned empty or failed. Check connectivity or token format."
        exit 1
    fi

    # Check for Authentication Failure (specific error object)
    if echo "$json" | grep -q "Authentication failed"; then
        echo "Error: Authentication failed. Please verify your token/format (e.g., 'Token XXXX')."
        echo "Response details:"
        echo "$json" | jq .
        exit 1
    fi

    # Final check to ensure the response is a JSON array (starts with '[')
    if ! echo "$json" | grep -q "^\["; then
        echo "Error: Unexpected response format. The API may have changed or failed."
        echo "Received first line: $(echo "$json" | head -n 1)"
        echo "Received full response:"
        echo "$json" | jq .
        exit 1
    fi
}

# --- Main Command Handling ---

if [ "$1" = "-b" ]; then
    fetch_data # Load data before backup
    ## 💾 Backup Logic: Correct File Header Format (v3.6)
    
	if [[ -z "$backuppath" ]] ; then
		echo "Error: You need to define the backuppath."
		exit 1
	fi
	
	if [ ! -d "$backuppath" ] ; then
		read -p "Directory '$backuppath' does not exist. Create it? (y/n): " -n 1 -r response
		echo
    	if [[ "$response" =~ ^[Yy]$ ]]; then
			mkdir -p "$backuppath"
			echo "Directory created."
		else
			echo "Directory not created. Exiting."
			exit 1
		fi
	fi

    echo "Starting backup of target lists to: $backuppath"
    
    # JQ output: ID\nName\nTarget1\nTarget2\n---END_OF_LIST---\nID2\nName2...
    current_id=""
    current_name=""
    current_content=""
    
    while IFS= read -r line; do
        if [ "$line" = "---END_OF_LIST---" ]; then
            # We reached the end of a list. Write the file.
            if [ -n "$current_name" ]; then
                # Sanitize the filename (uses current_name)
                filename=$(echo "$current_name" | tr ' /' '_-')
                filepath="$backuppath/$filename.txt"
                
                echo "Backing up: $current_name"
                
                # --- FILE CONTENT CONSTRUCTION ---
                # First line: #ID:[ID]. Subsequent lines: Targets.
                if [ -n "$current_content" ]; then
                     # Remove the trailing newline from current_content
                    clean_content=${current_content%$'\n'}
                    final_content="#ID:$current_id"$'\n'"$clean_content"
                else
                    # Only the ID line if there are no targets
                    final_content="#ID:$current_id"
                fi

                # Write the file
                echo "$final_content" > "$filepath"
                
                # Reset for the next list
                current_id=""
                current_name=""
                current_content=""
            fi

        elif [ -z "$current_id" ]; then
            # First line is always the ID
            current_id="$line"

        elif [ -z "$current_name" ]; then
            # Second line is always the Name (used only for filename)
            current_name="$line"

        else
            # All subsequent lines until the delimiter are content (targets)
            current_content="$current_content$line"$'\n'
        fi
    done < <(echo "$json" | jq -r '.[] | .id, .name, (.targets | .[]), "---END_OF_LIST---"')

    echo "Backup complete! ✅"

elif [ "$1" = "-s" ]; then
    fetch_data # Load data before search
    ## 🔎 Search Logic: Corrected to display Name and Targets (v3.6)

    if [ "$2" ]; then
        list_id="$2"
        
        # JQ filter to extract Name and Targets for the given ID.
        # Outputs: "Name\tTarget1\nTarget2\nTarget3"
        result=$(echo "$json" | jq -r '[.[] | select(.id=="'"$list_id"'") | .name, (.targets | join("\n"))] | join("\t")')
        
        # Check if a match was found (result is empty if no ID matched)
        if [ -z "$result" ]; then
            echo "Error: No target list found for ID: $list_id"
        else
            # Split the result into Name and Targets
            list_name=$(echo "$result" | awk -F'\t' '{print $1}')
            targets=$(echo "$result" | awk -F'\t' '{print $2}')
            
            # Use 'NONE' for empty Name or empty Targets
            final_name=${list_name:-NONE}
            final_targets=${targets:-NONE}

            # Output the required format
            echo "Name: $final_name"
            echo "Contents:" # Using "Contents" as requested
            
            # Print targets directly if not NONE
            if [ "$final_targets" = "NONE" ]; then
                echo ""
            else
                echo "$targets"
            fi
        fi
        
    else
        # No ID provided → print all IDs and Names. ORDER: Name | ID
        echo "Listing all Target Lists (Name | ID):"
        echo "---"
        echo "$json" | jq -r '.[] | "\(.name) | \(.id)"'
    fi

else
    # This block executes if $1 is empty (no argument provided)
    echo "MSP Target List Tool (Version $version)"
    echo "Usage:"
    echo "  $0 -b          # **B**ackup all target lists (content only) to '$backuppath'"
    echo "  $0 -s <id>     # **S**how the Name and Contents of a specific list"
    echo "  $0 -s          # **S**how/list all target list IDs and Names (Name | ID)"
fi
