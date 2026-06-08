import os
import zipfile
import xml.etree.ElementTree as ET

def search_in_docx(file_path):
    print(f"Checking {file_path}...")
    try:
        with zipfile.ZipFile(file_path) as z:
            # check document.xml
            doc_xml = z.read('word/document.xml')
            root = ET.fromstring(doc_xml)
            # Find all text
            texts = []
            for elem in root.iter():
                if elem.tag.endswith('t'):
                    if elem.text:
                        texts.append(elem.text)
            
            full_text = " ".join(texts)
            print(f"  Length of text: {len(full_text)}")
            if "Business Analysis" in full_text:
                print(f"  --> FOUND 'Business Analysis'")
            if "System Analysis" in full_text:
                print(f"  --> FOUND 'System Analysis'")
            if "System Modeling" in full_text:
                print(f"  --> FOUND 'System Modeling'")
            if "System Design" in full_text:
                print(f"  --> FOUND 'System Design'")
            if "System Implementation" in full_text:
                print(f"  --> FOUND 'System Implementation'")
            if "Conclusions and Future Work" in full_text:
                print(f"  --> FOUND 'Conclusions and Future Work'")
    except Exception as e:
        print(f"  Error: {e}")

for f in os.listdir('.'):
    if f.endswith('.docx'):
        search_in_docx(f)
