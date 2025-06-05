#!/bin/bash
set -e

# Interactive install script for groq-api

echo "[groq-api] Starting installation..."

# Ask for multiple API keys
APIKEYS=()
echo "Enter your Groq API keys (one per line). Leave empty and press Enter to finish:"
while true; do
    read -p "API Key: " key
    if [[ -z "$key" ]]; then
        break
    fi
    APIKEYS+=("$key")
done

if [[ ${#APIKEYS[@]} -eq 0 ]]; then
    echo "No API keys entered. Exiting."
    exit 1
fi

# Ask if service should be installed
read -p "Do you want to install groq-api as a systemd service? (y/n): " INSTALL_SERVICE

# Create venv if not exists
if [ ! -d "venv" ]; then
    echo "[groq-api] Creating virtual environment..."
    python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create apikeys.json
cat > apikeys.json <<EOF
[
$(for i in "${!APIKEYS[@]}"; do
    printf '  {"key": "%s"}%s\n' "${APIKEYS[$i]}" $( [[ $i -lt $((${#APIKEYS[@]}-1)) ]] && echo "," )
done)
]
EOF

echo "[groq-api] apikeys.json created."

# Debug test run
echo "[groq-api] Running debug test (starting server in background)..."
nohup venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --reload > debug.log 2>&1 &
SERVER_PID=$!
sleep 5
python3 test_proxy.py || echo "[groq-api] Test failed. Check debug.log for details."
kill $SERVER_PID || true

# Install service if requested
echo "[groq-api] Installation complete."
if [[ "$INSTALL_SERVICE" =~ ^[Yy]$ ]]; then
    bash install-service.sh
fi
