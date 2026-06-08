import requests

# Test uploading a small file to file.io
url = "https://file.io"
files = {"file": ("test.txt", b"hello world")}

try:
    print("Uploading to file.io...")
    r = requests.post(url, files=files, timeout=20)
    print("Status code:", r.status_code)
    print("Response json:", r.json())
except Exception as e:
    print("Upload to file.io failed:", e)

# Test uploading to tmpfiles.org
url2 = "https://tmpfiles.org/api/v1/upload"
files2 = {"file": ("test.txt", b"hello world")}
try:
    print("Uploading to tmpfiles.org...")
    r2 = requests.post(url2, files=files2, timeout=20)
    print("Status code:", r2.status_code)
    print("Response json:", r2.json())
except Exception as e:
    print("Upload to tmpfiles.org failed:", e)
