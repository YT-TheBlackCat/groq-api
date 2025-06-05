import os
import requests

def test_proxy_api():
    url = "http://localhost:8000/v1/chat/completions"
    headers = {
        "Authorization": "Bearer lassetestapi",
        "Content-Type": "application/json"
    }
    data = {
        "messages": [
            {
                "role": "user",
                "content": "Explain the importance of fast language models"
            }
        ],
        "model": "auto"
    }
    response = requests.post(url, json=data, headers=headers)
    print("Status Code:", response.status_code)
    print("Response:", response.json())

if __name__ == "__main__":
    test_proxy_api()

