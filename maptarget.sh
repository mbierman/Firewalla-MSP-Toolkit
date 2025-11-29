#!/bin/bash
version="3.9"

# --- Configuration Variables ---
MSP=""         # the first part of the MSP URL (exlude the "firewalla.net" portion
token="Token " # your MSP Token
backuppath=""  # The path you wnt to save to
# --- End Configuration Variables ---

# Explicitly declare global variables used in the main script body
declare json=""
delclare owner=""
declare active_owner=""
declare display_owner=""
declare owner_override_value=""
declare owner_override_friendly_name=""
declare input_name=""
declare resolved_id=""
declare display_for_confirmation=""

# --- Friendly Name Mappings (BASH 3.2 CASE STATEMENT - COMBINED) ---
# Use https://kaleb.firewalla.net/api/docs/api-reference/box/ to get the IDs 
get_owner_map_id() {
    local friendly_name="$1"
    
    case "$friendly_name" in
        # Combined case for names sharing the same GUID
		# Edit the names  below and put the GUID of each box on the pirntf line. You can add all your MSP boxes. 
		# "default" should only be used once. 
         "Gold Plus Home" | "default")
            printf '%s' "25509ec0..."
            return 0
            ;;
        "Gold Work")
            printf '%s' "51f86711..." 
            return 0
            ;;
        "Support Purple")
            printf '%s' "45100000..."
            return 0
            ;;
        *)
            return 1 
            ;;
    esac
}

# --- Hardcoded list of names for error/help messages ---
AVAILABLE_NAMES="Gold Plus Home, Gold Work, silver, default"
# --- End Mappings ---

# --- Function to Resolve and Validate Owner ID ---
resolve_owner() {
    local input_owner="$1"
    
    if [[ "$(echo "$input_owner" | tr '[:upper:]' '[:lower:]')" == "global" ]]; then
        printf '%s' "global"
        return 0
    fi
    
    local mapped_id=$(get_owner_map_id "$input_owner")
    if [ "$?" -eq 0 ] && [[ -n "$mapped_id" ]]; then
        printf '%s' "$mapped_id"
        return 0
    fi
    
    if [[ "$input_owner" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        printf '%s' "$input_owner"
        return 0
    fi

    return 1
}

# --- Function to Map GUID back to Friendly Name (used for all output) ---
get_display_name() {
    local guid="$1"
    
    if [[ "$guid" == "global" ]]; then
        printf '%s' "global"
        return
    fi
    
    # Surgical fix for display priority: If the GUID matches the shared GUID, ensure Gold Plus Home is returned.
    local gold_plus_guid=$(get_owner_map_id "Gold Plus Home")
    if [[ "$guid" == "$gold_plus_guid" ]]; then
        printf '%s' "Gold Plus Home"
        return
    fi

    # Check other specific names
    local names_to_check="silver Gold Work"
    
    for name in $names_to_check; do
        local mapped_guid=$(get_owner_map_id "$name")
        if [[ "$mapped_guid" == "$guid" ]]; then
            printf '%s' "$name"
            return
        fi
    done

    # If it's still running and the GUID matches the default GUID, return 'default' 
    if [[ "$guid" == "$gold_plus_guid" ]]; then
        printf '%s' "default"
        return
    fi

    printf '%s' "$guid"
}

# --- Argument Pre-Processing: Handle Owner Override (-o) ---

arg_list=("$@")
temp_arg_list=("$@")
owner_index=-1
# Find the -o flag's position
for (( i=0; i < ${#temp_arg_list[@]}; i++ )); do
    if [[ "${temp_arg_list[i]}" == "-o" ]]; then
        owner_index=$i
        break
    fi
done

if (( owner_index >= 0 )); then
    if (( owner_index + 1 < ${#temp_arg_list[@]} )); then
        input_name="${temp_arg_list[owner_index+1]}"
        resolved_id=$(resolve_owner "$input_name") 
        
        if [ "$?" -eq 0 ]; then
            owner_override_value="$resolved_id"
            owner_override_friendly_name=$(get_display_name "$owner_override_value")
            
            # Remove -o and its argument from the array for the main case block
            if (( ${#arg_list[@]} > owner_index + 1 )); then
                unset 'arg_list[owner_index]'
                unset 'arg_list[owner_index+1]'
                arg_list=("${arg_list[@]}")
            fi
        else
            echo "Error: Unrecognized owner name or ID: '$input_name'" >&2
            echo "Available names: $AVAILABLE_NAMES, global" >&2
            exit 1
        fi
    fi
fi

# --- ROBUST OWNER SETTING & CONFIRMATION ---
if [[ -n "$owner_override_value" ]]; then
    
    display_for_confirmation="$input_name"
    
    if [[ "$input_name" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        display_for_confirmation="$owner_override_friendly_name"
    fi

    echo "Owner override detected: '$display_for_confirmation' (GUID: $owner_override_value)"
    
    owner="$owner_override_value"
fi
# --- END ROBUST OWNER SETTING ---

# --- End Argument Pre-Processing ---

# Function to handle API connection and data validation
fetch_data() {
    if [[ -z "$MSP" ]] ; then
        echo "Error: You need an MSP!"
        exit 1
    elif [[ -z "$token" ]] ; then
        echo "Error: You need your MSP token"
        exit 1
    fi

    # Set active_owner to the default GUID if no owner was overridden
    if [[ -z "$owner" ]]; then
        default_id=$(get_owner_map_id "default")
        if [[ -n "$default_id" ]]; then
            active_owner="$default_id"
        else
            active_owner="global" 
        fi
    else
        active_owner="$owner"
    fi
    
    local temp_display_owner
    temp_display_owner=$(get_display_name "$active_owner")
    
    if [[ -z "$temp_display_owner" ]]; then
        display_owner="$active_owner"
    else
        display_owner="$temp_display_owner"
    fi

    # *** FIXED: Consolidated fetch message ***
    echo "Fetching target lists for Active Owner: $display_owner from https://${MSP}.firewalla.net..."
    json=$(curl -sk "https://${MSP}.firewalla.net/v2/target-lists?owner=${active_owner}" \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json")
    
    if [ -z "$json" ]; then
        echo "Error: API call returned empty or failed. Check connectivity or token format."
        exit 1
    fi

    if echo "$json" | grep -q "Authentication failed"; then
        echo "Error: Authentication failed. Please verify your token/format (e.g., 'Token XXXX')."
        echo "Response details:"
        echo "$json" | jq .
        exit 1
    fi

    if ! echo "$json" | grep -q "^\["; then
        echo "Error: Unexpected response format. The API may have changed or failed."
        echo "Received first line: $(echo "$json" | head -n 1)"
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

case "${arg_list[0]}" in
    "-b")
        fetch_data 
        check_dir
        
        echo "Starting text backup of target lists for $display_owner to: $backuppath"
        
        current_id=""
        current_name=""
        current_content=""
        
        while IFS= read -r line; do
            if [ "$line" = "---END_OF_LIST---" ]; then
                if [ -n "$current_name" ]; then
                    filename=$(echo "$current_name" | tr ' /' '_-')
                    filepath="$backuppath/$filename.txt"
                    
                    echo "Backing up TXT: $current_name"
                    
                    if [ -n "$current_content" ]; then
                        clean_content=${current_content%$'\n'}
                        final_content="#ID:$current_id"$'\n'"$clean_content"
                    else
                        final_content="#ID:$current_id"
                    fi

                    echo "$final_content" > "$filepath"
                    
                    current_id=""
                    current_name=""
                    current_content=""
                fi

            elif [ -z "$current_id" ]; then
                current_id="$line"

            elif [ -z "$current_name" ]; then
                current_name="$line"

            else
                current_content="$current_content$line"$'\n'
            fi
        done < <(echo "$json" | jq -r '.[] | .id, .name, (.targets | .[]), "---END_OF_LIST---"')

        echo "Text backup complete! ✅"
        ;;

    "-j")
        fetch_data 
        check_dir
        
        echo "Starting JSON backup of target lists for $display_owner to: $backuppath"

        echo "$json" | jq -r -c '.[] | .name, @json' |
        while IFS= read -r line; do
            if [ -z "$current_name" ]; then
                current_name="$line"
            else
                filename=$(echo "$current_name" | tr ' /' '_-')
                filepath="$backuppath/$filename.json"

                echo "Backing up JSON: $current_name"

                echo "$line" | jq '.' > "$filepath"
                
                current_name=""
            fi
        done

        echo "JSON backup complete! ✅"
        ;;

    "-s")
        fetch_data 

        # *** FIXED: Removed the redundant 'echo "Active Owner: $display_owner"' line ***
        echo "---"

        list_id_arg="${arg_list[1]}"

        if [ "$list_id_arg" ]; then
            list_id="$list_id_arg"
            
            result=$(echo "$json" | jq -r '[.[] | select(.id=="'"$list_id"'") | .name, (.targets | join("\n"))] | @tsv')
            
            if [ -z "$result" ]; then
                echo "Error: No target list found for ID: $list_id"
            else
                IFS=$'\t' read -r list_name targets <<< "$result"
                
                final_name=${list_name:-NONE}
                final_targets=${targets:-NONE}

                echo "Name: $final_name"
                echo "Contents:" 
                
                if [ "$final_targets" = "NONE" ]; then
                    echo ""
                else
                    echo -e "$targets"
                fi
            fi
            
        else
            echo "Listing all Target Lists (Name | ID):"
            echo "---"
            echo "$json" | jq -r '.[] | "\(.name) | \(.id)"'
        fi
        ;;

    "-o")
        if [[ -n "$owner_override_value" ]]; then
            echo "Owner ID set to: '$display_for_confirmation' ($owner_override_value)"
        else
            echo "Error: The -o option requires an owner name or ID to be provided."
            echo "Example: $0 -o 'Gold Plus Home'"
            exit 1
        fi
        ;;

    *)
        # Default help menu
        echo "MSP Target List Tool (Version $version)"
        echo "Usage:"
        echo "  ${0##*/} -b [-o <owner_name|id>]      # Backup: Save targets to .txt files."
        echo "  ${0##*/} -j [-o <owner_name|id>]      # JSON: Save complete list JSON objects to .json files."
        echo "  ${0##*/} -s <id> [-o <owner_name|id>] # Show the Name and Contents of a specific list."
        echo "  ${0##*/} -s [-o <owner_name|id>]      # Show/list all target list IDs and Names (Name | ID)."
        echo "   Names available: $AVAILABLE_NAMES, global"
        ;;  
esac
