#!/bin/bash
version="1.0" 

MSP="" # The first part of the MSP URL
token="Token " # The MSP token
owner="" # The owner ID for fetching lists
backuppath="" # The path to save the Rules
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

    echo "Fetching rules from https://${MSP}.firewalla.net/v2/rules..."
    # Use -sk for security bypass and silent output
    json=$(curl -sk --location "https://${MSP}.firewalla.net/v2/rules" \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json")
    
    # --- API Error and JSON Validation ---

    if [ -z "$json" ]; then
        echo "Error: API call returned empty or failed. Check connectivity or token format."
        exit 1
    fi

    # Check for Authentication Failure (specific error object or message)
    if echo "$json" | grep -q "Authentication failed"; then
        echo "Error: Authentication failed. Please verify your token/format (e.g., 'Token XXXX')."
        echo "Response details:"
        echo "$json" | jq .
        exit 1
    fi

    # Check for the top-level "results" array key in the new structure
    if ! echo "$json" | jq -e '.results | arrays' > /dev/null; then
        echo "Error: Unexpected response format. The JSON does not contain a top-level 'results' array."
        echo "Received full response:"
        echo "$json" | jq .
        exit 1
    fi
} 

# Function to check and create the backup directory
check_dir() {
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
} 

# --- Main Command Handling ---

if [ "$1" = "-j" ]; then
    fetch_data # Load data before backup
    check_dir
    ## 💾 JSON Backup Logic: Rules to JSON file

    echo "Starting JSON backup of rules to: $backuppath"

    # JQ output: Prints the rule's ID followed by the compacted JSON object for that rule.
    echo "$json" | jq -r -c '.results[] | .id, @json' |
    while IFS= read -r line; do
        if [ -z "$current_id" ]; then
            # First line is the unquoted rule ID (raw output)
            current_id="$line"
        else
            # Second line is the JSON object (compacted)
            
            # The filename is the rule's ID
            filepath="$backuppath/$current_id.json"

            echo "Backing up JSON: $current_id"

            # Use jq '.' to pretty-print the compact JSON before saving it.
            echo "$line" | jq '.' > "$filepath"
            
            # Reset for the next rule
            current_id=""
        fi
    done

    echo "JSON backup complete! ✅"

elif [ "$1" = "-s" ]; then
    fetch_data # Load data before search
    ## 🔎 Search Logic: Rules by ID

    # Define the parser logic as a single-line string. We will now prepend this as a 'def' in the jq command.
    target_value_parser='def parse_target_value: .target.value as $val | if $val == null then "" elif ($val | type) == "array" then ($val | join(", ")) elif ($val | type) == "object" then ($val | to_entries | .[].value | join(", ")) else ($val // "") end;'
    
    if [ "$2" ]; then
        rule_id="$2"
        
        # JQ filter: Select the rule by ID and format the output as TSV
        # Now we prepend the parser definition and call it directly.
        result=$(echo "$json" | jq -r --arg rule_id "$rule_id" "$target_value_parser"'
            .results[] | select(.id==$rule_id) | 
            [.action, .direction, .status, (.target.type // ""), (parse_target_value)] | @tsv')
        
        # Check if a match was found (result is empty if no ID matched)
        if [ -z "$result" ]; then
            echo "Error: No rule found for ID: $rule_id"
        else
            # Use read to split the TSV output into variables. 
            IFS=$'\t' read -r rule_action rule_direction rule_status target_type target_value <<< "$result"
            
            # Print NONE if target_value is empty (as per requirement)
            target_value=${target_value:-NONE}

            # Output the required format
            echo "Rule ID: $rule_id"
            echo "---"
            echo "Action: $rule_action"
            echo "Direction: $rule_direction"
            echo "Status: $rule_status"
            echo "Target Type: $target_type"
            echo "Target Value(s): $target_value"
        fi
        
    else
        # No ID provided → print all IDs, Actions, Statuses, Target Type, and Target Value
        echo "Listing all Rules (ID | Action | Status | Target Type | Target Value(s)):"
        echo "---"
        # Prepend the parser definition and call it directly.
        echo "$json" | jq -r "$target_value_parser"'
            .results[] | 
            (parse_target_value) as $target_val |
            "\(.id) | \(.action) | \(.status) | \(.target.type // "") | \($target_val | if . == "" then "NONE" else . end)"'
    fi

else
    # This block executes if $1 is empty (no argument provided) or invalid
    echo "MSP Rule Backup Tool (Version $version)"
    echo "Usage:"
    echo " 	$0 -j 	 	 # **J**SON: Save complete rule JSON objects to individual **.json** files, named by the rule's ID."
    echo " 	$0 -s <id> 	 # **S**earch: Show rule details (Action, Status, Target Type, etc.) for a specific ID."
    echo " 	$0 -s 	 	 # **S**earch: List all rule IDs and key details."
fi
