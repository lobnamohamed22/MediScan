import requests

url = "https://tmpfiles.org/dl/13768800/Lobna_Mohamed_Mahmoud_MediScan.docx"
try:
    print("Testing download from tmpfiles.org direct link...")
    r = requests.get(url, stream=True, timeout=10)
    print("Status code:", r.status_code)
    # Read first 4 bytes
    content = r.raw.read(4)
    print("First 4 bytes of download:", content)
    if content == b'PK\x03\x04':
        print("Success! File is a valid zip/docx package.")
    else:
        print("Warning: File header is not a standard zip package.")
except Exception as e:
    print("Failed to download/verify link:", e)
