from PIL import Image, ImageDraw
import math

# Tamaño del ícono
size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Fondo circular azul oscuro
draw.ellipse([0, 0, size, size], fill=(13, 27, 75, 255))

# Escudo (polígono)
cx, cy = size // 2, size // 2
shield_points = []
w, h = 340, 420
top = cy - h // 2 + 20
bottom = cy + h // 2 + 40

shield_points = [
    (cx - w//2, top),
    (cx + w//2, top),
    (cx + w//2, top + h * 0.55),
    (cx, bottom),
    (cx - w//2, top + h * 0.55),
]

draw.polygon(shield_points, fill=(30, 60, 180, 255))

# Borde del escudo
draw.line(shield_points + [shield_points[0]],
          fill=(100, 160, 255, 255), width=18)

# Tilde de verificación dentro del escudo
check = [
    (cx - 90, cy + 10),
    (cx - 20, cy + 80),
    (cx + 100, cy - 80),
]
draw.line(check, fill=(255, 255, 255, 255), width=40)

img.save('assets/icon/vigiapp_icon.png')
print('✅ Ícono creado en assets/icon/vigiapp_icon.png')