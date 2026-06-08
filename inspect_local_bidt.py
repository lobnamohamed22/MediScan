import os
import zipfile
import xml.etree.ElementTree as ET

def search_in_docx(file_path):
    try:
        with zipfile.ZipFile(file_path) as z:
            doc_xml = z.read('word/document.xml')
            root = ET.fromstring(doc_xml)
            texts = [elem.text for elem in root.iter() if elem.tag.endswith('t') and elem.text]
            full_text = " ".join(texts)
            if "BIDT" in full_text:
                print(f"FOUND 'BIDT' in local file: {file_path}")
                # Print first 200 chars
                print("  Snippet:", full_text[:200])
    except Exception as e:
         pass

for root, dirs, files in os.walk('.'):
    for f in files:
        if f.endswith('.docx'):
            search_in_docx(os.path.join(root, f))
print("Done searching local files.")
