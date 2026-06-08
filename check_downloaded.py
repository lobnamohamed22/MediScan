import os
import zipfile
import xml.etree.ElementTree as ET

print("Current working directory:", os.getcwd())
print("Files in current directory:", os.listdir('.'))

file_path = "downloaded_document.docx"
try:
    with zipfile.ZipFile(file_path) as z:
        doc_xml = z.read('word/document.xml')
        root = ET.fromstring(doc_xml)
        
        texts = []
        for elem in root.iter():
            if elem.tag.endswith('t'):
                if elem.text:
                    texts.append(elem.text)
        
        full_text = " ".join(texts)
        print(f"Length of text in downloaded file: {len(full_text)}")
        
        targets = [
            "Business Analysis & Modeling",
            "System Analysis",
            "System Modeling",
            "System Design",
            "System Implementation & Testing",
            "Conclusions and Future Work"
        ]
        
        for target in targets:
            count = full_text.count(target)
            print(f"Occurrence of '{target}': {count}")
            
except Exception as e:
    print(f"Error checking downloaded file: {e}")
