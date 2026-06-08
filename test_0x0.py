import requests

url = "https://0x0.st"
files = {"file": ("test.txt", b"hello 0x0.st")}
try:
    print("Uploading to 0x0.st...")
    r = requests.post(url, files=files, timeout=20)
    print("Status code:", r.status_code)
    print("Response text:", r.text.strip())
except Exception as e:
    print("Upload to 0x0.st failed:", e)
