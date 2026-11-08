# Генератор иконки Coin: золотая монета без надписи на зелёном фоне. Запуск: python3 Tools/make_icon.py (нужен Pillow).
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

S = 4096  # рисуем крупно, потом уменьшаем — гладкие края
OUT = sys.argv[1] if len(sys.argv) > 1 else "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

# Фон: диагональный зелёный градиент + мягкий блик сверху слева
bg = Image.new("RGB", (S, S))
top, bottom = (58, 214, 134), (8, 122, 78)
px = bg.load()
grad = Image.linear_gradient("L").resize((S, S))
# диагональ: поворачиваем линейный градиент на 45°
grad = grad.rotate(-45, resample=Image.BICUBIC, expand=False)
g = grad.load()
for y in range(0, S):
    for x in range(0, S, 1):
        pass
# быстрее через композит двух цветов по маске
c1 = Image.new("RGB", (S, S), top)
c2 = Image.new("RGB", (S, S), bottom)
# диагональный градиент без пустых углов: крупнее холста, поворот, обрезка по центру
big = Image.linear_gradient("L").resize((S*2, S*2)).rotate(45, resample=Image.BICUBIC)
mask = big.crop((S//2, S//2, S//2 + S, S//2 + S))
bg = Image.composite(c2, c1, mask)
# блик
glow = Image.new("L", (S, S), 0)
ImageDraw.Draw(glow).ellipse([-S*0.2, -S*0.3, S*0.75, S*0.55], fill=110)
glow = glow.filter(ImageFilter.GaussianBlur(S*0.12))
bg = Image.composite(Image.new("RGB", (S, S), (190, 255, 215)), bg, glow)

cx, cy = S/2, S*0.5
R = S*0.33

# Тень монеты
shadow = Image.new("L", (S, S), 0)
ImageDraw.Draw(shadow).ellipse([cx-R, cy-R+S*0.035, cx+R, cy+R+S*0.035], fill=150)
shadow = shadow.filter(ImageFilter.GaussianBlur(S*0.03))
bg = Image.composite(Image.new("RGB", (S, S), (4, 70, 44)), bg, shadow)

def radial(radius, inner, outer, center_shift=(-0.25, -0.3)):
    """Круг с радиальным градиентом (свет сверху слева)."""
    size = int(radius*2)
    img = Image.new("RGB", (size, size), outer)
    m = Image.radial_gradient("L").resize((size, size))
    # сдвигаем центр градиента к блику
    m = ImageChops.offset(m, int(size*center_shift[0]), int(size*center_shift[1]))
    img = Image.composite(Image.new("RGB", (size, size), outer), Image.new("RGB", (size, size), inner), m)
    return img

def paste_circle(base, img, radius, center):
    size = img.size[0]
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size-1, size-1], fill=255)
    base.paste(img, (int(center[0]-radius), int(center[1]-radius)), m)

# Ребро (обод) — тёмное золото
paste_circle(bg, radial(R, (255, 214, 102), (176, 112, 10)), R, (cx, cy))
# Внешнее кольцо поверхности
r2 = R*0.90
paste_circle(bg, radial(r2, (255, 236, 150), (214, 150, 28)), r2, (cx, cy))
# Канавка
r3 = R*0.78
paste_circle(bg, radial(r3, (196, 132, 18), (232, 170, 40), (0.2, 0.25)), r3, (cx, cy))
# Лицевая сторона
r4 = R*0.74
paste_circle(bg, radial(r4, (255, 230, 140), (226, 160, 34)), r4, (cx, cy))

# Лицевая сторона без надписи: мягкое внутреннее кольцо-тиснение
ring = Image.new("L", (S, S), 0)
rd = ImageDraw.Draw(ring)
rr = R*0.52
rd.ellipse([cx-rr, cy-rr, cx+rr, cy+rr], outline=255, width=int(S*0.006))
ring_dark = ImageChops.offset(ring, -int(S*0.003), -int(S*0.003)).filter(ImageFilter.GaussianBlur(S*0.002))
ring_light = ImageChops.offset(ring, int(S*0.003), int(S*0.003)).filter(ImageFilter.GaussianBlur(S*0.002))
bg.paste(Image.new("RGB", (S, S), (255, 240, 180)), (0, 0), ring_light)
bg.paste(Image.new("RGB", (S, S), (176, 112, 10)), (0, 0), ring_dark)

# Блик на монете
shine = Image.new("L", (S, S), 0)
ImageDraw.Draw(shine).ellipse([cx-R*0.85, cy-R*0.95, cx+R*0.2, cy-R*0.15], fill=90)
shine = shine.filter(ImageFilter.GaussianBlur(S*0.03))
coinmask = Image.new("L", (S, S), 0)
ImageDraw.Draw(coinmask).ellipse([cx-R, cy-R, cx+R, cy+R], fill=255)
shine = ImageChops.multiply(shine, coinmask)
bg = Image.composite(Image.new("RGB", (S, S), (255, 255, 240)), bg, shine)

bg.resize((1024, 1024), Image.LANCZOS).save(OUT, "PNG")
print("ok", OUT)
