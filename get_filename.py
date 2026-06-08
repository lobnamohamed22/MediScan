import re
import requests

share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
}

print("Fetching share URL...")
r = requests.get(share_url, headers=headers, timeout=30)
html = r.text
urls = re.findall(r'https?://[^\s"\'>]+', html)
download_url = None
for url in urls:
    if "download.aspx" in url and "tempauth=" in url:
        download_url = url.replace(r'\u0026', '&')
        break

if not download_url:
    print("Download URL not found.")
    exit(1)

print("Fetching headers from download URL...")
r_file = requests.get(download_url, headers=headers, stream=True, timeout=30)
print("Headers:")
for k, v in r_file.headers.items():
    print(f"  {k}: {v}")
