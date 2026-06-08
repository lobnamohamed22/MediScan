import os
import requests
import zipfile
import xml.etree.ElementTree as ET

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

download_url = (
    "https://my.microsoftpersonalcontent.com/personal/64c5fd955c53e9e2/_layouts/15/download.aspx"
    "?UniqueId=4c8daf12-20e8-448c-ab05-3a5a18ed5f5b"
    "&Translate=false"
    "&tempauth=v1e.eyJzaXRlaWQiOiI5Y2U5ZjdmZC05ZWM4LTQyYTEtYjMxYS1mOGFiYmZmZDJkYmIiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgxMjc3MjE0In0.AWUssMAerFbQ5vCCtRoNjAR0y7SqgeUXifG3RAsWpSKZjN9714sfhdyMffFXm3a975Z-09Bqv84FPBwXSGVzqu2pEdHxEGPNqM45hII22_JA5aPjgwdQe4BpD_y-83rJGNZmFpfmjS70NI2UkQT0hX7ToTpeI3ckIAR8jC1Ef82U2glvFqKHbvggAOavWlMTFU4aGjZxxKfJM_hfdrQ1_Cs2up8YIJxo-s5UcBpfv6gt90WU9CAXaEPJ938xrBpInQOgVIl5f9J1EnHF2tznrRG53I6phEu0mvUeQIIyTlr8Ar8TvBzgIJN7oMRwATBGN7xXyFWXhDjuKjRLAYvH0LJK9uSzO-lIg-agWv1alO1QeiRrTBPhnII876cnHiFXBRr_0MuapFYUXlGNwXuTwDNN9EKfwDRBorXTE8no2xFIyHtyKhGMQHY_-Haq1F-_70o8h7mbCvs93okmLNWoPoqZJXH1V2IQeqRYGtIfT6ufcuCO7IQBo5yme0QOTbMnCrePY-V9t_MX0xOuT6kGMrN3ict5mkhF_mf0MSwVqtdxe6ewUrCcdomKNuOPcqAP.YGrd0VxjLRFWH23wkJ0dIIQNwUfeX86ofs0uNM119sc"
)

filename = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\downloaded_document.docx"

print("Fetching from URL...")
r = requests.get(download_url, headers=headers, allow_redirects=True)
print("Status code:", r.status_code)
print("Content length:", len(r.content))

if r.status_code == 200:
    with open(filename, "wb") as f:
        f.write(r.content)
    print(f"File successfully saved to: {filename}")
    print("Does file exist?", os.path.exists(filename))
    
    # Inspect
    try:
        with zipfile.ZipFile(filename) as z:
            doc_xml = z.read('word/document.xml')
            root = ET.fromstring(doc_xml)
            
            texts = []
            for elem in root.iter():
                if elem.tag.endswith('t'):
                    if elem.text:
                        texts.append(elem.text)
            
            full_text = " ".join(texts)
            print(f"Length of text: {len(full_text)}")
            
            # Print sections of text containing the keywords
            for target in ["Business Analysis", "System Analysis", "System Modeling", "System Design", "System Implementation", "Conclusions and Future Work"]:
                count = full_text.count(target)
                print(f"Occurrence of '{target}': {count}")
                
    except Exception as e:
        print(f"Error checking file inside script: {e}")
else:
    print("Failed to download file.")
