#!/usr/bin/env python3
"""Independent PNG check for compress dev3 tests (stdlib only, test-side)."""
import base64, struct, sys, zlib
data = base64.b64decode(open(sys.argv[1]).read())
assert data[:8] == b'\x89PNG\r\n\x1a\n', 'signature'
p, chunks = 8, {}
while p < len(data):
    n = struct.unpack('>I', data[p:p+4])[0]; kind = data[p+4:p+8]; body = data[p+8:p+8+n]
    crc = struct.unpack('>I', data[p+8+n:p+12+n])[0]
    assert zlib.crc32(kind + body) & 0xffffffff == crc, f'crc {kind}'
    chunks.setdefault(kind, b''); chunks[kind] += body; p += 12 + n
w, h, depth, ctype = struct.unpack('>IIBB', chunks[b'IHDR'][:10])
raw = zlib.decompress(chunks[b'IDAT'])
assert depth == 8 and ctype == 3 and len(raw) == h * (w + 1), 'geometry'
rows = [raw[i*(w+1)+1:(i+1)*(w+1)] for i in range(h)]
print(w, h, len(chunks[b'PLTE']) // 3, ''.join(f'{b:02x}' for b in rows[0][:8]), ''.join(f'{b:02x}' for b in rows[-1][-8:]))
