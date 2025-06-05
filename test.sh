#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create systemprompt.txt with a default system prompt if it doesn't exist
if [ ! -f systemprompt.txt ]; then
    echo "You are a helpful, polite, and knowledgeable AI assistant. Answer as helpfully and concisely as possible." > systemprompt.txt
    echo -e "${YELLOW}[groq-api] Created systemprompt.txt with default system prompt.${NC}"
fi

# Read custom_local_api_key from apikeys.json
if [ -f apikeys.json ]; then
    API_KEY=$(python3 -c "import json; print(json.load(open('apikeys.json'))['custom_local_api_key'])")
else
    echo -e "${YELLOW}[groq-api] apikeys.json not found. Using default API key.${NC}"
    API_KEY="lassetestapi"
fi

# Ask for API server IP (default: localhost:8000)
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
