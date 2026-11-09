"""Нарезка листа персонажей (6 настроений × 9 персонажей) в каталог картинок Shared/Mascots.xcassets.

Запуск: python3 Tools/cut_mascots.py <лист.png|webp>  (нужны Pillow и numpy).
Каждая картинка вырезается по контуру (прозрачный фон) и обводится белой каймой, как наклейка.
Контур: тёмные линии рисунка → чуть раздуть (закрыть щели) → залить фон снаружи → всё, куда заливка
не дошла, — персонаж (так белый котик внутри своей обводки не пропадает, хоть и совпадает по цвету с фоном).
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

IDS = ["persimmon", "husky", "dachshund", "whitecat", "ironman", "girl", "boy", "tabby", "washer"]
OUT = os.path.join(os.path.dirname(__file__), "..", "Shared", "Mascots.xcassets")
SCALE = 3          # работаем в увеличенном виде — гладкие края
SIZE = 300         # итоговая картинка
CLOSE = 4 * SCALE  # насколько раздуваем линии, чтобы закрыть щели в обводке
# у белых персонажей щели в обводке шире (живот того же цвета, что фон листа)
CLOSE_FOR = {"whitecat": 11 * SCALE, "husky": 9 * SCALE}
BORDER = 3 * SCALE # белая кайма наклейки

def bands(p, minlen, gap):
    res, start = [], None
    for i, v in enumerate(p):
        if v > gap and start is None: start = i
        if v <= gap and start is not None:
            if i - start >= minlen: res.append((start, i))
            start = None
    if start is not None: res.append((start, len(p)))
    return res

def odd(n): return n * 2 + 1

def silhouette(ink, close):
    """Маска персонажа: замкнуть линии, залить фон снаружи, вернуть размер."""
    m = grow(Image.fromarray((ink * 255).astype(np.uint8)), close)
    padded = Image.new("L", (m.width + 2, m.height + 2), 0)
    padded.paste(m, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    filled = Image.fromarray(np.where(np.asarray(padded) == 128, 0, 255).astype(np.uint8))
    return shrink(filled, close).crop((1, 1, m.width + 1, m.height + 1))

def shrink(mask, radius):
    m = mask
    while radius > 0:
        r = min(radius, 12)
        m = m.filter(ImageFilter.MinFilter(odd(r)))
        radius -= r
    return m

def grow(mask, radius):
    m = mask
    while radius > 0:
        r = min(radius, 12)
        m = m.filter(ImageFilter.MaxFilter(odd(r)))
        radius -= r
    return m

def main(path):
    img = Image.open(path).convert("RGB")
    arr = np.asarray(img).astype(int)
    bg = np.median(np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]]), axis=0)
    diff = np.abs(arr - bg).max(axis=2)
    mask = diff > 40
    rows = bands(mask.sum(axis=1), 20, 3)
    assert len(rows) == len(IDS), f"рядов {len(rows)}, ожидалось {len(IDS)}"
    os.makedirs(OUT, exist_ok=True)
    json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(OUT, "Contents.json"), "w"))
    for r, (top, bottom) in enumerate(rows):
        cols = bands(mask[top:bottom].sum(axis=0), 15, 1)
        assert len(cols) == 6, f"ряд {r}: колонок {len(cols)}"
        for c, (left, right) in enumerate(cols):
            pad = 10
            box = (max(left - pad, 0), max(top - pad, 0), min(right + pad, img.width), min(bottom + pad, img.height))
            crop = img.crop(box)
            w, h = crop.width * SCALE, crop.height * SCALE
            big = crop.resize((w, h), Image.LANCZOS)
            d = np.abs(np.asarray(big).astype(int) - bg).max(axis=2)
            ink = d > 28
            # чужие кусочки за пределами своей колонки/ряда не берём
            keep = np.zeros_like(ink)
            x0, y0 = (left - box[0] - 2) * SCALE, (top - box[1] - 2) * SCALE
            x1, y1 = (right - box[0] + 2) * SCALE, (bottom - box[1] + 2) * SCALE
            keep[max(y0, 0):y1, max(x0, 0):x1] = True
            ink &= keep
            body = silhouette(ink, CLOSE_FOR.get(IDS[r], CLOSE))
            body_soft = body.filter(ImageFilter.GaussianBlur(SCALE * 0.6))
            border = grow(body, BORDER).filter(ImageFilter.GaussianBlur(SCALE * 0.7))

            sticker = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            sticker.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), border)
            sticker.paste(big.convert("RGBA"), (0, 0), body_soft)

            bbox = border.point(lambda v: 255 if v > 8 else 0).getbbox()
            sticker = sticker.crop(bbox)
            side = int(max(sticker.width, sticker.height) * 1.04)
            square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            square.paste(sticker, ((side - sticker.width) // 2, (side - sticker.height) // 2), sticker)
            square = square.resize((SIZE, SIZE), Image.LANCZOS)

            name = f"mascot-{IDS[r]}-{c + 1}"
            folder = os.path.join(OUT, f"{name}.imageset")
            os.makedirs(folder, exist_ok=True)
            square.save(os.path.join(folder, f"{name}.png"), optimize=True)
            json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
                       "info": {"author": "xcode", "version": 1}},
                      open(os.path.join(folder, "Contents.json"), "w"))
    print("ok:", len(rows) * 6, "картинок →", os.path.abspath(OUT))

if __name__ == "__main__":
    main(sys.argv[1])
