/* PdfDeflate.cls
 * Native ooRexx raw DEFLATE encoder for PDF /FlateDecode streams.
 * Derived from the existing Alchemy native fixed-Huffman compression work.
 * No shell, zlib, gzip wrapper, Java, or Python at runtime.
 */

::class PdfDeflate public

::method init
  expose outBytes currentByte bitCount
  outBytes = ""
  currentByte = 0
  bitCount = 0

::method deflate
  expose outBytes currentByte bitCount
  use strict arg rawData, useMatches=.true
  numeric digits 30

  outBytes = ""
  currentByte = 0
  bitCount = 0

  /* BFINAL=1, BTYPE=01 (fixed Huffman), LSB first. */
  self~writeBits(3, 3)

  cursor = 1
  dataLen = length(rawData)
  windowSize = 32768

  do while cursor <= dataLen
    matchLen = 0
    matchDist = 0

    if useMatches then do
      remaining = dataLen - cursor + 1
      if cursor > 1 & remaining >= 3 then do
        winStart = max(1, cursor - windowSize)
        winLen = cursor - winStart
        history = substr(rawData, winStart, winLen)
        maxLen = min(258, remaining)

        do tryLen = maxLen to 3 by -1
          probe = substr(rawData, cursor, tryLen)
          hit = lastpos(probe, history)
          if hit \= 0 then do
            matchLen = tryLen
            matchDist = (winLen - hit) + 1
            leave
          end
        end
      end
    end

    if matchLen >= 3 then do
      parse value self~lengthCode(matchLen) with lenSym lenExtra lenExtraBits
      self~emitFixedSymbol(lenSym)
      if lenExtraBits > 0 then self~writeBits(lenExtra, lenExtraBits)

      parse value self~distanceCode(matchDist) with distSym distExtra distExtraBits
      self~writeBits(self~bitReverse(distSym, 5), 5)
      if distExtraBits > 0 then self~writeBits(distExtra, distExtraBits)

      cursor = cursor + matchLen
    end
    else do
      self~emitFixedSymbol(c2d(substr(rawData, cursor, 1)))
      cursor = cursor + 1
    end
  end

  self~emitFixedSymbol(256)
  if bitCount > 0 then outBytes = outBytes || d2c(currentByte)
  return outBytes


::method zlib
  use strict arg rawData, useMatches=.true
  numeric digits 30
  /* PDF FlateDecode consumes a zlib stream (RFC 1950) containing DEFLATE,
     not a naked RFC 1951 bitstream. 0x78 0x01 is CM=8/CINFO=7 with a valid
     FCHECK and the fastest/no-dictionary profile. */
  payload = self~deflate(rawData, useMatches)
  return '7801'x || payload || x2c(right(d2x(self~adler32(rawData)), 8, '0'))

::method adler32 private
  use strict arg data
  numeric digits 30
  mod = 65521
  a = 1
  b = 0
  do i = 1 to length(data)
    a = (a + c2d(substr(data, i, 1))) // mod
    b = (b + a) // mod
  end
  return b * 65536 + a

::method emitFixedSymbol private
  use strict arg sym
  if sym <= 143 then do; code = sym + 48; bits = 8; end
  else if sym <= 255 then do; code = sym + 256; bits = 9; end
  else if sym <= 279 then do; code = sym - 256; bits = 7; end
  else do; code = sym - 88; bits = 8; end
  self~writeBits(self~bitReverse(code, bits), bits)
  return

::method writeBits private
  expose outBytes currentByte bitCount
  use strict arg value, count
  numeric digits 30
  v = value
  do k = 1 to count
    if (v // 2) = 1 then currentByte = currentByte + (2 ** bitCount)
    v = v % 2
    bitCount = bitCount + 1
    if bitCount = 8 then do
      outBytes = outBytes || d2c(currentByte)
      currentByte = 0
      bitCount = 0
    end
  end
  return

::method bitReverse private
  use strict arg value, count
  v = value
  out = 0
  do k = 1 to count
    out = out * 2 + (v // 2)
    v = v % 2
  end
  return out

::method lengthCode private
  use strict arg len
  if len = 258 then return "285 0 0"

  base.257 = 3;   extra.257 = 0
  base.258 = 4;   extra.258 = 0
  base.259 = 5;   extra.259 = 0
  base.260 = 6;   extra.260 = 0
  base.261 = 7;   extra.261 = 0
  base.262 = 8;   extra.262 = 0
  base.263 = 9;   extra.263 = 0
  base.264 = 10;  extra.264 = 0
  base.265 = 11;  extra.265 = 1
  base.266 = 13;  extra.266 = 1
  base.267 = 15;  extra.267 = 1
  base.268 = 17;  extra.268 = 1
  base.269 = 19;  extra.269 = 2
  base.270 = 23;  extra.270 = 2
  base.271 = 27;  extra.271 = 2
  base.272 = 31;  extra.272 = 2
  base.273 = 35;  extra.273 = 3
  base.274 = 43;  extra.274 = 3
  base.275 = 51;  extra.275 = 3
  base.276 = 59;  extra.276 = 3
  base.277 = 67;  extra.277 = 4
  base.278 = 83;  extra.278 = 4
  base.279 = 99;  extra.279 = 4
  base.280 = 115; extra.280 = 4
  base.281 = 131; extra.281 = 5
  base.282 = 163; extra.282 = 5
  base.283 = 195; extra.283 = 5
  base.284 = 227; extra.284 = 5

  do code = 257 to 284
    b = base.code
    e = extra.code
    span = 2 ** e
    if len >= b & len < b + span then return code (len - b) e
  end
  return "285 0 0"

::method distanceCode private
  use strict arg dist
  base.0 = 1;      extra.0 = 0
  base.1 = 2;      extra.1 = 0
  base.2 = 3;      extra.2 = 0
  base.3 = 4;      extra.3 = 0
  base.4 = 5;      extra.4 = 1
  base.5 = 7;      extra.5 = 1
  base.6 = 9;      extra.6 = 2
  base.7 = 13;     extra.7 = 2
  base.8 = 17;     extra.8 = 3
  base.9 = 25;     extra.9 = 3
  base.10 = 33;    extra.10 = 4
  base.11 = 49;    extra.11 = 4
  base.12 = 65;    extra.12 = 5
  base.13 = 97;    extra.13 = 5
  base.14 = 129;   extra.14 = 6
  base.15 = 193;   extra.15 = 6
  base.16 = 257;   extra.16 = 7
  base.17 = 385;   extra.17 = 7
  base.18 = 513;   extra.18 = 8
  base.19 = 769;   extra.19 = 8
  base.20 = 1025;  extra.20 = 9
  base.21 = 1537;  extra.21 = 9
  base.22 = 2049;  extra.22 = 10
  base.23 = 3073;  extra.23 = 10
  base.24 = 4097;  extra.24 = 11
  base.25 = 6145;  extra.25 = 11
  base.26 = 8193;  extra.26 = 12
  base.27 = 12289; extra.27 = 12
  base.28 = 16385; extra.28 = 13
  base.29 = 24577; extra.29 = 13

  do code = 0 to 29
    b = base.code
    e = extra.code
    span = 2 ** e
    if dist >= b & dist < b + span then return code (dist - b) e
  end
  return "29 0 13"
