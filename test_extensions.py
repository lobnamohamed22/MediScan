import os

# Create files with different extensions
files = {
    "test_ext.zip": b"zip binary contents",
    "test_ext.bin": b"bin binary contents",
    "test_ext.docx.dat": b"docx dat binary contents",
    "test_ext.docx.txt": b"docx txt binary contents",
}

for name, content in files.items():
    with open(name, "wb") as f:
        f.write(content)
    print(f"Created {name}")
