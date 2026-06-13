import subprocess
import os
import time

adb_path = r'C:\Android\Sdk\platform-tools\adb.exe'
output_dir = r'C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d'

try:
    print("Tapping Don't Allow at (500, 1330)...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '500', '1330'], check=True)
    time.sleep(2)
    
    # Capture screen
    path = os.path.join(output_dir, "test_dismissed.png")
    temp_path = '/data/local/tmp/test_dismissed.png'
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    subprocess.run([adb_path, 'shell', 'screencap', '-p', temp_path], check=True)
    subprocess.run([adb_path, 'pull', temp_path, path], check=True)
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    print(f"Captured: {path}")
except Exception as e:
    print("Error:", e)
