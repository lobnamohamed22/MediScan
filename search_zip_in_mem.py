import io
import re
import requests
import zipfile

# 1. Fetch sharing page to get fresh token and URL
share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
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
    print("Could not find download URL in page.")
    exit(1)

print("Downloading file to memory...")
r_file = requests.get(download_url, headers=headers, timeout=60)
print("Download status:", r_file.status_code)
print("File size in memory:", len(r_file.content))

if r_file.status_code == 200:
    # Read the zip archive in memory
    zip_data = io.BytesIO(r_file.content)
    with zipfile.ZipFile(zip_data) as z:
        print("\nListing all files inside zip:")
        for name in z.namelist():
            # Only look at XML files
            if name.endswith('.xml'):
                content = z.read(name).decode('utf-8', errors='ignore')
                # Check for our targets
                targets = [
                    "Chapter 3: System Analysis",
                    "Chapter 5: System Design",
                    "Chapter 7: Conclusions and Future Work",
                    "System Analysis",
                    "System Design",
                    "Conclusions and Future Work",
                    "Business Analysis & Modeling"
                ]
                matches = []
                for target in targets:
                    if target in content:
                        matches.append(target)
                if matches:
                    print(f"File '{name}' contains matches: {matches}")
                    # Let's count characters and print a small snippet around one match
                    for match in matches[:3]:
                        idx = content.find(match)
                        snippet = content[max(0, idx-50):min(len(content), idx+len(match)+50)]
                        print(f"  Snippet for '{match}': ...{repr(snippet)}...")
else:
    print("Download failed.")
