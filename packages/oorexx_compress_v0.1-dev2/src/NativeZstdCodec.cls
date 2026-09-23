/*----------------------------------------------------------------------------*/
/* NativeZstdCodec.cls -- standards-conformant pure ooRexx bootstrap profile. */
/* Bootstrap encoder emits Raw/RLE blocks. Decoder additionally implements    */
/* dictionary-free Compressed_Block literals/Huffman/FSE/sequences/history.    */
/*----------------------------------------------------------------------------*/
::class NativeZstdCodec public

::method init
  expose hasher maxWindow
  hasher = .NativeXXH64~new
  maxWindow = 8388608

::method capabilities
  return .array~of('compress.zstd.raw', 'compress.zstd.rle', -
                   'decompress.zstd.raw', 'decompress.zstd.rle', -
                   'decompress.zstd.compressed', 'decompress.zstd.huffman', -
                   'decompress.zstd.fse', 'decompress.zstd.repeat-mode', -
                   'frame.zstd.skippable', 'checksum.xxh64', -
                   'bootstrap.no-foreign-runtime')

::method xxh64
  expose hasher
  use strict arg bytes, seed = 0
  return hasher~calculate(bytes, seed)

::method encode
  expose hasher maxWindow
  use strict arg data, mode = 'AUTO', checksum = .true
  numeric digits 80
  mode = translate(mode)
  if mode \== 'AUTO' & mode \== 'RAW' & mode \== 'RLE' then -
    raise syntax 88.900 array('Unsupported native Zstandard mode: ' || mode)
  if checksum \== .true & checksum \== .false & checksum \== 0 & checksum \== 1 then -
    raise syntax 88.900 array('Zstandard checksum option must be boolean')
  checksumFlag = (checksum == .true | checksum == 1)

  n = length(data)
  singleSegment = (n <= maxWindow)
  fcsFlag = self~fcsFlag(n)
  descriptor = fcsFlag * 64
  if singleSegment then descriptor += 32
  if checksumFlag then descriptor += 4

  out = x2c('28B52FFD') || d2c(descriptor,1)
  if \singleSegment then out ||= d2c(104,1)  /* Window_Size = 8 MiB */
  out ||= self~encodeFcs(n, fcsFlag)

  if n = 0 then do
    out ||= self~blockHeader(1, 0, 0)
  end
  else do
    pos = 1
    do while pos <= n
      chunkLength = n - pos + 1
      if chunkLength > 131072 then chunkLength = 131072
      chunk = substr(data,pos,chunkLength)
      last = (pos + chunkLength > n)
      useRle = .false
      if mode == 'RLE' then do
        if \self~isRle(chunk) then raise syntax 88.900 array('RLE mode requires each Zstandard block to contain one repeated byte value')
        useRle = .true
      end
      else if mode == 'AUTO' then useRle = self~isRle(chunk)

      if useRle then out ||= self~blockHeader(last,1,chunkLength) || substr(chunk,1,1)
      else out ||= self~blockHeader(last,0,chunkLength) || chunk
      pos += chunkLength
    end
  end

  if checksumFlag then out ||= self~le(self~low32(hasher~calculate(data,0)),4)
  return out

::method decode
  expose hasher maxWindow
  use strict arg stream
  numeric digits 80
  if length(stream) = 0 then raise syntax 88.900 array('Empty input is not a Zstandard frame stream')
  pos = 1
  allOut = ''
  frames = 0
  do while pos <= length(stream)
    if pos + 3 > length(stream) then raise syntax 88.900 array('Truncated Zstandard frame magic')
    magic = self~leAt(stream,pos,4)
    if magic >= x2d('184D2A50') & magic <= x2d('184D2A5F') then do
      frames += 1
      if pos + 7 > length(stream) then raise syntax 88.900 array('Truncated Zstandard skippable frame header')
      skipSize = self~leAt(stream,pos+4,4)
      if pos + 8 + skipSize - 1 > length(stream) then raise syntax 88.900 array('Truncated Zstandard skippable frame payload')
      pos += 8 + skipSize
      iterate
    end
    if magic \== x2d('FD2FB528') then raise syntax 88.900 array('Invalid Zstandard frame magic at byte ' || pos)

    frames += 1
    frameStart = pos
    pos += 4
    if pos > length(stream) then raise syntax 88.900 array('Missing Zstandard Frame_Header_Descriptor')
    descriptor = self~byteAt(stream,pos); pos += 1
    fcsFlag = descriptor % 64
    singleSegment = (descriptor % 32) // 2
    reservedBit = (descriptor % 8) // 2
    checksumFlag = (descriptor % 4) // 2
    dictFlag = descriptor // 4
    if reservedBit \== 0 then raise syntax 88.900 array('Reserved Zstandard frame-header bit is set')

    if singleSegment = 0 then do
      if pos > length(stream) then raise syntax 88.900 array('Missing Zstandard Window_Descriptor')
      windowDescriptor = self~byteAt(stream,pos); pos += 1
      exponent = windowDescriptor % 8
      mantissa = windowDescriptor // 8
      windowBase = 2 ** (10 + exponent)
      windowAdd = (windowBase % 8) * mantissa
      windowSize = windowBase + windowAdd
    end
    else windowSize = -1

    select
      when dictFlag = 0 then dictSize = 0
      when dictFlag = 1 then dictSize = 1
      when dictFlag = 2 then dictSize = 2
      otherwise dictSize = 4
    end
    dictionaryId = 0
    if dictSize > 0 then do
      dictionaryId = self~leAt(stream,pos,dictSize)
      pos += dictSize
      if dictionaryId \== 0 then raise syntax 88.900 array('Zstandard dictionary ID ' || dictionaryId || ' is unsupported by the native bootstrap provider')
    end

    select
      when fcsFlag = 0 then do
        if singleSegment then fcsSize = 1
        else fcsSize = 0
      end
      when fcsFlag = 1 then fcsSize = 2
      when fcsFlag = 2 then fcsSize = 4
      otherwise fcsSize = 8
    end
    frameContentSize = -1
    if fcsSize > 0 then do
      frameContentSize = self~leAt(stream,pos,fcsSize)
      pos += fcsSize
      if fcsSize = 2 then frameContentSize += 256
    end
    if singleSegment then do
      if frameContentSize < 0 then raise syntax 88.900 array('Single-segment Zstandard frame is missing Frame_Content_Size')
      windowSize = frameContentSize
    end

    if windowSize > maxWindow then raise syntax 88.900 array('Zstandard window ' || windowSize || ' exceeds native bootstrap policy limit ' || maxWindow)
    if windowSize < 0 then raise syntax 88.900 array('Invalid Zstandard window size')
    blockMaximum = windowSize
    if blockMaximum > 131072 then blockMaximum = 131072

    frameOut = ''
    compressedDecoder = .ZstdCompressedBlockDecoder~new(windowSize)
    last = 0
    blocks = 0
    do while last = 0
      blocks += 1
      if pos + 2 > length(stream) then raise syntax 88.900 array('Truncated Zstandard block header')
      blockHeader = self~leAt(stream,pos,3); pos += 3
      last = blockHeader // 2
      blockType = (blockHeader % 2) // 4
      blockSize = blockHeader % 8

      if blockType = 3 then raise syntax 88.900 array('Reserved Zstandard block type 3')
      if blockSize > blockMaximum then raise syntax 88.900 array('Zstandard block size ' || blockSize || ' exceeds Block_Maximum_Size ' || blockMaximum)

      select
        when blockType = 0 then do
          if pos + blockSize - 1 > length(stream) then raise syntax 88.900 array('Truncated Zstandard Raw_Block')
          if blockSize > 0 then frameOut ||= substr(stream,pos,blockSize)
          pos += blockSize
        end
        when blockType = 1 then do
          if pos > length(stream) then raise syntax 88.900 array('Truncated Zstandard RLE_Block')
          repeated = substr(stream,pos,1); pos += 1
          if blockSize > 0 then frameOut ||= copies(repeated,blockSize)
        end
        when blockType = 2 then do
          if pos + blockSize - 1 > length(stream) then raise syntax 88.900 array('Truncated Zstandard Compressed_Block')
          blockContent = substr(stream,pos,blockSize); pos += blockSize
          decodedBlock = compressedDecoder~decode(blockContent,frameOut)
          if length(decodedBlock) > blockMaximum then raise syntax 88.900 array('Decoded Zstandard Compressed_Block exceeds Block_Maximum_Size')
          frameOut ||= decodedBlock
        end
      end
    end

    if frameContentSize >= 0 & length(frameOut) \== frameContentSize then -
      raise syntax 88.900 array('Zstandard Frame_Content_Size mismatch: expected ' || frameContentSize || ' got ' || length(frameOut))

    if checksumFlag then do
      if pos + 3 > length(stream) then raise syntax 88.900 array('Missing Zstandard content checksum')
      expectedChecksum = substr(stream,pos,4); pos += 4
      actualChecksum = self~le(self~low32(hasher~calculate(frameOut,0)),4)
      if expectedChecksum \== actualChecksum then raise syntax 88.900 array('Zstandard content checksum mismatch')
    end
    allOut ||= frameOut
  end
  if frames = 0 then raise syntax 88.900 array('No Zstandard frames found')
  return allOut

::method fcsFlag private
  use strict arg n
  numeric digits 80
  if n <= 255 then return 0
  if n <= 65791 then return 1
  if n <= 4294967295 then return 2
  return 3

::method encodeFcs private
  use strict arg n, flag
  if flag = 0 then return self~le(n,1)
  if flag = 1 then return self~le(n-256,2)
  if flag = 2 then return self~le(n,4)
  return self~le(n,8)

::method blockHeader private
  use strict arg last, blockType, blockSize
  numeric digits 80
  if blockSize < 0 | blockSize > 2097151 then raise syntax 88.900 array('Invalid Zstandard block size ' || blockSize)
  value = blockSize * 8 + blockType * 2 + last
  return self~le(value,3)

::method isRle private
  use strict arg chunk
  if length(chunk) <= 1 then return .true
  return chunk == copies(substr(chunk,1,1),length(chunk))

::method low32 private
  use strict arg value
  numeric digits 80
  return value // 4294967296

::method le private
  use strict arg value, count
  numeric digits 80
  if value < 0 then raise syntax 88.900 array('Cannot encode negative little-endian integer')
  out = ''
  do count
    out ||= d2c(value // 256,1)
    value = value % 256
  end
  if value \== 0 then raise syntax 88.900 array('Integer does not fit in requested little-endian width')
  return out

::method leAt private
  use strict arg bytes, pos, count
  numeric digits 80
  if count < 0 | pos < 1 | pos + count - 1 > length(bytes) then raise syntax 88.900 array('Out-of-range Zstandard integer read')
  value = 0
  multiplier = 1
  do i = 0 to count - 1
    value += self~byteAt(bytes,pos+i) * multiplier
    multiplier *= 256
  end
  return value

::method byteAt private
  use strict arg bytes, pos
  if pos < 1 | pos > length(bytes) then raise syntax 88.900 array('Out-of-range Zstandard byte read at ' || pos)
  return c2d(substr(bytes,pos,1))

::requires 'NativeXXH64.cls'
::requires 'ZstdCompressedBlockDecoder.cls'
