/*----------------------------------------------------------------------------*/
/* ZstdFSETable.cls -- normalized-distribution parser and FSE decode table.    */
/*----------------------------------------------------------------------------*/
::class ZstdFSETable public

::method init
  expose symbols numBits baselines log tableSize normalized maxSymbol
  use strict arg normalized, log
  if log < 5 | log > 15 then raise syntax 88.900 array('Invalid Zstandard FSE Accuracy_Log ' || log)
  tableSize = 2 ** log
  maxSymbol = normalized~items - 1
  if maxSymbol < 0 then raise syntax 88.900 array('Empty Zstandard FSE distribution')

  total = 0
  nonzero = 0
  do s = 0 to maxSymbol
    p = normalized[s+1]
    if p < -1 then raise syntax 88.900 array('Invalid Zstandard FSE probability ' || p)
    if p \== 0 then nonzero += 1
    if p = -1 then total += 1
    else total += p
  end
  if total \== tableSize then raise syntax 88.900 array('Zstandard FSE distribution sum ' || total || ' does not equal table size ' || tableSize)
  if nonzero < 2 then raise syntax 88.900 array('Zstandard FSE distribution must contain at least two non-zero symbols')

  symbols = .array~new(tableSize)
  numBits = .array~new(tableSize)
  baselines = .array~new(tableSize)

  /* Less-than-one probabilities occupy the high rows first. */
  high = tableSize - 1
  do s = 0 to maxSymbol
    if normalized[s+1] = -1 then do
      symbols[high+1] = s
      high -= 1
    end
  end

  step = tableSize % 2 + tableSize % 8 + 3
  mask = tableSize - 1
  position = 0
  do s = 0 to maxSymbol
    p = normalized[s+1]
    if p <= 0 then iterate
    do p
      symbols[position+1] = s
      position = (position + step) // tableSize
      do while position > high
        position = (position + step) // tableSize
      end
    end
  end
  if position \== 0 then raise syntax 88.900 array('Zstandard FSE row spread did not terminate at state zero')

  /* Standard FSE decode-table construction: symbolNext is the next ordinal */
  /* for each symbol. It is equivalent to the specification's sorted-row rule.*/
  symbolNext = .array~new(maxSymbol+1)
  do s = 0 to maxSymbol
    p = normalized[s+1]
    if p = -1 then symbolNext[s+1] = 1
    else symbolNext[s+1] = p
  end

  do state = 0 to tableSize - 1
    sym = symbols[state+1]
    if sym == .nil then raise syntax 88.900 array('Unfilled Zstandard FSE decode-table row ' || state)
    next = symbolNext[sym+1]
    symbolNext[sym+1] = next + 1
    nbits = log - self~floorLog2(next)
    base = next * (2 ** nbits) - tableSize
    numBits[state+1] = nbits
    baselines[state+1] = base
  end

::method accuracyLog
  expose log
  return log

::method size
  expose tableSize
  return tableSize

::method symbolAt
  expose symbols tableSize
  use strict arg state
  if state < 0 | state >= tableSize then raise syntax 88.900 array('Invalid Zstandard FSE state ' || state)
  return symbols[state+1]

::method numBitsAt
  expose numBits tableSize
  use strict arg state
  if state < 0 | state >= tableSize then raise syntax 88.900 array('Invalid Zstandard FSE state ' || state)
  return numBits[state+1]

::method baselineAt
  expose baselines tableSize
  use strict arg state
  if state < 0 | state >= tableSize then raise syntax 88.900 array('Invalid Zstandard FSE state ' || state)
  return baselines[state+1]

::method nextState
  expose numBits baselines tableSize
  use strict arg state, bitReader, padded = .false
  if state < 0 | state >= tableSize then raise syntax 88.900 array('Invalid Zstandard FSE state ' || state)
  n = numBits[state+1]
  if padded then extra = bitReader~readBitsPadded(n)
  else extra = bitReader~readBits(n)
  return baselines[state+1] + extra

::method normalizedDistribution
  expose normalized
  return normalized

::method fromDescription class
  use strict arg bytes, maxAllowedSymbol, maxAccuracyLog
  if length(bytes) = 0 then raise syntax 88.900 array('Missing Zstandard FSE table description')
  reader = .ZstdForwardBitReader~new(bytes)
  log = reader~readBits(4) + 5
  if log > maxAccuracyLog then raise syntax 88.900 array('Zstandard FSE Accuracy_Log ' || log || ' exceeds allowed ' || maxAccuracyLog)
  tableSize = 2 ** log
  remaining = tableSize + 1
  threshold = tableSize
  nbBits = log + 1
  normalized = .array~new
  symbol = 0
  nonzero = 0

  do while remaining > 1
    if symbol > maxAllowedSymbol then raise syntax 88.900 array('Zstandard FSE distribution exceeds symbol limit ' || maxAllowedSymbol)
    max = (2 * threshold - 1) - remaining
    full = reader~peekBits(nbBits)
    low = full // threshold
    if low < max then do
      value = low
      reader~skipBits(nbBits-1)
    end
    else do
      value = full
      if value >= threshold then value -= max
      reader~skipBits(nbBits)
    end

    probability = value - 1
    normalized[symbol+1] = probability
    if probability \== 0 then nonzero += 1
    if probability = -1 then remaining -= 1
    else remaining -= probability
    if remaining < 1 then raise syntax 88.900 array('Zstandard FSE probabilities over-allocate table')

    symbol += 1
    if probability = 0 then do
      zeroRun = 0
      do forever
        repeat = reader~readBits(2)
        zeroRun += repeat
        if repeat < 3 then leave
      end
      do zeroRun
        if symbol > maxAllowedSymbol then raise syntax 88.900 array('Zstandard FSE zero run exceeds symbol limit ' || maxAllowedSymbol)
        normalized[symbol+1] = 0
        symbol += 1
      end
    end

    do while remaining < threshold
      nbBits -= 1
      threshold = threshold % 2
    end
  end

  if remaining \== 1 then raise syntax 88.900 array('Invalid Zstandard FSE distribution remainder')
  if nonzero < 2 then raise syntax 88.900 array('Zstandard FSE distribution has fewer than two non-zero symbols')
  consumed = reader~bytesConsumed
  table = self~new(normalized,log)
  return .array~of(table,consumed)

::method floorLog2 private
  use strict arg value
  if value <= 0 then raise syntax 88.900 array('floorLog2 requires positive value')
  log = 0
  do while value >= 2
    value = value % 2
    log += 1
  end
  return log

::requires 'ZstdForwardBitReader.cls'

::class ZstdRLEFSETable public
::method init
  expose fixedSymbol
  use strict arg fixedSymbol
::method accuracyLog
  return 0
::method size
  return 1
::method symbolAt
  expose fixedSymbol
  use strict arg state
  if state \== 0 then raise syntax 88.900 array('Invalid RLE FSE state ' || state)
  return fixedSymbol
::method numBitsAt
  use strict arg state
  if state \== 0 then raise syntax 88.900 array('Invalid RLE FSE state ' || state)
  return 0
::method baselineAt
  use strict arg state
  if state \== 0 then raise syntax 88.900 array('Invalid RLE FSE state ' || state)
  return 0
::method nextState
  use strict arg state, bitReader, padded = .false
  if state \== 0 then raise syntax 88.900 array('Invalid RLE FSE state ' || state)
  return 0
