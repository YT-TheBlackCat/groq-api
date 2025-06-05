#!/bin/bash
# uninstall.sh: Remove groq-api installation, venv, apikeys, and service
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_NAME=groq-api
WORKDIR=$(pwd)

# Stop and disable the systemd service if it exists
if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
    echo -e "${YELLOW}[groq-api] Stopping and disabling systemd service...${NC}"
    sudo systemctl stop $SERVICE_NAME || true
    sudo systemctl disable $SERVICE_NAME || true
    sudo rm -f /etc/systemd/system/$SERVICE_NAME.service
    sudo systemctl daemon-reload
fi

# Remove venv
if [ -d "venv" ]; then
    echo -e "${YELLOW}[groq-api] Removing virtual environment...${NC}"
    rm -rf venv
fi

# Remove apikeys.json
if [ -f "apikeys.json" ]; then
    echo -e "${YELLOW}[groq-api] Removing apikeys.json...${NC}"
    rm -f apikeys.json
fi

# Remove debug log
if [ -f "debug.log" ]; then
    echo -e "${YELLOW}[groq-api] Removing debug.log...${NC}"
    rm -f debug.log
fi

# Remove __pycache__
if [ -d "__pycache__" ]; then
    echo -e "${YELLOW}[groq-api] Removing __pycache__...${NC}"
    rm -rf __pycache__
fi

# Remove the entire groq-api project folder if running from within it
PARENT_DIR=$(dirname "$WORKDIR")
FOLDER_NAME=$(basename "$WORKDIR")
if [ "$FOLDER_NAME" = "groq-api" ]; then
    cd "$PARENT_DIR"
    echo -e "${RED}[groq-api] Removing project folder $FOLDER_NAME...${NC}"
    rm -rf "$FOLDER_NAME"
fi

echo -e "${GREEN}[groq-api] Uninstallation complete.${NC}"
