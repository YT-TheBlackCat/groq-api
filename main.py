import os
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq

# Set GROQ_API_KEY environment variable here for testing/demo purposes
os.environ["GROQ_API_KEY"] = "api_key"  # Replace with your actual key

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
    if model == "test":
        model = "allam-2-7b"
    elif model == "auto" or model == "fast":
        model = "llama-3.1-8b-instant"
    elif model == "smart":
        model = "llama3-70b-8192"
    elif model == "smart-long":
        model = "llama-3.3-70b-vertasile"
    elif model == "reasoning":
        model = "deepseek-r1-distill-llama-70b"
    elif model == "reasoning2":
        model = "qwen-qwq-32b"
    else:
        raise HTTPException(status_code=400, detail="Invalid model specified")
    # Prepare Groq client with the API key
    client = Groq(api_key=os.environ.get("GROQ_API_KEY"))
    try:
        chat_completion = client.chat.completions.create(
            messages=body.get("messages", []),
            model=model,
        )
        print(chat_completion.choices[0].message.content)
        # Return only the message content in OpenAI style
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
