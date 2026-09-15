::options digits 30

/* msqlshim native zlib/DEFLATE codec.
 *
 * The raw fixed-Huffman writer and DEFLATE tables are adapted from the user's
 * native_gzip_fixed_huffman_exposefix.rex.  This class adds the zlib wrapper
 * required by MySQL CLIENT_COMPRESS and a dynamic-Huffman decoder so it can
 * accept ordinary zlib output from stock clients.
 */

::class MySQLDeflate public

::method compressZlib class
  use arg data
  raw = self~deflateFixed(data)
  adler = self~adler32(data)
  /* CMF=0x78 (deflate, 32K window), FLG=0x01 (fastest/no dictionary). */
  return '7801'x || raw || self~be32(adler)

::method decompressZlib class
  use arg data
  if data~length < 6 then raise syntax 93.900 additional('Truncated zlib stream')
  cmf = c2d(data~substr(1,1))
  flg = c2d(data~substr(2,1))
  if cmf // 16 \= 8 then raise syntax 93.900 additional('Unsupported zlib compression method')
  if (cmf * 256 + flg) // 31 \= 0 then raise syntax 93.900 additional('Invalid zlib header check bits')
  if self~bitSet8(flg, 32) then raise syntax 93.900 additional('Preset zlib dictionary is unsupported')
  raw = data~substr(3, data~length - 6)
  expected = self~readBE32(data, data~length - 3)
  out = self~inflateRaw(raw)
  actual = self~adler32(out)
  if actual \= expected then raise syntax 93.900 additional('zlib Adler-32 mismatch')
  return out

::method deflateFixed class private
  use arg data
  writer = .MySQLBitWriter~new
  writer~writeBits(1, 1)       /* BFINAL */
  writer~writeBits(1, 2)       /* BTYPE=01 fixed Huffman */
  do i = 1 to data~length
    self~emitFixedSymbol(writer, c2d(data~substr(i,1)))
  end
  self~emitFixedSymbol(writer, 256)
  return writer~finish

::method emitFixedSymbol class private
  use arg writer, sym
  select
    when sym >= 0 & sym <= 143 then do
      code = 48 + sym; bits = 8
    end
    when sym >= 144 & sym <= 255 then do
      code = 400 + sym - 144; bits = 9
    end
    when sym >= 256 & sym <= 279 then do
      code = sym - 256; bits = 7
    end
    when sym >= 280 & sym <= 287 then do
      code = 192 + sym - 280; bits = 8
    end
    otherwise raise syntax 93.900 additional('Invalid fixed Huffman symbol')
  end
  writer~writeBits(self~reverseBits(code, bits), bits)

::method inflateRaw class private
  use arg data
  reader = .MySQLBitReader~new(data)
  out = ''
  final = 0
  do while final = 0
    final = reader~readBits(1)
    btype = reader~readBits(2)
    select
      when btype = 0 then out ||= self~inflateStoredBlock(reader)
      when btype = 1 then out = self~inflateCompressedBlock(reader, out, self~fixedLiteralTable, self~fixedDistanceTable)
      when btype = 2 then do
        tables = self~dynamicTables(reader)
        out = self~inflateCompressedBlock(reader, out, tables[1], tables[2])
      end
      otherwise raise syntax 93.900 additional('Invalid DEFLATE block type')
    end
  end
  return out

::method inflateStoredBlock class private
  use arg reader
  reader~alignByte
  lenBytes = reader~readBytes(2)
  nlenBytes = reader~readBytes(2)
  len = self~readLE16(lenBytes, 1)
  nlen = self~readLE16(nlenBytes, 1)
  if nlen \= 65535 - len then raise syntax 93.900 additional('DEFLATE stored LEN/NLEN mismatch')
  return reader~readBytes(len)

::method inflateCompressedBlock class private
  use arg reader, out, literalTable, distanceTable
  do forever
    sym = self~decodeSymbol(reader, literalTable)
    if sym < 256 then do
      out ||= d2c(sym)
      iterate
    end
    if sym = 256 then leave
    if sym < 257 then raise syntax 93.900 additional('Invalid DEFLATE length symbol')
    if sym > 285 then raise syntax 93.900 additional('Invalid DEFLATE length symbol')
    lengthInfo = self~lengthInfo(sym)
    parse var lengthInfo base extraBits
    extra = 0
    if extraBits > 0 then extra = reader~readBits(extraBits)
    matchLength = base + extra

    distSym = self~decodeSymbol(reader, distanceTable)
    if distSym > 29 then raise syntax 93.900 additional('Invalid DEFLATE distance symbol')
    distanceInfo = self~distanceInfo(distSym)
    parse var distanceInfo distBase distExtraBits
    distExtra = 0
    if distExtraBits > 0 then distExtra = reader~readBits(distExtraBits)
    distance = distBase + distExtra
    if distance < 1 then raise syntax 93.900 additional('Invalid DEFLATE distance')
    if distance > out~length then raise syntax 93.900 additional('DEFLATE distance exceeds output')
    do i = 1 to matchLength
      out ||= out~substr(out~length - distance + 1, 1)
    end
  end
  return out

::method dynamicTables class private
  use arg reader
  hlit = reader~readBits(5) + 257
  hdist = reader~readBits(5) + 1
  hclen = reader~readBits(4) + 4
  order = .array~of(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15)
  codeLengths = .array~new(19)
  do i = 1 to 19
    codeLengths[i] = 0
  end
  do i = 1 to hclen
    codeLengths[order[i] + 1] = reader~readBits(3)
  end
  codeTable = self~buildHuffmanTable(codeLengths)

  total = hlit + hdist
  lengths = .array~new
  do while lengths~items < total
    sym = self~decodeSymbol(reader, codeTable)
    select
      when sym <= 15 then lengths~append(sym)
      when sym = 16 then do
        if lengths~items = 0 then raise syntax 93.900 additional('Invalid dynamic Huffman repeat')
        repeatCount = reader~readBits(2) + 3
        previous = lengths[lengths~items]
        do repeatCount
          lengths~append(previous)
        end
      end
      when sym = 17 then do
        repeatCount = reader~readBits(3) + 3
        do repeatCount
          lengths~append(0)
        end
      end
      when sym = 18 then do
        repeatCount = reader~readBits(7) + 11
        do repeatCount
          lengths~append(0)
        end
      end
      otherwise raise syntax 93.900 additional('Invalid dynamic Huffman code-length symbol')
    end
    if lengths~items > total then raise syntax 93.900 additional('Dynamic Huffman lengths overrun')
  end

  literalLengths = .array~new(hlit)
  do i = 1 to hlit
    literalLengths[i] = lengths[i]
  end
  distanceLengths = .array~new(hdist)
  do i = 1 to hdist
    distanceLengths[i] = lengths[hlit + i]
  end
  if literalLengths[257] = 0 then raise syntax 93.900 additional('Dynamic Huffman table lacks end-of-block')

  tables = .array~new(2)
  tables[1] = self~buildHuffmanTable(literalLengths)
  tables[2] = self~buildHuffmanTable(distanceLengths)
  return tables

::method fixedLiteralTable class private
  lengths = .array~new(288)
  do sym = 0 to 143; lengths[sym+1] = 8; end
  do sym = 144 to 255; lengths[sym+1] = 9; end
  do sym = 256 to 279; lengths[sym+1] = 7; end
  do sym = 280 to 287; lengths[sym+1] = 8; end
  return self~buildHuffmanTable(lengths)

::method fixedDistanceTable class private
  lengths = .array~new(32)
  do i = 1 to 32; lengths[i] = 5; end
  return self~buildHuffmanTable(lengths)

::method buildHuffmanTable class private
  use arg lengths
  maxBits = 0
  do lengthValue over lengths
    if lengthValue > maxBits then maxBits = lengthValue
  end
  if maxBits = 0 then raise syntax 93.900 additional('Empty Huffman table')

  counts = .array~new(maxBits + 1)
  do i = 1 to maxBits + 1; counts[i] = 0; end
  do lengthValue over lengths
    if lengthValue > 0 then counts[lengthValue + 1] = counts[lengthValue + 1] + 1
  end

  nextCode = .array~new(maxBits + 1)
  do i = 1 to maxBits + 1; nextCode[i] = 0; end
  code = 0
  do bits = 1 to maxBits
    code = (code + counts[bits]) * 2
    nextCode[bits + 1] = code
  end

  table = .directory~new
  table['MAXBITS'] = maxBits
  do sym = 0 to lengths~items - 1
    bits = lengths[sym + 1]
    if bits > 0 then do
      code = nextCode[bits + 1]
      nextCode[bits + 1] = code + 1
      table[bits || ':' || code] = sym
    end
  end
  return table

::method decodeSymbol class private
  use arg reader, table
  code = 0
  maxBits = table['MAXBITS']
  do bits = 1 to maxBits
    bit = reader~readBits(1)
    code = code * 2 + bit
    value = table[bits || ':' || code]
    if value \== .nil then return value
  end
  raise syntax 93.900 additional('Invalid Huffman code')

::method lengthInfo class private
  use arg code
  select
    when code = 257 then return '3 0'
    when code = 258 then return '4 0'
    when code = 259 then return '5 0'
    when code = 260 then return '6 0'
    when code = 261 then return '7 0'
    when code = 262 then return '8 0'
    when code = 263 then return '9 0'
    when code = 264 then return '10 0'
    when code = 265 then return '11 1'
    when code = 266 then return '13 1'
    when code = 267 then return '15 1'
    when code = 268 then return '17 1'
    when code = 269 then return '19 2'
    when code = 270 then return '23 2'
    when code = 271 then return '27 2'
    when code = 272 then return '31 2'
    when code = 273 then return '35 3'
    when code = 274 then return '43 3'
    when code = 275 then return '51 3'
    when code = 276 then return '59 3'
    when code = 277 then return '67 4'
    when code = 278 then return '83 4'
    when code = 279 then return '99 4'
    when code = 280 then return '115 4'
    when code = 281 then return '131 5'
    when code = 282 then return '163 5'
    when code = 283 then return '195 5'
    when code = 284 then return '227 5'
    when code = 285 then return '258 0'
    otherwise raise syntax 93.900 additional('Invalid DEFLATE length code')
  end

::method distanceInfo class private
  use arg code
  bases = .array~of(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577)
  bits = .array~of(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13)
  return bases[code + 1] bits[code + 1]

::method reverseBits class private
  use arg value, bits
  out = 0
  do bits
    out = out * 2 + value // 2
    value = value % 2
  end
  return out

::method adler32 class private
  use arg data
  a = 1
  b = 0
  do i = 1 to data~length
    a = (a + c2d(data~substr(i,1))) // 65521
    b = (b + a) // 65521
  end
  return b * 65536 + a

::method be32 class private
  use arg n
  b3 = n // 256; n = n % 256
  b2 = n // 256; n = n % 256
  b1 = n // 256; n = n % 256
  b0 = n // 256
  return d2c(b0) || d2c(b1) || d2c(b2) || d2c(b3)

::method readBE32 class private
  use arg data, offset
  b0 = c2d(data~substr(offset,1))
  b1 = c2d(data~substr(offset+1,1))
  b2 = c2d(data~substr(offset+2,1))
  b3 = c2d(data~substr(offset+3,1))
  return b0 * 16777216 + b1 * 65536 + b2 * 256 + b3

::method readLE16 class private
  use arg data, offset
  return c2d(data~substr(offset,1)) + c2d(data~substr(offset+1,1)) * 256

::method bitSet8 class private
  use arg value, mask
  return bitand(d2c(value), d2c(mask)) \= '00'x

::class MySQLBitWriter
::attribute out
::attribute buffer
::attribute bitCount

::method init
  self~out = ''
  self~buffer = 0
  self~bitCount = 0

::method writeBits
  use arg value, count
  do while count > 0
    bit = value // 2
    value = value % 2
    if bit \= 0 then self~buffer = self~buffer + 2 ** self~bitCount
    self~bitCount += 1
    if self~bitCount >= 8 then do
      self~out ||= d2c(self~buffer // 256)
      self~buffer = self~buffer % 256
      self~bitCount -= 8
    end
    count -= 1
  end

::method finish
  if self~bitCount > 0 then self~out ||= d2c(self~buffer // 256)
  finishedBytes = self~out
  self~out = ''
  self~buffer = 0
  self~bitCount = 0
  return finishedBytes

::class MySQLBitReader
::attribute data
::attribute position
::attribute buffer
::attribute bitCount

::method init
  use arg data
  self~data = data
  self~position = 1
  self~buffer = 0
  self~bitCount = 0

::method readBits
  use arg count
  value = 0
  multiplier = 1
  do while count > 0
    if self~bitCount = 0 then do
      if self~position > self~data~length then raise syntax 93.900 additional('Unexpected end of DEFLATE bit stream')
      self~buffer = c2d(self~data~substr(self~position,1))
      self~position += 1
      self~bitCount = 8
    end
    bit = self~buffer // 2
    self~buffer = self~buffer % 2
    self~bitCount -= 1
    if bit \= 0 then value += multiplier
    multiplier *= 2
    count -= 1
  end
  return value

::method alignByte
  self~buffer = 0
  self~bitCount = 0

::method readBytes
  use arg count
  if self~bitCount \= 0 then raise syntax 93.900 additional('Byte read requested while DEFLATE reader is unaligned')
  if count = 0 then return ''
  if self~position + count - 1 > self~data~length then raise syntax 93.900 additional('Truncated DEFLATE byte stream')
  byteChunk = self~data~substr(self~position, count)
  self~position += count
  return byteChunk
