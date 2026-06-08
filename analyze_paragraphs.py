import zipfile
import xml.etree.ElementTree as ET

filename = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\downloaded_document.docx"

try:
    with zipfile.ZipFile(filename) as z:
        doc_xml = z.read('word/document.xml')
        root = ET.fromstring(doc_xml)
        
        # namespaces
        namespaces = {
            'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
        }
        
        # Find all w:t elements and print their context if they contain our target texts
        # E.g. "Chapter 3: System Analysis", "Chapter 5: System Design", "Chapter 7: Conclusions and Future Work"
        targets = [
            "Chapter 3: System Analysis",
            "Chapter 5: System Design",
            "Chapter 7: Conclusions and Future Work",
            "Chapter 2", "Chapter 3", "Chapter 4", "Chapter 5", "Chapter 6", "Chapter 7"
        ]
        
        # Let's search in all paragraphs
        paragraphs = root.findall('.//w:p', namespaces)
        print(f"Total paragraphs: {len(paragraphs)}")
        
        found_count = 0
        for i, p in enumerate(paragraphs):
            p_text = "".join([t.text for t in p.findall('.//w:t', namespaces) if t.text])
            for target in targets:
                if target in p_text:
                    print(f"P#{i} (contains '{target}'): {p_text}")
                    # Print XML representation of the paragraph to understand it
                    # print(ET.tostring(p, encoding='utf-8').decode('utf-8')[:500])
                    found_count += 1
                    break
        print(f"Total matches found: {found_count}")

except Exception as e:
    print(f"Error checking paragraphs: {e}")
