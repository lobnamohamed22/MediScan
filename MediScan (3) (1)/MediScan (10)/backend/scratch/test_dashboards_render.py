import requests

base_url = "http://127.0.0.1:5000"
dashboards = ["/admin", "/pharmacy", "/delivery"]

print("Testing dashboard render endpoints...")
for db in dashboards:
    url = base_url + db
    try:
        res = requests.get(url, timeout=5)
        print(f"GET {url} - Status: {res.status_code}")
        if res.status_code == 200:
            print(f"  Success! Title / Preview snippet: {res.text[:150].strip()}...")
        else:
            print(f"  Failed: {res.text[:100]}")
    except Exception as e:
        print(f"GET {url} - Error: {e}")
