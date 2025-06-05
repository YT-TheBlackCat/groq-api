#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE_NAME=groq-api
UPDATED=0
EXCLUDE="apikeys.json"

for file in *; do
    if [[ "$file" == "$EXCLUDE" ]] || [[ ! -f "$file" ]]; then
        continue
    fi
    if git ls-remote --exit-code origin HEAD &>/dev/null; then
        if git ls-files --error-unmatch "$file" &>/dev/null; then
            echo -e "${YELLOW}[groq-api] Updating $file...${NC}"
            git fetch origin
            git checkout origin/main -- "$file"
            UPDATED=1
        fi
    fi
    # If not using git, could add wget/curl logic here
    # For now, only git-based update is supported
    # echo "[groq-api] $file updated."
done

if [[ $UPDATED -eq 1 ]]; then
    echo -e "${GREEN}[groq-api] Update complete. Restarting service...${NC}"
    sudo systemctl restart $SERVICE_NAME
    echo -e "${GREEN}[groq-api] Service restarted. Please check status with: sudo systemctl status $SERVICE_NAME${NC}"
else
    echo -e "${YELLOW}[groq-api] No files updated. Either already up to date or not a git repo.${NC}"
fi
