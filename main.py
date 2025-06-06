import os
import json
import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq
from apikeymanager import optimal_apikey, update_usage

APIKEYS_FILE = "apikeys.json"
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

# Helper to load API keys and usage
def load_apikeys():
    if not os.path.exists(APIKEYS_FILE):
        raise RuntimeError(f"{APIKEYS_FILE} not found. Please run install.sh to create it.")
    with open(APIKEYS_FILE, "r") as f:
        return json.load(f)

def get_local_api_key():
    if not os.path.exists(APIKEYS_FILE):
        raise RuntimeError(f"{APIKEYS_FILE} not found. Please run install.sh to create it.")
    with open(APIKEYS_FILE, "r") as f:
        return json.load(f).get("custom_local_api_key", "")

app = FastAPI()
API_KEY = get_local_api_key()

@app.post("/chat/completions")
async def proxy_chat_completions(request: Request):
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {API_KEY}":
        raise HTTPException(status_code=401, detail="Invalid API key")
    body = await request.json()
    # Change model if needed
    model = body.get("model")
    if model == "test":
        model = "allam-2-7b"
    elif model == "auto" or model == "fast":
        model = "llama-3.1-8b-instant"
    elif model == "smart":
        model = "llama3-70b-8192"
    elif model == "smart-long":
        model = "llama-3.3-70b-versatile"
    elif model == "reasoning":
        model = "deepseek-r1-distill-llama-70b"
    elif model == "reasoning2":
        model = "qwen-qwq-32b"
    else:
        raise HTTPException(status_code=400, detail="Invalid model specified")

    apikeys = [k["key"] for k in load_apikeys()["groq_keys"]]
    best_key = optimal_apikey(model, apikeys)
    if not best_key:
        raise HTTPException(status_code=429, detail="All API keys exhausted for this model.")

    # Print which key is used
    print(f"[groq-api] Using key: {best_key[:8]}... for model: {model}")

    client = Groq(api_key=best_key)
    try:
        chat_completion = client.chat.completions.create(
            messages=body.get("messages", []),
            model=model,
        )
        # Estimate token usage (very rough, for demo)
        prompt_tokens = sum(len(m.get("content", "")) for m in body.get("messages", []))
        completion_tokens = len(chat_completion.choices[0].message.content)
        total_tokens = prompt_tokens + completion_tokens
        update_usage(best_key, model, total_tokens)
        return JSONResponse(status_code=200, content={
            "choices": [
                {
                    "message": {
                        "role": chat_completion.choices[0].message.role,
                        "content": chat_completion.choices[0].message.content
                    }
                }
            ]
        })
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Groq error: {e}")
