/* ooRexx Compress v0.1-dev5 — RFC 1950 framing, Adler-32, indexed PNG container.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * PNG is a deflate container: IHDR/PLTE/IDAT/IEND chunks, each CRC-32
 * framed, with the IDAT payload an RFC 1950 stream. This package already
 * owns deflate and CRC-32; dev5 (on dev4) adds the missing RFC 1950 framing, Adler-32
 * and an 8-bit indexed (colour type 3) PNG writer for symbol rasters.
 *
 * Bootstrap rule: this file is pure ooRexx (stored deflate + table CRC-32 +
 * Adler-32). An accelerated encoder may be injected as a provider object
 * from the foreign/ directory (see foreign/ForeignPngProvider.cls); both
 * produce identical pixels, only the deflate encoding differs.
 */
::class NativeAdler32 public
::method calculate
  /* RFC 1950 Adler-32, returned as 4 big-endian bytes. */
  use strict arg bytes
  a = 1; b = 0
  n = length(bytes); p = 1
  do while p <= n
    chunk = min(3800, n - p + 1)        /* keep sums well inside 9 digits */
    do i = p to p + chunk - 1
      a = a + c2d(substr(bytes, i, 1)); b = b + a
    end
    a = a // 65521; b = b // 65521
    p = p + chunk
  end
  return d2c(b, 2) || d2c(a, 2)

::class Rfc1950Framing public
::method wrapStored class
  /* RFC 1950: CMF=0x78 (deflate, 32K window), FLG=0x01 (check bits). */
  use strict arg data
  return '7801'x || .NativeCompressProvider~new~deflateStored(data) || .NativeAdler32~new~calculate(data)

::class IndexedPngEncoder public
::attribute lane get
::attribute scale get
::method init
  /* palette: directory symbol -> "r g b" (0..255). Symbols are 1 char.
     provider: optional object answering name and
     indexedPngBase64(rows, paletteSpec, scale); .nil = pure lane. */
  expose lane scale symbols rgb provider
  use strict arg palette, pixelScale = 2, encoderProvider = .nil
  if \datatype(pixelScale, 'W') | pixelScale < 1 | pixelScale > 8 then raise syntax 88.900 array('scale 1..8')
  scale = pixelScale; provider = encoderProvider
  symbols = ''; rgb = .array~new
  do s over palette~allIndexes~sort
    if length(s) \= 1 then raise syntax 88.900 array('palette symbols must be single characters')
    parse value palette[s] with r g b .
    do v over .array~of(r, g, b)
      if \datatype(v, 'W') | v < 0 | v > 255 then raise syntax 88.900 array('palette rgb 0..255 for' s)
    end
    symbols = symbols || s; rgb~append(.array~of(r, g, b))
  end
  if length(symbols) > 256 then raise syntax 88.900 array('at most 256 palette entries')
  lane = 'PURE'
  if provider \== .nil then lane = provider~name
::method paletteSpec
  expose symbols rgb
  out = ''
  do i = 1 to length(symbols)
    c = rgb[i]; out = out || substr(symbols, i, 1) || c[1] c[2] c[3] || ';'
  end
  return out
::method encodeBase64
  /* rows: array of equal-length strings of palette symbols. */
  expose scale provider symbols
  use strict arg rows
  if rows~items = 0 then raise syntax 88.900 array('at least one row')
  w = length(rows[1])
  do r over rows
    if length(r) \= w then raise syntax 88.900 array('rows must be equal length')
    if verify(r, symbols) > 0 then raise syntax 88.900 array('row symbol not in palette:' substr(r, verify(r, symbols), 1))
  end
  if provider \== .nil then return provider~indexedPngBase64(rows, self~paletteSpec, scale)
  return self~encodePure(rows)~encodeBase64
::method encodePure
  expose scale symbols rgb
  use strict arg rows
  w = length(rows[1]) * scale; h = rows~items * scale
  table = xrange('00'x, d2c(length(symbols) - 1, 1))
  raw = .mutableBuffer~new
  do r over rows
    idx = translate(r, table, symbols)
    if scale > 1 then do
      wide = .mutableBuffer~new
      do k = 1 to length(idx); wide~append(copies(substr(idx, k, 1), scale)); end
      idx = wide~string
    end
    line = '00'x || idx
    do scale; raw~append(line); end
  end
  plte = ''
  do c over rgb; plte = plte || d2c(c[1], 1) || d2c(c[2], 1) || d2c(c[3], 1); end
  ihdr = d2c(w, 4) || d2c(h, 4) || '08'x || '03'x || '000000'x
  png = '89504E470D0A1A0A'x
  png = png || self~chunk('IHDR', ihdr) || self~chunk('PLTE', plte)
  png = png || self~chunk('IDAT', .Rfc1950Framing~wrapStored(raw~string)) || self~chunk('IEND', '')
  return png
::method chunk private
  use strict arg type, data
  crcLE = .NativeCRC32~new~calculate(type || data)
  return d2c(length(data), 4) || type || data || reverse(crcLE)

::requires 'NativeCompressProvider.cls'
::requires 'NativeCRC32.cls'
