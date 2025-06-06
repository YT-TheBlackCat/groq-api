"""
Main FastAPI app for groq-api
- Async, robust, and production-ready.
- Handles proxying, key selection, and usage tracking.
- Optimized for performance and maintainability.
"""
import os
import json
import logging
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq
from apikeymanager import optimal_apikey, update_usage, __version__

APIKEYS_FILE = "apikeys.json"
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

# Configure logging
logging.basicConfig(level=logging.INFO, format="[groq-api] %(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger("groq-api")

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

app = FastAPI(title="groq-api", version=__version__)
API_KEY = get_local_api_key()

@app.get("/version")
def version():
    return {"version": __version__}

@app.post("/chat/completions")
async def proxy_chat_completions(request: Request):
    auth = request.headers.get("Authorization", "")
    # Debug: log expected and received Authorization header (do not log full key in production)
    logger.info(f"Expected Authorization: Bearer {API_KEY[:6]}... (length {len(API_KEY)})")
    logger.info(f"Received Authorization: {auth[:20]}... (length {len(auth)})")
    if auth != f"Bearer {API_KEY}":
        logger.warning("401 Unauthorized: Authorization header mismatch.")
        raise HTTPException(status_code=401, detail="Invalid API key")
    body = await request.json()
    # Model aliasing
    model = body.get("model")
    aliases = {
        "test": "allam-2-7b",
        "auto": "llama-3.1-8b-instant",
        "fast": "llama-3.1-8b-instant",
        "smart": "llama3-70b-8192",
        "smart-long": "llama-3.3-70b-versatile",
        "reasoning": "deepseek-r1-distill-llama-70b",
        "reasoning2": "qwen-qwq-32b"
    }
    model = aliases.get(model, model)
    if model not in aliases.values() and model not in aliases.keys():
        raise HTTPException(status_code=400, detail="Invalid model specified")

    # System prompt file support
    messages = body.get("messages", [])
    if len(messages) > 0 and messages[0].get("role") == "system" and messages[0].get("content", "").strip().lower() == "systemprompt.txt":
        try:
            with open("systemprompt.txt", "r", encoding="utf-8") as f:
                system_prompt = f.read().strip()
            messages[0]["content"] = system_prompt
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Could not read systemprompt.txt: {e}")

    apikeys = [k["key"] for k in load_apikeys()["groq_keys"]]
    best_key = optimal_apikey(model, apikeys)
    if not best_key:
        raise HTTPException(status_code=429, detail="All API keys exhausted for this model.")

    logger.info(f"Using key: {best_key[:8]}... for model: {model}")

    client = Groq(api_key=best_key)
    try:
        chat_completion = client.chat.completions.create(
            messages=messages,
            model=model,
        )
        # Estimate token usage (rough)
        prompt_tokens = sum(len(m.get("content", "")) for m in messages)
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
        logger.error(f"Groq error: {e}")
        raise HTTPException(status_code=502, detail=f"Groq error: {e}")
