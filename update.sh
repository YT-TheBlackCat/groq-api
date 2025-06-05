#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SERVICE_NAME=groq-api
EXCLUDE="apikeys.json version.txt"
UPDATED=0
CHANGED_FILES=()

# Get remote repo URL and branch
REMOTE_URL=$(git config --get remote.origin.url)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# Fetch latest from remote
if git ls-remote --exit-code origin HEAD &>/dev/null; then
    git fetch origin $BRANCH
else
    echo -e "${RED}[groq-api] No remote git repository found. Cannot update.${NC}"
    exit 1
fi

# Get list of tracked files in remote branch
REMOTE_FILES=$(git ls-tree -r --name-only origin/$BRANCH)

# Compare and update files, and add new files
for file in $REMOTE_FILES; do
    skip=0
    for ex in $EXCLUDE; do
        if [[ "$file" == "$ex" ]]; then
            skip=1
            break
        fi
    done
    if [[ $skip -eq 1 ]]; then
        continue
    fi
    # Download remote file to temp
    TMPFILE=$(mktemp)
    git show origin/$BRANCH:$file > "$TMPFILE" 2>/dev/null || continue
    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}[groq-api] Adding new file $file...${NC}"
        cp "$TMPFILE" "$file"
        UPDATED=1
        CHANGED_FILES+=("$file (new)")
    elif ! cmp -s "$file" "$TMPFILE"; then
        echo -e "${YELLOW}[groq-api] Updating $file...${NC}"
        git checkout origin/$BRANCH -- "$file"
        UPDATED=1
        CHANGED_FILES+=("$file")
    fi
    rm -f "$TMPFILE"
done

# Save current commit hash as version
VERSION=$(git rev-parse origin/$BRANCH)
echo "$VERSION" > version.txt

if [[ $UPDATED -eq 1 ]]; then
    echo -e "${GREEN}[groq-api] Update complete. The following files were updated:${NC}"
    for f in "${CHANGED_FILES[@]}"; do
        echo -e "  ${GREEN}$f${NC}"
    done
    echo -e "${GREEN}[groq-api] Service restarting...${NC}"
    sudo systemctl restart $SERVICE_NAME
    echo -e "${GREEN}[groq-api] Service restarted. Please check status with: sudo systemctl status $SERVICE_NAME${NC}"
else
    echo -e "${YELLOW}[groq-api] All files are already up to date. No changes made.${NC}"
fi

