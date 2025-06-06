#!/bin/bash
set -e

# --- Modern CLI for groq-api ---
# Usage: ./options.sh [command] [options]
# Run with --help for usage info

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERSION="1.0.0"

# Requirements check (auto-install pip/venv if missing)
function check_requirements() {
    command -v python3 >/dev/null || { echo -e "${RED}Python3 is required!${NC}"; exit 1; }
    command -v pip >/dev/null || { echo -e "${YELLOW}pip not found. Installing...${NC}"; python3 -m ensurepip --upgrade; }
    command -v virtualenv >/dev/null || pip install virtualenv
}

function usage() {
    echo -e "${BLUE}groq-api CLI v$VERSION${NC}"
    echo "Usage: $0 [command]"
    echo "Commands:"
    echo "  menu           Interactive menu (default if no command)"
    echo "  update-keys    Update API keys (interactive)"
    echo "  test           Test the API proxy (interactive)"
    echo "  usage          Show API key usage information"
    echo "  backup         Backup DB and API keys to ~/groq-api-backup/"
    echo "  add-model      Add a new model to the DB"
    echo "  uninstall      Uninstall groq-api and clean up"
    echo "  status         Show service and DB status"
    echo "  reset-usage    Reset usage counters for a key/model to a value"
    echo "  tools          List all available tools/commands"
    echo "  --help         Show this help message"
    echo "  --version      Show version"
}

function show_status() {
    echo -e "${BLUE}[groq-api] Status:${NC}"
    systemctl status groq-api --no-pager || echo -e "${YELLOW}Service not found.${NC}"
    [ -f apikeys.json ] && echo -e "${GREEN}apikeys.json present${NC}" || echo -e "${RED}apikeys.json missing${NC}"
    [ -f apikeys.db ] && echo -e "${GREEN}apikeys.db present${NC}" || echo -e "${RED}apikeys.db missing${NC}"
}

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
    # Also add the limits for all models for these keys (like on install)
    echo -e "${BLUE}[groq-api] Pre-populating apikeys.db with all models and API keys...${NC}"
    python3 -c "import apikeymanager; apikeymanager.init_db_with_limits()"
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
def show_usage():
    print(f"[groq-api] API key usage information:")
    import json, sqlite3
    from apikeymanager import MODEL_QUOTAS
    with open('apikeys.json') as f:
        keys = json.load(f)['groq_keys']
    conn = sqlite3.connect('apikeys.db')
    c = conn.cursor()
    # Gather all rows to determine max model name length and number widths
    rows = []
    max_model_len = len('Model')
    max_key_len = len('Key')
    max_vals = [len(h) for h in ['Req/min','Rem/min','Tok/min','RemTok/min','Req/day','Rem/day','Tok/day','RemTok/day']]
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
            key_disp = apikey[:12]+'...'
            max_key_len = max(max_key_len, len(key_disp))
            max_model_len = max(max_model_len, len(model))
            vals = [req_min, rem_req_min, tok_min, rem_tok_min, req_day, rem_req_day, tok_day, rem_tok_day]
            for i, v in enumerate(vals):
                max_vals[i] = max(max_vals[i], len(str(v)))
            rows.append((key_disp, model, *vals))
    # Print header
    print(f"{'Key':<{max_key_len}} {'Model':<{max_model_len}} " +
          f" {'Req/min':>{max_vals[0]}} {'Rem/min':>{max_vals[1]}} {'Tok/min':>{max_vals[2]}} {'RemTok/min':>{max_vals[3]}} " +
          f"{'Req/day':>{max_vals[4]}} {'Rem/day':>{max_vals[5]}} {'Tok/day':>{max_vals[6]}} {'RemTok/day':>{max_vals[7]}}")
    for row in rows:
        key_disp, model, *vals = row
        print(f"{key_disp:<{max_key_len}} {model:<{max_model_len}} " +
              " ".join(f"{v:>{w}}" for v, w in zip(vals, max_vals)))
    conn.close()
show_usage()
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
    export MODEL MAX_REQ_DAY MAX_REQ_MIN MAX_TOK_MIN MAX_TOK_DAY
    python3 - <<EOF
import sys
import os
import re
file = 'apikeymanager.py'
def parse_limit(val):
    if val is None or val.strip() == '' or val.strip() == '-':
        return '0'
    return val.strip()
MODEL = os.environ.get('MODEL')
MAX_REQ_DAY = os.environ.get('MAX_REQ_DAY')
MAX_REQ_MIN = os.environ.get('MAX_REQ_MIN')
MAX_TOK_MIN = os.environ.get('MAX_TOK_MIN')
MAX_TOK_DAY = os.environ.get('MAX_TOK_DAY')
with open(file, 'r', encoding='utf-8') as f:
    code = f.read()
pattern = r'MODEL_QUOTAS\\s*=\\s*{'
match = re.search(pattern, code)
if not match:
    print('MODEL_QUOTAS not found!')
    sys.exit(1)
insert_idx = code.find('}', code.find('MODEL_QUOTAS'))
model_entry = f'    "{MODEL}": {{\n        "max_requests_per_day": {parse_limit(MAX_REQ_DAY)},\n        "max_requests_per_minute": {parse_limit(MAX_REQ_MIN)},\n        "max_tokens_per_minute": {parse_limit(MAX_TOK_MIN)},\n        "max_tokens_per_day": {parse_limit(MAX_TOK_DAY)}\n    }},\n'
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

reset_usage_for_key_model() {
    echo -e "${YELLOW}[groq-api] Reset usage for a specific API key and model${NC}"
    read -p "Enter the API key (full key): " APIKEY
    read -p "Enter the model name: " MODEL
    read -p "Enter the value to reset all counters to (default 0): " VALUE
    if [ -z "$VALUE" ]; then VALUE=0; fi
    python3 -c "import apikeymanager; apikeymanager.reset_usage_for_key_model('$APIKEY', '$MODEL', int('$VALUE'))"
    echo -e "${GREEN}[groq-api] Usage counters reset for key $APIKEY and model $MODEL to $VALUE.${NC}"
}

list_tools() {
    echo -e "${BLUE}Available tools:${NC}"
    echo "  update-keys    Update API keys (interactive)"
    echo "  test           Test the API proxy (interactive)"
    echo "  usage          Show API key usage information"
    echo "  backup         Backup DB and API keys to ~/groq-api-backup/"
    echo "  add-model      Add a new model to the DB"
    echo "  uninstall      Uninstall groq-api and clean up"
    echo "  status         Show service and DB status"
    echo "  reset-usage    Reset usage counters for a key/model to a value"
    echo "  tools          List all available tools/commands"
    echo "  --help         Show this help message"
    echo "  --version      Show version"
}

# --- Argument parsing ---
if [[ "$1" == "--help" ]]; then usage; exit 0; fi
if [[ "$1" == "--version" ]]; then echo "$VERSION"; exit 0; fi
if [[ "$1" == "status" ]]; then show_status; exit 0; fi
if [[ "$1" == "update-keys" ]]; then update_apikeys; exit 0; fi
if [[ "$1" == "test" ]]; then test_proxy; exit 0; fi
if [[ "$1" == "usage" ]]; then show_usage; exit 0; fi
if [[ "$1" == "backup" ]]; then backup_files; exit 0; fi
if [[ "$1" == "add-model" ]]; then add_model; exit 0; fi
if [[ "$1" == "uninstall" ]]; then uninstall_groq; exit 0; fi
if [[ "$1" == "reset-usage" ]]; then reset_usage_for_key_model; exit 0; fi
if [[ "$1" == "tools" ]]; then list_tools; exit 0; fi

# Default: show menu
show_menu
while true; do
    read -p "Select an option [1-7]: " opt
    case $opt in
        1) update_apikeys ; exit 0 ;;
        2) test_proxy ; exit 0 ;;
        3) show_usage ; exit 0 ;;
        4) backup_files ; exit 0 ;;
        5) add_model ; exit 0 ;;
        6) uninstall_groq ; exit 0 ;;
        7) exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
    esac
done
