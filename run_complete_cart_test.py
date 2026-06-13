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

def tap(x, y, label=""):
    print(f"Tapping {label} at ({x}, {y})...")
    subprocess.run([adb_path, 'shell', 'input', 'tap', str(x), str(y)], check=True)

try:
    # 1. Relaunch app
    print("Relaunching MediScan app...")
    subprocess.run([adb_path, 'shell', 'am', 'force-stop', 'com.example.mediscan'], check=True)
    time.sleep(1)
    subprocess.run([adb_path, 'shell', 'monkey', '-p', 'com.example.mediscan', '-c', 'android.intent.category.LAUNCHER', '1'], check=True)
    time.sleep(8)
    capture("0_home.png")

    # 2. Tap Search tab
    tap(405, 2180, "Search tab")
    time.sleep(2)
    capture("1_search_tab.png")

    # 3. Tap search text field to focus
    tap(300, 400, "Search text field")
    time.sleep(1)
    
    # 4. Type "Panadol"
    print("Typing 'Panadol'...")
    subprocess.run([adb_path, 'shell', 'input', 'text', 'Panadol'], check=True)
    time.sleep(3)
    capture("2_search_results.png")

    # 5. Tap first search result
    tap(500, 480, "First search result")
    time.sleep(2)
    capture("3_details_page.png")

    # 6. Tap Add to Cart
    tap(540, 1660, "Add to Cart button")
    time.sleep(2)
    capture("4_after_add_to_cart.png")

    # 7. Tap Shopping Cart icon on top-right of details page
    tap(960, 150, "Shopping Cart icon")
    time.sleep(2)
    capture("5_cart_initial.png")

    # 8. Increment quantity (tap '+')
    tap(865, 350, "'+' button (qty 1 -> 2)")
    time.sleep(2)
    capture("6_cart_qty_2.png")

    # 9. Increment quantity again (tap '+')
    tap(865, 350, "'+' button (qty 2 -> 3)")
    time.sleep(2)
    capture("7_cart_qty_3.png")

    # 10. Decrement quantity (tap '-')
    tap(725, 350, "'-' button (qty 3 -> 2)")
    time.sleep(2)
    capture("8_cart_qty_2_again.png")

    # 11. Tap Checkout button
    tap(780, 2180, "Checkout button")
    time.sleep(3)
    capture("9_after_checkout.png")

    print("Flow test completed successfully!")
except Exception as e:
    print("Error during flow test:", e)
