import requests

url = "https://upload.gofile.io/uploadfile"
files = {"file": ("test.txt", b"hello gofile.io")}
try:
    print("Uploading to gofile.io...")
    r = requests.post(url, files=files, timeout=30)
    print("Status code:", r.status_code)
    print("Response JSON:", r.json())
except Exception as e:
    print("Upload to gofile.io failed:", e)
