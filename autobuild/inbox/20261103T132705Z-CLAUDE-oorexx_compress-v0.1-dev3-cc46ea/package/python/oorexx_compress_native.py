"""ooRexx Compress v0.1-dev3 FOREIGN lane kernel (Claude Opus 5.5, 2026-11-03).

Meaning lives in IndexedPngEncoder.cls; this module only performs the zlib
deflate + PNG chunk framing with the Python standard library. Input rows are
text (one palette symbol per pixel); output is base64 ASCII, so no binary
crosses the Foreign Runtime bridge.
"""
import base64, struct, zlib


def _chunk(kind, data):
    body = kind + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)


def indexed_png_base64(rows, palette_spec, scale):
    scale = int(scale)
    entries = [e for e in str(palette_spec).split(';') if e]
    symbols, plte = [], bytearray()
    for e in entries:
        sym, rgb = e[0], e[1:].split()
        symbols.append(sym)
        plte += bytes(int(x) for x in rgb)
    index = {s: i for i, s in enumerate(symbols)}
    rows = [str(r) for r in list(rows)]
    w, h = len(rows[0]) * scale, len(rows) * scale
    raw = bytearray()
    for r in rows:
        line = bytes(index[c] for c in r)
        if scale > 1:
            line = bytes(b for b in line for _ in range(scale))
        for _ in range(scale):
            raw += b'\x00' + line
    png = b'\x89PNG\r\n\x1a\n'
    png += _chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 3, 0, 0, 0))
    png += _chunk(b'PLTE', bytes(plte))
    png += _chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    png += _chunk(b'IEND', b'')
    return base64.b64encode(png).decode('ascii')
