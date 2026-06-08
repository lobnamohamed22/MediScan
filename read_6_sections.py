import io
import re
import time
import requests
import docx

share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
}

print("Fetching share URL...")
r = requests.get(share_url, headers=headers, timeout=20)
urls = re.findall(r'https?://[^\s"\'>]+', r.text)
download_url = None
for url in urls:
    if "download.aspx" in url and "tempauth=" in url:
        download_url = url.replace(r'\u0026', '&')
        break

if not download_url:
    print("Download URL not found.")
    exit(1)

print("Downloading document...")
r_file = requests.get(download_url, headers=headers, timeout=30)
if r_file.status_code == 200:
    doc = docx.Document(io.BytesIO(r_file.content))
    print(f"Total sections: {len(doc.sections)}")
    # Print the first few paragraphs of the document
    for i, p in enumerate(doc.paragraphs[:10]):
        print(f"P{i}: {repr(p.text)}")
else:
    print("Download failed:", r_file.status_code)
