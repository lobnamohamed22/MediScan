import os
import re
import requests
import zipfile
import xml.etree.ElementTree as ET

# 1. Fetch sharing page to get fresh token and URL
share_url = "https://1drv.ms/w/c/64c5fd955c53e9e2/IQASr41M6CCMRKsFOloY7V9bAVVZNhERVVNU9HdcKBpqVzM?e=8HjDbY"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

print("Fetching share URL...")
try:
    r = requests.get(share_url, headers=headers, timeout=30)
    print("Share URL fetch status:", r.status_code)
    html = r.text
    
    # Search for download URLs
    urls = re.findall(r'https?://[^\s"\'>]+', html)
    download_url = None
    for url in urls:
        if "download.aspx" in url and "tempauth=" in url:
            download_url = url.replace(r'\u0026', '&')
            break
            
    if not download_url:
        print("Could not find download URL in page. Trying to construct from redirects or using previous...")
        # Fallback to the previous known URL just in case
        download_url = (
            "https://my.microsoftpersonalcontent.com/personal/64c5fd955c53e9e2/_layouts/15/download.aspx"
            "?UniqueId=4c8daf12-20e8-448c-ab05-3a5a18ed5f5b"
            "&Translate=false"
            "&tempauth=v1e.eyJzaXRlaWQiOiI5Y2U5ZjdmZC05ZWM4LTQyYTEtYjMxYS1mOGFiYmZmZDJkYmIiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgxMjc3MjE0In0.AWUssMAerFbQ5vCCtRoNjAR0y7SqgeUXifG3RAsWpSKZjN9714sfhdyMffFXm3a975Z-09Bqv84FPBwXSGVzqu2pEdHxEGPNqM45hII22_JA5aPjgwdQe4BpD_y-83rJGNZmFpfmjS70NI2UkQT0hX7ToTpeI3ckIAR8jC1Ef82U2glvFqKHbvggAOavWlMTFU4aGjZxxKfJM_hfdrQ1_Cs2up8YIJxo-s5UcBpfv6gt90WU9CAXaEPJ938xrBpInQOgVIl5f9J1EnHF2tznrRG53I6phEu0mvUeQIIyTlr8Ar8TvBzgIJN7oMRwATBGN7xXyFWXhDjuKjRLAYvH0LJK9uSzO-lIg-agWv1alO1QeiRrTBPhnII876cnHiFXBRr_0MuapFYUXlGNwXuTwDNN9EKfwDRBorXTE8no2xFIyHtyKhGMQHY_-Haq1F-_70o8h7mbCvs93okmLNWoPoqZJXH1V2IQeqRYGtIfT6ufcuCO7IQBo5yme0QOTbMnCrePY-V9t_MX0xOuT6kGMrN3ict5mkhF_mf0MSwVqtdxe6ewUrCcdomKNuOPcqAP.YGrd0VxjLRFWH23wkJ0dIIQNwUfeX86ofs0uNM119sc"
        )
    
    print("Using download URL:", download_url[:150] + "...")
    
    # Download the file
    print("Downloading file...")
    r_file = requests.get(download_url, headers=headers, timeout=60)
    print("Download status:", r_file.status_code)
    print("File size:", len(r_file.content))
    
    if r_file.status_code == 200:
        filename = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\document.docx"
        with open(filename, "wb") as f:
            f.write(r_file.content)
        print("Saved file. Checking if exists:", os.path.exists(filename))
        
        # Test reading the zip structure
        with zipfile.ZipFile(filename) as z:
            print("Zip contents check (word/document.xml exists):", "word/document.xml" in z.namelist())
            
    else:
        print("Failed to download file:", r_file.status_code)
except Exception as e:
    print("Error occurred during download process:", e)
