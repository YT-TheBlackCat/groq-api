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
                "content": "Wieso ist der Himmel blau?"
            }
        ],
        "model": "test"
    }
    response = requests.post(url, json=data, headers=headers)
    print("Status Code:", response.status_code)
    print("Response:", response.json())

if __name__ == "__main__":
    test_proxy_api()
