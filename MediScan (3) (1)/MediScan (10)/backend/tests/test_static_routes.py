import urllib.request
import urllib.error

routes = ['/admin', '/pharmacy', '/delivery']
print("=== VERIFYING WEB DASHBOARD ROUTING ===")

for r in routes:
    url = f"http://127.0.0.1:5000{r}"
    try:
        response = urllib.request.urlopen(url)
        html = response.read().decode('utf-8')
        status = response.status
        print(f"URL: {url} -> Loaded successfully! Status Code: {status}")
        # Verify it has index.html tags
        if "doctype html" in html.lower():
            print(f"  Result: Verified as HTML5 template.")
        else:
            print(f"  Result: Warning! Template returned is not HTML5.")
    except urllib.error.HTTPError as e:
        print(f"URL: {url} -> Failed with HTTP Error: {e.code}")
    except Exception as e:
        print(f"URL: {url} -> Failed with connection error: {e}")
