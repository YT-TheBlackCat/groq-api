import os
import json
import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq

APIKEYS_FILE = "apikeys.json"
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

# Helper to load API keys and usage
def load_apikeys():
    if not os.path.exists(APIKEYS_FILE):
        raise RuntimeError(f"{APIKEYS_FILE} not found. Please run install.sh to create it.")
    with open(APIKEYS_FILE, "r") as f:
        return json.load(f)

# Get rate limit info for a key
def get_groq_ratelimit_headers(api_key):
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    # Use a lightweight request to get headers (OPTIONS is not supported, so use POST with minimal data)
    data = {"model": "llama-3-8b", "messages": [{"role": "user", "content": "ping"}]}
    try:
        with httpx.Client(timeout=10) as client:
            resp = client.post(GROQ_API_URL, headers=headers, json=data)
            # Even if the request fails, headers are returned
            return {
                "remaining_tokens": int(resp.headers.get("x-ratelimit-remaining-tokens", 0)),
                "remaining_requests": int(resp.headers.get("x-ratelimit-remaining-requests", 0)),
                "status_code": resp.status_code
            }
    except Exception:
        return {"remaining_tokens": 0, "remaining_requests": 0, "status_code": 0}

# Select the key with the highest remaining tokens
def select_best_key(apikeys):
    best = max(apikeys, key=lambda k: k.get("remaining_tokens", 0))
    return best

app = FastAPI()
API_KEY = "lassetestapi"

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

    # Load API keys and update their rate limit info
    apikeys = load_apikeys()
    for k in apikeys:
        info = get_groq_ratelimit_headers(k["key"])
        k["remaining_tokens"] = info["remaining_tokens"]
        k["remaining_requests"] = info["remaining_requests"]
        k["last_status_code"] = info["status_code"]
    save_apikeys(apikeys)
    best_key = select_best_key(apikeys)
    groq_key = best_key["key"]

    client = Groq(api_key=groq_key)
    try:
        chat_completion = client.chat.completions.create(
            messages=body.get("messages", []),
            model=model,
        )
        print(chat_completion.choices[0].message.content)
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
