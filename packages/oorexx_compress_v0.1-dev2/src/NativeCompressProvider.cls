/*----------------------------------------------------------------------------*/
/* ooRexx Compress v0.1-dev2 -- pure ooRexx bootstrap provider.               */
/* Bootstrap provider: DEFLATE stored/fixed plus native Zstandard decode.     */
/* Dynamic-Huffman DEFLATE and dictionary-backed Zstandard remain explicit gaps.*/
/*----------------------------------------------------------------------------*/
::class NativeCompressProvider public

::method name
  return 'native-oorexx'

::method capabilities
  return .array~of('checksum.crc32', 'compress.gzip.fixed', 'compress.gzip.stored', -
                   'decompress.gzip.fixed', 'decompress.gzip.stored', -
                   'compress.deflate.fixed', 'compress.deflate.stored', -
                   'decompress.deflate.fixed', 'decompress.deflate.stored', -
                   'compress.zstd.raw', 'compress.zstd.rle', -
                   'decompress.zstd.raw', 'decompress.zstd.rle', -
                   'decompress.zstd.compressed', 'decompress.zstd.huffman', -
                   'decompress.zstd.fse', 'decompress.zstd.repeat-mode', -
                   'frame.zstd.skippable', 'checksum.xxh64', -
                   'bootstrap.no-foreign-runtime')

::method gzip
  use strict arg bytes, mode = 'FIXED'
  mode = translate(mode)
  select
    when mode = 'FIXED' | mode = 'GZIP-FIXED' then deflated = self~deflateFixed(bytes)
    when mode = 'STORED' | mode = 'GZIP-STORED' then deflated = self~deflateStored(bytes)
    otherwise raise syntax 88.900 array('Unsupported native gzip mode: ' || mode)
  end
  return self~gzipHeader || deflated || self~crc32(bytes) || self~le32(length(bytes))

::method gunzip
  use strict arg data
  numeric digits 50
  n = length(data)
  if n < 18 then raise syntax 88.900 array('Input is too small to be gzip data')
  if substr(data, 1, 2) \== x2c('1F8B') then raise syntax 88.900 array('Not a gzip file: bad magic')
  if self~byteAt(data, 3) \== 8 then raise syntax 88.900 array('Unsupported gzip method: expected DEFLATE method 8')

  flags = self~byteAt(data, 4)
  if self~flagSet(flags, 32) | self~flagSet(flags, 64) | self~flagSet(flags, 128) then -
    raise syntax 88.900 array('Unsupported gzip reserved flag bit is set')

  pos = 11
  if self~flagSet(flags, 4) then do
    if pos + 1 > n then raise syntax 88.900 array('Truncated gzip extra field length')
    xlen = self~le16At(data, pos)
    pos += 2
    if pos + xlen - 1 > n then raise syntax 88.900 array('Truncated gzip extra field')
    pos += xlen
  end

  if self~flagSet(flags, 8) then pos = self~skipZero(data, pos)
  if self~flagSet(flags, 16) then pos = self~skipZero(data, pos)

  if self~flagSet(flags, 2) then do
    if pos + 1 > n then raise syntax 88.900 array('Truncated gzip header CRC')
    expectedHeaderCrc = substr(data, pos, 2)
    actualHeaderCrc = substr(self~crc32(substr(data, 1, pos - 1)), 1, 2)
    if expectedHeaderCrc \== actualHeaderCrc then raise syntax 88.900 array('gzip header CRC16 mismatch')
    pos += 2
  end

  if pos > n - 7 then raise syntax 88.900 array('Missing gzip DEFLATE stream or trailer')
  reader = .NativeBitReader~new(substr(data, pos))
  out = self~inflateReader(reader)
  trailerPos = pos + reader~position - 1
  if trailerPos + 7 > n then raise syntax 88.900 array('Missing gzip trailer')

  expectedCrc = substr(data, trailerPos, 4)
  expectedSize = self~le32At(data, trailerPos + 4)
  actualCrc = self~crc32(out)
  actualSize = length(out) // 4294967296
  if expectedCrc \== actualCrc then raise syntax 88.900 array('CRC32 mismatch: expected ' || self~hexBytes(expectedCrc) || ' got ' || self~hexBytes(actualCrc))
  if expectedSize \== actualSize then raise syntax 88.900 array('ISIZE mismatch: expected ' || expectedSize || ' got ' || actualSize)
  if trailerPos + 8 <= n then raise syntax 88.900 array('Trailing data or concatenated gzip member is not supported by the bootstrap codec')
  return out

::method crc32
  use strict arg bytes
  return .NativeCRC32~new~calculate(bytes)


::method zstd
  use strict arg bytes, mode = 'AUTO', checksum = .true
  return .NativeZstdCodec~new~encode(bytes, mode, checksum)

::method unzstd
  use strict arg bytes
  return .NativeZstdCodec~new~decode(bytes)

::method xxh64
  use strict arg bytes, seed = 0
  return .NativeXXH64~new~calculate(bytes, seed)

::method gzipHeader private
  return x2c('1F8B0800') || self~le32(0) || x2c('04FF')

::method deflateFixed
  use strict arg data
  writer = .NativeBitWriter~new
  writer~writeBits(1, 1)  /* BFINAL */
  writer~writeBits(1, 2)  /* BTYPE=01 fixed Huffman */
  pos = 1
  n = length(data)
  matcher = .NativeLZ77Matcher~new
  do while pos <= n
    match = matcher~find(data, pos)
    matchLength = match[1]
    matchDistance = match[2]
    if matchLength >= 3 then do
      self~emitLengthDistance(writer, matchLength, matchDistance)
      pos += matchLength
    end
    else do
      self~emitFixedSymbol(writer, self~byteAt(data, pos))
      pos += 1
    end
  end
  self~emitFixedSymbol(writer, 256)
  return writer~finish

::method emitLengthDistance private
  use strict arg writer, matchLength, matchDistance
  lengthSpec = self~lengthSpec(matchLength)
  parse var lengthSpec lengthCode lengthExtraBits lengthExtraValue
  self~emitFixedSymbol(writer, lengthCode)
  if lengthExtraBits > 0 then writer~writeBits(lengthExtraValue, lengthExtraBits)
  distanceSpec = self~distanceSpec(matchDistance)
  parse var distanceSpec distanceCode distanceExtraBits distanceExtraValue
  writer~writeBits(self~reverseBits(distanceCode, 5), 5)
  if distanceExtraBits > 0 then writer~writeBits(distanceExtraValue, distanceExtraBits)
  return

::method emitFixedSymbol private
  use strict arg writer, symbol
  select
    when symbol >= 0 & symbol <= 143 then do; code = 48 + symbol; bits = 8; end
    when symbol >= 144 & symbol <= 255 then do; code = 400 + symbol - 144; bits = 9; end
    when symbol >= 256 & symbol <= 279 then do; code = symbol - 256; bits = 7; end
    when symbol >= 280 & symbol <= 287 then do; code = 192 + symbol - 280; bits = 8; end
    otherwise raise syntax 88.900 array('Internal error: invalid fixed Huffman symbol ' || symbol)
  end
  writer~writeBits(self~reverseBits(code, bits), bits)
  return

::method lengthSpec private
  use strict arg len
  if len < 3 | len > 258 then raise syntax 88.900 array('Internal error: invalid match length ' || len)
  if len = 258 then return '285 0 0'
  bases = .array~of(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258)
  extras = .array~of(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0)
  do i = 1 to 28
    if len >= bases[i] & len < bases[i + 1] then return (256 + i) extras[i] (len - bases[i])
  end
  raise syntax 88.900 array('Internal error: length code lookup failed for ' || len)

::method distanceSpec private
  use strict arg distance
  if distance < 1 | distance > 32768 then raise syntax 88.900 array('Internal error: invalid match distance ' || distance)
  bases = .array~of(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577,32769)
  extras = .array~of(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13)
  do i = 1 to 30
    if distance >= bases[i] & distance < bases[i + 1] then return (i - 1) extras[i] (distance - bases[i])
  end
  raise syntax 88.900 array('Internal error: distance code lookup failed for ' || distance)

::method reverseBits private
  use strict arg value, bits
  out = 0
  do i = 1 to bits
    out = out * 2 + (value // 2)
    value = value % 2
  end
  return out

::method deflateStored
  use strict arg data
  out = ''
  pos = 1
  n = length(data)
  if n = 0 then return d2c(1, 1) || self~le16(0) || self~le16(65535)
  do while pos <= n
    remain = n - pos + 1
    chunkLength = remain
    if chunkLength > 65535 then chunkLength = 65535
    chunk = substr(data, pos, chunkLength)
    final = (pos + chunkLength > n)
    out ||= d2c(final, 1) || self~le16(chunkLength) || self~le16(65535 - chunkLength) || chunk
    pos += chunkLength
  end
  return out

::method inflate
  use strict arg data
  reader = .NativeBitReader~new(data)
  out = self~inflateReader(reader)
  if reader~position <= length(data) then raise syntax 88.900 array('Trailing data after DEFLATE stream')
  return out

::method inflateReader private
  use strict arg reader
  out = ''
  final = 0
  do while final = 0
    final = reader~readBits(1)
    blockType = reader~readBits(2)
    select
      when blockType = 0 then out ||= self~inflateStoredBlock(reader)
      when blockType = 1 then out = self~inflateFixedBlock(reader, out)
      when blockType = 2 then raise syntax 88.900 array('Dynamic Huffman DEFLATE is not implemented in the native bootstrap provider')
      otherwise raise syntax 88.900 array('Invalid DEFLATE block type 3')
    end
  end
  return out

::method inflateStoredBlock private
  use strict arg reader
  reader~alignByte
  data = reader~data
  pos = reader~position
  if pos + 3 > length(data) then raise syntax 88.900 array('Truncated stored block header')
  len = self~le16At(data, pos); pos += 2
  nlen = self~le16At(data, pos); pos += 2
  if nlen \== 65535 - len then raise syntax 88.900 array('Stored block LEN/NLEN check failed')
  if pos + len - 1 > length(data) then raise syntax 88.900 array('Truncated stored block payload')
  chunk = substr(data, pos, len)
  reader~position = pos + len
  return chunk

::method inflateFixedBlock private
  use strict arg reader, out
  do forever
    symbol = self~fixedDecodeSymbol(reader)
    if symbol < 256 then do; out ||= d2c(symbol, 1); iterate; end
    if symbol = 256 then leave
    if symbol < 257 | symbol > 285 then raise syntax 88.900 array('Invalid fixed-Huffman length symbol ' || symbol)
    lengthSpec = self~decodeLengthSpec(symbol)
    parse var lengthSpec base extraBits
    extra = 0
    if extraBits > 0 then extra = reader~readBits(extraBits)
    matchLength = base + extra
    distanceCode = self~fixedDecodeDistanceCode(reader)
    distanceSpec = self~decodeDistanceSpec(distanceCode)
    parse var distanceSpec distanceBase distanceExtraBits
    distanceExtra = 0
    if distanceExtraBits > 0 then distanceExtra = reader~readBits(distanceExtraBits)
    distance = distanceBase + distanceExtra
    if distance < 1 | distance > length(out) then raise syntax 88.900 array('Invalid match distance ' || distance)
    out = self~copyMatch(matchLength, distance, out)
  end
  return out

::method copyMatch private
  use strict arg matchLength, distance, out
  start = length(out) - distance + 1
  if distance >= matchLength then return out || substr(out, start, matchLength)
  seed = substr(out, start, distance)
  repeats = (matchLength + distance - 1) % distance
  return out || substr(copies(seed, repeats), 1, matchLength)

::method fixedDecodeSymbol private
  use strict arg reader
  code = 0
  do bits = 1 to 9
    code = code * 2 + reader~readBits(1)
    if bits = 7 then do
      if code >= 0 & code <= 23 then return 256 + code
    end
    else if bits = 8 then do
      if code >= 48 & code <= 191 then return code - 48
      if code >= 192 & code <= 199 then return 280 + code - 192
    end
    else if bits = 9 then do
      if code >= 400 & code <= 511 then return 144 + code - 400
    end
  end
  raise syntax 88.900 array('Invalid fixed-Huffman symbol')

::method fixedDecodeDistanceCode private
  use strict arg reader
  code = 0
  do 5
    code = code * 2 + reader~readBits(1)
  end
  if code > 29 then raise syntax 88.900 array('Reserved DEFLATE distance code ' || code)
  return code

::method decodeLengthSpec private
  use strict arg code
  bases = .array~of(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258)
  extras = .array~of(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0)
  if code < 257 | code > 285 then raise syntax 88.900 array('Invalid length code ' || code)
  i = code - 256
  return bases[i] extras[i]

::method decodeDistanceSpec private
  use strict arg code
  bases = .array~of(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577)
  extras = .array~of(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13)
  if code < 0 | code > 29 then raise syntax 88.900 array('Invalid distance code ' || code)
  i = code + 1
  return bases[i] extras[i]

::method le16 private
  use strict arg n
  return d2c(n // 256, 1) || d2c((n % 256) // 256, 1)

::method le32 private
  use strict arg n
  numeric digits 50
  n = n // 4294967296
  if n < 0 then n += 4294967296
  out = ''
  do 4
    out ||= d2c(n // 256, 1)
    n = n % 256
  end
  return out

::method le16At private
  use strict arg s, pos
  if pos < 1 | pos + 1 > length(s) then raise syntax 88.900 array('Out-of-range 16-bit read')
  return self~byteAt(s, pos) + self~byteAt(s, pos + 1) * 256

::method le32At private
  use strict arg s, pos
  if pos < 1 | pos + 3 > length(s) then raise syntax 88.900 array('Out-of-range 32-bit read')
  return self~byteAt(s,pos) + self~byteAt(s,pos+1)*256 + self~byteAt(s,pos+2)*65536 + self~byteAt(s,pos+3)*16777216

::method byteAt private
  use strict arg s, pos
  if pos < 1 | pos > length(s) then raise syntax 88.900 array('Out-of-range byte read at ' || pos)
  return c2d(substr(s, pos, 1))

::method flagSet private
  use strict arg value, mask
  return c2d(bitand(d2c(value // 256,1), d2c(mask // 256,1))) \== 0

::method skipZero private
  use strict arg s, pos
  do while pos <= length(s)
    if substr(s, pos, 1) == d2c(0,1) then return pos + 1
    pos += 1
  end
  raise syntax 88.900 array('Truncated zero-terminated gzip field')

::method hexBytes private
  use strict arg s
  out = ''
  do i = 1 to length(s)
    out ||= d2x(c2d(substr(s,i,1)), 2)
  end
  return out

::requires 'NativeBitWriter.cls'
::requires 'NativeBitReader.cls'
::requires 'NativeCRC32.cls'
::requires 'NativeLZ77Matcher.cls'
::requires 'NativeZstdCodec.cls'
::requires 'NativeXXH64.cls'
