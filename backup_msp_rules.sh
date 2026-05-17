#!/bin/bash
version="2.0" 

MSP="MSPNAME" # The first part of the MSP URL
token="Token " # The MSP token. leave the Token portion
backuppath="where you want the backup to go" # The base path to save the rules
default_gid="" # default box (if you have more than one box put the GID of the box here. 

# --- End Configuration Variables ---

# Global variables to hold the fetched JSON data
json="" 
boxes_json=""

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

    # 1. Fetch Boxes first to map GIDs to Names
    echo "Fetching boxes from https://${MSP}.firewalla.net/v2/boxes..."
    boxes_json=$(curl -sk --location "https://${MSP}.firewalla.net/v2/boxes" \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json")

    if [ -z "$boxes_json" ] || echo "$boxes_json" | grep -q "Authentication failed"; then
        echo "Error: Failed to fetch boxes. Check connectivity or token format."
        exit 1
    fi

    # 2. Fetch Rules
    echo "Fetching rules from https://${MSP}.firewalla.net/v2/rules..."
    json=$(curl -sk --location "https://${MSP}.firewalla.net/v2/rules" \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json")
    
    # --- API Error and JSON Validation ---
    if [ -z "$json" ]; then
        echo "Error: API call returned empty or failed. Check connectivity or token format."
        exit 1
    fi

    if echo "$json" | grep -q "Authentication failed"; then
        echo "Error: Authentication failed. Please verify your token/format."
        exit 1
    fi

    if ! echo "$json" | jq -e '.results | arrays' > /dev/null; then
        echo "Error: Unexpected response format. The JSON does not contain a top-level 'results' array."
        exit 1
    fi
} 

# Function to resolve GID to a safe folder name
get_box_folder_name() {
    local gid="$1"
    
    if [[ -z "$gid" || "$gid" == "global" ]]; then
        echo "global"
        return
    fi

    # Try matching assuming the response is nested under .results or direct array
    local box_name
    box_name=$(echo "$boxes_json" | jq -r --arg gid "$gid" '
        if type == "array" then 
            .[] | select(.gid == $gid) | .name
        elif type == "object" and .results then 
            .results[] | select(.gid == $gid) | .name
        else 
            empty 
        end' 2>/dev/null)

    # Fall back to GID if name mapping isn't found in the API results
    if [[ -z "$box_name" || "$box_name" == "null" ]]; then
        echo "$gid"
    else
        # 1. xargs strips out outer leading/trailing whitespaces cleanly
        # 2. sed replaces any internal remaining space or tab clusters with a single underscore
        # 3. tr -cd strips out remaining non-filesystem-safe characters
        echo "$box_name" | xargs | sed 's/[[:space:]]\+/_/g' | tr -cd '[:alnum:]_-'
    fi
}

# Function to check and create a specific directory path dynamically
check_dir() {
    local target_dir="$1"
    if [[ -z "$target_dir" ]] ; then
        echo "Error: Directory path is empty."
        exit 1
    fi
    
    if [ ! -d "$target_dir" ] ; then
        mkdir -p "$target_dir"
        echo "Directory created: $target_dir"
    fi
} 

# --- Main Command Handling ---

if [ "$1" = "-j" ]; then
    fetch_data # Load data before backup
    
    # Check if user explicitly called for all boxes or if we fall back to the default box
    if [ "$2" = "--all" ]; then
        echo "Starting JSON backup of rules for ALL boxes..."
        
        # JQ output: Prints the rule's box GID, the rule ID, followed by the compacted JSON object.
        echo "$json" | jq -r -c '.results[] | (.gid // "global"), .id, @json' |
        while IFS= read -r rule_box_gid; do
            read -r current_id
            read -r line
            
            # Map GID to Name for folder creation
            folder_name=$(get_box_folder_name "$rule_box_gid")
            target_dir="$backuppath/$folder_name"
            check_dir "$target_dir"
            
            filepath="$target_dir/$current_id.json"
            echo "Backing up Rule: $current_id to folder: $folder_name"
            echo "$line" | jq '.' > "$filepath"
        done
    else
        # Backup only the defined default box rules
        if [[ -z "$default_gid" || "$default_gid" == "YOUR_DEFAULT_BOX_GID_HERE" ]]; then
            echo "Error: Default GID is not configured. Please define 'default_gid' variable or pass '--all'."
            exit 1
        fi
        
        # Map default GID to name for the folder
        folder_name=$(get_box_folder_name "$default_gid")
        target_dir="$backuppath/$folder_name"
        check_dir "$target_dir"
        
        echo "Starting JSON backup of rules filtered by default box: $folder_name ($default_gid)"
        
        # JQ output: Filters results natively to only match the default box GID
        echo "$json" | jq -r -c --arg def_gid "$default_gid" '.results[] | select(.gid == $def_gid) | .id, @json' |
        while IFS= read -r line; do
            if [ -z "$current_id" ]; then
                current_id="$line"
            else
                filepath="$target_dir/$current_id.json"
                echo "Backing up default box JSON: $current_id"
                echo "$line" | jq '.' > "$filepath"
                current_id="" # Reset
            fi
        done
    fi

    echo "JSON backup complete! ✅"

elif [ "$1" = "-s" ]; then
    fetch_data # Load data before search
    ## 🔎 Search Logic: Rules by ID

    # Define the parser logic as a single-line string. We will now prepend this as a 'def' in the jq command.
    target_value_parser='def parse_target_value: .target.value as $val | if $val == null then "" elif ($val | type) == "array" then ($val | join(", ")) elif ($val | type) == "object" then ($val | to_entries | .[].value | join(", ")) else ($val // "") end;'
    
    if [ "$2" ] && [ "$2" != "--all" ]; then
        rule_id="$2"
        
        # JQ filter: Select the rule by ID and format the output as TSV
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
        echo "$json" | jq -r "$target_value_parser"'
            .results[] | 
            (parse_target_value) as $target_val |
            "\(.id) | \(.action) | \(.status) | \(.target.type // "") | \($target_val | if . == "" then "NONE" else . end)"'
    fi

else
# This block executes if $1 is empty (no argument provided) or invalid
    echo "MSP Rule Backup Tool (Version $version)"
    echo "Usage:"
    echo "    $0 -j              # Backup rules only for the configured default box GID ($default_gid)"
    echo "    $0 -j --all        # Backup all rules, sorting them into separate folders named by Box Name."
    echo "    $0 -s <id>         # Search: Show rule details for a specific ID."
    echo "    $0 -s              # Search: List all rule IDs and key details."
fi
