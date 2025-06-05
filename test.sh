#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create systemprompt.txt with a default system prompt if it doesn't exist
default_prompt="You are a helpful, polite, and knowledgeable AI assistant. Answer as helpfully and concisely as possible."
if [ ! -f systemprompt.txt ]; then
    echo "$default_prompt" > systemprompt.txt
    echo -e "${YELLOW}[groq-api] Created systemprompt.txt with default system prompt.${NC}"
fi

read -p "Enter the model to use for the test (e.g. test, auto, smart, etc.): " MODEL
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

echo -e "${YELLOW}[groq-api] Sending test request...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer lassetestapi" \
  -H "Content-Type: application/json" \
  -d @test_input.json)

rm -f test_input.json

echo -e "${GREEN}[groq-api] Response:${NC}"
echo "$RESPONSE"
