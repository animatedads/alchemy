/*----------------------------------------------------------------------------*/
/* ZstdHuffmanTable.cls -- Zstandard literal Huffman decoding table.          */
/*----------------------------------------------------------------------------*/
::class ZstdHuffmanTable public

::method init
  expose weights maxBits lookup nonzeroCount
  use strict arg listedWeights
  weights = .array~new
  sum = 0
  nonzeroCount = 0
  hasWeight1 = .false
  do i = 1 to listedWeights~items
    w = listedWeights[i]
    if w < 0 | w > 15 then raise syntax 88.900 array('Invalid Zstandard Huffman weight ' || w)
    weights[i] = w
    if w > 0 then do
      sum += 2 ** (w-1)
      nonzeroCount += 1
      if w = 1 then hasWeight1 = .true
    end
  end
  if sum <= 0 then raise syntax 88.900 array('Zstandard Huffman weight sum is empty')

  nextPower = 1
  maxBits = 0
  do while nextPower <= sum
    nextPower *= 2
    maxBits += 1
  end
  remainder = nextPower - sum
  if remainder <= 0 | \self~isPowerOfTwo(remainder) then raise syntax 88.900 array('Zstandard Huffman final weight cannot complete a power of two')
  finalWeight = self~floorLog2(remainder) + 1
  if finalWeight > 15 then raise syntax 88.900 array('Invalid inferred Zstandard Huffman weight ' || finalWeight)
  weights[listedWeights~items+1] = finalWeight
  nonzeroCount += 1
  if finalWeight = 1 then hasWeight1 = .true

  if maxBits > 11 then raise syntax 88.900 array('Zstandard Huffman tree exceeds maximum depth 11')
  if nonzeroCount < 2 then raise syntax 88.900 array('Zstandard Huffman tree requires at least two non-zero symbols')
  if \hasWeight1 then raise syntax 88.900 array('Zstandard Huffman tree has no weight-1 symbol')

  lookup = .directory~new
  cumulative = 0
  do w = 1 to maxBits
    unit = 2 ** (w-1)
    startCode = cumulative % unit
    ordinal = 0
    do symbol = 0 to weights~items - 1
      if weights[symbol+1] \== w then iterate
      nbits = maxBits + 1 - w
      code = startCode + ordinal
      key = nbits || ':' || code
      if lookup~hasIndex(key) then raise syntax 88.900 array('Duplicate Zstandard Huffman code')
      lookup[key] = symbol
      ordinal += 1
    end
    cumulative += ordinal * unit
  end
  if cumulative \== nextPower then raise syntax 88.900 array('Zstandard Huffman code space is incomplete')

::method maximumBits
  expose maxBits
  return maxBits

::method allWeights
  expose weights
  return weights

::method decodeStream
  expose maxBits lookup
  use strict arg bytes, symbolCount
  if symbolCount < 0 then raise syntax 88.900 array('Negative Zstandard Huffman symbol count')
  reader = .ZstdReverseBitReader~new(bytes)
  out = ''
  do symbolCount
    found = .false
    maximum = maxBits
    if reader~bitsRemaining < maximum then maximum = reader~bitsRemaining
    do n = 1 to maximum
      code = reader~peekBits(n)
      key = n || ':' || code
      if lookup~hasIndex(key) then do
        reader~skipBits(n)
        out ||= d2c(lookup[key],1)
        found = .true
        leave
      end
    end
    if \found then raise syntax 88.900 array('Invalid Zstandard Huffman prefix')
  end
  if \reader~exhausted then raise syntax 88.900 array('Zstandard Huffman stream not exactly consumed; ' || reader~bitsRemaining || ' bits remain')
  return out

::method fromDescription class
  use strict arg bytes
  if length(bytes) = 0 then raise syntax 88.900 array('Missing Zstandard Huffman tree description')
  header = c2d(substr(bytes,1,1))
  if header < 128 then do
    if header = 0 then raise syntax 88.900 array('Zero-sized FSE-compressed Zstandard Huffman weights')
    if 1 + header > length(bytes) then raise syntax 88.900 array('Truncated FSE-compressed Zstandard Huffman weights')
    payload = substr(bytes,2,header)
    fseInfo = .ZstdFSETable~fromDescription(payload,11,6)
    fseTable = fseInfo[1]
    tableBytes = fseInfo[2]
    if tableBytes >= header then raise syntax 88.900 array('Zstandard Huffman FSE header leaves no weight bitstream')
    bitstream = substr(payload,tableBytes+1)
    weights = self~decodeFseWeights(fseTable,bitstream)
    return .array~of(self~new(weights),1+header)
  end
  count = header - 127
  bodyBytes = (count + 1) % 2
  if 1 + bodyBytes > length(bytes) then raise syntax 88.900 array('Truncated direct Zstandard Huffman weights')
  weights = .array~new
  index = 1
  do i = 1 to bodyBytes
    b = c2d(substr(bytes,1+i,1))
    if index <= count then do; weights[index] = b % 16; index += 1; end
    if index <= count then do; weights[index] = b // 16; index += 1; end
  end
  return .array~of(self~new(weights),1+bodyBytes)

::method decodeFseWeights class private
  use strict arg table, bitstream
  reader = .ZstdReverseBitReader~new(bitstream)
  log = table~accuracyLog
  if reader~bitsRemaining < 2*log then raise syntax 88.900 array('Truncated Zstandard Huffman FSE initial states')
  state1 = reader~readBits(log)
  state2 = reader~readBits(log)
  weights = .array~new
  count = 0

  do forever
    count += 1
    if count > 255 then raise syntax 88.900 array('Zstandard Huffman FSE produced more than 255 weights')
    weights[count] = table~symbolAt(state1)
    need = table~numBitsAt(state1)
    if need > reader~bitsRemaining then do
      state1 = table~nextState(state1,reader,.true)
      count += 1
      if count > 255 then raise syntax 88.900 array('Zstandard Huffman FSE produced more than 255 weights')
      weights[count] = table~symbolAt(state2)
      leave
    end
    state1 = table~nextState(state1,reader)

    count += 1
    if count > 255 then raise syntax 88.900 array('Zstandard Huffman FSE produced more than 255 weights')
    weights[count] = table~symbolAt(state2)
    need = table~numBitsAt(state2)
    if need > reader~bitsRemaining then do
      state2 = table~nextState(state2,reader,.true)
      count += 1
      if count > 255 then raise syntax 88.900 array('Zstandard Huffman FSE produced more than 255 weights')
      weights[count] = table~symbolAt(state1)
      leave
    end
    state2 = table~nextState(state2,reader)
  end

  if \reader~exhausted then raise syntax 88.900 array('Zstandard Huffman FSE bitstream not exhausted after overflow termination')
  return weights

::method isPowerOfTwo private
  use strict arg n
  if n <= 0 then return .false
  do while n > 1
    if n // 2 \== 0 then return .false
    n = n % 2
  end
  return .true

::method floorLog2 private
  use strict arg n
  if n <= 0 then raise syntax 88.900 array('floorLog2 requires positive integer')
  p = 0
  do while n >= 2
    n = n % 2
    p += 1
  end
  return p

::requires 'ZstdReverseBitReader.cls'
::requires 'ZstdFSETable.cls'
