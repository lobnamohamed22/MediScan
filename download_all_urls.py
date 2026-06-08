import io
import re
import requests
import docx

share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
}

print("Fetching share URL...")
r = requests.get(share_url, headers=headers, timeout=20)
html = r.text

urls = set()
# Find all download URLs
for url in re.findall(r'https?://[^\s"\'>]+', html):
    if "download.aspx" in url and "tempauth=" in url:
        urls.add(url.replace(r'\u0026', '&'))

print(f"Found {len(urls)} download URLs.")
for i, url in enumerate(urls):
    print(f"\n--- URL {i+1} ---")
    print("Link snippet:", url[:150] + "...")
    try:
        r_file = requests.get(url, headers=headers, timeout=30)
        print("Status code:", r_file.status_code)
        if r_file.status_code == 200:
            doc = docx.Document(io.BytesIO(r_file.content))
            print("Sections count:", len(doc.sections))
            print("First 3 paragraphs:")
            for pi, p in enumerate(doc.paragraphs[:3]):
                print(f"  P{pi}: {repr(p.text)}")
        else:
            print("Download failed.")
    except Exception as e:
        print("Error:", e)
