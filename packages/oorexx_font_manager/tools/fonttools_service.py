#!/usr/bin/env python3
"""Optional fontTools backend for the ooRexx Font Manager."""
import argparse
from fontTools.ttLib import TTFont


def load_font(args):
    return TTFont(args.font, fontNumber=args.index, lazy=True)


def measure(args):
    with open(args.text_file, "r", encoding="utf-8") as f:
        text = f.read().rstrip("\n")
    font = load_font(args)
    upm = font["head"].unitsPerEm
    hhea = font["hhea"]
    cmap = font.getBestCmap() or {}
    metrics = font["hmtx"].metrics
    missing = font.getGlyphOrder()[0]
    total = 0
    for ch in text:
        glyph = cmap.get(ord(ch), missing)
        total += metrics.get(glyph, metrics[missing])[0]
    scale = float(args.size) / float(upm)
    print(f"{total*scale:.6f}\t{hhea.ascent*scale:.6f}\t{hhea.descent*scale:.6f}\t{upm}")


def glyphs(args):
    with open(args.text_file, "r", encoding="utf-8") as f:
        text = f.read()
    font = load_font(args)
    head = font["head"]
    hhea = font["hhea"]
    cmap = font.getBestCmap() or {}
    metrics = font["hmtx"].metrics
    order = font.getGlyphOrder()
    gids = {name: i for i, name in enumerate(order)}
    missing = order[0]
    psname = ""
    try:
        psname = font["name"].getDebugName(6) or ""
    except Exception:
        pass
    safe_ps = psname.replace("\t", " ").replace("\n", " ")
    print("\t".join(map(str, ["META", head.unitsPerEm, hhea.ascent, hhea.descent,
                              head.xMin, head.yMin, head.xMax, head.yMax, safe_ps, "1"])))
    seen = set()
    for ch in text:
        cp = ord(ch)
        if cp in seen:
            continue
        seen.add(cp)
        glyph = cmap.get(cp, missing)
        gid = gids.get(glyph, 0)
        advance = metrics.get(glyph, metrics[missing])[0]
        utf8hex = ch.encode("utf-8").hex().upper()
        uhex = ch.encode("utf-16-be").hex().upper()
        print(f"G\t{utf8hex}\t{uhex}\t{cp}\t{gid}\t{advance}")


def main():
    p = argparse.ArgumentParser()
    sp = p.add_subparsers(dest="command", required=True)
    m = sp.add_parser("measure")
    m.add_argument("--font", required=True); m.add_argument("--index", type=int, default=0)
    m.add_argument("--size", type=float, required=True); m.add_argument("--text-file", required=True)
    m.set_defaults(func=measure)
    g = sp.add_parser("glyphs")
    g.add_argument("--font", required=True); g.add_argument("--index", type=int, default=0)
    g.add_argument("--text-file", required=True); g.set_defaults(func=glyphs)
    args = p.parse_args(); args.func(args)

if __name__ == "__main__": main()
