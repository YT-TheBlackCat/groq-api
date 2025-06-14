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

# Tokenizer import for accurate token counting
try:
    import tiktoken
    _tiktoken_available = True
except ImportError:
    _tiktoken_available = False
    logging.warning("tiktoken not installed, falling back to character count for token estimation.")

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
    if auth != f"Bearer {API_KEY}":
        logger.warning("401 Unauthorized: Authorization header mismatch.")
        raise HTTPException(status_code=401, detail="Invalid API key")
    body = await request.json()
    # Model aliasing
    model = body.get("model")
    userprompt = body.get("messages", [{}])[0].get("content", "").strip() if body.get("messages") else ""
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

    if model == "allam-2-7b" and userprompt == "test":
        logger.info("Test mode activated: returning test message instead of calling Groq API.")
        return JSONResponse(status_code=200, content={
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "This is a test message from custom-groq-api (test mode)."
                    }
                }
            ]
        })

    # System prompt file support
    messages = body.get("messages", [])
    # --- Jailbreak bypass prevention ---
    forbidden_phrases = [

    ]
    for m in messages:
        content = m.get("content", "").lower()
        if any(phrase in content for phrase in forbidden_phrases):
            logger.warning("Jailbreak bypass attempt detected in user message. Blocking request.")
            return JSONResponse(status_code=403, content={
                "detail": "Your request does not match the terms of service of TheBlackCat/BlackBot."
            })
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
        # Jailbreak detection: if the AI response contains 'jailbreak detected', block the response
        ai_message = chat_completion.choices[0].message.content.strip().lower()
        if 1==2 and "jailbreak detected" in ai_message:
            logger.warning("Jailbreak detected in AI response. Blocking output.")
            return JSONResponse(status_code=403, content={
                "detail": "Your request does not match the terms of service of TheBlackCat/BlackBot."
            })
        # Accurate token usage estimation using tiktoken if available
        if _tiktoken_available:
            try:
                # Use get_encoding with fallback for unknown models
                try:
                    enc = tiktoken.encoding_for_model(model)
                except Exception:
                    enc = tiktoken.get_encoding("cl100k_base")
                prompt_tokens = sum(len(enc.encode(m.get("content", ""))) for m in messages)
                completion_tokens = len(enc.encode(chat_completion.choices[0].message.content))
            except Exception as e:
                logger.warning(f"tiktoken error: {e}, falling back to character count.")
                prompt_tokens = sum(len(m.get("content", "")) for m in messages)
                completion_tokens = len(chat_completion.choices[0].message.content)
        else:
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
