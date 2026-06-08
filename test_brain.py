import os

brain_dir = r"C:\Users\lenovo\.gemini\antigravity\brain\4063795c-ef98-479b-9bb7-7d50dfe97afa"
print("Brain dir exists:", os.path.exists(brain_dir))

# Check scratch dir
scratch_dir = os.path.join(brain_dir, "scratch")
if not os.path.exists(scratch_dir):
    try:
        os.makedirs(scratch_dir)
        print("Created scratch dir")
    except Exception as e:
        print("Failed to create scratch dir:", e)
else:
    print("Scratch dir exists")

# Create a test file there
test_file = os.path.join(scratch_dir, "test_file.txt")
with open(test_file, "w") as f:
    f.write("hello from brain scratch")

print("Created test file. Exists:", os.path.exists(test_file))
