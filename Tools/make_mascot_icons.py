"""Иконки приложения с персонажами (запасные иконки iOS).

Запуск: python3 Tools/make_mascot_icons.py  (нужен Pillow; сначала Tools/make_icon.py и Tools/cut_mascots.py).
Для каждого персонажа: зелёный фон как у основной иконки, персонаж (улыбается) и маленькая монета Coin.
Пишет App/Assets.xcassets/AppIcon-<id>.appiconset (1024×1024) и превью icon-preview-<id>.imageset для настроек.
"""
import json, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "App", "Assets.xcassets")
MASCOTS = os.path.join(ROOT, "Shared", "Mascots.xcassets")
IDS = ["persimmon", "husky", "dachshund", "whitecat", "ironman", "girl", "boy", "tabby", "washer"]
S = 1024
MOOD = 2

def background():
    top, bottom = (58, 214, 134), (8, 122, 78)
    big = Image.linear_gradient("L").resize((S * 2, S * 2)).rotate(45, resample=Image.BICUBIC)
    mask = big.crop((S // 2, S // 2, S // 2 + S, S // 2 + S))
    bg = Image.composite(Image.new("RGB", (S, S), bottom), Image.new("RGB", (S, S), top), mask)
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([-S * 0.2, -S * 0.3, S * 0.75, S * 0.55], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    return Image.composite(Image.new("RGB", (S, S), (190, 255, 215)), bg, glow)

def coin(size):
    """Монета из основной иконки (круг по центру), уменьшенная."""
    icon = Image.open(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon.png")).convert("RGB")
    r = int(icon.width * 0.335)
    c = icon.width // 2
    crop = icon.crop((c - r, c - r, c + r, c + r)).resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
    return crop, m.resize((size, size), Image.LANCZOS)

def save_set(folder, filename, image, appicon):
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, filename), optimize=True)
    if appicon:
        images = [{"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    else:
        images = [{"filename": filename, "idiom": "universal"}]
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}},
              open(os.path.join(folder, "Contents.json"), "w"), indent=1)

def main():
    coin_img, coin_mask = coin(int(S * 0.30))
    for mid in IDS:
        icon = background()
        name = f"mascot-{mid}-{MOOD}"
        sticker = Image.open(os.path.join(MASCOTS, f"{name}.imageset", f"{name}.png")).convert("RGBA")
        side = int(S * 0.80)
        sticker = sticker.resize((side, side), Image.LANCZOS)
        # мягкая тень под персонажем
        shadow = Image.new("L", (S, S), 0)
        sx, sy = (S - side) // 2 - int(S * 0.03), (S - side) // 2 - int(S * 0.02)
        shadow.paste(sticker.getchannel("A").point(lambda v: v * 0.45), (sx, sy + int(S * 0.02)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.02))
        icon = Image.composite(Image.new("RGB", (S, S), (4, 70, 44)), icon, shadow)
        icon.paste(sticker, (sx, sy), sticker)
        cs = coin_img.width
        icon.paste(coin_img, (S - cs - int(S * 0.06), S - cs - int(S * 0.06)), coin_mask)
        save_set(os.path.join(ASSETS, f"AppIcon-{mid}.appiconset"), f"AppIcon-{mid}.png", icon, True)
        save_set(os.path.join(ASSETS, f"icon-preview-{mid}.imageset"), f"icon-preview-{mid}.png",
                 icon.resize((180, 180), Image.LANCZOS), False)
    base = Image.open(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon.png")).convert("RGB")
    save_set(os.path.join(ASSETS, "icon-preview-coin.imageset"), "icon-preview-coin.png",
             base.resize((180, 180), Image.LANCZOS), False)
    print("ok:", len(IDS), "иконок")

if __name__ == "__main__":
    main()
