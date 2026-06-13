import subprocess
import os
import time

adb_path = r'C:\Android\Sdk\platform-tools\adb.exe'
output_dir = r'C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d'

def capture(name):
    path = os.path.join(output_dir, name)
    temp_path = f'/data/local/tmp/{name}'
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    subprocess.run([adb_path, 'shell', 'screencap', '-p', temp_path], check=True)
    subprocess.run([adb_path, 'pull', temp_path, path], check=True)
    subprocess.run([adb_path, 'shell', 'rm', temp_path], capture_output=True)
    print(f"Captured: {path}")

try:
    # We are already on the Cart screen.
    # 1. Tap '+' button once (X=865, Y=166)
    print("Tapping '+' button...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '865', '166'], check=True)
    time.sleep(1) # wait a second for transition/api
    capture("cart_after_plus_1.png")

    # 2. Tap '+' button again
    print("Tapping '+' button again...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '865', '166'], check=True)
    time.sleep(1)
    capture("cart_after_plus_2.png")

    print("Completed!")
except Exception as e:
    print("Error:", e)
