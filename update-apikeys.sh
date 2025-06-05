#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Interactive script to reconfigure apikeys.json for groq-api

echo -e "${YELLOW}[groq-api] This will update your apikeys.json file.${NC}"
if [ -f apikeys.json ]; then
    echo -e "${YELLOW}[groq-api] Existing apikeys.json found. Backing up to apikeys.json.bak...${NC}"
    cp apikeys.json apikeys.json.bak
fi

# Ask for multiple API keys
APIKEYS=()
echo -e "${YELLOW}Enter your Groq API keys (one per line). Leave empty and press Enter to finish:${NC}"
while true; do
    read -p "API Key: " key
    if [[ -z "$key" ]]; then
        break
    fi
    APIKEYS+=("$key")
done

if [[ ${#APIKEYS[@]} -eq 0 ]]; then
    echo -e "${RED}No API keys entered. Exiting.${NC}"
    exit 1
fi

# Ask for custom local API key for test.sh
while true; do
    read -p "Enter a custom local API key for test.sh (used as Authorization header, cannot be empty): " CUSTOM_API_KEY
    if [[ -n "$CUSTOM_API_KEY" ]]; then
        break
    else
        echo -e "${RED}Custom local API key cannot be empty. Please enter a value.${NC}"
    fi
done

# Create apikeys.json with custom local API key
cat > apikeys.json <<EOF
{
  "custom_local_api_key": "$CUSTOM_API_KEY",
  "groq_keys": [
$(for i in "${!APIKEYS[@]}"; do
    printf '    {"key": "%s"}%s\n' "${APIKEYS[$i]}" $( [[ $i -lt $((${#APIKEYS[@]}-1)) ]] && echo "," )
done)
  ]
}
EOF
echo -e "${GREEN}[groq-api] apikeys.json updated successfully.${NC}"

