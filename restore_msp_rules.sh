#!/bin/bash
# V 1.0

# ==========================================
# CONFIGURATION
# ==========================================
MSP_DOMAIN="YOURDOMAIN.firewalla.net"  # EDIT HERE
TOKEN="MSP_TOKEN"                      # EDIT HERE
BOX_ID="BOX_GID"                       # EDIT HERE

# ==========================================
# 1. DEFAULT TO SAFE (DRY RUN), -l TO GO LIVE
# ==========================================
DRY_RUN=true
files=()

# The script ONLY runs live if it sees "-l"
for arg in "$@"; do
    if [[ "$arg" == "-l" ]]; then
        DRY_RUN=false
    fi
done

# Collect the files, excluding the -l flag
for arg in "$@"; do
    if [[ "$arg" != "-l" && -f "$arg" ]]; then
        files+=("$arg")
    fi
done

# ==========================================
# 2. LIST MATCHING FILES
# ==========================================
echo "=========================================="
echo "🔍 Matching Files to Process:"
echo "=========================================="
for file in "${files[@]}"; do
    echo "  -> $file"
done

if [ ${#files[@]} -eq 0 ]; then
    echo "❌ No matching files found."
    exit 1
fi

# ==========================================
# 3 & 4. GENERATE CURL / EXECUTE RESPONSES
# ==========================================
echo -e "\n=========================================="
echo "🚀 Processing Commands (DRY_RUN=$DRY_RUN):"
echo "=========================================="

for file in "${files[@]}"; do
    # Strip unneeded keys, preserve/overwrite .gid with the exact $BOX_ID string per spec
    payload=$(jq --arg gid "$BOX_ID" 'del(.id, .ts, .updateTs, .hit, .bid) | .gid = $gid' "$file" 2>/dev/null)
    
    echo "# Target: $file"
    echo "curl -s -X POST \"https://$MSP_DOMAIN/v2/rules\" \\"
    echo "  -H \"Authorization: Token $TOKEN\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '$payload'"
    
    if [ "$DRY_RUN" = false ]; then
        echo "📡 Execution Output:"
        curl -s -X POST "https://$MSP_DOMAIN/v2/rules" \
          -H "Authorization: Token $TOKEN" \
          -H "Content-Type: application/json" \
          -d "$payload"
        echo -e "\n"
    else
        echo -e "# [SAFE] Dry run active. No network traffic sent.\n"
    fi
done
