import os
import shutil
import time

print("Starting file persistence test...")

# Test 1: Copy an existing local docx file
shutil.copy("MediScan_Website_Map.docx", "test_copy.docx")
print("Test 1: Created test_copy.docx (copied local)")

# Test 2: Create a tiny docx file
with open("test_tiny.docx", "w") as f:
    f.write("dummy")
print("Test 2: Created test_tiny.docx (tiny size)")

# Test 3: Create a dummy 11MB text file
with open("test_large.txt", "wb") as f:
    f.write(b"\0" * 11090409)
print("Test 3: Created test_large.txt (large size)")

# Wait 5 seconds
print("Waiting 5 seconds...")
time.sleep(5)

# Check existence
print("test_copy.docx exists:", os.path.exists("test_copy.docx"))
print("test_tiny.docx exists:", os.path.exists("test_tiny.docx"))
print("test_large.txt exists:", os.path.exists("test_large.txt"))

# Clean up if they exist
for f in ["test_copy.docx", "test_tiny.docx", "test_large.txt"]:
    if os.path.exists(f):
        try:
            os.remove(f)
            print(f"Cleaned up {f}")
        except Exception as e:
            print(f"Error cleaning up {f}: {e}")
