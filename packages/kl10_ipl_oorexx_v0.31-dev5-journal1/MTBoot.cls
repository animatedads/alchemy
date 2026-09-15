/* MTBoot.cls
 * TOPS-20 DUMPER -> MTBOOT.EXB -> KL10 bootstrap-state adapter.
 *
 * BinarySheet still only describes representation.  This layer owns the
 * historical meanings: DUMPER file records, PDP-10 four-8-bit-byte file
 * packing, and the EXB load-record grammar used by the KL10 simulator.
 */

::class Tops20DumperExtractor public

::method init
  expose tape
  use arg tapeObject
  tape = tapeObject

::method extract
  expose tape
  use arg wantedName
  numeric digits 30
  tape~rewind
  collecting = 0
  found = 0
  sourceRecords = 0
  words = .array~new
  actualName = ""

  do forever
    rec = tape~next
    if rec~isEot then leave
    if rec~isGap then iterate
    if rec~isMark then do
      if collecting then raise syntax 40.900 array("tape mark before DUMPER file trailer:" wantedName)
      iterate
    end
    if rec~length \= 2590 then iterate
    if rec~wordCount36 \= 518 then iterate

    typ = self~signed36(rec~word36(4))
    if typ = -2 then do
      name = self~ascii7z(rec, 6, 122)
      if name~pos(wantedName) = 1 then do
        collecting = 1
        found = 1
        actualName = wantedName
      end
      else collecting = 0
      iterate
    end

    if collecting then do
      if typ = 0 then do
        sourceRecords = sourceRecords + 1
        do i = 6 to 517
          words[words~items + 1] = rec~word36(i)
        end
        iterate
      end
      if typ = -3 then leave
      raise syntax 40.900 array("unexpected DUMPER record type while extracting" wantedName ":" typ)
    end
  end

  if \found then raise syntax 40.900 array("DUMPER file not found:" wantedName)
  return .DumperWordFile~new(actualName, words, sourceRecords)

::method signed36 private
  use arg value
  numeric digits 30
  if value >= (2 ** 35) then return value - (2 ** 36)
  return value

::method ascii7z private
  use arg rec, firstWord, count
  numeric digits 30
  out = ""
  stop = 0
  do wi = 0 to count - 1 while \stop
    word = rec~word36(firstWord + wi)
    do shift over 29, 22, 15, 8, 1
      code = (word % (2 ** shift)) // 128
      if code = 0 then do
        stop = 1
        leave
      end
      out = out || d2c(code)
    end
  end
  return out


::class DumperWordFile public

::method init
  expose name words recordCount
  use arg fileName, fileWords, sourceRecords
  name = fileName
  words = fileWords
  recordCount = sourceRecords

::method name
  expose name
  return name

::method words
  expose words
  return words~items

::method sourceRecords
  expose recordCount
  return recordCount

::method byteCount
  expose words
  return words~items * 4

::method byteAt
  expose words
  use arg index
  numeric digits 30
  if index < 0 | index >= self~byteCount then
    raise syntax 40.900 array("DUMPER file byte index out of range:" index)
  wi = index % 4
  slot = index // 4
  word = words[wi + 1]
  select
    when slot = 0 then return (word % (2 ** 18)) // 256
    when slot = 1 then return (word % (2 ** 26)) // 256
    when slot = 2 then return word // 256
    when slot = 3 then return (word % (2 ** 8)) // 256
  end
  raise syntax 40.900 array("internal PDP-10 byte-slot error")

::method openByteStream
  return .DumperByteStream~new(self)


::class DumperByteStream public

::method init
  expose file pos
  use arg wordFile
  file = wordFile
  pos = 0

::method position
  expose pos
  return pos

::method remaining
  expose file pos
  return file~byteCount - pos

::method readByte
  expose file pos
  if pos >= file~byteCount then raise syntax 40.900 array("EOF in DUMPER file byte stream")
  value = file~byteAt(pos)
  pos = pos + 1
  return value


::class KL10ExbLoader public

::method init
  expose start recordCount deposited consumed padCount records memory
  start = .nil
  recordCount = 0
  deposited = 0
  consumed = 0
  padCount = 0
  records = .array~new
  memory = .nil

::method load
  expose start recordCount deposited consumed padCount records memory
  use arg wordFile
  numeric digits 30
  stream = wordFile~openByteStream
  memory = .KL10DepositMemory~new
  start = .nil
  recordCount = 0
  deposited = 0
  padCount = 0
  records = .array~new
  odd = 0

  do forever
    if odd then do
      ignorePad = stream~readByte
      padCount = padCount + 1
    end

    rawCount = stream~readByte + stream~readByte * 256
    byteCount = rawCount - 4
    if byteCount < 0 then raise syntax 40.900 array("bad EXB record byte count:" rawCount)
    odd = byteCount // 2

    address = stream~readByte
    address = address + stream~readByte * (2 ** 8)
    address = address + stream~readByte * (2 ** 16)
    address = address + stream~readByte * (2 ** 24)

    info = .directory~new
    info["rawCount"] = rawCount
    info["byteCount"] = byteCount
    info["address"] = address
    records[records~items + 1] = info

    if byteCount = 0 then do
      start = address
      leave
    end

    if byteCount // 5 \= 0 then
      raise syntax 40.900 array("EXB data record is not an integral number of 5-byte 36-bit words:" byteCount)

    addr = address
    do i = 1 to byteCount % 5
      b0 = stream~readByte
      b1 = stream~readByte
      b2 = stream~readByte
      b3 = stream~readByte
      b4 = stream~readByte
      word = b0 + b1 * (2 ** 8) + b2 * (2 ** 16) + b3 * (2 ** 24) + (b4 // 16) * (2 ** 32)
      memory~deposit(addr, word)
      addr = addr + 1
      deposited = deposited + 1
    end
    recordCount = recordCount + 1
  end

  consumed = stream~position
  if start = .nil then raise syntax 40.900 array("EXB stream ended without start-address terminator")
  return memory

::method startAddress
  expose start
  return start

::method dataRecords
  expose recordCount
  return recordCount

::method depositedWords
  expose deposited
  return deposited

::method consumedBytes
  expose consumed
  return consumed

::method padBytes
  expose padCount
  return padCount

::method records
  expose records
  return records

::method memory
  expose memory
  return memory

::requires "KL10TapeRaw.cls"
