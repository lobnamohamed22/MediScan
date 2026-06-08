import re

with open("response.html", "r", encoding="utf-8") as f:
    html = f.read()

# Let's find all URLs in the HTML
urls = re.findall(r'https?://[^\s"\'>]+', html)
print(f"Found {len(urls)} URLs")

# Print unique URLs that might be relevant
relevant_urls = set()
for url in urls:
    if "download" in url or "download.aspx" in url or "Doc.aspx" in url or "stream" in url:
        relevant_urls.add(url)

print("Relevant URLs:")
for url in sorted(relevant_urls):
    print("  ", url)
