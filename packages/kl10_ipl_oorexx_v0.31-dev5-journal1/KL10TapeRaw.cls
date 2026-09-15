/* KL10TapeRaw.cls
 * Generic SIMH/E11 tape-file reader and PDP-10 36-bit raw depositor.
 *
 * Representation stays in BinarySheet.  This class understands SIMH tape
 * framing and the PDP-10 5-byte CORE-DUMP storage slot, but it deliberately
 * does not claim that every tape file is an IPL image.
 */

::class SimhTapeReader public

::method init
  expose sheet pos fileNo markRun mounted
  sheet = .BinarySheet~new~~useLittleEndian~~useMsbFirstBits
  sheet~define("meta", "value u32le")
  sheet~define("core36", "hi u32be skipbits4 lo u4msb")
  pos = 0
  fileNo = 0
  markRun = 0
  mounted = 0

::method mount
  expose sheet pos fileNo markRun mounted
  use arg path
  sheet~bindFile(path)
  pos = 0
  fileNo = 0
  markRun = 0
  mounted = 1
  return self

::method close
  expose sheet mounted
  sheet~close
  mounted = 0
  return self

::method rewind
  expose pos fileNo markRun
  pos = 0
  fileNo = 0
  markRun = 0
  return self

::method size
  expose sheet
  return sheet~size

::method fileNumber
  expose fileNo
  return fileNo

::method position
  expose pos
  return pos

::method markRun
  expose markRun
  return markRun

::method isMounted
  expose mounted
  return mounted

::method restorePosition
  expose sheet pos fileNo markRun mounted
  use strict arg bytePosition, restoredFileNo, restoredMarkRun
  if \mounted then raise syntax 40.900 array("SIMH tape must be mounted before restoring position")
  if \datatype(bytePosition,"W") | bytePosition < 0 | bytePosition > sheet~size then
    raise syntax 40.900 array("invalid SIMH tape byte position:" bytePosition)
  if \datatype(restoredFileNo,"W") | restoredFileNo < 0 then
    raise syntax 40.900 array("invalid SIMH tape file number:" restoredFileNo)
  if \datatype(restoredMarkRun,"W") | restoredMarkRun < 0 then
    raise syntax 40.900 array("invalid SIMH tape mark-run:" restoredMarkRun)
  pos=bytePosition
  fileNo=restoredFileNo
  markRun=restoredMarkRun
  return self

::method next
  expose sheet pos fileNo markRun mounted
  numeric digits 30
  if \mounted then raise syntax 40.900 array("SIMH tape is not mounted")
  if pos + 4 > sheet~size then return .SimhTapeRecord~eot(pos, fileNo, "HOST_EOF")

  raw = sheet~parse("meta", pos)["value"]
  headerAt = pos
  pos = pos + 4

  /* SIMH/E11 special metadata values. */
  if raw = 0 then do
    r = .SimhTapeRecord~mark(headerAt, fileNo)
    fileNo = fileNo + 1
    markRun = markRun + 1
    return r
  end
  if raw = 4294967295 then do
    markRun = 0
    return .SimhTapeRecord~eot(headerAt, fileNo, "MTR_EOM")
  end
  if raw = 4294967294 then do
    markRun = 0
    return .SimhTapeRecord~gap(headerAt, fileNo, "MTR_GAP")
  end
  if raw = 4294901759 then do
    markRun = 0
    return .SimhTapeRecord~gap(headerAt, fileNo, "MTR_FHGAP")
  end

  errorFlag = 0
  if raw >= (2 ** 31) then do
    errorFlag = 1
    n = raw - (2 ** 31)
  end
  else n = raw

  if n < 1 | n > 16777215 then
    raise syntax 40.900 array("unsupported SIMH metadata word:" raw "at" headerAt)

  pad = n // 2
  payloadAt = pos
  trailerAt = payloadAt + n + pad
  if trailerAt + 4 > sheet~size then
    raise syntax 40.900 array("truncated SIMH record at" headerAt "length" n)

  trailerRaw = sheet~parse("meta", trailerAt)["value"]
  if trailerRaw = 4294967295 | trailerRaw = 4294967294 then
    raise syntax 40.900 array("SIMH special marker where record trailer expected at" trailerAt)
  if trailerRaw >= (2 ** 31) then trailerLen = trailerRaw - (2 ** 31)
                               else trailerLen = trailerRaw
  if trailerLen \= n then
    raise syntax 40.900 array("SIMH trailer mismatch at" headerAt "header" n "trailer" trailerLen)

  pos = trailerAt + 4
  markRun = 0
  return .SimhTapeRecord~data(sheet, headerAt, payloadAt, n, fileNo, errorFlag)


::class SimhTapeRecord public
::attribute kind
::attribute headerOffset
::attribute payloadOffset
::attribute length
::attribute fileNumber
::attribute errorFlag
::attribute reason
::attribute sheet

::method data class
  use arg sheet, headerAt, payloadAt, n, fileNo, errorFlag
  r = .SimhTapeRecord~new
  r~kind = "DATA"
  r~sheet = sheet
  r~headerOffset = headerAt
  r~payloadOffset = payloadAt
  r~length = n
  r~fileNumber = fileNo
  r~errorFlag = errorFlag
  r~reason = ""
  return r

::method mark class
  use arg at, fileNo
  r = .SimhTapeRecord~new
  r~kind = "MARK"
  r~sheet = .nil
  r~headerOffset = at
  r~payloadOffset = .nil
  r~length = 0
  r~fileNumber = fileNo
  r~errorFlag = 0
  r~reason = "TAPE_MARK"
  return r

::method eot class
  use arg at, fileNo, why
  r = .SimhTapeRecord~new
  r~kind = "EOT"
  r~sheet = .nil
  r~headerOffset = at
  r~payloadOffset = .nil
  r~length = 0
  r~fileNumber = fileNo
  r~errorFlag = 0
  r~reason = why
  return r

::method gap class
  use arg at, fileNo, why
  r = .SimhTapeRecord~new
  r~kind = "GAP"
  r~sheet = .nil
  r~headerOffset = at
  r~payloadOffset = .nil
  r~length = 0
  r~fileNumber = fileNo
  r~errorFlag = 0
  r~reason = why
  return r

::method isData
  expose kind
  return kind = "DATA"
::method isMark
  expose kind
  return kind = "MARK"
::method isEot
  expose kind
  return kind = "EOT"
::method isGap
  expose kind
  return kind = "GAP"

::method wordCount36
  expose kind length
  if kind \= "DATA" then return 0
  if length // 5 \= 0 then return .nil
  return length % 5

::method word36
  expose kind sheet payloadOffset length
  use arg index
  numeric digits 30
  if kind \= "DATA" then raise syntax 40.900 array("word36 requires a data record")
  if length // 5 \= 0 then raise syntax 40.900 array("record is not an integral number of PDP-10 core-dump slots:" length)
  count = length % 5
  if index < 0 | index >= count then raise syntax 40.900 array("word36 index out of range:" index)
  row = sheet~parseBits("core36", (payloadOffset + index * 5) * 8)
  return row["hi"] * 16 + row["lo"]


::class KL10DepositMemory public

::method init
  expose words count highest installedPages
  words = .directory~new
  count = 0
  highest = -1
  /* The preserved KL10 target has 256K words = 512 512-word pages of
   * installed physical core. Deposited EXB extent is independent of this. */
  installedPages = 512

::method deposit
  expose words count highest
  use arg address, value
  numeric digits 30
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 deposit address:" address)
  if \words~hasIndex(address) then count = count + 1
  words[address] = value // (2 ** 36)
  if address > highest then highest = address
  return self

::method put
  use arg address, value
  return self~deposit(address, value)

::method examine
  expose words
  use arg address
  if \words~hasIndex(address) then return 0
  return words[address]

::method word
  /* Common memory read surface used by KL10CPU.  Sparse, undeposited words
   * read as zero, matching a freshly cleared bootstrap memory model. */
  use arg address
  return self~examine(address)

::method contains
  expose words
  use arg address
  return words~hasIndex(address)

::method depositedWords
  expose count
  return count

::method highestAddress
  expose highest
  return highest

::method installedPages
  expose installedPages
  return installedPages

::method installedWords
  expose installedPages
  return installedPages * 512

::method mappedPageNumbers
  expose highest
  out = .array~new
  if highest < 0 then return out
  lastPage = highest % 512
  do page = 0 to lastPage
    out~append(page)
  end
  return out


::class KL10RawTapeLoader public

::method init
  expose tape loaded firstWord selectedFile
  use arg tapeObject
  tape = tapeObject
  loaded = 0
  firstWord = .nil
  selectedFile = .nil

::method loadFile
  expose tape loaded firstWord selectedFile
  use arg wantedFile, startAddress, maxWords
  if arg(1, "O") then wantedFile = 0
  if arg(2, "O") then startAddress = 0
  if arg(3, "O") then maxWords = .nil
  if \datatype(wantedFile, "W") | wantedFile < 0 then
    raise syntax 40.900 array("bad tape file number:" wantedFile)
  if \datatype(startAddress, "W") | startAddress < 0 then
    raise syntax 40.900 array("bad deposit start address:" startAddress)
  if maxWords \= .nil then do
    if \datatype(maxWords, "W") | maxWords < 1 then
      raise syntax 40.900 array("bad maximum word count:" maxWords)
  end

  tape~rewind
  mem = .KL10DepositMemory~new
  loaded = 0
  firstWord = .nil
  selectedFile = wantedFile
  inSelected = 0

  do forever
    rec = tape~next
    if rec~isEot then leave
    if rec~isGap then iterate
    if rec~isMark then do
      if inSelected then leave
      iterate
    end
    if rec~fileNumber \= wantedFile then iterate
    inSelected = 1
    wc = rec~wordCount36
    if wc = .nil then
      raise syntax 40.900 array("selected tape file contains non-core-dump record of" rec~length "bytes")
    do i = 0 to wc - 1
      if maxWords \= .nil then do
        if loaded >= maxWords then return mem
      end
      w = rec~word36(i)
      if firstWord = .nil then firstWord = w
      mem~deposit(startAddress + loaded, w)
      loaded = loaded + 1
    end
  end
  if \inSelected then raise syntax 40.900 array("tape file not found:" wantedFile)
  return mem

::method loadedWords
  expose loaded
  return loaded

::method firstWord
  expose firstWord
  return firstWord

::method classification
  expose firstWord
  numeric digits 30
  if firstWord = .nil then return "EMPTY"
  lh = (firstWord % (2 ** 18)) // (2 ** 18)
  if lh = 1022 then return "TOPS20_EXE_DIRECTORY"
  return "RAW_OR_UNKNOWN"

::method canAssumePcZero
  /* Raw loading does not establish architecture start state. */
  return 0

::requires "lib/BinarySheet.cls"
