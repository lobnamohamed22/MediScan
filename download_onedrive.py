import requests

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

download_url = "https://onedrive.live.com/download?resid=64C5FD955C53E9E2!1016&authkey=!AACSr41M6CCMRKs&ithint=file%2cdocx"

r = requests.get(download_url, headers=headers, allow_redirects=True)
print("Status code:", r.status_code)
print("Content length:", len(r.content))

if r.status_code == 200:
    filename = "downloaded_document.docx"
    with open(filename, "wb") as f:
        f.write(r.content)
    print(f"File successfully saved as {filename}")
else:
    print("Failed to download file.")
