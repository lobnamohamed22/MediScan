import re
import requests

share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
}

print("Fetching share page...")
r = requests.get(share_url, headers=headers, timeout=20)
html = r.text

print("Searching for URLs containing 'download.aspx'...")
urls = set()
for url in re.findall(r'https?://[^\s"\'>]+', html):
    if "download.aspx" in url:
        urls.add(url.replace(r'\u0026', '&'))

print(f"Found {len(urls)} unique download URLs:")
for i, url in enumerate(urls):
    print(f"URL {i+1}:")
    print("  Link:", url[:120] + "...")
    # Try to find UniqueId or resid in the url
    uniq_id = re.search(r'UniqueId=([^&]+)', url)
    if uniq_id:
        print("  UniqueId:", uniq_id.group(1))
    resid = re.search(r'resid=([^&]+)', url)
    if resid:
        print("  resid:", resid.group(1))
        
# Let's search the HTML text for document titles or filenames
# Often they are in JSON blocks like ModelData or similar
print("\nSearching for file/document names in HTML...")
json_blocks = re.findall(r'\{[^}]*"name"[^}]*\}', html)
for block in json_blocks[:10]:
    if ".docx" in block or "MediScan" in block:
        print("  Match:", block[:200])
        
# Try a simpler regex to search for anything ending in .docx
docx_files = re.findall(r'[^"\'>]+\.docx', html)
print(f"Found {len(docx_files)} potential .docx references in HTML:")
for docx in set(docx_files)[:10]:
    print("  ", docx[-100:])
