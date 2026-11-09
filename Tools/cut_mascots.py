"""Нарезка листа персонажей (6 настроений × 9 персонажей) в каталог картинок Shared/Mascots.xcassets.

Запуск: python3 Tools/cut_mascots.py <лист.png|webp>  (нужны Pillow и numpy).
Каждая картинка — квадрат 300×300 на родном кремовом фоне (стикер); в приложении показывается со скруглёнными углами.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

IDS = ["persimmon", "husky", "dachshund", "whitecat", "ironman", "girl", "boy", "tabby", "washer"]
OUT = os.path.join(os.path.dirname(__file__), "..", "Shared", "Mascots.xcassets")

def bands(p, minlen, gap):
    res, start = [], None
    for i, v in enumerate(p):
        if v > gap and start is None: start = i
        if v <= gap and start is not None:
            if i - start >= minlen: res.append((start, i))
            start = None
    if start is not None: res.append((start, len(p)))
    return res

def main(path):
    img = Image.open(path).convert("RGB")
    arr = np.asarray(img).astype(int)
    bg = np.median(np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]]), axis=0)
    mask = np.abs(arr - bg).max(axis=2) > 40
    rows = bands(mask.sum(axis=1), 20, 3)
    assert len(rows) == len(IDS), f"рядов {len(rows)}, ожидалось {len(IDS)}"
    os.makedirs(OUT, exist_ok=True)
    json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(OUT, "Contents.json"), "w"))
    for r, (top, bottom) in enumerate(rows):
        cols = bands(mask[top:bottom].sum(axis=0), 15, 1)
        assert len(cols) == 6, f"ряд {r}: колонок {len(cols)}"
        for c, (left, right) in enumerate(cols):
            # Квадрат вокруг картинки на родном кремовом фоне — «стикер».
            # (Прозрачный фон не делаем: белый котик почти совпадает с фоном листа.)
            cx, cy = (left + right) / 2, (top + bottom) / 2
            side = max(right - left, bottom - top) + 14
            box = [int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2)]
            square = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), tuple(int(v) for v in bg))
            src = (max(box[0], 0), max(box[1], 0), min(box[2], img.width), min(box[3], img.height))
            square.paste(img.crop(src), (src[0] - box[0], src[1] - box[1]))
            # соседние картинки, попавшие в угол квадрата, закрашиваем фоном
            sq = np.asarray(square).copy()
            inner = (left - box[0], top - box[1], right - box[0], bottom - box[1])
            sq[:, :max(inner[0] - 4, 0)] = bg
            sq[:, min(inner[2] + 4, sq.shape[1]):] = bg
            square = Image.fromarray(sq.astype(np.uint8)).resize((300, 300), Image.LANCZOS)
            name = f"mascot-{IDS[r]}-{c + 1}"
            folder = os.path.join(OUT, f"{name}.imageset")
            os.makedirs(folder, exist_ok=True)
            square.save(os.path.join(folder, f"{name}.png"))
            json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
                       "info": {"author": "xcode", "version": 1}},
                      open(os.path.join(folder, "Contents.json"), "w"))
    print("ok:", len(rows) * 6, "картинок →", os.path.abspath(OUT))

if __name__ == "__main__":
    main(sys.argv[1])
