import os
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq

# Set GROQ_API_KEY environment variable here for testing/demo purposes
os.environ["GROQ_API_KEY"] = "your-groq-api-key"  # Replace with your actual key

app = FastAPI()

API_KEY = "lassetestapi"

@app.post("/v1/chat/completions")
async def proxy_chat_completions(request: Request):
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {API_KEY}":
        raise HTTPException(status_code=401, detail="Invalid API key")
    body = await request.json()
    # Change model if needed
    model = body.get("model")
    if model == "auto":
        model = "allam-2-7b"
    # Prepare Groq client
    client = Groq(api_key=os.environ.get("GROQ_API_KEY"))
    try:
        chat_completion = client.chat.completions.create(
            messages=body.get("messages", []),
            model=model,
        )
        return JSONResponse(status_code=200, content=chat_completion.dict())
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Groq error: {e}")
