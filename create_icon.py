from PIL import Image

# Open your original Boundary logo
logo = Image.open("assets/icon/icon.png").convert("RGBA")

# Remove transparent outer space
bbox = logo.getbbox()
logo = logo.crop(bbox)

# Create a transparent 1024x1024 canvas
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))

# Resize logo to fit within approximately 55% of canvas
logo.thumbnail((563, 563), Image.Resampling.LANCZOS)

# Center the logo
x = (1024 - logo.width) // 2
y = (1024 - logo.height) // 2

canvas.alpha_composite(logo, (x, y))

# Save the foreground icon
canvas.save("assets/icon/icon_foreground.png")

print("Adaptive foreground icon created!")
