import requests

# Try the direct link without /dl/
url1 = "https://tmpfiles.org/13768800/Lobna_Mohamed_Mahmoud_MediScan.docx"
print("Testing url1:", url1)
r1 = requests.get(url1, stream=True, timeout=10)
print("Status code:", r1.status_code)
print("Headers:", dict(r1.headers))

# Try direct download url with /dl/
url2 = "https://tmpfiles.org/dl/13768800/Lobna_Mohamed_Mahmoud_MediScan.docx"
print("\nTesting url2:", url2)
r2 = requests.get(url2, stream=True, timeout=10)
print("Status code:", r2.status_code)
print("Headers:", dict(r2.headers))
print("First 100 bytes:", r2.content[:100] if r2.status_code == 200 else "N/A")
