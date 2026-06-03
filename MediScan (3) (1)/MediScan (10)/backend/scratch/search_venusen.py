import os

root_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)"

for dirpath, dirnames, filenames in os.walk(root_dir):
    # Ignore node_modules, .git, env, venv
    if any(x in dirpath.lower() for x in ['.git', 'node_modules', 'env', 'venv', '__pycache__', '.vscode']):
        continue
    for file in filenames:
        if file.endswith(('.py', '.js', '.dart', '.json', '.html', '.txt')):
            filepath = os.path.join(dirpath, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if 'venusen' in content.lower():
                        print(f"Found in: {filepath}")
                        # Print matching lines
                        for idx, line in enumerate(content.splitlines(), 1):
                            if 'venusen' in line.lower():
                                print(f"  Line {idx}: {line.strip()}")
            except Exception as e:
                pass
