import requests

# Read system prompt from file
with open("systemprompt.txt", "r", encoding="utf-8") as f:
    SYSTEMPROMPT = f.read().strip()

def test_proxy_api():
    url = "http://localhost:8000/v1/chat/completions"
    headers = {
        "Authorization": "Bearer lassetestapi",
        "Content-Type": "application/json"
    }
    user_prompt = input("Enter your prompt/question: ")
    model = input("Enter the model to use for the test (e.g. test, auto, smart, etc.): ")
    data = {
        "messages": [
            {
                "role": "system",
                "content": SYSTEMPROMPT
            },
            {
                "role": "user",
                "content": user_prompt
            }
        ],
        "model": model
    }
    response = requests.post(url, json=data, headers=headers)
    print("Status Code:", response.status_code)
    try:
        print("Response:", response.json())
    except Exception:
        print("Response (raw):", response.text)

if __name__ == "__main__":
    test_proxy_api()
