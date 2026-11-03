/*----------------------------------------------------------------------------*/
/* ZstdCompressedBlockDecoder.cls -- native Zstandard Compressed_Block core.  */
/* Covers raw/RLE/Huffman literals, FSE/predefined/RLE/repeat sequences, and  */
/* repeat-offset/history execution for dictionary-free frames.                 */
/*----------------------------------------------------------------------------*/
::class ZstdCompressedBlockDecoder public

::method init
  expose windowSize repeat1 repeat2 repeat3 prevLL prevOF prevML prevHuff predefinedLL predefinedOF predefinedML
  use strict arg windowSize
  repeat1 = 1; repeat2 = 4; repeat3 = 8
  prevLL = .nil; prevOF = .nil; prevML = .nil; prevHuff = .nil
  predefinedLL = .ZstdFSETable~new(self~llDefault,6)
  predefinedML = .ZstdFSETable~new(self~mlDefault,6)
  predefinedOF = .ZstdFSETable~new(self~ofDefault,5)

::method decode
  expose windowSize repeat1 repeat2 repeat3 prevLL prevOF prevML predefinedLL predefinedOF predefinedML
  use strict arg block, priorFrameOut
  numeric digits 80
  if length(block) = 0 then raise syntax 88.900 array('Empty Zstandard Compressed_Block')

  literalInfo = self~decodeLiterals(block)
  literals = literalInfo[1]
  pos = literalInfo[2] + 1
  if pos > length(block) then raise syntax 88.900 array('Missing Zstandard Sequences_Section')

  first = self~byteAt(block,pos); pos += 1
  if first < 128 then sequenceCount = first
  else if first < 255 then do
    if pos > length(block) then raise syntax 88.900 array('Truncated Zstandard Number_of_Sequences')
    sequenceCount = (first-128)*256 + self~byteAt(block,pos); pos += 1
  end
  else do
    if pos+1 > length(block) then raise syntax 88.900 array('Truncated Zstandard Number_of_Sequences')
    sequenceCount = self~byteAt(block,pos) + self~byteAt(block,pos+1)*256 + x2d('7F00')
    pos += 2
  end

  if sequenceCount = 0 then do
    if pos \== length(block)+1 then raise syntax 88.900 array('Trailing bytes after zero-sequence Zstandard section')
    return literals
  end

  if pos > length(block) then raise syntax 88.900 array('Missing Zstandard sequence compression modes')
  modes = self~byteAt(block,pos); pos += 1
  if (modes // 4) \== 0 then raise syntax 88.900 array('Reserved Zstandard sequence-mode bits are non-zero')
  llMode = modes % 64
  ofMode = (modes % 16) // 4
  mlMode = (modes % 4) // 4

  tableInfo = self~tableForMode(block,pos,llMode,'LL',35,9,prevLL,predefinedLL)
  llTable = tableInfo[1]; pos += tableInfo[2]
  tableInfo = self~tableForMode(block,pos,ofMode,'OF',31,8,prevOF,predefinedOF)
  ofTable = tableInfo[1]; pos += tableInfo[2]
  tableInfo = self~tableForMode(block,pos,mlMode,'ML',52,9,prevML,predefinedML)
  mlTable = tableInfo[1]; pos += tableInfo[2]

  /* Any non-repeat selected table becomes the table eligible for Repeat_Mode. */
  if llMode \== 3 then prevLL = llTable
  if ofMode \== 3 then prevOF = ofTable
  if mlMode \== 3 then prevML = mlTable

  if pos > length(block) then raise syntax 88.900 array('Missing Zstandard sequence bitstream')
  bitstream = substr(block,pos)
  bits = .ZstdReverseBitReader~new(bitstream)

  llState = bits~readBits(llTable~accuracyLog)
  ofState = bits~readBits(ofTable~accuracyLog)
  mlState = bits~readBits(mlTable~accuracyLog)

  out = ''
  literalPos = 1
  do sequence = 1 to sequenceCount
    llCode = llTable~symbolAt(llState)
    ofCode = ofTable~symbolAt(ofState)
    mlCode = mlTable~symbolAt(mlState)

    offsetValue = (2 ** ofCode) + bits~readBits(ofCode)
    mlInfo = self~matchLengthInfo(mlCode)
    matchLength = mlInfo[1] + bits~readBits(mlInfo[2])
    llInfo = self~literalLengthInfo(llCode)
    literalLength = llInfo[1] + bits~readBits(llInfo[2])

    if literalPos + literalLength - 1 > length(literals) then raise syntax 88.900 array('Zstandard sequence consumes beyond literal section')
    if literalLength > 0 then do
      out ||= substr(literals,literalPos,literalLength)
      literalPos += literalLength
    end

    offset = self~resolveOffset(offsetValue,literalLength)
    if offset <= 0 then raise syntax 88.900 array('Invalid Zstandard match offset ' || offset)
    if offset > windowSize then raise syntax 88.900 array('Zstandard match offset ' || offset || ' exceeds window ' || windowSize)
    if offset > length(priorFrameOut) + length(out) then raise syntax 88.900 array('Zstandard match offset points before available history')
    out = self~appendMatch(priorFrameOut,out,offset,matchLength)

    if sequence < sequenceCount then do
      llState = llTable~nextState(llState,bits)
      mlState = mlTable~nextState(mlState,bits)
      ofState = ofTable~nextState(ofState,bits)
    end
  end

  if \bits~exhausted then raise syntax 88.900 array('Zstandard sequence bitstream not exactly consumed; ' || bits~bitsRemaining || ' bits remain')
  if literalPos <= length(literals) then out ||= substr(literals,literalPos)
  return out

::method decodeLiterals private
  expose prevHuff
  use strict arg block
  numeric digits 80
  first = self~byteAt(block,1)
  literalType = first // 4
  sizeFormat = (first % 4) // 4

  if literalType = 0 | literalType = 1 then do
    select
      when sizeFormat = 0 | sizeFormat = 2 then do
        headerSize = 1
        regen = first % 8
      end
      when sizeFormat = 1 then do
        if length(block) < 2 then raise syntax 88.900 array('Truncated Zstandard raw/RLE literals header')
        headerSize = 2
        regen = (first % 16) + self~byteAt(block,2)*16
      end
      otherwise do
        if length(block) < 3 then raise syntax 88.900 array('Truncated Zstandard raw/RLE literals header')
        headerSize = 3
        regen = (first % 16) + self~byteAt(block,2)*16 + self~byteAt(block,3)*4096
      end
    end
    if literalType = 0 then do
      if headerSize + regen > length(block) then raise syntax 88.900 array('Truncated Zstandard Raw_Literals_Block')
      if regen = 0 then data = ''
      else data = substr(block,headerSize+1,regen)
      return .array~of(data,headerSize+regen)
    end
    if headerSize + 1 > length(block) then raise syntax 88.900 array('Truncated Zstandard RLE_Literals_Block')
    value = substr(block,headerSize+1,1)
    return .array~of(copies(value,regen),headerSize+1)
  end

  select
    when sizeFormat = 0 | sizeFormat = 1 then do; headerSize = 3; fieldBits = 10; end
    when sizeFormat = 2 then do; headerSize = 4; fieldBits = 14; end
    otherwise do; headerSize = 5; fieldBits = 18; end
  end
  if length(block) < headerSize then raise syntax 88.900 array('Truncated Zstandard Huffman literals header')
  packed = self~leAt(block,1,headerSize)
  shifted = packed % 16
  fieldMod = 2 ** fieldBits
  regen = shifted // fieldMod
  compressedSize = shifted % fieldMod
  streams = 4
  if sizeFormat = 0 then streams = 1
  if compressedSize = 0 then raise syntax 88.900 array('Zero-sized Zstandard Huffman literals payload')
  if streams = 4 & compressedSize < 10 then raise syntax 88.900 array('Four-stream Zstandard literals payload is too small')
  if streams = 1 & regen > 1024 then raise syntax 88.900 array('Single-stream Zstandard Huffman literals exceed 1 KiB')
  if headerSize + compressedSize > length(block) then raise syntax 88.900 array('Truncated Zstandard Huffman literals payload')

  body = substr(block,headerSize+1,compressedSize)
  treeSize = 0
  if literalType = 2 then do
    treeInfo = .ZstdHuffmanTable~fromDescription(body)
    table = treeInfo[1]
    treeSize = treeInfo[2]
    prevHuff = table
  end
  else do
    if prevHuff == .nil then raise syntax 88.900 array('Zstandard Treeless_Literals_Block has no previous Huffman table')
    table = prevHuff
  end
  if treeSize >= compressedSize then raise syntax 88.900 array('Zstandard Huffman tree leaves no literal stream')
  streamBytes = substr(body,treeSize+1)

  if streams = 1 then data = table~decodeStream(streamBytes,regen)
  else do
    if length(streamBytes) < 10 then raise syntax 88.900 array('Truncated Zstandard Huffman jump table')
    size1 = self~leAt(streamBytes,1,2)
    size2 = self~leAt(streamBytes,3,2)
    size3 = self~leAt(streamBytes,5,2)
    size4 = length(streamBytes) - 6 - size1 - size2 - size3
    if size1 < 1 | size2 < 1 | size3 < 1 | size4 < 1 then raise syntax 88.900 array('Invalid Zstandard Huffman stream size')
    p = 7
    s1 = substr(streamBytes,p,size1); p += size1
    s2 = substr(streamBytes,p,size2); p += size2
    s3 = substr(streamBytes,p,size3); p += size3
    s4 = substr(streamBytes,p,size4)
    each = (regen + 3) % 4
    count4 = regen - 3*each
    if count4 < 0 then raise syntax 88.900 array('Invalid Zstandard four-stream regenerated size')
    decoded1 = table~decodeStream(s1,each)
    decoded2 = table~decodeStream(s2,each)
    decoded3 = table~decodeStream(s3,each)
    decoded4 = table~decodeStream(s4,count4)
    data = decoded1 || decoded2 || decoded3 || decoded4
  end
  if length(data) \== regen then raise syntax 88.900 array('Zstandard Huffman regenerated-size mismatch')
  return .array~of(data,headerSize+compressedSize)

::method tableForMode private
  use strict arg block, pos, mode, kind, maxSymbol, maxLog, previous, predefined
  select
    when mode = 0 then return .array~of(predefined,0)
    when mode = 1 then do
      if pos > length(block) then raise syntax 88.900 array('Missing Zstandard ' || kind || ' RLE table symbol')
      symbol = self~byteAt(block,pos)
      if symbol > maxSymbol then raise syntax 88.900 array('Zstandard ' || kind || ' RLE symbol exceeds limit')
      return .array~of(.ZstdRLEFSETable~new(symbol),1)
    end
    when mode = 2 then do
      if pos > length(block) then raise syntax 88.900 array('Missing Zstandard ' || kind || ' FSE table description')
      info = .ZstdFSETable~fromDescription(substr(block,pos),maxSymbol,maxLog)
      return .array~of(info[1],info[2])
    end
    otherwise do
      if previous == .nil then raise syntax 88.900 array('Zstandard ' || kind || ' Repeat_Mode has no previous table')
      return .array~of(previous,0)
    end
  end

::method resolveOffset private
  expose repeat1 repeat2 repeat3
  use strict arg offsetValue, literalLength
  numeric digits 80
  if offsetValue > 3 then do
    offset = offsetValue - 3
    repeat3 = repeat2; repeat2 = repeat1; repeat1 = offset
    return offset
  end

  if literalLength = 0 then do
    select
      when offsetValue = 1 then do
        offset = repeat2
        old1 = repeat1; repeat1 = repeat2; repeat2 = old1
      end
      when offsetValue = 2 then do
        offset = repeat3
        old1 = repeat1; old2 = repeat2
        repeat1 = repeat3; repeat2 = old1; repeat3 = old2
      end
      otherwise do
        offset = repeat1 - 1
        if offset = 0 then raise syntax 88.900 array('Invalid Zstandard repeat1-1 offset zero')
        repeat3 = repeat2; repeat2 = repeat1; repeat1 = offset
      end
    end
    return offset
  end

  select
    when offsetValue = 1 then return repeat1
    when offsetValue = 2 then do
      offset = repeat2
      old1 = repeat1; repeat1 = repeat2; repeat2 = old1
      return offset
    end
    otherwise do
      offset = repeat3
      old1 = repeat1; old2 = repeat2
      repeat1 = repeat3; repeat2 = old1; repeat3 = old2
      return offset
    end
  end

::method appendMatch private
  use strict arg prior, current, offset, count
  available = length(prior) + length(current)
  if offset <= 0 | offset > available then raise syntax 88.900 array('Zstandard match source outside available history')
  if count = 0 then return current
  if offset <= length(current) then pattern = right(current,offset)
  else do
    fromPrior = offset - length(current)
    pattern = right(prior,fromPrior) || current
  end
  if length(pattern) \== offset then raise syntax 88.900 array('Zstandard match pattern construction failed')
  repetitions = count % offset
  remainder = count // offset
  if repetitions > 0 then current ||= copies(pattern,repetitions)
  if remainder > 0 then current ||= left(pattern,remainder)
  return current

::method literalLengthInfo private
  use strict arg code
  if code < 0 | code > 35 then raise syntax 88.900 array('Invalid Zstandard literal-length code ' || code)
  if code <= 15 then return .array~of(code,0)
  if code <= 23 then do
    bases = .array~of(16,18,20,22,24,28,32,40)
    bits = .array~of(1,1,1,1,2,2,3,3)
    i = code-15
    return .array~of(bases[i],bits[i])
  end
  if code <= 31 then do
    bases = .array~of(48,64,128,256,512,1024,2048,4096)
    bits = .array~of(4,6,7,8,9,10,11,12)
    i = code-23
    return .array~of(bases[i],bits[i])
  end
  bases = .array~of(8192,16384,32768,65536)
  bits = .array~of(13,14,15,16)
  i = code-31
  return .array~of(bases[i],bits[i])

::method matchLengthInfo private
  use strict arg code
  if code < 0 | code > 52 then raise syntax 88.900 array('Invalid Zstandard match-length code ' || code)
  if code <= 31 then return .array~of(code+3,0)
  if code <= 39 then do
    bases = .array~of(35,37,39,41,43,47,51,59)
    bits = .array~of(1,1,1,1,2,2,3,3)
    i = code-31
    return .array~of(bases[i],bits[i])
  end
  if code <= 47 then do
    bases = .array~of(67,83,99,131,259,515,1027,2051)
    bits = .array~of(4,4,5,7,8,9,10,11)
    i = code-39
    return .array~of(bases[i],bits[i])
  end
  bases = .array~of(4099,8195,16387,32771,65539)
  bits = .array~of(12,13,14,15,16)
  i = code-47
  return .array~of(bases[i],bits[i])

::method llDefault private
  return .array~of(4,3,2,2,2,2,2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,2,2,3,2,1,1,1,1,1,-1,-1,-1,-1)
::method mlDefault private
  return .array~of(1,4,3,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,-1,-1,-1,-1,-1,-1,-1)
::method ofDefault private
  return .array~of(1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,-1,-1,-1,-1,-1)

::method leAt private
  use strict arg bytes, pos, count
  numeric digits 80
  if count < 0 | pos < 1 | pos + count - 1 > length(bytes) then raise syntax 88.900 array('Out-of-range Zstandard compressed-block integer read')
  value = 0
  multiplier = 1
  do i = 0 to count - 1
    value += self~byteAt(bytes,pos+i) * multiplier
    multiplier *= 256
  end
  return value

::method byteAt private
  use strict arg bytes, pos
  if pos < 1 | pos > length(bytes) then raise syntax 88.900 array('Out-of-range Zstandard compressed-block byte read')
  return c2d(substr(bytes,pos,1))

::requires 'ZstdReverseBitReader.cls'
::requires 'ZstdFSETable.cls'
::requires 'ZstdHuffmanTable.cls'
