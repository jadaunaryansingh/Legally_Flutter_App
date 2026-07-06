import requests

base_url = "https://legally-backend.onrender.com"

# 1. Test POST /api/legal-advice with message payload
try:
    payload = {"message": "Hello"}
    r = requests.post(f"{base_url}/api/legal-advice", json=payload, timeout=10)
    print("--- POST /api/legal-advice ---")
    print(f"Status Code: {r.status_code}")
    print(f"Response: {r.text}")
except Exception as e:
    print(f"Error: {e}")
