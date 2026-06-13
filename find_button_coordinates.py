from PIL import Image

image_path = r'C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d\cart_screen_view.png'
img = Image.open(image_path)
width, height = img.size

# We want to find pixels that are green (high G, low R, low B) and red (high R, low G, low B)
green_pixels = []
red_pixels = []

for y in range(0, height):
    for x in range(0, width):
        r, g, b, a = img.getpixel((x, y))
        # Green color for '+' button
        if g > 150 and r < 100 and b < 100:
            green_pixels.append((x, y))
        # Red color for '-' button
        if r > 180 and g < 100 and b < 100:
            red_pixels.append((x, y))

# Calculate centroids
if green_pixels:
    avg_x = sum([p[0] for p in green_pixels]) // len(green_pixels)
    avg_y = sum([p[1] for p in green_pixels]) // len(green_pixels)
    print(f"Green button '+' centroid: ({avg_x}, {avg_y})")
else:
    print("Green button not found")

if red_pixels:
    avg_x = sum([p[0] for p in red_pixels]) // len(red_pixels)
    avg_y = sum([p[1] for p in red_pixels]) // len(red_pixels)
    print(f"Red button '-' centroid: ({avg_x}, {avg_y})")
else:
    print("Red button not found")
