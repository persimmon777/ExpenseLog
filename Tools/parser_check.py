"""Проверка регулярных выражений SMSParser без Mac.

Регулярки здесь — копия из Shared/SMSParser.swift (синтаксис ICU и Python для них совпадает).
Меняешь регулярку в Swift — поменяй и здесь, затем: python3 Tools/parser_check.py
"""
import re

F = re.I | re.S
HEAD = re.compile(r"^\s*(OPLATA|POPOLNENIE(?:\s+KARTOCHKI)?|NALICHNYE)\s+(\d+(?:[.,]\d{1,2})?)\s*([A-Z]{3})", F)
START = re.compile(r"\b(OPLATA|POPOLNENIE|NALICHNYE)\b", F)
CARD = re.compile(r"KARTA\s*#?\s*(\d{4})", F)
DATE = re.compile(r"DATA\s+(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2}(?::\d{2})?)", F)
PLACE = re.compile(r"DATA\s+\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}(?::\d{2})?\s+(.+?)\s*(?:MCC\s*:|OSTATOK\b|$)", F)
MCC = re.compile(r"MCC\s*:\s*(\d{4})", F)
BAL = re.compile(r"OSTATOK\s+(-?\d+(?:[.,]\d{1,2})?)", F)


def split(text):
    ms = list(START.finditer(text))
    if not ms:
        return [text.strip()] if text.strip() else []
    return [text[m.start():(ms[i + 1].start() if i + 1 < len(ms) else len(text))].strip() for i, m in enumerate(ms)]


def parse(text):
    text = text.strip()
    h = HEAD.search(text)
    if not h:
        return None
    first = lambda r: (r.search(text).group(1) if r.search(text) else None)
    d = DATE.search(text)
    raw = (first(PLACE) or "").replace("\n", " ").strip()
    kw = h.group(1).upper()
    return {
        "type": "payment" if kw.startswith("OPLATA") else "topUp" if kw.startswith("POPOLNENIE") else "cashWithdrawal",
        "amount": h.group(2), "currency": h.group(3).upper(), "card": first(CARD),
        "date": f"{d.group(1)} {d.group(2)}" if d else None,
        "placeRaw": raw, "place": raw.split(">")[0].strip(), "mcc": first(MCC), "balance": first(BAL),
    }


VECTORS = [
    ("OPLATA 22.60 BYN  KARTA #7738 DATA 07.11.2026 20:41:16 OMBSHOP.OZON.BY>MINSKIY R-N>BY MCC:5300 OSTATOK 35.14 BYN",
     dict(type="payment", amount="22.60", place="OMBSHOP.OZON.BY", mcc="5300", balance="35.14", date="07.11.2026 20:41:16")),
    ("OPLATA 7.97 BYN  KARTA\n#7738 DATA 07.11.2026 20:41:16\nOMBSHOP.OZON.BY>MINSKIY R-N>BY MCC:5300 OSTATOK 57.74\nBYN",
     dict(type="payment", amount="7.97", place="OMBSHOP.OZON.BY", balance="57.74")),
    ("POPOLNENIE KARTOCHKI\n400.00 BYN  KARTA #7738 DATA\n06.11.2026 17:49:22 INFOKIOSK\n12723 CASH IN>MINSK>BY\nMCC:6011 OSTATOK 509.01 BYN",
     dict(type="topUp", amount="400.00", place="INFOKIOSK 12723 CASH IN", mcc="6011", balance="509.01")),
    ("NALICHNYE 10.00 BYN  KARTA\n#7738 DATA 07.11.2026 16:04:14\nBR.527/209 BR.795/795\nATM>MINSK>BY MCC:6011\nOSTATOK 65.71 BYN",
     dict(type="cashWithdrawal", amount="10.00", place="BR.527/209 BR.795/795 ATM", card="7738", balance="65.71")),
    ("Vash kod 1234 dlya vhoda", None),
]

if __name__ == "__main__":
    for text, expected in VECTORS:
        got = parse(text)
        if expected is None:
            assert got is None, (text, got)
        else:
            for k, v in expected.items():
                assert got and got[k] == v, (text, k, got and got[k], v)
    assert len(split("\n\n".join(t for t, _ in VECTORS))) == 4
    print("OK: все тест-векторы SMS проходят")
