import subprocess
import os
import time

adb_path = r'C:\Android\Sdk\platform-tools\adb.exe'
output_dir = r'C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d'

try:
    print("Focusing text field at (300, 400)...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '300', '400'], check=True)
    time.sleep(2)
    
    # Clear any existing text first (backspace multiple times)
    print("Clearing text...")
    for _ in range(15):
        subprocess.run([adb_path, 'shell', 'input', 'keyevent', '67'], check=True) # 67 is KEYCODE_DEL
        time.sleep(0.05)
        
    print("Typing 'Panadol' slowly...")
    for char in "Panadol":
        subprocess.run([adb_path, 'shell', 'input', 'text', char], check=True)
        time.sleep(0.2)
        
    time.sleep(3)
    
    # Capture screen
    path = os.path.join(output_dir, "test_typing_loop.png")
    temp_path = '/data/local/tmp/test_typing_loop.png'
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    subprocess.run([adb_path, 'shell', 'screencap', '-p', temp_path], check=True)
    subprocess.run([adb_path, 'pull', temp_path, path], check=True)
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    print(f"Captured: {path}")
except Exception as e:
    print("Error:", e)
