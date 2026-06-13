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
    # 1. Tap Add to Cart button (centered horizontally, Y ~ 1660)
    print("Tapping Add to Cart button...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '540', '1660'], check=True)
    time.sleep(2)
    capture("add_to_cart_clicked.png")

    # 2. Tap Shopping Cart icon on the details screen (top-right, X=960, Y=150)
    print("Tapping Shopping Cart icon...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', '960', '150'], check=True)
    time.sleep(2)
    capture("cart_screen_view.png")

    print("Completed!")
except Exception as e:
    print("Error:", e)
