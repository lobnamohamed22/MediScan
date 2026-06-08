import requests

# Test uploading a small file to transfer.sh
url = "https://transfer.sh/test.txt"
try:
    print("Uploading to transfer.sh...")
    r = requests.put(url, data=b"hello transfer.sh", timeout=20)
    print("Status code:", r.status_code)
    print("Response text:", r.text)
except Exception as e:
    print("Upload to transfer.sh failed:", e)
