#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Interactive install script for groq-api

echo -e "${BLUE}[groq-api] Starting installation...${NC}"

# Check for global apikeys.json in /home/$USER/apikeys.json
GLOBAL_APIKEYS="/home/$USER/apikeys.json"
if [ -f "$GLOBAL_APIKEYS" ]; then
    echo -e "${GREEN}[groq-api] Found global apikeys.json at $GLOBAL_APIKEYS. Using it.${NC}"
    cp "$GLOBAL_APIKEYS" apikeys.json
else
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

    # Create apikeys.json
    cat > apikeys.json <<EOF
[
$(for i in "${!APIKEYS[@]}"; do
    printf '  {"key": "%s"}%s\n' "${APIKEYS[$i]}" $( [[ $i -lt $((${#APIKEYS[@]}-1)) ]] && echo "," )
done)
]
EOF
    echo -e "${GREEN}[groq-api] apikeys.json created.${NC}"
fi

# Ask if service should be installed
read -p "Do you want to install groq-api as a systemd service? (y/n): " INSTALL_SERVICE

# Create venv if not exists
if [ ! -d "venv" ]; then
    echo -e "${BLUE}[groq-api] Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Upgrade pip and install dependencies (suppress output, show spinner)
echo -en "${BLUE}[groq-api] Installing dependencies...${NC} "
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1 && echo -e "${GREEN}done${NC}"

# Debug test run
echo -e "${BLUE}[groq-api] Running debug test (starting server in background)...${NC}"
nohup venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --reload > debug.log 2>&1 &
SERVER_PID=$!
sleep 5
python3 test_proxy.py || echo -e "${RED}[groq-api] Test failed. Check debug.log for details.${NC}"
kill $SERVER_PID || true

# Install service if requested
echo -e "${GREEN}[groq-api] Installation complete.${NC}"
if [[ "$INSTALL_SERVICE" =~ ^[Yy]$ ]]; then
    bash install-service.sh
fi
