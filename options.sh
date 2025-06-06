#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo -e "${BLUE}groq-api options:${NC}"
    echo "1) Update API keys (apikeys.json)"
    echo "2) Test the API proxy (interactive)"
    echo "3) Show API key usage information"
    echo "4) Backup DB and API keys to ~/groq-api-backup/"
    echo "5) Add a new model to the DB"
    echo "6) Uninstall groq-api and clean up"
    echo "7) Exit"
}

update_apikeys() {
    echo -e "${YELLOW}[groq-api] This will update your apikeys.json file.${NC}"
    if [ -f apikeys.json ]; then
        echo -e "${YELLOW}[groq-api] Existing apikeys.json found. Backing up to apikeys.json.bak...${NC}"
        cp apikeys.json apikeys.json.bak
    fi
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
        return
    fi
    while true; do
        read -p "Enter a custom local API key for test.sh (used as Authorization header, cannot be empty): " CUSTOM_API_KEY
        if [[ -n "$CUSTOM_API_KEY" ]]; then
            break
        else
            echo -e "${RED}Custom local API key cannot be empty. Please enter a value.${NC}"
        fi
    done
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
}

test_proxy() {
    # Create systemprompt.txt with a default system prompt if it doesn't exist
    if [ ! -f systemprompt.txt ]; then
        echo "You are a helpful, polite, and knowledgeable AI assistant. Answer as helpfully and concisely as possible." > systemprompt.txt
        echo -e "${YELLOW}[groq-api] Created systemprompt.txt with default system prompt.${NC}"
    fi
    if [ -f apikeys.json ]; then
        API_KEY=$(python3 -c "import json; print(json.load(open('apikeys.json'))['custom_local_api_key'])")
    else
        echo -e "${YELLOW}[groq-api] apikeys.json not found. Please run install.sh to create it.${NC}"
        return
    fi
    read -p "Enter the API server IP and port (default: localhost:8000): " API_SERVER
    if [ -z "$API_SERVER" ]; then
        API_SERVER="localhost:8000"
    fi
    MODEL=""
    while [[ -z "$MODEL" ]]; do
        read -p "Enter the model to use for the test (e.g. test, auto, smart, etc.): " MODEL
    done
    read -p "Enter your prompt/question: " PROMPT
    SYSTEMPROMPT=$(cat systemprompt.txt)
    cat <<EOF > test_input.json
{
  "messages": [
    {
      "role": "system",
      "content": "$SYSTEMPROMPT"
    },
    {
      "role": "user",
      "content": "$PROMPT"
    }
  ],
  "model": "$MODEL"
}
EOF
    RESPONSE=$(curl -s -X POST http://$API_SERVER/chat/completions \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d @test_input.json)
    rm -f test_input.json
    echo -e "${GREEN}[groq-api] Response:${NC}"
    echo "$RESPONSE"
}

show_usage() {
    echo -e "${BLUE}[groq-api] API key usage information:${NC}"
    if [ ! -f apikeys.json ]; then
        echo -e "${RED}apikeys.json not found. Please run install.sh to create it.${NC}"
        return
    fi
    if [ ! -f apikeys.db ]; then
        echo -e "${YELLOW}No usage data found (apikeys.db missing).${NC}"
        return
    fi
    python3 - <<EOF
import json, sqlite3
from apikeymanager import MODEL_QUOTAS
with open('apikeys.json') as f:
    keys = json.load(f)['groq_keys']
conn = sqlite3.connect('apikeys.db')
c = conn.cursor()
print(f"{'Key':<16} {'Model':<24} {'Req/min':>8} {'Rem/min':>8} {'Tok/min':>10} {'RemTok/min':>10} {'Req/day':>8} {'Rem/day':>8} {'Tok/day':>10} {'RemTok/day':>10}")
for k in keys:
    apikey = k['key']
    for row in c.execute('SELECT model, requests_minute, tokens_minute, requests_today, tokens_today FROM apikey_usage WHERE apikey=?', (apikey,)):
        model, req_min, tok_min, req_day, tok_day = row
        quotas = MODEL_QUOTAS.get(model, {})
        max_req_min = quotas.get('max_requests_per_minute', 0)
        max_tok_min = quotas.get('max_tokens_per_minute', 0)
        max_req_day = quotas.get('max_requests_per_day', 0)
        max_tok_day = quotas.get('max_tokens_per_day', 0)
        rem_req_min = max_req_min - req_min
        rem_tok_min = max_tok_min - tok_min
        rem_req_day = max_req_day - req_day
        rem_tok_day = max_tok_day - tok_day
        print(f"{apikey[:12]}... {model:<24} {req_min:>8} {rem_req_min:>8} {tok_min:>10} {rem_tok_min:>10} {req_day:>8} {rem_req_day:>8} {tok_day:>10} {rem_tok_day:>10}")
conn.close()
EOF
}

backup_files() {
    BACKUP_DIR="$HOME/groq-api-backup"
    mkdir -p "$BACKUP_DIR"
    cp -v apikeys.json "$BACKUP_DIR/" 2>/dev/null || echo "apikeys.json not found."
    cp -v apikeys.db "$BACKUP_DIR/" 2>/dev/null || echo "apikeys.db not found."
    echo -e "${GREEN}[groq-api] Backup complete. Files saved to $BACKUP_DIR${NC}"
}

add_model() {
    echo -e "${YELLOW}[groq-api] Add a new model to the DB (apikeymanager.py)${NC}"
    read -p "Model name: " MODEL
    read -p "Max requests per day (enter - for no limit): " MAX_REQ_DAY
    read -p "Max requests per minute (enter - for no limit): " MAX_REQ_MIN
    read -p "Max tokens per minute (enter - for no limit): " MAX_TOK_MIN
    read -p "Max tokens per day (enter - for no limit): " MAX_TOK_DAY
    # Convert '-' to None in Python
    python3 - <<EOF
import sys
import os
import re
file = 'apikeymanager.py'
def parse_limit(val):
    return 'None' if val.strip() == '-' else val.strip()
with open(file, 'r', encoding='utf-8') as f:
    code = f.read()
pattern = r'MODEL_QUOTAS\\s*=\\s*{'
match = re.search(pattern, code)
if not match:
    print('MODEL_QUOTAS not found!')
    sys.exit(1)
insert_idx = code.find('}', code.find('MODEL_QUOTAS'))
model_entry = f'    "{MODEL}": {{\n        "max_requests_per_day": {parse_limit("""$MAX_REQ_DAY""")},\n        "max_requests_per_minute": {parse_limit("""$MAX_REQ_MIN""")},\n        "max_tokens_per_minute": {parse_limit("""$MAX_TOK_MIN""")},\n        "max_tokens_per_day": {parse_limit("""$MAX_TOK_DAY""")}\n    }},\n'
code = code[:insert_idx] + model_entry + code[insert_idx:]
with open(file, 'w', encoding='utf-8') as f:
    f.write(code)
print(f"Added model {MODEL} to apikeymanager.py")
EOF
}

uninstall_groq() {
    read -p "Are you sure you want to uninstall and delete everything? Type YES to confirm: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo -e "${RED}Uninstall cancelled.${NC}"
        return
    fi
    echo -e "${YELLOW}[groq-api] Uninstalling and cleaning up...${NC}"
    SERVICE_NAME=groq-api
    WORKDIR=$(pwd)
    if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
        echo -e "${YELLOW}[groq-api] Stopping and disabling systemd service...${NC}"
        sudo systemctl stop $SERVICE_NAME || true
        sudo systemctl disable $SERVICE_NAME || true
        sudo rm -f /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
    fi
    if [ -d "venv" ]; then
        echo -e "${YELLOW}[groq-api] Removing virtual environment...${NC}"
        rm -rf venv
    fi
    if [ -f "apikeys.json" ]; then
        echo -e "${YELLOW}[groq-api] Removing apikeys.json...${NC}"
        rm -f apikeys.json
    fi
    if [ -f "debug.log" ]; then
        echo -e "${YELLOW}[groq-api] Removing debug.log...${NC}"
        rm -f debug.log
    fi
    if [ -d "__pycache__" ]; then
        echo -e "${YELLOW}[groq-api] Removing __pycache__...${NC}"
        rm -rf __pycache__
    fi
    PARENT_DIR=$(dirname "$WORKDIR")
    FOLDER_NAME=$(basename "$WORKDIR")
    if [ "$FOLDER_NAME" = "groq-api" ]; then
        cd "$PARENT_DIR"
        echo -e "${RED}[groq-api] Removing project folder $FOLDER_NAME...${NC}"
        rm -rf "$FOLDER_NAME"
    fi
    echo -e "${GREEN}[groq-api] Uninstallation complete.${NC}"
}

while true; do
    show_menu
    read -p "Select an option [1-7]: " opt
    case $opt in
        1) update_apikeys ; exit 0 ;;
        2) test_proxy ; exit 0 ;;
        3) show_usage ; exit 0 ;;
        4) backup_files ; exit 0 ;;
        5) add_model ; exit 0 ;;
        6) uninstall_groq ; exit 0 ;;
        7) exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}" ; exit 1 ;;
    esac
done
