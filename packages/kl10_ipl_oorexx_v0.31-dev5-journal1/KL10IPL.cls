/* KL10IPL.cls
 * Small TOPS-20/KL10 IPL staging model for ooRexx.
 *
 * This is deliberately NOT a KL10 emulator.  It mounts a SIMH/E11 tape,
 * recognizes the first tape file as a PDP-10 .EXE image, follows the .EXE
 * page directory, exposes mapped 36-bit memory, recovers entry/bootstrap state,
 * and provides a deliberately bounded debugger-style CPU step surface.
 *
 * Binary representation belongs to BinarySheet.  TOPS-20/.EXE meaning lives
 * here.
 */

::class Tops20InstallTape public

::method init
  expose sheet pageBases pageCount tapePath
  sheet = .BinarySheet~new~~useLittleEndian~~useMsbFirstBits
  sheet~define("simh", "len u32le")
  sheet~define("core36", "hi u32be skipbits4 lo u4msb")
  tapePath = ""
  pageBases = .array~new
  pageCount = 0

::method mount
  expose sheet pageBases pageCount tapePath
  use arg path
  tapePath = path
  sheet~bindFile(path)
  pageBases = .array~new
  pageCount = 0
  pos = 0
  do while pos < sheet~size
    hdr = sheet~parse("simh", pos)
    n = hdr["len"]
    pos = pos + 4
    if n = 0 then leave
    if n \= 2560 then
      raise syntax 40.900 array("first tape file is not 512 PDP-10 words per record; bytes=" n)
    if pos + n + 4 > sheet~size then
      raise syntax 40.900 array("truncated SIMH tape record")
    trailerAt = pos + n + (n // 2)
    trailer = sheet~parse("simh", trailerAt)["len"]
    if trailer \= n then
      raise syntax 40.900 array("SIMH record trailer mismatch")
    pageCount = pageCount + 1
    pageBases[pageCount] = pos
    pos = trailerAt + 4
  end
  return self

::method close
  expose sheet
  sheet~close
  return self

::method filePages
  expose pageCount
  return pageCount

::method word36
  expose sheet pageBases pageCount
  use arg filePage, wordOffset
  numeric digits 30
  if filePage < 0 | filePage >= pageCount then
    raise syntax 40.900 array("file page out of range:" filePage)
  if wordOffset < 0 | wordOffset >= 512 then
    raise syntax 40.900 array("word offset out of range:" wordOffset)
  base = pageBases[filePage + 1]
  row = sheet~parseBits("core36", (base + wordOffset * 5) * 8)
  return row["hi"] * 16 + row["lo"]

::method halfLeft
  use arg word
  numeric digits 30
  return (word % (2 ** 18)) // (2 ** 18)

::method halfRight
  use arg word
  numeric digits 30
  return word // (2 ** 18)


::class Tops20ExeImage public

::method init
  expose tape groups blocks entryAddress directoryWords
  use arg tapeObject
  tape = tapeObject
  groups = .array~new
  blocks = .array~new
  entryAddress = .nil
  directoryWords = 0
  self~parseDirectory

::method parseDirectory private
  expose tape groups blocks entryAddress directoryWords
  numeric digits 30
  pos = 0
  do forever
    word = tape~word36(0, pos)
    code = tape~halfLeft(word)
    n = tape~halfRight(word)
    if n < 1 then raise syntax 40.900 array("invalid .EXE block length at word" pos)

    b = .directory~new
    b["code"] = code
    b["length"] = n
    b["word"] = pos
    blocks[blocks~items + 1] = b

    select
      when code = 1022 then do       /* 1776 octal: directory */
        directoryWords = n
        if (n - 1) // 2 \= 0 then
          raise syntax 40.900 array("odd .EXE directory payload length")
        p = pos + 1
        do while p < pos + n
          fp = tape~word36(0, p)
          pp = tape~word36(0, p + 1)
          g = .directory~new
          g["flags"] = (fp % (2 ** 27)) // 512
          g["filePage"] = fp // (2 ** 27)
          g["repeat"] = (pp % (2 ** 27)) // 512
          g["processPage"] = pp // (2 ** 27)
          groups[groups~items + 1] = g
          p = p + 2
        end
      end
      when code = 1021 then do       /* 1775 octal: entry vector */
        if n >= 3 then entryAddress = tape~word36(0, pos + 2) // (2 ** 30)
      end
      when code = 1023 then leave    /* 1777 octal: end */
      otherwise nop                  /* preserve unknown blocks; do not invent meaning */
    end
    pos = pos + n
    if pos >= 512 then raise syntax 40.900 array(".EXE directory exceeds first page")
  end
  if directoryWords = 0 then raise syntax 40.900 array("no .EXE directory block")
  if entryAddress = .nil then raise syntax 40.900 array("no .EXE entry vector")

::method groups
  expose groups
  return groups

::method blocks
  expose blocks
  return blocks

::method entryAddress
  expose entryAddress
  return entryAddress

::method directoryWords
  expose directoryWords
  return directoryWords

::method mappedPageCount
  expose groups
  total = 0
  do g over groups
    total = total + g["repeat"] + 1
  end
  return total

::method loadMemory
  expose tape groups
  mem = .KL10Memory~new
  do g over groups
    count = g["repeat"] + 1
    do i = 0 to count - 1
      processPage = g["processPage"] + i
      filePage = g["filePage"]
      if filePage = 0 then
        mem~mapZeroPage(processPage, g["flags"])
      else
        mem~mapTapePage(processPage, tape, filePage + i, g["flags"])
    end
  end
  return mem


::class KL10Memory public

::method init
  expose pages flags writes journalState journalEdit journalPending journalRemoved
  pages = .directory~new
  flags = .directory~new
  writes = .directory~new
  journalState = .nil
  journalEdit = .nil
  journalPending = .directory~new
  journalRemoved = .directory~new

::method enableJournal
  expose writes journalState journalEdit journalPending journalRemoved
  use arg journalId = "KL10-MEMORY"
  if journalState \= .nil then return journalState
  initial=.directory~new
  do address over writes~allIndexes
    initial[address]=writes[address]
  end
  journalState=.JournalPointedState~new(initial,journalId)
  journalEdit=.nil
  journalPending=.directory~new
  journalRemoved=.directory~new
  return journalState

::method journalEnabled
  expose journalState
  return journalState \= .nil

::method journalState
  expose journalState
  return journalState

::method beginJournalEvent
  expose journalState journalEdit journalPending journalRemoved
  use arg tag="INSTRUCTION", metadata=.nil
  if journalState = .nil then raise syntax 40.900 array("KL10 memory journal is not enabled")
  if journalEdit \= .nil then raise syntax 40.900 array("KL10 memory journal event already active")
  journalEdit=journalState~beginEdit(tag,metadata)
  journalPending=.directory~new
  journalRemoved=.directory~new
  return journalState~journalPoint

::method commitJournalEvent
  expose journalState journalEdit journalPending journalRemoved
  if journalEdit = .nil then raise syntax 40.900 array("KL10 memory journal event is not active")
  do address over journalPending~allIndexes
    journalEdit~put(address,journalPending[address])
  end
  do address over journalRemoved~allIndexes
    journalEdit~remove(address)
  end
  point=journalEdit~commit
  journalEdit=.nil
  journalPending=.directory~new
  journalRemoved=.directory~new
  return point

::method abortJournalEvent
  expose journalState journalEdit journalPending journalRemoved
  if journalState = .nil then return .nil
  journalEdit=.nil
  journalPending=.directory~new
  journalRemoved=.directory~new
  return journalState~journalPoint

::method mapTapePage
  expose pages flags
  use arg processPage, tape, filePage, pageFlags
  m = .directory~new
  m["kind"] = "TAPE"
  m["source"] = tape
  m["filePage"] = filePage
  pages[processPage] = m
  flags[processPage] = pageFlags
  return self

::method mapZeroPage
  expose pages flags
  use arg processPage, pageFlags
  m = .directory~new
  m["kind"] = "ZERO"
  pages[processPage] = m
  flags[processPage] = pageFlags
  return self

::method mappedPages
  expose pages
  return pages~items

::method mappedPageNumbers
  expose pages
  out = .array~new
  do page over pages
    out~append(page)
  end
  return out

::method isMapped
  expose pages
  use arg processPage
  return pages~hasIndex(processPage)

::method word
  expose pages writes journalState journalEdit journalPending journalRemoved
  use arg address
  numeric digits 30
  if address < 0 then raise syntax 40.900 array("negative KL10 address")
  if journalEdit \= .nil then do
    if journalPending~hasIndex(address) then return journalPending[address]
    if journalRemoved~hasIndex(address) then signal journalBaseWord
  end
  if journalState \= .nil then do
    if journalState~hasIndex(address) then return journalState~at(address)
  end
  else if writes~hasIndex(address) then return writes[address]
journalBaseWord:
  page = address % 512
  offset = address // 512
  if \pages~hasIndex(page) then
    raise syntax 40.900 array("unmapped KL10 page:" page)
  m = pages[page]
  if m["kind"] = "ZERO" then return 0
  return m["source"]~word36(m["filePage"], offset)

::method put
  expose pages writes journalState journalEdit journalPending journalRemoved
  use arg address, value
  numeric digits 30
  if address < 0 then raise syntax 40.900 array("negative KL10 address")
  page = address % 512
  if \pages~hasIndex(page) then
    raise syntax 40.900 array("write to unmapped KL10 page:" page)
  if value~isa(.LROct) then value = value~decimal
  if \datatype(value, "W") then
    raise syntax 40.900 array("KL10 word write requires a whole 36-bit value")
  value = value // (2 ** 36)
  if journalEdit \= .nil then do
    journalPending[address]=value
    if journalRemoved~hasIndex(address) then ignored=journalRemoved~remove(address)
  end
  else if journalState \= .nil then ignored=journalState~put(address,value,"memory-write")
  else writes[address] = value
  return self

::method deposit
  use arg address, value
  return self~put(address, value)

::method zeroRange
  expose pages writes journalState journalEdit journalPending journalRemoved
  use strict arg first,last
  numeric digits 30
  if first<0 | last<first then
    raise syntax 40.900 array("invalid KL10 zero range:" first last)
  do address=first to last
    page=address % 512
    if \pages~hasIndex(page) then
      raise syntax 40.900 array("zero of unmapped KL10 page:" page)
    m=pages[page]
    if m["kind"]="ZERO" then do
      if journalEdit \= .nil then do
        if journalPending~hasIndex(address) then ignored=journalPending~remove(address)
        journalRemoved[address]=1
      end
      else if journalState \= .nil then do
        if journalState~hasIndex(address) then ignored=journalState~remove(address,"zero-range")
      end
      else if writes~hasIndex(address) then ignored=writes~remove(address)
    end
    else do
      if journalEdit \= .nil then do
        journalPending[address]=0
        if journalRemoved~hasIndex(address) then ignored=journalRemoved~remove(address)
      end
      else if journalState \= .nil then ignored=journalState~put(address,0,"zero-range")
      else writes[address]=0
    end
  end
  return self


::class KL10Word public

::method fromDecimal class
  use strict arg value
  numeric digits 30
  if value~isa(.LROct) then value=value~decimal
  if \datatype(value,"W") then
    raise syntax 40.900 array("KL10Word requires a whole-number value")
  return value // (2 ** 36)

::method fromOctal class
  use strict arg text
  numeric digits 30
  text=changestr(",",text,"")
  if text="" then raise syntax 40.900 array("KL10Word requires octal digits")
  value=0
  do i=1 to text~length
    ch=text~substr(i,1)
    if pos(ch,"01234567")=0 then
      raise syntax 40.900 array("KL10Word invalid octal digit:" ch)
    value=value*8+ch
  end
  return value // (2 ** 36)

::method allOnes class
  numeric digits 30
  return (2 ** 36) - 1

::method bit class
  use strict arg bitNumber
  numeric digits 30
  if \datatype(bitNumber,"W") | bitNumber<0 | bitNumber>35 then
    raise syntax 40.900 array("KL10Word bit number must be 0..35")
  return 2 ** (35-bitNumber)

::class KL10AddressSpace public

::method init
  expose backing cpu overlay lastTranslation
  use strict arg backingMemory, cpuObject
  backing = backingMemory
  cpu = cpuObject
  overlay = .directory~new
  lastTranslation = .nil

::method backingMemory
  expose backing
  return backing

::method lastTranslation
  expose lastTranslation
  return lastTranslation

::method sourceKind
  expose cpu
  use strict arg address
  if address >= 0 & address < 16 then return "AC"
  if cpu~pag~pageEnabled = 1 then return "VIRTUAL"
  return "MEMORY"

::method physicalWord
  expose backing overlay
  use strict arg address
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 physical address:" address)
  if overlay~hasIndex(address) then return overlay[address]
  return backing~word(address)

::method physicalPut
  expose backing overlay
  use strict arg address, value
  numeric digits 30
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 physical address:" address)
  if value~isa(.LROct) then value = value~decimal
  if \datatype(value, "W") then
    raise syntax 40.900 array("KL10 physical write requires a whole 36-bit value")
  value = value // (2 ** 36)
  if backing~hasMethod("PUT") then do
    backing~put(address, value)
    return self
  end
  overlay[address] = value
  return self

::method physicalExists
  expose backing
  use strict arg address
  if \datatype(address, "W") | address < 0 then return 0
  if backing~hasMethod("ISMAPPED") then return backing~isMapped(address % 512)
  /* Sparse bootstrap images describe deposits, not installed-core extent.
   * KL10DepositMemory therefore carries the machine's physical capacity
   * independently from highestAddress. */
  if backing~hasMethod("INSTALLEDWORDS") then return address < backing~installedWords
  return 1

::method probeWord
  expose cpu lastTranslation
  use strict arg address
  probeResult = .directory~new
  probeResult["ok"] = 1
  probeResult["nxm"] = 0
  probeResult["value"] = .nil
  probeResult["translation"] = .nil
  if address < 16 then do
    probeResult["value"] = cpu~accumulator(address)
    return probeResult
  end

  if cpu~pag~pageEnabled = 1 then tr = self~translateTops20(address, 0, 0)
  else do
    tr = .directory~new
    tr["virtual"] = address
    tr["physical"] = address
    tr["kind"] = "DIRECT"
  end
  lastTranslation = tr
  probeResult["translation"] = tr
  physical = tr["physical"]
  if \self~physicalExists(physical) then do
    /* KL APR NXM_MEM is 002000. A nonexistent memory cycle terminates the
     * current operand cycle and leaves the flag visible to subsequent CONI /
     * CONSZ, exactly what MTBOOT's sizing probe depends on. */
    ignored = cpu~apr~signalFlag(self~octToDecLocal("002000"))
    probeResult["ok"] = 0
    probeResult["nxm"] = 1
    probeResult["physical"] = physical
    return probeResult
  end
  probeResult["physical"] = physical
  probeResult["value"] = self~physicalWord(physical)
  return probeResult

::method peekWord
  expose cpu lastTranslation
  use strict arg address
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 address:" address)
  if address < 16 then return cpu~accumulator(address)
  if cpu~pag~pageEnabled \= 1 then return self~physicalWord(address)
  tr = self~translateTops20(address, 0, 1)
  lastTranslation = tr
  return self~physicalWord(tr["physical"])

::method word
  expose cpu lastTranslation
  use strict arg address
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 address:" address)
  if address < 16 then return cpu~accumulator(address)

  if cpu~pag~pageEnabled = 1 then tr = self~translateTops20(address, 0, 0)
  else do
    tr = .directory~new
    tr["virtual"] = address
    tr["physical"] = address
    tr["kind"] = "DIRECT"
    tr["page"] = address % 512
    tr["offset"] = address // 512
    tr["write"] = 0
  end
  lastTranslation = tr

  physical=tr["physical"]
  if \self~physicalExists(physical) then do
    /* KL10 nonexistent-memory read: the memory cycle returns zero while the
     * APR NXM_MEM flag is latched.  Interrupt qualification is a separate APR/
     * PI concern; this bounded path has no NXM enable set in the historical
     * checkpoint, so no interrupt is fabricated here. */
    ignored=cpu~apr~signalFlag(self~octToDecLocal("002000"))
    return 0
  end
  return self~physicalWord(physical)

::method at
  use strict arg address
  return self~word(address)

::method put
  expose cpu lastTranslation
  use strict arg address, value
  numeric digits 30
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 address:" address)
  if value~isa(.LROct) then value = value~decimal
  if \datatype(value, "W") then
    raise syntax 40.900 array("KL10 word write requires a whole 36-bit value")
  value = value // (2 ** 36)
  if address < 16 then do
    cpu~setAccumulator(address, value)
    return self
  end

  if cpu~pag~pageEnabled = 1 then tr = self~translateTops20(address, 1, 0)
  else do
    tr = .directory~new
    tr["virtual"] = address
    tr["physical"] = address
    tr["kind"] = "DIRECT"
    tr["page"] = address % 512
    tr["offset"] = address // 512
    tr["write"] = 1
  end
  lastTranslation = tr

  physical=tr["physical"]
  if \self~physicalExists(physical) then do
    /* KL10 nonexistent-memory write: discard the write and latch APR NXM_MEM.
     * Do not materialize memory beyond installed capacity. */
    ignored=cpu~apr~signalFlag(self~octToDecLocal("002000"))
    return self
  end
  return self~physicalPut(physical, value)

::method deposit
  use strict arg address, value
  return self~put(address, value)

::method translate
  expose lastTranslation
  use arg address, writeAccess = 0, observeOnly = 1
  if address < 16 then do
    tr = .directory~new
    tr["virtual"] = address
    tr["physical"] = address
    tr["kind"] = "AC"
    tr["page"] = 0
    tr["offset"] = address
    tr["sectionPointerAddress"] = .nil
    tr["sectionPointer"] = .nil
    tr["pageMapPage"] = .nil
    tr["pagePointerAddress"] = .nil
    tr["pagePointer"] = .nil
    tr["write"] = writeAccess
    lastTranslation = tr
    return tr
  end
  tr = self~translateTops20(address, writeAccess, observeOnly)
  lastTranslation = tr
  return tr

::method translateTops20 private
  expose cpu
  use strict arg address, writeAccess, observeOnly
  numeric digits 30
  pag = cpu~pag
  if pag~pageEnabled \= 1 then do
    tr = .directory~new
    tr["virtual"] = address
    tr["physical"] = address
    tr["kind"] = "DIRECT"
    tr["page"] = address % 512
    tr["offset"] = address // 512
    tr["write"] = writeAccess
    return tr
  end
  if \pag~tops20Page then
    raise syntax 40.900 array("enabled non-TOPS-20 paging is outside bounded KL10 address space")
  if address >= (2 ** 18) then
    raise syntax 40.900 array("extended-section virtual address is outside current section-zero pager:" address)

  /* KL10 TOPS-20 page refill, section zero.
   *
   * The KL special pager registers are fast-memory block 6:
   *   AC0 CSTM, AC1 CST data, AC2 CST base, AC3 SPT base.
   * Pointer evaluation follows Cornwell's KL load_tlb() structure.  TLBs are
   * intentionally not modeled: the authentic tables are walked on every
   * reference, making the translation evidence directly inspectable.
   */
  rm = (2 ** 18) - 1
  pgPub = self~octToDecLocal("040000")
  pgWrt = self~octToDecLocal("020000")
  pgKep = self~octToDecLocal("010000")
  pgCac = self~octToDecLocal("004000")
  pgMask = self~octToDecLocal("3777777")
  pgPag = self~octToDecLocal("017777")
  pgStgMask = self~octToDecLocal("000077") * (2 ** 18)
  pgAgeMask = self~octToDecLocal("770000") * (2 ** 18)

  page = address % 512
  offset = address // 512
  accBits = pgPub + pgWrt + pgKep + pgCac

  spt = cpu~accumulatorInBlock(6, 3) // (2 ** 18)
  cst = cpu~accumulatorInBlock(6, 2) // (2 ** 18)
  cstMask = cpu~accumulatorInBlock(6, 0)
  cstData = cpu~accumulatorInBlock(6, 1)
  sptBase = spt // (pgMask + 1)
  cstBase = cst // (pgMask + 1)

  sectionPointerAddress = pag~ebPtr + self~octToDecLocal("0540")
  data = self~physicalWord(sectionPointerAddress)
  sectionPointer = data

  /* Resolve section pointer to a page-map page. */
  loopCount = 0
  do forever
    loopCount = loopCount + 1
    if loopCount > 32 then
      raise syntax 40.900 array("TOPS-20 section pointer indirection limit exceeded")
    accBits = self~and18(accBits, (data % (2 ** 18)) // (2 ** 18))
    typ = (data % (2 ** 33)) // 8
    select
      when typ = 1 then leave                         /* direct */
      when typ = 2 then do                            /* shared */
        index = data // (2 ** 18)
        data = self~physicalWord(sptBase + index)
        leave
      end
      when typ = 3 then do                            /* indirect */
        index = (data % (2 ** 18)) // 512
        sharedIndex = data // (2 ** 18)
        data = self~physicalWord(sptBase + sharedIndex)
        if self~and36(data, pgStgMask) \= 0 then
          raise syntax 40.900 array("TOPS-20 section pointer references nonresident storage")
        pg = data // (pgPag + 1)
        data = self~physicalWord(pg * 512 + index)
      end
      otherwise
        raise syntax 40.900 array("TOPS-20 section pointer denies access for virtual address:" address)
    end
  end

  if self~and36(data, pgStgMask) \= 0 then
    raise syntax 40.900 array("TOPS-20 page map is nonresident for virtual address:" address)
  pageMapPage = data // (pgPag + 1)

  /* The page-map page itself participates in CST aging. */
  if cstBase \= 0 then
    ignored = self~touchCst(cstBase, pageMapPage, cstMask, cstData, pgAgeMask, observeOnly, 0)

  pagePointerAddress = pageMapPage * 512 + page
  data = self~physicalWord(pagePointerAddress)
  pagePointer = data

  /* Resolve page pointer. */
  loopCount = 0
  do forever
    loopCount = loopCount + 1
    if loopCount > 32 then
      raise syntax 40.900 array("TOPS-20 page pointer indirection limit exceeded")
    accBits = self~and18(accBits, (data % (2 ** 18)) // (2 ** 18))
    typ = (data % (2 ** 33)) // 8
    select
      when typ = 1 then leave                         /* direct */
      when typ = 2 then do                            /* shared */
        index = data // (2 ** 18)
        data = self~physicalWord(sptBase + index)
        leave
      end
      when typ = 3 then do                            /* indirect */
        index = (data % (2 ** 18)) // 512
        sharedIndex = data // (2 ** 18)
        data = self~physicalWord(sptBase + sharedIndex)
        if self~and36(data, pgStgMask) \= 0 then
          raise syntax 40.900 array("TOPS-20 page pointer references nonresident storage")
        pg = data // (pgPag + 1)
        data = self~physicalWord(pg * 512 + index)
      end
      otherwise
        raise syntax 40.900 array("TOPS-20 page pointer denies access for virtual address:" address)
    end
  end

  if self~and36(data, pgStgMask) \= 0 then
    raise syntax 40.900 array("TOPS-20 final page is nonresident for virtual address:" address)
  physicalPage = data // (pgPag + 1)

  if writeAccess & self~and18(accBits, pgWrt) = 0 then do
    fault=.directory~new
    fault["kind"]="TOPS20_PAGE_FAIL"
    fault["virtual"]=address
    fault["write"]=1
    fault["accessBits"]=accBits
    fault["public"]=(self~and18(accBits,pgPub) \= 0)
    fault["cache"]=(self~and18(accBits,pgCac) \= 0)
    fault["accessible"]=1
    fault["section"]=0
    ignored=cpu~setPendingPageFault(fault)
    raise syntax 40.900 array("KL10_PAGE_FAULT",address)
  end

  if cstBase \= 0 then
    ignored = self~touchCst(cstBase, physicalPage, cstMask, cstData, pgAgeMask, observeOnly, writeAccess)

  physical = physicalPage * 512 + offset

  tr = .directory~new
  tr["kind"] = "TOPS20"
  tr["virtual"] = address
  tr["physical"] = physical
  tr["page"] = page
  tr["offset"] = offset
  tr["section"] = 0
  tr["sectionPointerAddress"] = sectionPointerAddress
  tr["sectionPointer"] = sectionPointer
  tr["sptBase"] = sptBase
  tr["pageMapPage"] = pageMapPage
  tr["pagePointerAddress"] = pagePointerAddress
  tr["pagePointer"] = pagePointer
  tr["physicalPage"] = physicalPage
  tr["accessBits"] = accBits
  tr["write"] = writeAccess
  return tr

::method touchCst private
  use strict arg cstBase, physicalPage, cstMask, cstData, ageMask, observeOnly, writeAccess
  address = cstBase + physicalPage
  cstValue = self~physicalWord(address)
  if self~and36(cstValue, ageMask) = 0 then
    raise syntax 40.900 array("TOPS-20 CST age fault for physical page:" physicalPage)
  if \observeOnly then do
    updated = self~and36(cstValue, cstMask)
    updated = self~or36(updated, cstData)
    if writeAccess then updated = self~or36(updated, 1)
    self~physicalPut(address, updated)
  end
  return self

::method and18 private
  use strict arg a, b
  return (.LROct~fromDecimal(a) & .LROct~fromDecimal(b))~decimal // (2 ** 18)

::method and36 private
  use strict arg a, b
  return (.LROct~fromDecimal(a) & .LROct~fromDecimal(b))~decimal

::method or36 private
  use strict arg a, b
  return (.LROct~fromDecimal(a) | .LROct~fromDecimal(b))~decimal

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

::method mapWord
  expose cpu
  use strict arg address
  numeric digits 30
  if cpu~pag~pageEnabled \= 1 | cpu~pag~tops20Page \= 1 then
    raise syntax 40.900 array("MAP outside enabled TOPS-20 paging is outside bounded model")

  /* MAP is an observation of translation state, not an operand reference.
   * Walk the authentic tables without CST aging/modification side effects. */
  tr=self~translateTops20(address,0,1)
  access=tr["accessBits"]
  physical=tr["physical"]

  mapResult=2 ** 33                    /* AC bit 02: valid true mapping */

  cstBase=cpu~accumulatorInBlock(6,2) // (2 ** 18)
  if cstBase \= 0 then do
    cstWord=self~physicalWord(cstBase+tr["physicalPage"])
    if (cstWord // 2) = 1 then mapResult=mapResult + (2 ** 32) /* MODIFIED */
  end

  pgPub=self~octToDecLocal("040000")
  pgWrt=self~octToDecLocal("020000")
  pgKep=self~octToDecLocal("010000")
  pgCac=self~octToDecLocal("004000")

  if self~and18(access,pgWrt) \= 0 then mapResult=mapResult + (2 ** 31)
  if self~and18(access,pgPub) \= 0 then mapResult=mapResult + (2 ** 29)
  if self~and18(access,pgCac) \= 0 then mapResult=mapResult + (2 ** 28)
  if self~and18(access,pgKep) \= 0 then mapResult=mapResult + (2 ** 27)

  /* Current CPU state is EXEC. Bit 00 would identify a USER mapping. */
  if cpu~processorMode = "USER" then mapResult=mapResult + (2 ** 35)

  mapResult=mapResult + (physical // (2 ** 22))

  out=.directory~new
  out["word"]=mapResult
  out["translation"]=tr
  out["physical"]=physical
  out["accessBits"]=access
  return out

::method readBits
  use strict arg address, bitOffset, width
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 address:" address)
  if \datatype(bitOffset, "W") | bitOffset < 0 then
    raise syntax 40.900 array("invalid KL10 bit offset:" bitOffset)
  if \datatype(width, "W") | width < 0 then
    raise syntax 40.900 array("invalid KL10 bit width:" width)
  if width = 0 then return ""

  currentAddress = address + (bitOffset % 36)
  currentOffset = bitOffset // 36
  remaining = width
  out = ""
  do while remaining > 0
    wordBits = .LROct~fromDecimal(self~word(currentAddress))~bits
    take = 36 - currentOffset
    if take > remaining then take = remaining
    out = out || wordBits~substr(currentOffset + 1, take)
    remaining = remaining - take
    currentAddress = currentAddress + 1
    currentOffset = 0
  end
  return out

::method writeBits
  use strict arg address, bitOffset, valueBits
  if \datatype(address, "W") | address < 0 then
    raise syntax 40.900 array("invalid KL10 address:" address)
  if \datatype(bitOffset, "W") | bitOffset < 0 then
    raise syntax 40.900 array("invalid KL10 bit offset:" bitOffset)
  if valueBits = "" then return self
  do i = 1 to valueBits~length
    if pos(valueBits~substr(i, 1), "01") = 0 then
      raise syntax 40.900 array("invalid KL10 bit value:" valueBits~substr(i, 1))
  end

  currentAddress = address + (bitOffset % 36)
  currentOffset = bitOffset // 36
  sourceAt = 1
  remaining = valueBits~length
  do while remaining > 0
    oldWord = .LROct~fromDecimal(self~word(currentAddress))
    oldBits = oldWord~bits
    take = 36 - currentOffset
    if take > remaining then take = remaining
    replacement = valueBits~substr(sourceAt, take)
    if currentOffset = 0 then prefix = ""
    else prefix = oldBits~substr(1, currentOffset)
    suffixAt = currentOffset + take + 1
    if suffixAt > 36 then suffix = ""
    else suffix = oldBits~substr(suffixAt)
    newBits = prefix || replacement || suffix
    self~put(currentAddress, .LROct~fromBits(newBits))
    remaining = remaining - take
    sourceAt = sourceAt + take
    currentAddress = currentAddress + 1
    currentOffset = 0
  end
  return self

::method string
  expose backing overlay cpu
  mode = "DIRECT"
  if cpu~pag~pageEnabled = 1 then mode = "TOPS20"
  return "KL10AddressSpace [backing=" || backing~class~id || ", overlayWords=" || overlay~items || ", mode=" || mode || "]"


::class KL10IOBus public

::method init
  expose cpu devices
  use strict arg cpuObject
  cpu = cpuObject
  devices = .directory~new

::method attach
  expose devices
  use strict arg device
  code = device~deviceCode
  if \datatype(code, "W") | code < 0 | code > 508 | code // 4 \= 0 then
    raise syntax 40.900 array("invalid PDP-10 I/O device code:" code)
  devices[code] = device
  return self

::method device
  expose devices
  use strict arg code
  if devices~hasIndex(code) then return devices[code]
  raise syntax 40.900 array("no KL10 I/O device attached for code:" code)

::method hasDevice
  expose devices
  use strict arg code
  return devices~hasIndex(code)

::method detach
  expose devices
  use strict arg code
  if devices~hasIndex(code) then devices~remove(code)
  return self

::method deviceName
  expose devices
  use strict arg code
  if devices~hasIndex(code) then return devices[code]~deviceName
  /* Architectural names can be known even when their state model is not yet
   * attached.  Execution still requires an attached device object. */
  if code = 0 then return "APR"
  if code = 4 then return "PI"
  if code = 8 then return "PAG"
  if code = 128 then return "DTE"                    /* 0200 octal */
  if code >= 352 & code <= 380 & code // 4 = 0 then return "RH20" /* 0540..0574 */
  return "DEVICE"

::method attached
  expose devices
  return devices~items

::method cpu
  expose cpu
  return cpu

::method advance
  expose devices
  events=.array~new
  do code over devices
    dev=devices[code]
    if dev~hasMethod("ADVANCE") then do
      event=dev~advance(self)
      if event \= .nil then events~append(event)
    end
  end
  return events

::method deviceCodes
  expose devices
  out = .array~new
  do code = 0 to 508 by 4
    if devices~hasIndex(code) then out~append(code)
  end
  return out

::method resetOtherDevices
  expose devices
  use strict arg sourceDevice
  do code over devices
    dev = devices[code]
    if dev \== sourceDevice then do
      if dev~hasMethod("IORESET") then ignored = dev~ioReset
    end
  end
  return self

::method execute
  expose cpu
  use strict arg ioFunction, deviceCode, effectiveAddress
  numeric digits 30
  if \datatype(ioFunction, "W") | ioFunction < 0 | ioFunction > 7 then
    raise syntax 40.900 array("invalid PDP-10 I/O function:" ioFunction)
  if \datatype(effectiveAddress, "W") | effectiveAddress < 0 | effectiveAddress >= (2 ** 18) then
    raise syntax 40.900 array("invalid PDP-10 I/O effective address:" effectiveAddress)

  dev = self~device(deviceCode)
  memory = cpu~memory
  event = .directory~new
  event["device"] = deviceCode
  event["deviceName"] = dev~deviceName
  event["ioFunction"] = ioFunction
  event["effectiveAddress"] = effectiveAddress
  event["action"] = .nil
  event["status"] = .nil
  event["condition"] = .nil
  event["tested"] = .nil
  event["destination"] = .nil
  event["writeValue"] = .nil
  event["source"] = .nil
  event["data"] = .nil
  event["skip"] = 0

  if dev~hasMethod("IOACTION") then event["action"] = dev~ioAction(ioFunction)

  select
    when ioFunction = 0 | ioFunction = 2 then do
      /* KL special devices repurpose block-I/O encodings for processor
       * operations. PAG BLKO is CLRPT, not a DMA channel transfer. */
      if ioFunction = 0 & deviceCode = 0 & dev~hasMethod("BLKI") then do
        detail = dev~blki(effectiveAddress,self)
        if detail~isa(.Directory) then do key over detail
          event[key] = detail[key]
        end
      end
      else if ioFunction = 2 & deviceCode = 8 & dev~hasMethod("CLRPT") then do
        detail = dev~clrpt(effectiveAddress)
        if detail~isa(.Directory) then do key over detail
          event[key] = detail[key]
        end
      end
      else
        raise syntax 40.900 array("BLKI/BLKO channel semantics are outside bounded I/O bus")
    end

    when ioFunction = 1 then do                         /* DATAI */
      if \dev~hasMethod("DATAI") then
        raise syntax 40.900 array("DATAI unsupported by device" deviceCode)
      value = dev~datai(self)
      if value~isa(.LROct) then value = value~decimal
      if \datatype(value, "W") then
        raise syntax 40.900 array("DATAI device returned non-word value")
      value = value // (2 ** 36)
      memory~put(effectiveAddress, value)
      event["destination"] = effectiveAddress
      event["writeValue"] = value
      event["data"] = value
    end

    when ioFunction = 3 then do                         /* DATAO */
      if \dev~hasMethod("DATAO") then
        raise syntax 40.900 array("DATAO unsupported by device" deviceCode)
      value = memory~word(effectiveAddress)
      ignored = dev~datao(value, self)
      event["source"] = effectiveAddress
      event["data"] = value
    end

    when ioFunction = 4 then do                         /* CONO */
      if \dev~hasMethod("CONO") then
        raise syntax 40.900 array("CONO unsupported by device" deviceCode)
      detail = dev~cono(effectiveAddress, self)
      if detail~isa(.Directory) then do key over detail
        event[key] = detail[key]
      end
    end

    when ioFunction = 5 then do                         /* CONI */
      if \dev~hasMethod("CONI") then
        raise syntax 40.900 array("CONI unsupported by device" deviceCode)
      value = dev~coni(self)
      if value~isa(.LROct) then value = value~decimal
      if \datatype(value, "W") then
        raise syntax 40.900 array("CONI device returned non-word value")
      value = value // (2 ** 36)
      memory~put(effectiveAddress, value)
      event["status"] = value
      event["destination"] = effectiveAddress
      event["writeValue"] = value
    end

    when ioFunction = 6 | ioFunction = 7 then do        /* CONSZ / CONSO */
      if \dev~hasMethod("CONI") then
        raise syntax 40.900 array("CONSZ/CONSO status unsupported by device" deviceCode)
      value = dev~coni(self)
      if value~isa(.LROct) then value = value~decimal
      if \datatype(value, "W") then
        raise syntax 40.900 array("I/O status device returned non-word value")
      value = value // (2 ** 36)
      masked = (.LROct~fromDecimal(value) & .LROct~fromDecimal(effectiveAddress))~decimal
      event["status"] = value
      event["condition"] = effectiveAddress
      event["tested"] = masked
      if ioFunction = 6 then event["skip"] = masked = 0
      else event["skip"] = masked \= 0
    end
  end
  return event

::method string
  expose devices
  out = "KL10IOBus [devices="
  first = 1
  do code = 0 to 508 by 4
    if devices~hasIndex(code) then do
      if \first then out = out || ","
      codeText = right(.LROct~fromDecimal(code)~right, 3)
      out = out || codeText || ":" || devices[code]~deviceName
      first = 0
    end
  end
  return out || "]"





::class KL10MassbusTape public

::method init
  expose reader mounted online writeLocked model formatter mediaPath mediaSha256 selectedSlave -
         frameCount tapeControl controlReg errorReg lastRecordKind readCount rewindCount -
         pendingKind pendingHeader pendingPayload pendingLength pendingError pendingFileNumber pendingRecordObj
  reader=.SimhTapeReader~new
  mounted=0
  online=0
  writeLocked=1
  model="TU45"
  formatter="TM03"
  mediaPath=""
  mediaSha256=""
  selectedSlave=0
  frameCount=0
  tapeControl=0
  controlReg=0
  errorReg=0
  lastRecordKind="BOT"
  readCount=0
  rewindCount=0
  pendingKind=""
  pendingHeader=0
  pendingPayload=0
  pendingLength=0
  pendingError=0
  pendingFileNumber=0
  pendingRecordObj=.nil

::method stateSchema
  return "KL10_MASSBUS_TAPE_STATE/1"

::method mount
  expose reader mounted online mediaPath mediaSha256 lastRecordKind
  use strict arg path
  mediaSha256=self~sha256File(path)
  ignored=reader~mount(path)
  mediaPath=path
  mounted=1
  online=1
  lastRecordKind="BOT"
  return self

::method mediaSha256
  expose mediaSha256
  return mediaSha256

::method mediaPath
  expose mediaPath
  return mediaPath

::method mounted
  expose mounted
  return mounted

::method online
  expose online
  return online

::method writeLocked
  expose writeLocked
  return writeLocked

::method position
  expose reader mounted
  if \mounted then return 0
  return reader~position

::method fileNumber
  expose reader mounted
  if \mounted then return 0
  return reader~fileNumber

::method markRun
  expose reader mounted
  if \mounted then return 0
  return reader~markRun

::method driveType
  expose mounted online formatter model
  numeric digits 30
  if \mounted | \online then return .KL10Word~fromOctal("140050")
  /* NSA + TAP + slave present + TM03 + TU45 (75 ips selected). */
  return .KL10Word~fromOctal("142052")

::method driveStatus
  expose mounted online writeLocked reader lastRecordKind
  numeric digits 30
  status=.KL10Word~fromOctal("000400") /* DPR, hardwired formatter present */
  if mounted & online then do
    status=status+.KL10Word~fromOctal("010200") /* MOL + DRY */
    if reader~position=0 then status=status+.KL10Word~fromOctal("000002") /* BOT */
    if writeLocked then status=status+.KL10Word~fromOctal("004000")
    if lastRecordKind="MARK" then status=status+.KL10Word~fromOctal("000004")
  end
  return status

::method readRegister
  expose frameCount tapeControl controlReg errorReg selectedSlave
  use strict arg register
  select
    when register=0 then return controlReg
    when register=1 then return self~driveStatus
    when register=2 then return errorReg
    when register=4 then return 0
    when register=5 then return frameCount
    when register=6 then return self~driveType
    when register=7 then return 0
    when register=8 then return .KL10Word~fromOctal("000001") /* stable synthetic serial */
    when register=9 then return tapeControl
    otherwise raise syntax 40.900 array("TM03 register read outside bounded model:" register)
  end

::method writeRegister
  expose frameCount tapeControl controlReg errorReg selectedSlave reader mounted online lastRecordKind rewindCount -
         pendingKind pendingHeader pendingPayload pendingLength pendingError pendingFileNumber pendingRecordObj
  use strict arg register,value
  numeric digits 30
  value=value // (2 ** 16)
  select
    when register=0 then do
      function=value // 64
      controlReg=value
      select
        when function=1 then controlReg=0                    /* NOP */
        when function=7 then do                              /* rewind */
          if \mounted | \online then
            raise syntax 40.900 array("TM03 rewind requested without online media")
          ignored=reader~rewind
          lastRecordKind="BOT"
          rewindCount=rewindCount+1
          controlReg=0
        end
        when function=11 then do                             /* drive clear */
          errorReg=0
          controlReg=0
        end
        when function=21 then do                             /* read-in preset */
          tapeControl=.KL10Word~fromOctal("000000")
          if mounted & online then ignored=reader~rewind
          lastRecordKind="BOT"
          controlReg=0
        end
        when function=self~octToDec("071") then do           /* READ FORWARD */
          rec=self~nextRecord
          pendingRecordObj=rec
          pendingKind=rec~kind
          pendingFileNumber=rec~fileNumber
          pendingHeader=rec~headerOffset
          if rec~payloadOffset=.nil then pendingPayload=0
          else pendingPayload=rec~payloadOffset
          pendingLength=rec~length
          pendingError=rec~errorFlag
          controlReg=0
        end
        otherwise
          raise syntax 40.900 array("TM03 control function outside bounded model:" function)
      end
    end
    when register=4 then do
      /* Attention Summary pseudo-register: writing ones clears corresponding
       * formatter attention bits. This bounded unit has no latched ATA yet. */
      nop=value
    end
    when register=5 then frameCount=value
    when register=9 then do
      tapeControl=value
      selectedSlave=value // 8
      if selectedSlave \= 0 then
        raise syntax 40.900 array("bounded TU45 transport supports slave 0 only:" selectedSlave)
    end
    otherwise
      raise syntax 40.900 array("TM03 register write outside bounded model:" register)
  end
  return self

::method nextRecord
  expose reader mounted online lastRecordKind readCount
  if \mounted | \online then
    raise syntax 40.900 array("TM03 read requested without online media")
  rec=reader~next
  if rec~isData then lastRecordKind="DATA"
  else if rec~isMark then lastRecordKind="MARK"
  else if rec~isEot then lastRecordKind="EOT"
  else lastRecordKind="GAP"
  readCount=readCount+1
  return rec

/* Operator controls.  These are transport actions, not guest register writes. */
::method operatorOnline
  expose mounted online
  if \mounted then return .false
  online=1
  return .true

::method operatorOffline
  expose online
  online=0
  return .true

::method operatorRewind
  expose reader mounted online lastRecordKind rewindCount
  if \mounted then return .false
  ignored=reader~rewind
  lastRecordKind="BOT"
  rewindCount=rewindCount+1
  return .true

::method operatorUnload
  expose reader mounted online mediaPath mediaSha256 selectedSlave frameCount tapeControl controlReg errorReg lastRecordKind
  if mounted then ignored=reader~close
  mounted=0
  online=0
  mediaPath=""
  mediaSha256=""
  selectedSlave=0
  frameCount=0
  tapeControl=0
  controlReg=0
  errorReg=0
  lastRecordKind="UNLOADED"
  return .true

::method operatorState
  expose mounted online writeLocked model formatter mediaSha256 lastRecordKind
  d=.directory~new
  d["mounted"]=mounted
  d["online"]=online
  d["ready"]=mounted & online
  d["writeLocked"]=writeLocked
  d["bot"]=mounted & (self~position=0)
  d["tapeMark"]=lastRecordKind="MARK"
  d["motion"]="STOPPED"
  d["position"]=self~position
  d["fileNumber"]=self~fileNumber
  d["model"]=model
  d["formatter"]=formatter
  d["mediaSha256"]=mediaSha256
  return d

::method state
  expose mounted online writeLocked model formatter mediaPath mediaSha256 selectedSlave -
         frameCount tapeControl controlReg errorReg lastRecordKind readCount rewindCount reader -
         pendingKind pendingHeader pendingPayload pendingLength pendingError pendingFileNumber
  d=.directory~new
  d["mounted"]=mounted
  d["online"]=online
  d["writeLocked"]=writeLocked
  d["model"]=model
  d["formatter"]=formatter
  d["mediaPath"]=mediaPath
  d["mediaSha256"]=mediaSha256
  d["position"]=self~position
  d["fileNumber"]=self~fileNumber
  d["markRun"]=self~markRun
  d["selectedSlave"]=selectedSlave
  d["frameCount"]=frameCount
  d["tapeControl"]=tapeControl
  d["controlReg"]=controlReg
  d["errorReg"]=errorReg
  d["lastRecordKind"]=lastRecordKind
  d["readCount"]=readCount
  d["rewindCount"]=rewindCount
  d["pendingKind"]=pendingKind
  d["pendingFileNumber"]=pendingFileNumber
  d["pendingHeader"]=pendingHeader
  d["pendingPayload"]=pendingPayload
  d["pendingLength"]=pendingLength
  d["pendingError"]=pendingError
  return d

::method restoreState
  expose reader mounted online writeLocked model formatter mediaPath mediaSha256 selectedSlave -
         frameCount tapeControl controlReg errorReg lastRecordKind readCount rewindCount -
         pendingKind pendingHeader pendingPayload pendingLength pendingError pendingFileNumber pendingRecordObj
  use strict arg d, suppliedMediaPath
  expected=d["mediaSha256"]
  actual=self~sha256File(suppliedMediaPath)
  if actual \= expected then
    raise syntax 40.900 array("Massbus tape media SHA-256 mismatch")
  ignored=reader~mount(suppliedMediaPath)
  ignored=reader~restorePosition(d["position"],d["fileNumber"],d["markRun"])
  mounted=d["mounted"]
  online=d["online"]
  writeLocked=d["writeLocked"]
  model=d["model"]
  formatter=d["formatter"]
  mediaPath=suppliedMediaPath
  mediaSha256=expected
  selectedSlave=d["selectedSlave"]
  frameCount=d["frameCount"]
  tapeControl=d["tapeControl"]
  controlReg=d["controlReg"]
  errorReg=d["errorReg"]
  lastRecordKind=d["lastRecordKind"]
  readCount=d["readCount"]
  rewindCount=d["rewindCount"]
  pendingKind=d["pendingKind"]
  pendingFileNumber=d["pendingFileNumber"]
  pendingHeader=d["pendingHeader"]
  pendingPayload=d["pendingPayload"]
  pendingLength=d["pendingLength"]
  pendingError=d["pendingError"]
  pendingRecordObj=.nil
  if pendingKind\="" then do
    finalPos=d["position"]
    finalFile=d["fileNumber"]
    finalMark=d["markRun"]
    ignored=reader~restorePosition(pendingHeader,pendingFileNumber,0)
    rec=reader~next
    if rec~kind\=pendingKind | rec~headerOffset\=pendingHeader | rec~length\=pendingLength then
      raise syntax 40.900 array("Massbus pending record reconstruction mismatch")
    pendingRecordObj=rec
    ignored=reader~restorePosition(finalPos,finalFile,finalMark)
  end
  return self

::method pendingRecord
  expose pendingKind pendingHeader pendingPayload pendingLength pendingError pendingFileNumber
  d=.directory~new
  d["kind"]=pendingKind
  d["fileNumber"]=pendingFileNumber
  d["headerOffset"]=pendingHeader
  d["payloadOffset"]=pendingPayload
  d["length"]=pendingLength
  d["errorFlag"]=pendingError
  return d

::method pendingWord36
  expose pendingRecordObj pendingKind
  use strict arg index
  if pendingRecordObj=.nil | pendingKind\="DATA" then
    raise syntax 40.900 array("no pending Massbus tape data record")
  return pendingRecordObj~word36(index)

::method octToDec private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method string
  expose mounted online writeLocked model formatter mediaSha256
  return "KL10MassbusTape [" || formatter || "/" || model || -
         " mounted=" || mounted || " online=" || online || -
         " writeLocked=" || writeLocked || " pos=" || self~position || -
         " file=" || self~fileNumber || " sha256=" || mediaSha256 || "]"

::method sha256File private
  use strict arg path
  if path="" | pos('"',path) \= 0 then
    raise syntax 40.900 array("invalid tape media path")
  out=path || ".kl10-tape-sha256.tmp"
  address system 'sha256sum "' || path || '" > "' || out || '"'
  if rc \= 0 then do
    ignored=sysFileDelete(out)
    raise syntax 40.900 array("sha256sum failed for tape media")
  end
  st=.stream~new(out)~~open("READ")
  line=st~linein
  st~close
  ignored=sysFileDelete(out)
  parse var line digest .
  if digest~length \= 64 then
    raise syntax 40.900 array("invalid tape media SHA-256")
  return digest


::class KL10Rh20 public

::method init
  expose code statusWord preparation resetCount massbusEnabled channelResetCount units lastTransferReceived -
         sbar stcr pbar ptcr ivect attentionInterruptEnabled
  use arg code = 352
  if code < 352 | code > 380 | code // 4 \= 0 then
    raise syntax 40.900 array("bounded RH20 requires device 540..574 by fours:" code)
  statusWord=0
  preparation=0
  resetCount=0
  massbusEnabled=0
  channelResetCount=0
  units=.directory~new
  lastTransferReceived=0
  sbar=0
  stcr=0
  pbar=0
  ptcr=0
  ivect=0
  attentionInterruptEnabled=0

::method deviceCode
  expose code
  return code

::method deviceName
  return "RH20"

::method stateSchema
  return "KL10_RH20_STATE/3"

::method attachUnit
  expose units
  use strict arg unitNumber,unit
  if \datatype(unitNumber,"W") | unitNumber<0 | unitNumber>7 then
    raise syntax 40.900 array("RH20 Massbus unit number must be 0..7")
  if units~hasIndex(unitNumber) then
    raise syntax 40.900 array("RH20 Massbus unit already attached:" unitNumber)
  units[unitNumber]=unit
  return unit

::method hasUnit
  expose units
  use strict arg unitNumber
  return units~hasIndex(unitNumber)

::method unit
  expose units
  use strict arg unitNumber
  if \units~hasIndex(unitNumber) then
    raise syntax 40.900 array("RH20 Massbus unit not attached:" unitNumber)
  return units[unitNumber]

::method unitNumbers
  expose units
  out=.array~new
  do unitNumber over units
    out~append(unitNumber)
  end
  return out

::method ioAction
  use strict arg ioFunction
  if ioFunction=4 then return "RH20_CONO"
  if ioFunction=5 then return "RH20_CONI"
  if ioFunction=3 then return "RH20_DATAO"
  if ioFunction=1 then return "RH20_DATAI"
  return "RH20_IO"

::method cono
  expose statusWord preparation resetCount massbusEnabled channelResetCount sbar stcr pbar ptcr attentionInterruptEnabled
  use strict arg condition,bus
  numeric digits 30

  clrRae=.KL10Word~fromOctal("004000")
  clrMbc=.KL10Word~fromOctal("002000")
  xferErrClr=.KL10Word~fromOctal("001000")
  massbusEna=.KL10Word~fromOctal("000400")
  rclp=.KL10Word~fromOctal("000200")
  deleteScr=.KL10Word~fromOctal("000100")
  attnIntEna=.KL10Word~fromOctal("000040")
  stopXfer=.KL10Word~fromOctal("000020")
  reserved10=.KL10Word~fromOctal("000010")
  known=clrRae+clrMbc+xferErrClr+massbusEna+rclp+deleteScr+attnIntEna+stopXfer+reserved10

  unknown=(.LROct~fromDecimal(condition) & (\.LROct~fromDecimal(known)))~decimal
  if unknown \= 0 then
    raise syntax 40.900 array("RH20 CONO control bits outside bounded model:" condition)

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(clrMbc))~decimal \= 0 then do
    statusWord=0
    preparation=0
    massbusEnabled=0
    attentionInterruptEnabled=0
    resetCount=resetCount+1
  end

  admitted=0
  action="RH20_CONO"

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(clrRae))~decimal \= 0 then do
    admitted=admitted+clrRae
    action="RH20_CLR_RAE"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(clrMbc))~decimal \= 0 then do
    admitted=admitted+clrMbc
    statusWord=0
    preparation=0
    massbusEnabled=0
    attentionInterruptEnabled=0
    resetCount=resetCount+1
    if action="RH20_CONO" then action="RH20_CLR_MBC"
    else action=action || "+CLR_MBC"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(xferErrClr))~decimal \= 0 then do
    admitted=admitted+xferErrClr
    if action="RH20_CONO" then action="RH20_CLR_XFER_ERR"
    else action=action || "+CLR_XFER_ERR"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(massbusEna))~decimal \= 0 then do
    massbusEnabled=1
    admitted=admitted+massbusEna
    if action="RH20_CONO" then action="RH20_MASSBUS_ENA"
    else action=action || "+MASSBUS_ENA"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(rclp))~decimal \= 0 then do
    /* RH20 RCLP initializes only the associated MBox channel.  The DEC
     * RH20 manual specifies restoration of the command-list pointer to the
     * initial control-word address, clearing channel buffers/status, while
     * leaving the RH20 controller and attached Massbus devices initialized.
     * The bounded model has no separate data-buffer object, so the channel
     * pointer/status fields are the complete represented channel state. */
    channelResetCount=channelResetCount+1
    pbar=sbar
    ptcr=stcr
    channelStatus=self~octToDecLocal("000130")
    cleared=(.LROct~fromDecimal(statusWord) & .LROct~fromDecimal(channelStatus))~decimal
    statusWord=statusWord-cleared
    admitted=admitted+rclp
    if action="RH20_CONO" then action="RH20_RCLP"
    else action=action || "+RCLP"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(attnIntEna))~decimal \= 0 then do
    /* MEAE/ATTN INT ENA permits a future Massbus ATTN source to request an
     * RH20 interrupt.  It is a set control; absence on a later CONO does not
     * manufacture a clear operation.  This bounded model has no asserted
     * attention source or interrupt delivery to fabricate here. */
    attentionInterruptEnabled=1
    admitted=admitted+attnIntEna
    if action="RH20_CONO" then action="RH20_ATTN_INT_ENA"
    else action=action || "+ATTN_INT_ENA"
  end

  if (.LROct~fromDecimal(condition) & .LROct~fromDecimal(reserved10))~decimal \= 0 then do
    admitted=admitted+reserved10
    if action="RH20_CONO" then action="RH20_RESERVED_000010"
    else action=action || "+RESERVED_000010"
  end

  other=(.LROct~fromDecimal(condition) & (\.LROct~fromDecimal(admitted)))~decimal
  if other \= 0 then
    raise syntax 40.900 array("RH20 CONO operation beyond admitted controls is outside bounded model:" condition)

  detail=.directory~new
  detail["action"]=action
  detail["rh20ResetCountAfter"]=resetCount
  detail["rh20MassbusEnabledAfter"]=massbusEnabled
  detail["rh20StatusAfter"]=statusWord
  return detail

::method coni
  expose statusWord massbusEnabled
  use strict arg bus
  out=statusWord
  if massbusEnabled then out=(.LROct~fromDecimal(out) | .LROct~fromDecimal(.KL10Word~fromOctal("000400")))~decimal
  return out

::method datao
  expose preparation units lastTransferReceived statusWord ivect
  use strict arg value,bus
  numeric digits 30
  value=value // (2 ** 36)
  rs=value % (2 ** 30)
  lr=(value % (2 ** 29)) // 2
  draes=(value % (2 ** 26)) // 2
  left=value % (2 ** 18)
  ds=left // 8
  externalData=value // (2 ** 16)

  if rs > 31 & (rs < self~octToDecLocal("070") | rs > self~octToDecLocal("077")) & rs \= 60 then
    raise syntax 40.900 array("RH20 internal DATAO register outside bounded model:" rs)
  preparation=value
  lastTransferReceived=0

  if rs <= 31 & units~hasIndex(ds) then do
    lastTransferReceived=1
    if lr then ignored=units[ds]~writeRegister(rs,externalData)
  end
  else if rs=60 then do
    lastTransferReceived=1
    if lr then ignored=self~writeInternalRegister(rs,value,bus)
  end
  else if rs >= self~octToDecLocal("070") & rs <= self~octToDecLocal("077") then do
    lastTransferReceived=1
    if lr then ignored=self~writeInternalRegister(rs,value,bus)
  end

  detail=.directory~new
  detail["action"]="RH20_PREPARE_EXTERNAL"
  detail["rs"]=rs
  detail["lr"]=lr
  detail["ds"]=ds
  detail["transferReceived"]=lastTransferReceived
  detail["externalData"]=externalData
  return detail

::method datai
  expose preparation units lastTransferReceived
  use strict arg bus
  numeric digits 30
  /* A zero preparation word is the architecturally valid reset image. */

  rs=preparation % (2 ** 30)
  lr=(preparation % (2 ** 29)) // 2
  draes=(preparation % (2 ** 26)) // 2
  left=preparation % (2 ** 18)
  ds=left // 8
  lastTransferReceived=0
  data=0

  if rs=60 then return 0
  if rs >= self~octToDecLocal("070") & rs <= self~octToDecLocal("077") then
    return self~readInternalRegister(rs)
  if units~hasIndex(ds) then do
    data=units[ds]~readRegister(rs)
    lastTransferReceived=1
  end

  /* DATAI external register: RS 00-05, LR 06, DRAES 09, TRA 10,
   * DS 15-17, external register data 20-35. */
  out=rs*(2 ** 30)+lr*(2 ** 29)+draes*(2 ** 26)+ds*(2 ** 18)+(data // (2 ** 16))
  if lastTransferReceived then out=out+(2 ** 25)
  return out

::method writeInternalRegister private
  expose sbar stcr pbar ptcr ivect statusWord units
  use strict arg rs,value,bus
  numeric digits 30
  slot=rs // 8
  select
    when slot=0 then do
      sbar=value // (2 ** 21)
      statusWord=self~bitOr18(statusWord,self~octToDecLocal("1000000"))
    end
    when slot=1 then do
      mask=self~octToDecLocal("022700777777")
      stcr=(.LROct~fromDecimal(value) & .LROct~fromDecimal(mask))~decimal
      statusWord=self~bitOr18(statusWord,self~octToDecLocal("000100"))
      ignored=self~setupPrimaryCommand(bus)
    end
    when slot=4 then ivect=value // 512
    when slot=2 then pbar=value
    when slot=3 then ptcr=value
    otherwise nop=value
  end
  return self

::method readInternalRegister private
  expose sbar stcr pbar ptcr ivect
  use strict arg rs
  slot=rs // 8
  select
    when slot=0 then return sbar
    when slot=1 then return stcr
    when slot=2 then return pbar
    when slot=3 then return ptcr
    when slot=4 then return ivect
    otherwise return 0
  end

::method setupPrimaryCommand private
  expose code sbar stcr pbar ptcr statusWord units
  use strict arg bus
  numeric digits 30
  scr=self~octToDecLocal("000100")
  pcr=self~octToDecLocal("000020")
  if self~bitAnd18(statusWord,scr)=0 then return self
  if self~bitAnd18(statusWord,pcr)\=0 then return self

  ptcr=stcr
  pbar=sbar
  statusWord=self~bitAndNot18(statusWord,scr)
  statusWord=self~bitOr18(statusWord,pcr)

  drive=(ptcr % (2 ** 18)) // 8
  function=ptcr // 64
  if units~hasIndex(drive) then do
    ignored=units[drive]~writeRegister(0,function)
    if function=self~octToDecLocal("071") then
      ignored=self~executeReadChannel(bus,units[drive])
  end
  else statusWord=self~bitOr18(statusWord,self~octToDecLocal("010000"))
  return self

::method executeReadChannel private
  expose code statusWord pbar ptcr
  use strict arg bus,tape
  numeric digits 30

  cpu=bus~cpu
  memory=cpu~memory
  ept=cpu~pag~ebPtr
  channel=(code-352) % 4
  logout=ept+channel*4

  resetCcw=memory~physicalWord(logout)
  resetOp=(resetCcw % (2 ** 33)) // 8
  if resetOp \= 2 then
    raise syntax 40.900 array("RH20 channel reset word is not JUMP:" resetOp)
  clp=resetCcw // (2 ** 22)

  pending=tape~pendingRecord
  if pending["kind"] \= "DATA" then
    raise syntax 40.900 array("RH20 channel read has no pending data record")
  recordWords=pending["length"] % 5
  if recordWords<1 then
    raise syntax 40.900 array("RH20 channel read has empty data record")

  recordIndex=0
  currentCcw=clp
  lastAddress=0
  lastOp=0
  foundLast=0

  do segment=1 to 64
    ccw=memory~physicalWord(currentCcw)
    op=(ccw % (2 ** 33)) // 8
    wc=(ccw % (2 ** 22)) // (2 ** 11)
    address=ccw // (2 ** 22)

    if op \= 4 & op \= 6 then
      raise syntax 40.900 array("RH20 channel CCW is not forward transfer:" op)
    if wc<1 then
      raise syntax 40.900 array("RH20 channel CCW has zero word count")
    if recordIndex+wc>recordWords then
      raise syntax 40.900 array("RH20 channel CCW exceeds pending tape record:" recordIndex wc recordWords)

    do i=0 to wc-1
      memory~physicalPut(address+i,tape~pendingWord36(recordIndex+i))
    end

    recordIndex=recordIndex+wc
    lastAddress=address+wc-1
    lastOp=op
    currentCcw=currentCcw+1

    if op=6 then do
      foundLast=1
      leave
    end
  end

  if \foundLast then
    raise syntax 40.900 array("RH20 channel command list exceeds bounded 64-CCW limit")
  if recordIndex \= recordWords then
    raise syntax 40.900 array("RH20 LAST CCW does not consume complete tape record:" recordIndex recordWords)

  /* Logout points past the final consumed CCW and records the final physical
   * transfer address.  DMA remains physical, so addresses 0..17 are memory,
   * not the CPU accumulator window. */
  memory~physicalPut(logout+1,currentCcw // (2 ** 22))
  memory~physicalPut(logout+2,lastOp*(2 ** 33)+(lastAddress // (2 ** 22)))

  pcr=self~octToDecLocal("000020")
  cmdDone=self~octToDecLocal("000010")
  if self~bitAnd18(statusWord,pcr) \= 0 then statusWord=statusWord-pcr
  if self~bitAnd18(statusWord,cmdDone) = 0 then statusWord=statusWord+cmdDone
  return self

::method bitAnd18 private
  use strict arg a,b
  return (.LROct~fromDecimal(a) & .LROct~fromDecimal(b))~decimal

::method bitAndNot18 private
  use strict arg a,b
  return (.LROct~fromDecimal(a) & (\\.LROct~fromDecimal(b)))~decimal

::method bitOr18 private
  use strict arg a,b
  return (.LROct~fromDecimal(a) | .LROct~fromDecimal(b))~decimal

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method ioReset
  expose statusWord preparation resetCount massbusEnabled channelResetCount attentionInterruptEnabled
  statusWord=0
  preparation=0
  massbusEnabled=0
  attentionInterruptEnabled=0
  channelResetCount=0
  resetCount=resetCount+1
  return self

::method state
  expose statusWord preparation resetCount massbusEnabled channelResetCount sbar stcr pbar ptcr ivect attentionInterruptEnabled
  d=.directory~new
  d["statusWord"]=statusWord
  d["preparation"]=preparation
  d["resetCount"]=resetCount
  d["massbusEnabled"]=massbusEnabled
  d["channelResetCount"]=channelResetCount
  d["sbar"]=sbar
  d["stcr"]=stcr
  d["pbar"]=pbar
  d["ptcr"]=ptcr
  d["ivect"]=ivect
  d["attentionInterruptEnabled"]=attentionInterruptEnabled
  return d

::method restoreState
  expose statusWord preparation resetCount massbusEnabled channelResetCount sbar stcr pbar ptcr ivect attentionInterruptEnabled
  use strict arg d
  statusWord=d["statusWord"]
  preparation=d["preparation"]
  resetCount=d["resetCount"]
  massbusEnabled=d["massbusEnabled"]
  channelResetCount=d["channelResetCount"]
  sbar=d["sbar"]
  stcr=d["stcr"]
  pbar=d["pbar"]
  ptcr=d["ptcr"]
  ivect=d["ivect"]
  if \d~hasIndex("attentionInterruptEnabled") then
    raise syntax 40.900 array("RH20 state missing attentionInterruptEnabled")
  attentionInterruptEnabled=d["attentionInterruptEnabled"]
  return self

::method statusWord
  expose statusWord
  return statusWord

::method resetCount
  expose resetCount
  return resetCount

::method extendedState
  expose sbar stcr pbar ptcr ivect attentionInterruptEnabled
  d=.directory~new
  d["sbar"]=sbar
  d["stcr"]=stcr
  d["pbar"]=pbar
  d["ptcr"]=ptcr
  d["ivect"]=ivect
  d["attentionInterruptEnabled"]=attentionInterruptEnabled
  return d

::method restoreExtendedState
  expose sbar stcr pbar ptcr ivect
  use strict arg d
  sbar=d["sbar"]; stcr=d["stcr"]; pbar=d["pbar"]; ptcr=d["ptcr"]; ivect=d["ivect"]
  return self

::method string
  expose code statusWord preparation resetCount massbusEnabled channelResetCount
  prepText=.LROct~fromDecimal(preparation)~string
  return "KL10Rh20 [device=" || .LROct~fromDecimal(code)~right || -
         " status=" || .LROct~fromDecimal(statusWord)~right || -
         " prep=" || prepText || -
         " resetCount=" || resetCount || " massbus=" || massbusEnabled || -
         " channelResets=" || channelResetCount || "]"


::class KL10Dte public

::method init
  expose statusInternal count resetCount servicePending monitorMode serviceCount txHex rxHex
  /* Cornwell KL reset: unit-0 STATUS contains only DTE_SEC (04000000),
   * which is internal and therefore invisible through the 18-bit CONI. */
  statusInternal = self~octToDecLocal("04000000")
  count = 0
  resetCount = 0
  servicePending = 0
  monitorMode = 0
  serviceCount = 0
  txHex = ""
  rxHex = ""

::method deviceCode
  return 128                             /* 0200 octal */

::method deviceName
  return "DTE"

::method stateSchema
  return "KL10_DTE_STATE/4"

::method ioAction
  use strict arg ioFunction
  if ioFunction = 4 then return "DTE_CONO"
  if ioFunction = 5 then return "DTE_CONI_STATUS"
  if ioFunction = 3 then return "DTE_DATAO"
  if ioFunction = 1 then return "DTE_DATAI"
  return "DTE_IO"

::method coni
  expose statusInternal
  use strict arg bus
  return statusInternal // (2 ** 18)

::method cono
  expose statusInternal servicePending
  use strict arg condition, bus
  numeric digits 30
  if \datatype(condition, "W") | condition < 0 | condition >= (2 ** 18) then
    raise syntax 40.900 array("CONO DTE invalid 18-bit condition:" condition)

  dtePia = self~octToDecLocal("00000007")
  dtePie = self~octToDecLocal("00000010")
  coPienb = self~octToDecLocal("00000020")
  co10cl = self~octToDecLocal("00000040")
  co11cl = self~octToDecLocal("00000100")
  co10db = self~octToDecLocal("00001000")
  co11sr = self~octToDecLocal("00004000")
  co11cr = self~octToDecLocal("00010000")
  co11db = self~octToDecLocal("00020000")

  dte10db = self~octToDecLocal("00001000")
  dte11er = self~octToDecLocal("00000400")
  dte11dn = self~octToDecLocal("00000100")
  dte10dn = self~octToDecLocal("00000040")
  dte10er = self~octToDecLocal("00000020")
  dte11reld = self~octToDecLocal("01000000")
  dte11door = self~octToDecLocal("00020000")

  if self~bitSet(condition, coPienb) then do
    statusInternal = self~andNot(statusInternal, dtePia + dtePie)
    statusInternal = self~or36(statusInternal, self~and36(condition, dtePia + dtePie))
  end
  if self~bitSet(condition, co11cl) then
    statusInternal = self~andNot(statusInternal, dte11dn + dte11er)
  if self~bitSet(condition, co10cl) then
    statusInternal = self~andNot(statusInternal, dte10dn + dte10er)
  if self~bitSet(condition, co10db) then
    statusInternal = self~andNot(statusInternal, dte10db)
  if self~bitSet(condition, co11cr) then
    statusInternal = self~andNot(statusInternal, dte11reld)
  if self~bitSet(condition, co11sr) then
    statusInternal = self~or36(statusInternal, dte11reld)
  if self~bitSet(condition, co11db) then do
    statusInternal = self~or36(statusInternal, dte11door)
    servicePending = 1
  end

  detail=.directory~new
  detail["action"]="DTE_CONO"
  detail["dteStatusAfter"]=statusInternal // (2 ** 18)
  detail["dteStatusInternalAfter"]=statusInternal
  detail["dteServicePendingAfter"]=servicePending
  return detail

::method type
  expose rxHex
  use strict arg text
  do i=1 to text~length
    code=c2d(text~substr(i,1)) // 128
    rxHex=rxHex || right(d2x(code),2,"0")
  end
  return self

::method rxHex
  expose rxHex
  return rxHex

::method takeOutput
  expose txHex
  out=txHex
  txHex=""
  return out

::method advance
  expose statusInternal servicePending monitorMode serviceCount txHex rxHex
  use strict arg bus
  numeric digits 30
  cpu=bus~cpu
  memory=cpu~memory
  base=cpu~pag~ebPtr

  /* Monitor input service is asynchronous with respect to CPU execution.
   * Cornwell deposits one queued character into DTF11 and sets DTMTI only
   * when the input flag is clear. */
  dtF11=base+self~octToDecLocal("0450")
  dtMti=base+self~octToDecLocal("0456")
  if monitorMode & rxHex \= "" & memory~physicalWord(dtMti)=0 then do
    ch=x2d(rxHex~substr(1,2))
    if rxHex~length=2 then rxHex=""
    else rxHex=rxHex~substr(3)
    memory~physicalPut(dtF11,ch)
    memory~physicalPut(dtMti,.KL10Word~allOnes)
    event=.directory~new
    event["device"]=128
    event["deviceName"]="DTE"
    event["action"]="DTE_MONITOR_INPUT_DELIVERED"
    event["character"]=ch
    event["inputAddress"]=dtF11
    event["inputFlagAddress"]=dtMti
    return event
  end

  if \servicePending then return .nil

  dtFlag=base+self~octToDecLocal("0444")
  dtCmd=base+self~octToDecLocal("0451")
  command=memory~physicalWord(dtCmd)
  commandClass=self~and36(command,self~octToDecLocal("07400"))
  monOutput=self~octToDecLocal("04000")
  monOn=self~octToDecLocal("04400")
  dtChar=base+self~octToDecLocal("0454")
  dtMonDone=base+self~octToDecLocal("0455")
  serviceAction=""

  /* Secondary protocol operations admitted only when MTBOOT reaches them. */
  if commandClass = monOn then do
    monitorMode=1
    serviceAction="DTE_SECONDARY_MONON_COMPLETE"
  end
  else if commandClass = monOutput then do
    if \monitorMode then
      raise syntax 40.900 array("DTE MONO requested before monitor mode is enabled")
    ch=command // 128
    txHex=txHex || d2x(ch,2)
    memory~physicalPut(dtChar,ch)
    memory~physicalPut(dtMonDone,.KL10Word~allOnes)
    serviceAction="DTE_SECONDARY_MONO_COMPLETE"
  end
  else
    raise syntax 40.900 array("DTE secondary command outside bounded model:" command)

  memory~physicalPut(dtCmd,0)
  memory~physicalPut(dtFlag,.KL10Word~allOnes)
  statusInternal=self~andNot(statusInternal,self~octToDecLocal("00020000"))
  servicePending=0
  serviceCount=serviceCount+1

  event=.directory~new
  event["device"]=128
  event["deviceName"]="DTE"
  event["action"]=serviceAction
  event["command"]=command
  event["flagAddress"]=dtFlag
  event["commandAddress"]=dtCmd
  event["serviceCountAfter"]=serviceCount
  return event

::method datao
  expose statusInternal count
  use strict arg value, bus
  numeric digits 30
  value=value // (2 ** 36)
  if value = self~octToDecLocal("00001365") then do
    statusInternal = self~or36(statusInternal, self~octToDecLocal("04000000"))
    statusInternal = self~or36(statusInternal, self~octToDecLocal("00000020"))
    statusInternal = self~andNot(statusInternal, self~octToDecLocal("00021000"))
    count=0
    return self
  end
  raise syntax 40.900 array("DTE DATAO transfer protocol beyond secondary-entry word is outside bounded model:" value)

::method datai
  use strict arg bus
  raise syntax 40.900 array("DTE DATAI transfer protocol is outside bounded model")

::method ioReset
  expose statusInternal count resetCount servicePending monitorMode serviceCount txHex rxHex
  statusInternal=self~octToDecLocal("04000000")
  count=0
  servicePending=0
  monitorMode=0
  serviceCount=0
  txHex=""
  rxHex=""
  resetCount=resetCount+1
  return self

::method state
  expose statusInternal count resetCount servicePending monitorMode serviceCount txHex rxHex
  d=.directory~new
  d["statusInternal"]=statusInternal
  d["count"]=count
  d["resetCount"]=resetCount
  d["servicePending"]=servicePending
  d["monitorMode"]=monitorMode
  d["serviceCount"]=serviceCount
  d["txHex"]=txHex
  d["rxHex"]=rxHex
  return d

::method restoreState
  expose statusInternal count resetCount servicePending monitorMode serviceCount txHex rxHex
  use strict arg d
  statusInternal=d["statusInternal"]
  count=d["count"]
  resetCount=d["resetCount"]
  servicePending=d["servicePending"]
  monitorMode=d["monitorMode"]
  serviceCount=d["serviceCount"]
  txHex=d["txHex"]
  rxHex=d["rxHex"]
  return self

::method statusInternal
  expose statusInternal
  return statusInternal
::method count
  expose count
  return count
::method resetCount
  expose resetCount
  return resetCount
::method servicePending
  expose servicePending
  return servicePending
::method monitorMode
  expose monitorMode
  return monitorMode
::method serviceCount
  expose serviceCount
  return serviceCount
::method txHex
  expose txHex
  return txHex

::method string
  expose statusInternal count resetCount servicePending monitorMode serviceCount txHex rxHex
  return "KL10Dte [device=200 status=" || .LROct~fromDecimal(statusInternal // (2 ** 18))~right || -
         " internal=" || statusInternal || " count=" || count || " resetCount=" || resetCount || -
         " pending=" || servicePending || " monitor=" || monitorMode || -
         " serviceCount=" || serviceCount || " txBytes=" || (txHex~length % 2) || -
         " rxBytes=" || (rxHex~length % 2) || "]"

::method bitSet private
  use strict arg value, mask
  return self~and36(value,mask) \= 0
::method and36 private
  use strict arg a,b
  return (.LROct~fromDecimal(a) & .LROct~fromDecimal(b))~decimal
::method andNot private
  use strict arg a,b
  return (.LROct~fromDecimal(a) & (\.LROct~fromDecimal(b)))~decimal
::method or36 private
  use strict arg a,b
  return (.LROct~fromDecimal(a) | .LROct~fromDecimal(b))~decimal
::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n



::class KL10Apr public

::method init
  expose resetCount resetDone aprIrq irqEnable irqFlags
  resetCount = 0
  resetDone = 0
  aprIrq = 0
  irqEnable = 0
  irqFlags = 0

::method deviceCode
  return 0

::method deviceName
  return "APR"

::method stateSchema
  return "KL10_APR_STATE/1"

::method ioAction
  use strict arg ioFunction
  if ioFunction = 4 then return "APR_CONO"
  if ioFunction = 5 then return "APR_CONI_STATUS"
  return "APR_IO"

::method cono
  expose resetCount aprIrq irqEnable irqFlags
  use strict arg condition, bus
  numeric digits 30
  if \datatype(condition, "W") | condition < 0 | condition >= (2 ** 18) then
    raise syntax 40.900 array("CONO APR invalid 18-bit condition:" condition)

  resetBit = ((condition % (2 ** 16)) // 2)
  resetPerformed=0
  beforeResetCount=resetCount
  if resetBit then do
    /* I/O RESET is a control bit, not an exclusive CONO form.  The resident
     * monitor deliberately combines it with APR flag controls in 227560. */
    ignored=self~ioReset
    ignored=bus~resetOtherDevices(self)
    resetPerformed=1
  end

  aprIrq = condition // 8
  low12 = condition // (2 ** 12)
  flagBits = (low12 % 16) * 16           /* 07760 octal mask */
  if ((condition % (2 ** 15)) // 2) then
    irqEnable = (.LROct~fromDecimal(irqEnable) | .LROct~fromDecimal(flagBits))~decimal
  if ((condition % (2 ** 14)) // 2) then
    irqEnable = (.LROct~fromDecimal(irqEnable) & (\.LROct~fromDecimal(flagBits)))~decimal
  if ((condition % (2 ** 13)) // 2) then
    irqFlags = (.LROct~fromDecimal(irqFlags) & (\.LROct~fromDecimal(flagBits)))~decimal
  if ((condition % (2 ** 12)) // 2) then
    irqFlags = (.LROct~fromDecimal(irqFlags) | .LROct~fromDecimal(flagBits))~decimal

  detail = .directory~new
  if resetPerformed then do
    if condition=(2**16) then detail["action"]="APR_IO_RESET"
    else detail["action"]="APR_IO_RESET+APR_CONO"
  end
  else detail["action"]="APR_CONO"
  detail["aprResetCountBefore"]=beforeResetCount
  detail["aprResetCountAfter"]=resetCount
  detail["aprIrqAfter"] = aprIrq
  detail["aprIrqEnableAfter"] = irqEnable
  detail["aprIrqFlagsAfter"] = irqFlags
  return detail

::method blki
  use strict arg effectiveAddress, bus
  numeric digits 30
  /* KL10 APR BLKI is APRID, not channel I/O. Base KL10 identity:
   * bit 0 advertises KL/TOPS-20 paging, microcode level 500, DEC test
   * serial 1025 decimal (002001 octal). KL10B/extended bits remain clear. */
  aprid=.KL10Word~bit(0) + .KL10Word~fromOctal("000500")*(2 ** 18) + 1025
  bus~cpu~memory~put(effectiveAddress,aprid)
  detail=.directory~new
  detail["action"]="APR_APRID"
  detail["destination"]=effectiveAddress
  detail["writeValue"]=aprid
  detail["data"]=aprid
  return detail

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method coni
  expose aprIrq irqEnable irqFlags
  use strict arg bus
  numeric digits 30
  res = (.LROct~fromDecimal(irqFlags) | .LROct~fromDecimal(aprIrq))~decimal
  res = res + irqEnable * (2 ** 18)
  pending = (.LROct~fromDecimal(irqFlags) & .LROct~fromDecimal(irqEnable))~decimal
  if pending \= 0 then
    res = (.LROct~fromDecimal(res) | .LROct~fromDecimal(8))~decimal
  return res

::method ioReset
  expose resetCount resetDone aprIrq irqEnable irqFlags
  resetCount = resetCount + 1
  resetDone = 1
  aprIrq = 0
  irqEnable = 0
  irqFlags = 0
  return self

::method ioResetCount
  expose resetCount
  return resetCount

::method ioResetDone
  expose resetDone
  return resetDone

::method aprIrq
  expose aprIrq
  return aprIrq

::method irqEnable
  expose irqEnable
  return irqEnable

::method irqFlags
  expose irqFlags
  return irqFlags

::method signalFlag
  expose irqFlags
  use strict arg mask
  irqFlags = (.LROct~fromDecimal(irqFlags) | .LROct~fromDecimal(mask))~decimal
  return self

::method state
  expose resetCount resetDone aprIrq irqEnable irqFlags
  d = .directory~new
  d["resetCount"] = resetCount
  d["resetDone"] = resetDone
  d["aprIrq"] = aprIrq
  d["irqEnable"] = irqEnable
  d["irqFlags"] = irqFlags
  return d

::method restoreState
  expose resetCount resetDone aprIrq irqEnable irqFlags
  use strict arg d
  resetCount = d["resetCount"]
  resetDone = d["resetDone"]
  aprIrq = d["aprIrq"]
  irqEnable = d["irqEnable"]
  irqFlags = d["irqFlags"]
  return self

::method string
  expose resetCount resetDone aprIrq irqEnable irqFlags
  return "KL10Apr [device=000 resetCount=" || resetCount || " resetDone=" || resetDone || -
         " PIA=" || .LROct~fromDecimal(aprIrq)~right || -
         " irqEnable=" || .LROct~fromDecimal(irqEnable)~right || -
         " irqFlags=" || .LROct~fromDecimal(irqFlags)~right || "]"



::class KL10Pi public

::method init
  expose systemOn channelsOn programRequests inProgress resetCount
  systemOn=0
  channelsOn=0
  programRequests=0
  inProgress=0
  resetCount=0

::method deviceCode
  return 4

::method deviceName
  return "PI"

::method stateSchema
  return "KL10_PI_STATE/1"

::method ioAction
  use strict arg ioFunction
  if ioFunction=4 then return "PI_CONO"
  if ioFunction=5 then return "PI_CONI_STATUS"
  return "PI_IO"

::method cono
  expose systemOn channelsOn programRequests inProgress resetCount
  use strict arg condition,bus
  numeric digits 30
  if \datatype(condition,"W") | condition<0 | condition>=2**18 then
    raise syntax 40.900 array("CONO PI invalid 18-bit condition:" condition)

  /* The resident monitor first executes CONO PI,010000: RESET PI SYSTEM.
   * Model the control register latches, but do not invent interrupt dispatch. */
  resetPi=self~octToDecLocal("010000")
  piOff=self~octToDecLocal("000400")
  if condition=resetPi then do
    ignored=self~ioReset
    d=.directory~new
    d["action"]="PI_RESET"
    d["resetCountAfter"]=resetCount
    return d
  end
  if condition=piOff then do
    systemOn=0
    d=.directory~new
    d["action"]="PI_OFF"
    d["systemOnAfter"]=systemOn
    return d
  end

  raise syntax 40.900 array("CONO PI operation outside bounded model:" condition)

::method coni
  expose systemOn channelsOn programRequests inProgress
  numeric digits 30
  out=programRequests*(2**18)
  out=out+inProgress*256
  if systemOn then out=out+128
  out=out+channelsOn
  return out

::method ioReset
  expose systemOn channelsOn programRequests inProgress resetCount
  systemOn=0
  channelsOn=0
  programRequests=0
  inProgress=0
  resetCount=resetCount+1
  return self

::method state
  expose systemOn channelsOn programRequests inProgress resetCount
  d=.directory~new
  d["systemOn"]=systemOn
  d["channelsOn"]=channelsOn
  d["programRequests"]=programRequests
  d["inProgress"]=inProgress
  d["resetCount"]=resetCount
  return d

::method restoreState
  expose systemOn channelsOn programRequests inProgress resetCount
  use strict arg d
  systemOn=d["systemOn"]
  channelsOn=d["channelsOn"]
  programRequests=d["programRequests"]
  inProgress=d["inProgress"]
  resetCount=d["resetCount"]
  return self

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method string
  expose systemOn channelsOn programRequests inProgress resetCount
  return "KL10Pi [device=004 systemOn=" || systemOn || -
      " channelsOn=" || .LROct~fromDecimal(channelsOn)~right || -
      " programRequests=" || .LROct~fromDecimal(programRequests)~right || -
      " inProgress=" || .LROct~fromDecimal(inProgress)~right || -
      " resetCount=" || resetCount || "]"


::class KL10Pag public

::method init
  expose statusWord conoZeroCount conoCount ebPtr ubPtr pageEnabled tops20Page tlbFlushCount dataoCount lastDatao currentAcBlock previousAcBlock previousContextSection
  /* Unknown until a modeled hardware reset establishes the PAG register state. */
  statusWord = .nil
  conoZeroCount = 0
  conoCount = 0
  ebPtr = .nil
  ubPtr = .nil
  pageEnabled = .nil
  tops20Page = .nil
  tlbFlushCount = 0
  dataoCount = 0
  lastDatao = .nil
  currentAcBlock = 0
  previousAcBlock = 0
  previousContextSection = 0

::method deviceCode
  return 8                              /* 010 octal */

::method deviceName
  return "PAG"

::method stateSchema
  return "KL10_PAG_STATE/1"

::method ioAction
  use strict arg ioFunction
  if ioFunction = 4 then return "PAG_CONO"
  if ioFunction = 5 then return "PAG_CONI_STATUS"
  return "PAG_IO"

::method ioReset
  expose statusWord ebPtr ubPtr pageEnabled tops20Page tlbFlushCount currentAcBlock previousAcBlock previousContextSection
  /* reset_all() leaves the bounded KL10 PAG state with paging disabled and
   * a zero executive base.  Treat the associated translation invalidation as
   * an observable generation count rather than inventing TLB contents. */
  statusWord = 0
  ebPtr = 0
  ubPtr = 0
  pageEnabled = 0
  tops20Page = 0
  currentAcBlock = 0
  previousAcBlock = 0
  previousContextSection = 0
  tlbFlushCount = tlbFlushCount + 1
  return self

::method cono
  expose statusWord conoZeroCount conoCount ebPtr pageEnabled tops20Page tlbFlushCount
  use strict arg condition, bus
  numeric digits 30
  if \datatype(condition, "W") | condition < 0 | condition >= (2 ** 18) then
    raise syntax 40.900 array("CONO PAG invalid 18-bit condition:" condition)

  /* Cornwell KL10 dev_pag(CONO):
   *   EBR       = (condition & 017777) << 9
   *   page_en   = condition & 020000
   *   t20_page  = condition & 040000
   *   invalidate executive/user translation caches.
   *
   * v0.27 admits KL TOPS-20 section-zero translation. KI/TOPS-10 paging is
   * still refused when paging is actually enabled. */
  enableBit = ((condition % (2 ** 13)) // 2)
  tops20Bit = ((condition % (2 ** 14)) // 2)
  if enableBit & \tops20Bit then
    raise syntax 40.900 array("CONO PAG enabling non-TOPS-20 paging is outside bounded memory model:" condition)

  beforeCount = conoCount
  beforeZeroCount = conoZeroCount
  ebBase = condition // (2 ** 13)
  ebPtr = ebBase * (2 ** 9)
  pageEnabled = enableBit
  tops20Page = tops20Bit
  statusWord = ebBase
  conoCount = conoCount + 1
  if condition = 0 then conoZeroCount = conoZeroCount + 1
  tlbFlushCount = tlbFlushCount + 1

  detail = .directory~new
  if condition = 0 then detail["action"] = "PAG_CONO_ZERO"
  else detail["action"] = "PAG_CONO"
  detail["pagConoCountBefore"] = beforeCount
  detail["pagConoCountAfter"] = conoCount
  detail["pagConoZeroCountBefore"] = beforeZeroCount
  detail["pagConoZeroCountAfter"] = conoZeroCount
  detail["pagStatusAfter"] = statusWord
  detail["pagEbPtrAfter"] = ebPtr
  detail["pagPageEnabledAfter"] = pageEnabled
  detail["pagTops20PageAfter"] = tops20Page
  detail["pagTlbFlushCountAfter"] = tlbFlushCount
  return detail

::method clrpt
  expose tlbFlushCount
  use strict arg effectiveAddress
  /* KL10 BLKO PAG is CLRPT: invalidate the eight-entry page group containing
   * E. This model deliberately walks the authentic page tables on every
   * access and therefore has no hidden TLB entries to erase. Preserve the
   * architecturally observable invalidation generation. */
  if \datatype(effectiveAddress, "W") | effectiveAddress < 0 | effectiveAddress >= (2 ** 18) then
    raise syntax 40.900 array("CLRPT invalid virtual address:" effectiveAddress)
  tlbFlushCount = tlbFlushCount + 1
  detail = .directory~new
  detail["action"] = "PAG_CLRPT"
  detail["clearPageGroup"] = (effectiveAddress % 512) - ((effectiveAddress % 512) // 8)
  detail["pagTlbFlushCountAfter"] = tlbFlushCount
  return detail

::method datao
  expose dataoCount lastDatao ubPtr pageEnabled tops20Page tlbFlushCount currentAcBlock previousAcBlock previousContextSection
  use strict arg value, bus
  numeric digits 30
  value = value // (2 ** 36)
  /* KL10 PAG DATAO, left half (DEC KL10 assignments):
   *   400000 LLACBL  load current/previous AC block selectors
   *   200000 LLPRCN  load previous-context section
   *   100000 LLDUSB  load user base register from RH bits 23..35
   *   LH bits 6..8   current AC block
   *   LH bits 9..11  previous AC block
   *   LH bits 13..17 previous-context section
   *
   * The bounded CPU currently has one architecturally live AC array.  It can
   * therefore represent LLACBL exactly only while the requested CURRENT block
   * remains block zero.  A nonzero previous block is safe to record: ordinary
   * section-zero execution does not read previous-context ACs.  LLPRCN is
   * likewise recorded but remains unusable until an instruction actually asks
   * for previous-context addressing.
   *
   * MTBOOT's real handoff value is 500600,,000765: LLACBL+LLDUSB, current
   * block 0, previous block 6, UBR 765000. */
  leftHalf = value % (2 ** 18)
  rightHalf = value // (2 ** 18)
  loadAcBlocks = leftHalf >= self~octToDecLocal("400000")
  loadPreviousContext = ((leftHalf // self~octToDecLocal("400000")) >= self~octToDecLocal("200000"))
  loadUserBase = ((leftHalf // self~octToDecLocal("200000")) >= self~octToDecLocal("100000"))

  if loadAcBlocks then do
    requestedCurrent = (leftHalf // self~octToDecLocal("010000")) % self~octToDecLocal("001000")
    requestedPrevious = (leftHalf // self~octToDecLocal("001000")) % self~octToDecLocal("000100")
    if requestedCurrent \= 0 then
      raise syntax 40.900 array("PAG DATAO selecting nonzero current AC block is outside bounded AC model:" requestedCurrent)
    currentAcBlock = requestedCurrent
    previousAcBlock = requestedPrevious
  end

  if loadPreviousContext then do
    /* Bits 13..17 are the low five bits of the left half. */
    previousContextSection = leftHalf // 32
  end

  if pageEnabled | tops20Page then
    raise syntax 40.900 array("PAG DATAO while address translation enabled is outside bounded memory model")

  if loadUserBase then do
    ubBase = rightHalf // (2 ** 13)
    ubPtr = ubBase * (2 ** 9)
    tlbFlushCount = tlbFlushCount + 1
  end
  dataoCount = dataoCount + 1
  lastDatao = value
  return self

/* Small octal helper local to PAG register decoding; avoids depending on the
 * external test helpers while keeping the bit masks readable. */
::method octToDecLocal private
  use arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n


::method coni
  expose statusWord ebPtr pageEnabled tops20Page
  use strict arg bus
  numeric digits 30
  if statusWord = .nil then
    raise syntax 40.900 array("PAG status is unknown before modeled I/O reset")
  statusWord = ebPtr % (2 ** 9)
  if pageEnabled then statusWord = statusWord + (2 ** 13)
  if tops20Page then statusWord = statusWord + (2 ** 14)
  return statusWord

::method conoZero
  use strict arg
  /* Compatibility helper retained for older probes.  Route through the exact
   * register transition rather than maintaining a second PAG state path. */
  return self~cono(0, .nil)

::method status
  expose statusWord
  return statusWord

::method ebPtr
  expose ebPtr
  return ebPtr

::method ubPtr
  expose ubPtr
  return ubPtr

::method pageEnabled
  expose pageEnabled
  return pageEnabled

::method tops20Page
  expose tops20Page
  return tops20Page

::method currentAcBlock
  expose currentAcBlock
  return currentAcBlock

::method previousAcBlock
  expose previousAcBlock
  return previousAcBlock

::method previousContextSection
  expose previousContextSection
  return previousContextSection

::method conoCount
  expose conoCount
  return conoCount

::method conoZeroCount
  expose conoZeroCount
  return conoZeroCount

::method tlbFlushCount
  expose tlbFlushCount
  return tlbFlushCount

::method dataoCount
  expose dataoCount
  return dataoCount

::method lastDatao
  expose lastDatao
  return lastDatao

::method state
  expose statusWord conoZeroCount conoCount ebPtr ubPtr pageEnabled tops20Page tlbFlushCount dataoCount lastDatao currentAcBlock previousAcBlock previousContextSection
  d = .directory~new
  d["statusWord"] = statusWord
  d["conoZeroCount"] = conoZeroCount
  d["conoCount"] = conoCount
  d["ebPtr"] = ebPtr
  d["ubPtr"] = ubPtr
  d["pageEnabled"] = pageEnabled
  d["tops20Page"] = tops20Page
  d["tlbFlushCount"] = tlbFlushCount
  d["dataoCount"] = dataoCount
  d["lastDatao"] = lastDatao
  d["currentAcBlock"] = currentAcBlock
  d["previousAcBlock"] = previousAcBlock
  d["previousContextSection"] = previousContextSection
  return d

::method restoreState
  expose statusWord conoZeroCount conoCount ebPtr ubPtr pageEnabled tops20Page tlbFlushCount dataoCount lastDatao currentAcBlock previousAcBlock previousContextSection
  use strict arg d
  statusWord = d["statusWord"]
  conoZeroCount = d["conoZeroCount"]
  conoCount = d["conoCount"]
  ebPtr = d["ebPtr"]
  ubPtr = d["ubPtr"]
  pageEnabled = d["pageEnabled"]
  tops20Page = d["tops20Page"]
  tlbFlushCount = d["tlbFlushCount"]
  dataoCount = d["dataoCount"]
  lastDatao = d["lastDatao"]
  currentAcBlock = d["currentAcBlock"]
  previousAcBlock = d["previousAcBlock"]
  previousContextSection = d["previousContextSection"]
  return self

::method string
  expose statusWord conoZeroCount conoCount ebPtr ubPtr pageEnabled tops20Page tlbFlushCount dataoCount lastDatao currentAcBlock previousAcBlock previousContextSection
  if statusWord = .nil then return "KL10Pag [device=010 status=UNKNOWN]"
  return "KL10Pag [device=010 status=" || .LROct~fromDecimal(statusWord)~right || -
         " EBR=" || .LROct~fromDecimal(ebPtr)~right || -
         " UBR=" || .LROct~fromDecimal(ubPtr)~right || -
         " pageEnable=" || pageEnabled || " t20Page=" || tops20Page || -
         " conoCount=" || conoCount || " conoZeroCount=" || conoZeroCount || -
         " currentACBlock=" || currentAcBlock || " previousACBlock=" || previousAcBlock || -
         " previousSection=" || previousContextSection || -
         " dataoCount=" || dataoCount || " tlbFlushCount=" || tlbFlushCount || "]"


::class KL10CPU public

::method init
  expose memory imageMemory pc acBlocks halted apr pag flags ioBus instructionCount processorMode pendingPageFault
  memory = .nil
  imageMemory = .nil
  pc = 0
  acBlocks = .array~new(8)
  do block = 1 to 8
    blockAc = .array~new(16)
    do i = 1 to 16
      blockAc[i] = 0
    end
    acBlocks[block] = blockAc
  end
  halted = 1
  ioBus = .KL10IOBus~new(self)
  apr = .KL10Apr~new
  pi = .KL10Pi~new
  pag = .KL10Pag~new
  ignored = ioBus~attach(apr)
  ignored = ioBus~attach(pi)
  ignored = ioBus~attach(pag)
  /* The bounded bootstrap CPU begins with the modeled processor flag word
   * clear.  None of the instructions admitted before JSP alter FLAGS.
   * Non-zero flag evolution remains outside the current boundary. */
  flags = 0
  instructionCount = 0
  processorMode = "EXEC"
  pendingPageFault = .nil

::method loadImage
  expose memory imageMemory pc halted
  use arg mem, startAddress
  imageMemory = mem
  memory = .KL10AddressSpace~new(mem, self)
  pc = startAddress
  halted = 1
  return self

::method pc
  expose pc
  return pc

::method memory
  expose memory
  return memory

::method imageMemory
  expose imageMemory
  return imageMemory

::method halted
  expose halted
  return halted

::method apr
  expose ioBus
  return ioBus~device(0)

::method pi
  expose ioBus
  return ioBus~device(4)

::method pag
  expose ioBus
  return ioBus~device(8)

::method ioBus
  expose ioBus
  return ioBus

::method attachDte
  expose ioBus
  code=128                              /* 0200 octal */
  if ioBus~hasDevice(code) then return ioBus~device(code)
  dte=.KL10Dte~new
  ignored=ioBus~attach(dte)
  return dte

::method dte
  expose ioBus
  return ioBus~device(128)              /* 0200 octal */

::method attachRh20
  expose ioBus
  use arg code = 352                    /* default 0540 octal */
  if code < 352 | code > 380 | code // 4 \= 0 then
    raise syntax 40.900 array("bounded RH20 attachment requires device 540..574 by fours:" code)
  if ioBus~hasDevice(code) then return ioBus~device(code)
  rh=.KL10Rh20~new(code)
  ignored=ioBus~attach(rh)
  return rh

::method rh20
  expose ioBus
  use arg code = 352
  return ioBus~device(code)

::method flags
  expose flags
  return flags

::method instructionCount
  expose instructionCount
  return instructionCount

::method processorMode
  expose processorMode
  return processorMode

::method pendingPageFault
  expose pendingPageFault
  return pendingPageFault

::method setPendingPageFault
  expose pendingPageFault
  use strict arg fault
  pendingPageFault=fault
  return self

::method clearPendingPageFault
  expose pendingPageFault
  pendingPageFault=.nil
  return self

::method restoreCoreState
  expose pc halted flags instructionCount processorMode
  use arg restoredPc, restoredFlags, restoredHalted, restoredInstructionCount, restoredProcessorMode
  pc = restoredPc
  flags = restoredFlags
  halted = restoredHalted
  if arg() >= 4 then instructionCount = restoredInstructionCount
  if arg() >= 5 then processorMode = restoredProcessorMode
  return self

::method string
  expose pc acBlocks halted flags instructionCount processorMode
  out = "KL10CPU [PC=" || .LROct~fromDecimal(pc)~right || -
        " FLAGS=" || .LROct~fromDecimal(flags)~right || -
        " MODE=" || processorMode || -
        " ICOUNT=" || instructionCount || -
        " HALTED=" || halted
  do i = 0 to 15
    regName = right(.LROct~fromDecimal(i)~right, 2)
    if left(regName, 1) = "0" then regName = right(regName, 1)
    out = out || " AC" || regName || "=" || .LROct~fromDecimal(self~accumulator(i))~string
  end
  return out || "]"

::method accumulator
  expose acBlocks
  use arg number
  if number < 0 | number > 15 then raise syntax 40.900 array("bad accumulator:" number)
  block = self~pag~currentAcBlock
  return acBlocks[block + 1][number + 1]

::method setAccumulator
  expose acBlocks
  use arg number, value
  numeric digits 30
  if number < 0 | number > 15 then raise syntax 40.900 array("bad accumulator:" number)
  block = self~pag~currentAcBlock
  acBlocks[block + 1][number + 1] = value // (2 ** 36)
  return self

::method accumulatorInBlock
  expose acBlocks
  use strict arg block, number
  if block < 0 | block > 7 then raise syntax 40.900 array("bad AC block:" block)
  if number < 0 | number > 15 then raise syntax 40.900 array("bad accumulator:" number)
  return acBlocks[block + 1][number + 1]

::method setAccumulatorInBlock
  expose acBlocks
  use strict arg block, number, value
  numeric digits 30
  if block < 0 | block > 7 then raise syntax 40.900 array("bad AC block:" block)
  if number < 0 | number > 15 then raise syntax 40.900 array("bad accumulator:" number)
  acBlocks[block + 1][number + 1] = value // (2 ** 36)
  return self

::method previousAccumulator
  use strict arg number
  return self~accumulatorInBlock(self~pag~previousAcBlock, number)

::method setPreviousAccumulator
  use strict arg number, value
  return self~setAccumulatorInBlock(self~pag~previousAcBlock, number, value)

::method fetch
  expose memory pc
  if memory = .nil then raise syntax 40.900 array("CPU has no memory image")
  /* The address-space object, not the CPU fetch path, owns the mapping of
   * architectural addresses to fast registers or backing core. */
  return memory~word(pc)

::method preview
  expose memory pc
  if memory = .nil then raise syntax 40.900 array("CPU has no memory image")
  word = memory~peekWord(pc)
  d = self~decode(word)
  out = .directory~new
  out["pc"] = pc
  out["instruction"] = word
  out["fetchSource"] = memory~sourceKind(pc)
  out["opcode"] = d["opcode"]
  out["mnemonic"] = d["mnemonic"]
  out["format"] = d["format"]
  out["device"] = d["device"]
  out["deviceName"] = d["deviceName"]
  out["ioFunction"] = d["ioFunction"]
  out["indirect"] = d["indirect"]
  out["index"] = d["index"]
  out["address"] = d["address"]
  out["effectiveAddress"] = .nil
  out["translation"] = memory~lastTranslation
  out["xctInstruction"] = .nil
  out["xctMnemonic"] = .nil
  out["xctDevice"] = .nil
  out["xctDeviceName"] = .nil
  out["xctIoFunction"] = .nil
  if d["indirect"] = 0 then do
    out["effectiveAddress"] = self~effectiveAddress18(d)
    if d["opcode"] = 174 then do
      xctEa = out["effectiveAddress"]
      xctWord = memory~peekWord(xctEa)
      xctDecoded = self~decode(xctWord)
      out["xctInstruction"] = xctWord
      out["xctMnemonic"] = xctDecoded["mnemonic"]
      out["xctDevice"] = xctDecoded["device"]
      out["xctDeviceName"] = xctDecoded["deviceName"]
      out["xctIoFunction"] = xctDecoded["ioFunction"]
    end
  end
  return out

::method decode
  expose ioBus
  use arg word
  numeric digits 30
  d = .directory~new
  d["opcode"] = (word % (2 ** 27)) // 512
  d["ac"] = (word % (2 ** 23)) // 16
  d["indirect"] = (word % (2 ** 22)) // 2
  d["index"] = (word % (2 ** 18)) // 16
  d["address"] = word // (2 ** 18)
  d["format"] = "GENERAL"
  d["device"] = .nil
  d["deviceField"] = .nil
  d["deviceName"] = .nil
  d["ioFunction"] = .nil

  /* PDP-10 I/O instructions are a distinct format.  All have top three
   * bits 111; bits 3..9 are the device number and bits 10..12 select the
   * I/O operation.  Decode the format generically; bounded execution admits
   * only explicitly modeled device transitions. */
  if (word % (2 ** 33)) = 7 then do
    d["format"] = "IO"
    d["ac"] = .nil
    d["deviceField"] = (word % (2 ** 26)) // 128
    /* DEC device numbers are conventionally written in octal multiples of
     * four (APR=000, PI=004, PAG=010, ...); the seven encoded bits are that
     * device number divided by four. */
    d["device"] = d["deviceField"] * 4
    d["deviceName"] = ioBus~deviceName(d["device"])
    d["ioFunction"] = (word % (2 ** 23)) // 8
    d["e"] = d["address"]
    select
      when d["ioFunction"] = 0 then d["mnemonic"] = "BLKI"
      when d["ioFunction"] = 1 then d["mnemonic"] = "DATAI"
      when d["ioFunction"] = 2 then d["mnemonic"] = "BLKO"
      when d["ioFunction"] = 3 then d["mnemonic"] = "DATAO"
      when d["ioFunction"] = 4 then d["mnemonic"] = "CONO"
      when d["ioFunction"] = 5 then d["mnemonic"] = "CONI"
      when d["ioFunction"] = 6 then d["mnemonic"] = "CONSZ"
      when d["ioFunction"] = 7 then d["mnemonic"] = "CONSO"
    end
    return d
  end

  if d["opcode"] >= 256 & d["opcode"] <= 319 then do /* 400..477 Boolean */
    booleanBases = "SETZ AND ANDCA SETM ANDCM SETA XOR IOR ANDCB EQV SETCA ORCA SETCM ORCM ORCB SETO"
    booleanGroup = (d["opcode"] - 256) % 4
    booleanForm = d["opcode"] // 4
    baseName = word(booleanBases, booleanGroup + 1)
    select
      when booleanForm = 0 then d["mnemonic"] = baseName
      when booleanForm = 1 then d["mnemonic"] = baseName || "I"
      when booleanForm = 2 then d["mnemonic"] = baseName || "M"
      when booleanForm = 3 then d["mnemonic"] = baseName || "B"
    end
    return d
  end

  if d["opcode"] >= 320 & d["opcode"] <= 383 then do /* 500..577 halfword decode */
    halfBases = "HLL HRL HLLZ HRLZ HLLO HRLO HLLE HRLE HRR HLR HRRZ HLRZ HRRO HLRO HRRE HLRE"
    halfGroup = (d["opcode"] - 320) % 4
    halfForm = d["opcode"] // 4
    halfName = word(halfBases, halfGroup + 1)
    select
      when halfForm = 0 then d["mnemonic"] = halfName
      when halfForm = 1 then d["mnemonic"] = halfName || "I"
      when halfForm = 2 then d["mnemonic"] = halfName || "M"
      otherwise d["mnemonic"] = halfName || "S"
    end
    return d
  end

  if d["opcode"] >= 384 & d["opcode"] <= 447 then do /* 600..677 Test */
    testOffset = d["opcode"] - 384
    testOperation = testOffset % 16
    testWithin = testOffset // 16
    testLeft = testWithin // 2
    if testWithin >= 8 then testMemory = 1
    else testMemory = 0
    testCond = (testWithin // 8) - testLeft
    if testMemory then do
      if testLeft then testAddressChar = "S"
      else testAddressChar = "D"
    end
    else do
      if testLeft then testAddressChar = "L"
      else testAddressChar = "R"
    end
    testOperationChar = word("N Z C O", testOperation + 1)
    select
      when testCond = 0 then testSuffix = ""
      when testCond = 2 then testSuffix = "E"
      when testCond = 4 then testSuffix = "A"
      when testCond = 6 then testSuffix = "N"
    end
    d["mnemonic"] = "T" || testAddressChar || testOperationChar || testSuffix
    return d
  end

  if d["opcode"] >= 91 & d["opcode"] <= 95 then do /* 133..137 byte ops */
    byteNames = "IBP ILDB LDB IDPB DPB"
    d["mnemonic"] = word(byteNames, d["opcode"] - 90)
    return d
  end

  if d["opcode"] >= 128 & d["opcode"] <= 135 then do /* 200..207 MOVE family */
    moveNames = "MOVE MOVEI MOVEM MOVES MOVS MOVSI MOVSM MOVSS"
    d["mnemonic"] = word(moveNames, d["opcode"] - 127)
    return d
  end

  if d["opcode"] >= 136 & d["opcode"] <= 139 then do /* 210..213 MOVN family */
    movnNames="MOVN MOVNI MOVNM MOVNS"
    d["mnemonic"]=word(movnNames,d["opcode"]-135)
    return d
  end

  if d["opcode"] >= 140 & d["opcode"] <= 143 then do /* 214..217 MOVM family */
    movmNames="MOVM MOVMI MOVMM MOVMS"
    d["mnemonic"]=word(movmNames,d["opcode"]-139)
    return d
  end

  if d["opcode"] >= 192 & d["opcode"] <= 207 then do /* 300..317 CAI/CAM */
    if d["opcode"] < 200 then compareBase = "CAI"
    else compareBase = "CAM"
    compareCond = d["opcode"] // 8
    select
      when compareCond = 0 then suffix = ""
      when compareCond = 1 then suffix = "L"
      when compareCond = 2 then suffix = "E"
      when compareCond = 3 then suffix = "LE"
      when compareCond = 4 then suffix = "A"
      when compareCond = 5 then suffix = "GE"
      when compareCond = 6 then suffix = "N"
      otherwise suffix = "G"
    end
    d["mnemonic"] = compareBase || suffix
    return d
  end

  if d["opcode"] >= 208 & d["opcode"] <= 215 then do /* 320..327 JUMP family */
    jumpNames = "JUMP JUMPL JUMPE JUMPLE JUMPA JUMPGE JUMPN JUMPG"
    d["mnemonic"] = word(jumpNames, d["opcode"] - 207)
    return d
  end

  if d["opcode"] >= 216 & d["opcode"] <= 223 then do /* 330..337 SKIP family */
    skipNames = "SKIP SKIPL SKIPE SKIPLE SKIPA SKIPGE SKIPN SKIPG"
    d["mnemonic"] = word(skipNames, d["opcode"] - 215)
    return d
  end

  if d["opcode"] >= 224 & d["opcode"] <= 231 then do /* 340..347 AOJ family */
    aojNames = "AOJ AOJL AOJE AOJLE AOJA AOJGE AOJN AOJG"
    d["mnemonic"] = word(aojNames, d["opcode"] - 223)
    return d
  end

  if d["opcode"] >= 232 & d["opcode"] <= 239 then do /* 350..357 AOS family */
    aosNames = "AOS AOSL AOSE AOSLE AOSA AOSGE AOSN AOSG"
    d["mnemonic"] = word(aosNames, d["opcode"] - 231)
    return d
  end

  if d["opcode"] >= 240 & d["opcode"] <= 247 then do /* 360..367 SOJ family */
    sojNames = "SOJ SOJL SOJE SOJLE SOJA SOJGE SOJN SOJG"
    d["mnemonic"] = word(sojNames, d["opcode"] - 239)
    return d
  end

  if d["opcode"] = 80 then do
    d["mnemonic"]="DMOVE"
    return d
  end
  if d["opcode"] = 84 then do
    d["mnemonic"]="DMOVEM"
    return d
  end

  if d["opcode"] >= 144 & d["opcode"] <= 151 then do /* 220..227 multiply */
    multiplyNames = "IMUL IMULI IMULM IMULB MUL MULI MULM MULB"
    d["mnemonic"] = word(multiplyNames, d["opcode"] - 143)
    return d
  end

  if d["opcode"] >= 160 & d["opcode"] <= 166 then do /* 240..246 shift/scan decode */
    shiftNames = "ASH ROT LSH JFFO ASHC ROTC LSHC"
    d["mnemonic"] = word(shiftNames, d["opcode"] - 159)
    return d
  end

  if d["opcode"] >= 168 & d["opcode"] <= 175 then do /* 250..257 branch/control decode */
    branchNames = "EXCH BLT AOBJP AOBJN JRST JFCL XCT MAP"
    d["mnemonic"] = word(branchNames, d["opcode"] - 167)
    return d
  end

  if d["opcode"] >= 176 & d["opcode"] <= 183 then do /* 260..267 stack/control */
    stackNames = "PUSHJ PUSH POP POPJ JSR JSP JSA JRA"
    d["mnemonic"] = word(stackNames, d["opcode"] - 175)
    return d
  end

  if d["opcode"] >= 184 & d["opcode"] <= 191 then do /* 270..277 octal */
    arithmeticNames = "ADD ADDI ADDM ADDB SUB SUBI SUBM SUBB"
    d["mnemonic"] = word(arithmeticNames, d["opcode"] - 183)
    return d
  end

  select
    when d["opcode"] = 69 then d["mnemonic"] = "ADJSP" /* 105 octal */
    when d["opcode"] = 80 then d["mnemonic"] = "DMOVE" /* 120 octal */
    when d["opcode"] = 172 then d["mnemonic"] = "JRST"  /* 254 octal */
    when d["opcode"] = 181 then d["mnemonic"] = "JSP"   /* 265 octal */
    when d["opcode"] = 220 then d["mnemonic"] = "SKIPA" /* 334 octal */
    otherwise d["mnemonic"] = "OP" d["opcode"]
  end
  return d

::method nextInstruction
  return self~decode(self~fetch)

::method liveExtensionNameForOpcode
  use strict arg opcode
  if \datatype(opcode,"W") | opcode<0 | opcode>511 then
    raise syntax 40.900 array("KL10 opcode must be 0..511 for live extension:" opcode)
  octal=.LROct~fromDecimal(opcode)~right
  return "OP" || right(octal,3)

::method installLiveInstructionMethod
  use strict arg opcode,source
  name=self~liveExtensionNameForOpcode(opcode)
  self~setMethod(name,source,"OBJECT")
  return name

::method step
  /* Execute exactly one currently-supported PDP-10 instruction and stop
   * again.  This is a debugger-style single step, not a RUN implementation.
   * Unsupported addressing modes/opcodes fail rather than being guessed. */
  expose memory pc halted apr pag flags ioBus instructionCount pendingPageFault
  signal on syntax name StepSyntax
  numeric digits 30
  if memory = .nil then raise syntax 40.900 array("CPU has no memory image")

  beforePc = pc
  instruction = self~fetch
  d = self~decode(instruction)
  nextPc = (pc + 1) // (2 ** 18)

  trace = .directory~new
  trace["pcBefore"] = beforePc
  trace["fetchSource"] = memory~sourceKind(beforePc)
  trace["instruction"] = instruction
  trace["opcode"] = d["opcode"]
  trace["mnemonic"] = d["mnemonic"]
  trace["format"] = d["format"]
  trace["ac"] = d["ac"]
  trace["effectiveAddress"] = .nil
  trace["operand"] = .nil
  trace["device"] = d["device"]
  trace["deviceName"] = d["deviceName"]
  trace["ioFunction"] = d["ioFunction"]
  trace["ioCondition"] = .nil
  trace["ioAction"] = .nil
  trace["ioDestination"] = .nil
  trace["ioStatus"] = .nil
  trace["ioIndexValue"] = .nil
  trace["ioIndexRightHalf"] = .nil
  trace["flagsBefore"] = flags
  trace["savedWord"] = .nil
  if d["format"] = "IO" then trace["acBefore"] = .nil
  else trace["acBefore"] = self~accumulator(d["ac"])

  if d["format"] = "IO" then do
    /* v0.17: CPU decoding resolves the normal section-zero effective address,
     * then hands the I/O operation to the bus.  Devices own device semantics;
     * DATAI/CONI and DATAO use the same authoritative address space as CPU
     * fetch and operands.  BLKI/BLKO remain outside the bounded channel model. */
    /* KL section-zero I/O instructions use the ordinary indirect/indexed
     * effective-address chain.  The resident monitor's CONO PAG,@162267 is
     * the first historical indirect I/O form encountered. */
    ea = self~effectiveAddress18(d)
    trace["effectiveAddress"] = ea
    if d["index"] \= 0 then do
      indexValue = self~accumulator(d["index"])
      trace["ioIndexValue"] = indexValue
      trace["ioIndexRightHalf"] = indexValue // (2 ** 18)
    end

    if d["ioFunction"] = 4 | d["ioFunction"] = 6 | d["ioFunction"] = 7 then
      trace["ioCondition"] = ea

    destinationBefore = .nil
    if d["ioFunction"] = 1 | d["ioFunction"] = 5 then do
      /* Reading ordinary memory merely to build a trace would itself alter
       * the observable bus/memory access sequence.  The AC window can be
       * sampled without touching backing core, which preserves the historic
       * MTBOOT trace evidence. */
      if memory~sourceKind(ea) = "AC" then destinationBefore = memory~word(ea)
    end

    ioEvent = ioBus~execute(d["ioFunction"], d["device"], ea)
    trace["ioAction"] = ioEvent["action"]
    trace["ioDestination"] = ioEvent["destination"]
    trace["ioStatus"] = ioEvent["status"]
    trace["ioData"] = ioEvent["data"]
    trace["ioSource"] = ioEvent["source"]
    trace["ioTested"] = ioEvent["tested"]
    trace["ioSkip"] = ioEvent["skip"]
    if destinationBefore \= .nil then trace["destinationBefore"] = destinationBefore
    if ioEvent["writeValue"] \= .nil then trace["destinationAfter"] = ioEvent["writeValue"]

    /* Preserve device-specific evidence without putting the semantics back
     * into the CPU. */
    do key over ioEvent
      if trace~hasIndex(key) = 0 then trace[key] = ioEvent[key]
    end

    if ioEvent["skip"] then nextPc = (nextPc + 1) // (2 ** 18)
    pc = nextPc
    halted = 1
    instructionCount = instructionCount + 1
    trace["instructionCountAfter"] = instructionCount
    deviceEvents=ioBus~advance
    trace["deviceEvents"]=deviceEvents
    trace["acAfter"] = .nil
    trace["pcAfter"] = pc
    trace["halted"] = halted
    return trace
  end

  if d["opcode"] = 84 then do                       /* DMOVEM, 124 octal */
    ea=self~effectiveAddress18(d)
    first=self~accumulator(d["ac"])
    second=self~accumulator((d["ac"]+1)//16)
    memory~put(ea,first)
    memory~put((ea+1)//(2**18),second)
    trace["effectiveAddress"]=ea
    trace["operand"]=first
    trace["result"]=first
    trace["memoryWrite"]=1
    trace["doubleWordSecond"]=second
  end
  else   if d["opcode"] = 69 then do                       /* ADJSP, 105 octal */
    ea=self~effectiveAddress18(d)
    delta=ea
    if delta >= (2 ** 17) then delta=delta-(2 ** 18)
    oldP=self~accumulator(d["ac"])
    oldLeft=oldP % (2 ** 18)
    oldRight=oldP // (2 ** 18)
    newLeft=(oldLeft+delta) // (2 ** 18)
    newRight=(oldRight+delta) // (2 ** 18)
    newP=newLeft*(2 ** 18)+newRight
    self~setAccumulator(d["ac"],newP)

    trace["effectiveAddress"]=ea
    trace["operand"]=delta
    trace["adjustPointerBefore"]=oldP
    trace["adjustPointerAfter"]=newP
    trace["result"]=newP
  end
  else if d["opcode"] = 95 then do                       /* DPB, 137 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("DPB instruction indirect addressing outside bounded CPU")

    pointerEa=self~effectiveAddress18(d)
    pointerWord=memory~word(pointerEa)
    bytePosition=pointerWord % (2 ** 30)
    top12=pointerWord % (2 ** 24)
    byteSize=top12 // 64
    if byteSize < 0 | byteSize > 36 then
      raise syntax 40.900 array("DPB invalid byte size:" byteSize)

    byteAddress=self~bytePointerAddress(pointerWord)

    /* Capture AC before touching the destination: the resolved byte address
     * may alias the AC window, including the source accumulator itself. */
    sourceValue=self~accumulator(d["ac"])
    bitOffset=36-bytePosition-byteSize
    if byteSize=0 then do
      byteBits=""
      byteValue=0
    end
    else do
      sourceBits=.LROct~fromDecimal(sourceValue)~bits
      byteBits=sourceBits~substr(37-byteSize,byteSize)
      memory~writeBits(byteAddress,bitOffset,byteBits)
      byteValue=0
      do byteBit=1 to byteBits~length
        byteValue=byteValue*2+byteBits~substr(byteBit,1)
      end
    end

    trace["effectiveAddress"]=pointerEa
    trace["bytePointerBefore"]=pointerWord
    trace["bytePointerAfter"]=pointerWord
    trace["byteAddress"]=byteAddress
    trace["bytePosition"]=bytePosition
    trace["byteSize"]=byteSize
    trace["byteBitOffset"]=bitOffset
    trace["operand"]=sourceValue
    trace["byteValue"]=byteValue
    trace["result"]=sourceValue
    trace["memoryWrite"]=1
    nextPc=(pc+1) // (2 ** 18)
  end
  else if d["opcode"] = 94 then do                       /* IDPB, 136 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("IDPB instruction indirect addressing outside bounded CPU")

    pointerEa=self~effectiveAddress18(d)
    pointerWord=memory~word(pointerEa)
    advanced=self~incrementBytePointer(pointerWord)
    newPointer=advanced["word"]
    newPosition=advanced["position"]
    byteSize=advanced["size"]
    memory~put(pointerEa,newPointer)

    byteAddress=self~bytePointerAddress(newPointer)
    bitOffset=36-newPosition-byteSize
    sourceValue=self~accumulator(d["ac"])
    if byteSize=0 then do
      byteBits=""
      byteValue=0
    end
    else do
      sourceBits=.LROct~fromDecimal(sourceValue)~bits
      byteBits=sourceBits~substr(37-byteSize,byteSize)
      memory~writeBits(byteAddress,bitOffset,byteBits)
      byteValue=0
      do byteBit=1 to byteBits~length
        byteValue=byteValue*2+byteBits~substr(byteBit,1)
      end
    end

    trace["effectiveAddress"]=pointerEa
    trace["bytePointerBefore"]=pointerWord
    trace["bytePointerAfter"]=newPointer
    trace["byteAddress"]=byteAddress
    trace["bytePosition"]=newPosition
    trace["byteSize"]=byteSize
    trace["byteBitOffset"]=bitOffset
    trace["operand"]=sourceValue
    trace["byteValue"]=byteValue
    trace["result"]=sourceValue
    trace["memoryWrite"]=1
    nextPc=(pc+1) // (2 ** 18)
  end
  else if d["opcode"] = 93 then do                       /* LDB, 135 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("LDB instruction indirect addressing outside bounded CPU")

    pointerEa=self~effectiveAddress18(d)
    pointerWord=memory~word(pointerEa)
    bytePosition=pointerWord % (2 ** 30)
    top12=pointerWord % (2 ** 24)
    byteSize=top12 // 64
    if byteSize < 0 | byteSize > 36 then
      raise syntax 40.900 array("LDB invalid byte size:" byteSize)

    byteAddress=self~bytePointerAddress(pointerWord)
    bitOffset=36-bytePosition-byteSize
    if byteSize=0 then byteValue=0
    else do
      byteBits=memory~readBits(byteAddress,bitOffset,byteSize)
      byteValue=0
      do byteBit=1 to byteBits~length
        byteValue=byteValue*2+byteBits~substr(byteBit,1)
      end
    end
    self~setAccumulator(d["ac"],byteValue)

    trace["effectiveAddress"]=pointerEa
    trace["bytePointerBefore"]=pointerWord
    trace["bytePointerAfter"]=pointerWord
    trace["byteAddress"]=byteAddress
    trace["bytePosition"]=bytePosition
    trace["byteSize"]=byteSize
    trace["byteBitOffset"]=bitOffset
    trace["operand"]=byteValue
    trace["result"]=byteValue
  end
  else if d["opcode"] = 92 then do                       /* ILDB, 134 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("ILDB instruction indirect addressing outside bounded CPU")

    pointerEa=self~effectiveAddress18(d)
    pointerWord=memory~word(pointerEa)
    advanced=self~incrementBytePointer(pointerWord)
    newPointer=advanced["word"]
    newPosition=advanced["position"]
    byteSize=advanced["size"]
    memory~put(pointerEa,newPointer)

    byteAddress=self~bytePointerAddress(newPointer)
    bitOffset=36-newPosition-byteSize
    if byteSize=0 then byteValue=0
    else do
      byteBits=memory~readBits(byteAddress,bitOffset,byteSize)
      byteValue=0
      do byteBit=1 to byteBits~length
        byteValue=byteValue*2+byteBits~substr(byteBit,1)
      end
    end
    self~setAccumulator(d["ac"],byteValue)

    trace["effectiveAddress"]=pointerEa
    trace["bytePointerBefore"]=pointerWord
    trace["bytePointerAfter"]=newPointer
    trace["byteAddress"]=byteAddress
    trace["bytePosition"]=newPosition
    trace["byteSize"]=byteSize
    trace["byteBitOffset"]=bitOffset
    trace["operand"]=byteValue
    trace["result"]=byteValue
    trace["memoryWrite"]=1
    nextPc=(pc+1) // (2 ** 18)
  end
  else if d["opcode"] = 80 then do                       /* DMOVE, 120 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("DMOVE indirect addressing not implemented in bounded CPU")
    ea = self~effectiveAddress18(d)
    pairEa = (ea + 1) // (2 ** 18)
    pairAc = (d["ac"] + 1) // 16
    highWord = memory~word(ea)
    lowWord = memory~word(pairEa)
    self~setAccumulator(d["ac"], highWord)
    self~setAccumulator(pairAc, lowWord)
    trace["effectiveAddress"] = ea
    trace["operand"] = highWord
    trace["result"] = highWord
    trace["pairEffectiveAddress"] = pairEa
    trace["pairAc"] = pairAc
    trace["pairAfter"] = lowWord
  end
  else if d["opcode"] >= 128 & d["opcode"] <= 135 then do /* 200..207 MOVE family */
    ea = self~effectiveAddress18(d)
    moveKind = d["opcode"] - 128
    oldAc = self~accumulator(d["ac"])
    operand = .nil
    newValue = .nil
    memoryWrite = 0
    acWrite = 0

    select
      when moveKind = 0 then do                         /* MOVE */
        operand = memory~word(ea)
        newValue = operand
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when moveKind = 1 then do                         /* MOVEI */
        operand = ea
        newValue = ea
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when moveKind = 2 then do                         /* MOVEM */
        operand = oldAc
        newValue = oldAc
        memory~put(ea, newValue)
        memoryWrite = 1
      end
      when moveKind = 3 then do                         /* MOVES */
        operand = memory~word(ea)
        newValue = operand
        /* Reference semantics perform a real modify-cycle write even though
         * the word value is unchanged.  Preserve that state transition. */
        memory~put(ea, newValue)
        memoryWrite = 1
        if d["ac"] \= 0 then do
          self~setAccumulator(d["ac"], newValue)
          acWrite = 1
        end
      end
      when moveKind = 4 then do                         /* MOVS */
        operand = memory~word(ea)
        newValue = self~swapHalves36(operand)
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when moveKind = 5 then do                         /* MOVSI */
        newValue = self~swapHalves36(ea)
        /* Preserve the established MOVSI trace contract: operand is the
         * swapped immediate word actually presented to the destination AC. */
        operand = newValue
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when moveKind = 6 then do                         /* MOVSM */
        operand = oldAc
        newValue = self~swapHalves36(oldAc)
        memory~put(ea, newValue)
        memoryWrite = 1
      end
      when moveKind = 7 then do                         /* MOVSS */
        operand = memory~word(ea)
        newValue = self~swapHalves36(operand)
        memory~put(ea, newValue)
        memoryWrite = 1
        if d["ac"] \= 0 then do
          self~setAccumulator(d["ac"], newValue)
          acWrite = 1
        end
      end
    end

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["result"] = newValue
    trace["moveKind"] = moveKind
    trace["memoryWrite"] = memoryWrite
    trace["acWrite"] = acWrite
  end
  else if d["opcode"] = 144 then do                    /* IMUL, 220 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("IMUL indirect addressing outside bounded CPU")
    ea=self~effectiveAddress18(d)
    left=self~signed36(self~accumulator(d["ac"]))
    right=self~signed36(memory~word(ea))
    product=left*right
    value=product // (2 ** 36)
    if value<0 then value=value+(2 ** 36)
    self~setAccumulator(d["ac"],value)

    overflow=(product < -(2 ** 35)) | (product > (2 ** 35)-1)
    if overflow then ignored=self~applyMultiplyOverflow

    trace["effectiveAddress"]=ea
    trace["operand"]=right
    trace["result"]=value
    trace["multiplyProduct"]=product
    trace["overflow"]=overflow
  end
  else if d["opcode"] >= 160 & d["opcode"] <= 166 then do /* 240..246 shift/rotate family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    oldAc = self~accumulator(d["ac"])
    trace["effectiveAddress"] = ea
    trace["operand"] = oldAc
    trace["shiftCount"] = .nil
    trace["shiftDirection"] = .nil
    trace["pairAc"] = .nil
    trace["pairBefore"] = .nil
    trace["pairAfter"] = .nil
    trace["shiftOverflow"] = 0
    trace["branchTaken"] = 0

    if d["opcode"] = 163 then do                       /* JFFO */
      pairAc = (d["ac"] + 1) // 16
      leading = 0
      if oldAc \= 0 then do
        leading = self~leadingZeros36(oldAc)
        nextPc = ea
        trace["branchTaken"] = 1
      end
      self~setAccumulator(pairAc, leading)
      trace["pairAc"] = pairAc
      trace["pairAfter"] = leading
      trace["result"] = oldAc
      trace["jffoCount"] = leading
    end
    else do
      rotation = d["opcode"] = 161 | d["opcode"] = 165
      shift = self~shiftCount18(ea, rotation)
      count = shift["count"]
      rightShift = shift["right"]
      trace["shiftCount"] = count
      if rightShift then trace["shiftDirection"] = "RIGHT"
      else trace["shiftDirection"] = "LEFT"

      select
        when d["opcode"] = 160 then do                 /* ASH */
          shifted = self~arithmeticShift36(oldAc, count, rightShift)
          self~setAccumulator(d["ac"], shifted["value"])
          if shifted["overflow"] then self~applyShiftOverflow
          trace["result"] = shifted["value"]
          trace["shiftOverflow"] = shifted["overflow"]
        end

        when d["opcode"] = 161 then do                 /* ROT */
          newValue = self~rotate36(oldAc, count, rightShift)
          self~setAccumulator(d["ac"], newValue)
          trace["result"] = newValue
        end

        when d["opcode"] = 162 then do                 /* LSH */
          newValue = self~logicalShift36(oldAc, count, rightShift)
          self~setAccumulator(d["ac"], newValue)
          trace["result"] = newValue
        end

        when d["opcode"] = 164 | d["opcode"] = 165 | d["opcode"] = 166 then do
          pairAc = (d["ac"] + 1) // 16
          pairBefore = self~accumulator(pairAc)
          trace["pairAc"] = pairAc
          trace["pairBefore"] = pairBefore

          select
            when d["opcode"] = 164 then do             /* ASHC */
              shifted = self~arithmeticShiftCombined(oldAc, pairBefore, count, rightShift)
              newValue = shifted["high"]
              pairAfter = shifted["low"]
              if shifted["overflow"] then self~applyShiftOverflow
              trace["shiftOverflow"] = shifted["overflow"]
            end
            when d["opcode"] = 165 then do             /* ROTC */
              shifted = self~rotateCombined(oldAc, pairBefore, count, rightShift)
              newValue = shifted["high"]
              pairAfter = shifted["low"]
            end
            otherwise do                                /* LSHC */
              shifted = self~logicalShiftCombined(oldAc, pairBefore, count, rightShift)
              newValue = shifted["high"]
              pairAfter = shifted["low"]
            end
          end

          self~setAccumulator(d["ac"], newValue)
          self~setAccumulator(pairAc, pairAfter)
          trace["result"] = newValue
          trace["pairAfter"] = pairAfter
        end
      end
    end
  end
  else if d["opcode"] = 170 | d["opcode"] = 171 then do /* AOBJP/AOBJN, 252/253 octal */
    /* KL10 increments the two 18-bit halves independently.  This differs
     * from the KA10 whole-word +1000001(octal) implementation at RH rollover:
     * a carry out of the right half must not add an extra one to the left.
     * Branch testing is on the sign bit of the resulting 36-bit AC. */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    oldAc = self~accumulator(d["ac"])
    halfMod = 2 ** 18
    left = (oldAc % halfMod) // halfMod
    right = oldAc // halfMod
    left = (left + 1) // halfMod
    right = (right + 1) // halfMod
    newValue = left * halfMod + right
    self~setAccumulator(d["ac"], newValue)

    negative = newValue >= (2 ** 35)
    if d["opcode"] = 170 then jump = \negative
    else jump = negative
    if jump then nextPc = ea

    trace["effectiveAddress"] = ea
    trace["operand"] = oldAc
    trace["result"] = newValue
    trace["branchTaken"] = jump
    trace["aobjLeftAfter"] = left
    trace["aobjRightAfter"] = right
  end
  else if d["opcode"] = 173 then do                    /* JFCL, 255 octal */
    if d["ac"] \= 0 | d["indirect"] \= 0 | d["index"] \= 0 | d["address"] \= 0 then
      raise syntax 40.900 array("JFCL flag-selection semantics outside bounded CPU")
    trace["effectiveAddress"]=0
    trace["operand"]=flags
    trace["result"]=flags
  end
  else if d["opcode"] = 174 then do                    /* XCT/PXCT, 256 octal */
    /* XCT executes C(E) while normal sequencing remains relative to this XCT.
     * In executive mode a nonzero AC field is PXCT.  The current bounded path
     * needs the architecturally important PXCT 4 form used by MTBOOT:
     * effective-address calculation is current-context, while the executed
     * instruction's main data reference is previous-context.  DEC documents
     * PXCT 4,[MOVEM A,E] as the executive-AC to previous-context-memory form.
     *
     * For an E in 0..17, previous context means the Previous AC Block (PAB),
     * not the current fast-memory block.  Ordinary previous-context memory
     * references remain an explicit boundary until paging/section translation
     * is modeled. */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("XCT indirect addressing not implemented in bounded CPU")

    xctEa = self~effectiveAddress18(d)
    executedWord = memory~word(xctEa)
    executed = self~decode(executedWord)
    trace["effectiveAddress"] = xctEa
    trace["xctInstruction"] = executedWord
    trace["xctMnemonic"] = executed["mnemonic"]
    trace["xctAcField"] = d["ac"]

    if d["ac"] = 4 then do
      if executed["opcode"] \= 130 then
        raise syntax 40.900 array("PXCT 4 executed opcode outside bounded model:" executed["mnemonic"])
      if executed["indirect"] \= 0 then
        raise syntax 40.900 array("PXCT 4 MOVEM indirect addressing outside bounded model")

      dataEa = self~effectiveAddress18(executed)
      sourceValue = self~accumulator(executed["ac"])
      trace["xctDataEffectiveAddress"] = dataEa
      trace["xctSourceAc"] = executed["ac"]
      trace["operand"] = sourceValue
      trace["result"] = sourceValue
      trace["pxctPreviousAcBlock"] = self~pag~previousAcBlock

      if dataEa < 16 then do
        beforePrevious = self~previousAccumulator(dataEa)
        self~setPreviousAccumulator(dataEa, sourceValue)
        trace["destinationBefore"] = beforePrevious
        trace["destinationAfter"] = sourceValue
        trace["xctReferenceKind"] = "PREVIOUS_AC"
      end
      else
        raise syntax 40.900 array("PXCT 4 previous-context memory translation outside bounded model:" dataEa)
    end
    else if d["ac"] = 0 then do
      /* Ordinary current-context XCT. The first historical use after paging
       * executes a dynamically loaded I/O instruction. Route that through the
       * same bus path as a directly fetched I/O instruction; XCT itself is the
       * single architectural instruction and owns the resulting skip. */
      if executed["format"] = "IO" then do
        if executed["indirect"] \= 0 then
          raise syntax 40.900 array("ordinary XCT indirect I/O addressing outside bounded model")

        dataEa = self~effectiveAddress18(executed)
        trace["xctDataEffectiveAddress"] = dataEa
        trace["xctReferenceKind"] = "CURRENT_IO"
        trace["xctDevice"] = executed["device"]
        trace["xctDeviceName"] = executed["deviceName"]
        trace["xctIoFunction"] = executed["ioFunction"]

        ioEvent = ioBus~execute(executed["ioFunction"], executed["device"], dataEa)
        trace["xctIoAction"] = ioEvent["action"]
        trace["xctIoStatus"] = ioEvent["status"]
        trace["xctIoTested"] = ioEvent["tested"]
        trace["xctIoSkip"] = ioEvent["skip"]
        if ioEvent["skip"] then nextPc = (nextPc + 1) // (2 ** 18)
      end
      else if executed["opcode"]>=384 & executed["opcode"]<=447 then do
        if executed["indirect"] \= 0 then
          raise syntax 40.900 array("ordinary XCT indirect test-family instruction outside bounded model")
        dataEa=self~effectiveAddress18(executed)
        offset=executed["opcode"]-384
        testOperation=offset % 16
        within=offset // 16
        testLeft=within // 2
        if within>=8 then testMemory=1
        else testMemory=0
        condition=(within // 8)-testLeft

        if testMemory then operand=memory~word(dataEa)
        else operand=dataEa
        if testLeft then operand=self~swapHalves36(operand)

        oldAc=self~accumulator(executed["ac"])
        tested=self~bitAnd36(oldAc,operand)
        select
          when condition=0 then xctSkip=0
          when condition=2 then xctSkip=tested=0
          when condition=4 then xctSkip=1
          when condition=6 then xctSkip=tested\=0
        end
        select
          when testOperation=0 then newValue=oldAc
          when testOperation=1 then newValue=self~bitAnd36(oldAc,self~bitNot36(operand))
          when testOperation=2 then newValue=self~bitXor36(oldAc,operand)
          when testOperation=3 then newValue=self~bitOr36(oldAc,operand)
        end
        if testOperation\=0 then self~setAccumulator(executed["ac"],newValue)
        if xctSkip then nextPc=(nextPc+1)//(2**18)

        trace["xctReferenceKind"]="CURRENT_TEST"
        trace["xctDataEffectiveAddress"]=dataEa
        trace["xctTestValue"]=tested
        trace["xctTestSkip"]=xctSkip
        trace["xctTestOperation"]=testOperation
        trace["operand"]=operand
        trace["result"]=newValue
      end
      else if executed["opcode"]=181 then do          /* XCT of JSP */
        if executed["indirect"] \= 0 then
          raise syntax 40.900 array("ordinary XCT executed indirect JSP outside bounded model")
        dataEa=self~effectiveAddress18(executed)
        savedWord=(flags // (2**18))*(2**18)+nextPc
        self~setAccumulator(executed["ac"],savedWord)
        trace["xctReferenceKind"]="CURRENT_JSP"
        trace["xctDataEffectiveAddress"]=dataEa
        trace["xctSavedWord"]=savedWord
        nextPc=dataEa
      end
      else if executed["opcode"]=173 & executed["ac"]=0 & executed["indirect"]=0 & -
              executed["index"]=0 & executed["address"]=0 then do
        trace["xctReferenceKind"]="CURRENT_JFCL_NOP"
        trace["operand"]=flags
        trace["result"]=flags
      end
      else
        raise syntax 40.900 array("ordinary XCT executed non-I/O opcode outside bounded model:" executed["mnemonic"])
    end
    else
      raise syntax 40.900 array("PXCT AC field outside bounded model:" d["ac"])
  end
  else if d["opcode"] = 168 then do                    /* EXCH, 250 octal */
    /* Exchange the selected accumulator with the word at effective address.
     * Effective-address calculation is completed before either destination is
     * modified.  Both operand reads are likewise captured before the writes so
     * AC-window aliases behave as true simultaneous exchange semantics rather
     * than as two dependent MOVE operations. */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("EXCH indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    oldAc = self~accumulator(d["ac"])
    operand = memory~word(ea)

    memory~put(ea, oldAc)
    self~setAccumulator(d["ac"], operand)

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["destinationBefore"] = operand
    trace["result"] = operand
    trace["memoryResult"] = oldAc
    trace["memoryWrite"] = 1
    trace["acWrite"] = 1
  end
  else if d["opcode"] = 169 then do                    /* BLT, 251 octal */
    /* KL10 section-zero BLT.  AC contains source,,destination and E is the
     * inclusive final destination.  The hardware performs a forward sequence
     * of ordinary memory cycles, so every transfer goes through the live
     * KL10AddressSpace rather than through a bulk snapshot.  This is important
     * for AC-window destinations, overlapping copies, and self-modifying data.
     *
     * Cornwell precomputes the architectural final AC before entering the
     * transfer loop.  Preserve that ordering: a BLT which subsequently writes
     * its own accumulator address can overwrite that precomputed AC exactly as
     * a real fast-memory destination would. */
    /* Section-zero BLT uses the same indirect/indexed EA chain as other
     * memory-reference instructions.  The resident monitor's first indirect
     * BLT resolves 002624 -> 334507. */
    ea = self~effectiveAddress18(d)
    halfMod = 2 ** 18
    pointerBefore = self~accumulator(d["ac"])
    sourceAddress = (pointerBefore % halfMod) // halfMod
    destinationAddress = pointerBefore // halfMod

    /* Reference final-pointer computation is based on the 18-bit difference
     * E-destination, then AOB of that final transferred pair.  For the normal
     * case destination<=E this is simply one past the last copied pair. */
    delta = (ea - destinationAddress) // halfMod
    finalSource = (sourceAddress + delta + 1) // halfMod
    finalDestination = (destinationAddress + delta + 1) // halfMod
    finalPointer = finalSource * halfMod + finalDestination
    self~setAccumulator(d["ac"], finalPointer)

    if destinationAddress <= ea then transferCount = ea - destinationAddress + 1
    else transferCount = 1

    firstWord = .nil
    lastWord = .nil

    /* A resident-monitor memory-sizing BLT can intentionally span only
     * nonexistent physical memory.  Walking thousands of words through the
     * page tables is semantically redundant: every read is zero and every
     * write is discarded.  Collapse only when every source and destination
     * page proves NXM without side effects, then perform one real translation
     * touch per participating page so CST aging/MODIFIED state is identical
     * to ordinary repeated references. */
    fastNxm=0
    if transferCount>1 then do
      sourceEnd=sourceAddress+transferCount-1
      destinationEnd=destinationAddress+transferCount-1
      if sourceEnd<halfMod & destinationEnd<halfMod then do
        if self~rangeAllNxm(sourceAddress,sourceEnd,0) & -
           self~rangeAllNxm(destinationAddress,destinationEnd,1) then do
          ignored=self~touchRangePages(sourceAddress,sourceEnd,0)
          ignored=self~touchRangePages(destinationAddress,destinationEnd,1)
          ignored=apr~signalFlag(1024) /* 002000 octal NXM */
          firstWord=0
          lastWord=0
          fastNxm=1
        end
      end
    end

    if \fastNxm then do
      currentSource = sourceAddress
      currentDestination = destinationAddress
      do transferIndex = 1 to transferCount
        transferWord = memory~word(currentSource)
        if transferIndex = 1 then firstWord = transferWord
        lastWord = transferWord
        memory~put(currentDestination, transferWord)
        currentSource = (currentSource + 1) // halfMod
        currentDestination = (currentDestination + 1) // halfMod
      end
    end

    trace["effectiveAddress"] = ea
    trace["operand"] = pointerBefore
    trace["bltPointerBefore"] = pointerBefore
    trace["bltSourceStart"] = sourceAddress
    trace["bltDestinationStart"] = destinationAddress
    trace["bltEndDestination"] = ea
    trace["bltTransferCount"] = transferCount
    trace["bltFirstWord"] = firstWord
    trace["bltLastWord"] = lastWord
    trace["bltFinalPointer"] = finalPointer
    trace["result"] = finalPointer
    trace["memoryWrite"] = 1
  end
  else if d["opcode"] >= 256 & d["opcode"] <= 319 then do /* 400..477 Boolean family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")
    ea = self~effectiveAddress18(d)
    form = d["opcode"] // 4
    group = (d["opcode"] - 256) % 4
    oldAc = self~accumulator(d["ac"])

    /* SETZ, SETA, SETCA, SETO depend only on constants/AC.  Every other
     * memory form reads the live addressed word; immediate form uses E. */
    needsOperand = 1
    if group = 0 | group = 5 | group = 10 | group = 15 then needsOperand = 0
    operand = .nil
    if form = 1 then operand = ea
    else if needsOperand then operand = memory~word(ea)

    newValue = self~boolean36(group, oldAc, operand)

    /* M and B forms write memory.  SETMB is the one useful no-write
     * identity: memory already is M, matching the reference implementation. */
    if form = 2 then memory~put(ea, newValue)
    if form = 3 & group \= 3 then memory~put(ea, newValue)
    if form = 0 | form = 1 | form = 3 then self~setAccumulator(d["ac"], newValue)

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["result"] = newValue
    trace["booleanGroup"] = group
    trace["booleanForm"] = form
  end
  else if d["opcode"] >= 320 & d["opcode"] <= 383 then do /* 500..577 halfword family */
    ea = self~effectiveAddress18(d)
    form = d["opcode"] // 4
    group = (d["opcode"] - 320) % 4
    oldAc = self~accumulator(d["ac"])
    operand = .nil
    destinationBefore = .nil
    memoryWrite = 0
    acWrite = 0

    /* The halfword block is regular in two dimensions:
     *   group 0..7  -> write the destination LEFT half
     *   group 8..15 -> write the destination RIGHT half
     * and each pair selects source left/right.  The pair quartets choose
     * preserve / zero / ones / sign-extension for the untouched half.
     *
     * Forms follow the architectural instruction suffix:
     *   no suffix: memory source -> AC
     *   I:         section-zero E source -> AC
     *   M:         AC source -> memory
     *   S:         memory source -> memory and (unless AC=0) AC
     *
     * Only the preserve-M forms require the old memory word.  Every S form is
     * a real modify cycle and writes through KL10AddressSpace even when the
     * resulting word is identical to the source word. */
    mode = (group // 8) % 2

    select
      when form = 0 then do
        operand = memory~word(ea)
        destinationBefore = oldAc
        newValue = self~halfword36(group, operand, destinationBefore)
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when form = 1 then do
        operand = ea
        destinationBefore = oldAc
        newValue = self~halfword36(group, operand, destinationBefore)
        self~setAccumulator(d["ac"], newValue)
        acWrite = 1
      end
      when form = 2 then do
        operand = oldAc
        if mode = 0 then destinationBefore = memory~word(ea)
        else destinationBefore = 0
        newValue = self~halfword36(group, operand, destinationBefore)
        memory~put(ea, newValue)
        memoryWrite = 1
      end
      otherwise do
        operand = memory~word(ea)
        destinationBefore = operand
        newValue = self~halfword36(group, operand, destinationBefore)
        memory~put(ea, newValue)
        memoryWrite = 1
        if d["ac"] \= 0 then do
          self~setAccumulator(d["ac"], newValue)
          acWrite = 1
        end
      end
    end

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["destinationBefore"] = destinationBefore
    trace["result"] = newValue
    trace["halfwordGroup"] = group
    trace["halfwordForm"] = form
    trace["halfwordMode"] = mode
    trace["memoryWrite"] = memoryWrite
    trace["acWrite"] = acWrite
  end
  else if d["opcode"] >= 384 & d["opcode"] <= 447 then do /* 600..677 Test family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")
    ea = self~effectiveAddress18(d)
    offset = d["opcode"] - 384
    testOperation = offset % 16
    within = offset // 16
    testLeft = within // 2
    if within >= 8 then testMemory = 1
    else testMemory = 0
    condition = (within // 8) - testLeft

    if testMemory then operand = memory~word(ea)
    else operand = ea
    if testLeft then operand = self~swapHalves36(operand)

    oldAc = self~accumulator(d["ac"])
    tested = self~bitAnd36(oldAc, operand)
    select
      when condition = 0 then skip = 0
      when condition = 2 then skip = tested = 0
      when condition = 4 then skip = 1
      when condition = 6 then skip = tested \= 0
    end

    select
      when testOperation = 0 then newValue = oldAc
      when testOperation = 1 then newValue = self~bitAnd36(oldAc, self~bitNot36(operand))
      when testOperation = 2 then newValue = self~bitXor36(oldAc, operand)
      when testOperation = 3 then newValue = self~bitOr36(oldAc, operand)
    end
    if testOperation \= 0 then self~setAccumulator(d["ac"], newValue)
    if skip then nextPc = (nextPc + 1) // (2 ** 18)

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["testValue"] = tested
    trace["testSkip"] = skip
    trace["testOperation"] = testOperation
    trace["result"] = newValue
  end
  else if d["opcode"] >= 136 & d["opcode"] <= 139 then do /* 210..213 MOVN family */
    ea=self~effectiveAddress18(d)
    form=d["opcode"]-136
    oldAc=self~accumulator(d["ac"])
    if form=1 then source=ea
    else if form=2 then source=oldAc
    else source=memory~word(ea)

    alu=self~arithmetic36("SUB",0,source)
    newValue=alu["value"]

    if form=0 | form=1 then self~setAccumulator(d["ac"],newValue)
    else if form=2 then memory~put(ea,newValue)
    else do
      memory~put(ea,newValue)
      if d["ac"] \= 0 then self~setAccumulator(d["ac"],newValue)
    end
    self~applyArithmeticFlags(alu)

    trace["effectiveAddress"]=ea
    trace["operand"]=source
    trace["result"]=newValue
    trace["memoryWrite"]=form>=2
    trace["acWrite"]=form<2 | (form=3 & d["ac"]\=0)
    trace["carry1"]=alu["carry1"]
    trace["carry0"]=alu["carry0"]
    trace["overflow"]=alu["overflow"]
  end
  else if d["opcode"] >= 140 & d["opcode"] <= 143 then do /* 214..217 MOVM family */
    ea=self~effectiveAddress18(d)
    form=d["opcode"]-140
    oldAc=self~accumulator(d["ac"])

    if form=1 then source=ea                     /* MOVMI == MOVEI */
    else if form=2 then source=oldAc             /* MOVMM source is AC */
    else source=memory~word(ea)                  /* MOVM/MOVMS source is M */

    signBit=2**35
    if source>=signBit then do
      if source=signBit then do
        /* |-2^35| is unrepresentable: value remains 400000,,000000 and the
         * PDP-10 sets Trap 1, Overflow, and Carry 1. */
        newValue=source
        flags=(.LROct~fromDecimal(flags) | .LROct~fromDecimal(self~octToDecCpu("012004")))~decimal
      end
      else newValue=(2**36-source)//(2**36)
    end
    else newValue=source

    if form=0 | form=1 then self~setAccumulator(d["ac"],newValue)
    else if form=2 then memory~put(ea,newValue)
    else do
      memory~put(ea,newValue)
      if d["ac"]\=0 then self~setAccumulator(d["ac"],newValue)
    end

    trace["effectiveAddress"]=ea
    trace["operand"]=source
    trace["result"]=newValue
    trace["memoryWrite"]=form>=2
    trace["acWrite"]=form<2 | (form=3 & d["ac"]\=0)
  end
  else if d["opcode"] >= 192 & d["opcode"] <= 207 then do /* 300..317 CAI/CAM */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    leftValue = self~accumulator(d["ac"])
    if d["opcode"] < 200 then operand = ea
    else operand = memory~word(ea)

    leftSigned = leftValue
    if leftSigned >= (2 ** 35) then leftSigned = leftSigned - (2 ** 36)
    rightSigned = operand
    if rightSigned >= (2 ** 35) then rightSigned = rightSigned - (2 ** 36)

    condition = d["opcode"] // 8
    select
      when condition = 0 then skip = 0
      when condition = 1 then skip = leftSigned < rightSigned
      when condition = 2 then skip = leftSigned = rightSigned
      when condition = 3 then skip = leftSigned <= rightSigned
      when condition = 4 then skip = 1
      when condition = 5 then skip = leftSigned >= rightSigned
      when condition = 6 then skip = leftSigned \= rightSigned
      otherwise skip = leftSigned > rightSigned
    end
    if skip then nextPc = (nextPc + 1) // (2 ** 18)

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["compareLeft"] = leftValue
    trace["compareRight"] = operand
    trace["compareCondition"] = condition
    trace["skipTaken"] = skip
    trace["result"] = leftValue
  end
  else if d["opcode"] >= 208 & d["opcode"] <= 215 then do /* 320..327 JUMP family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")
    ea=self~effectiveAddress18(d)
    value=self~accumulator(d["ac"])
    condition=d["opcode"]-208
    negative=value >= (2 ** 35)
    zero=value=0
    select
      when condition=0 then jump=0
      when condition=1 then jump=negative
      when condition=2 then jump=zero
      when condition=3 then jump=negative | zero
      when condition=4 then jump=1
      when condition=5 then jump=\negative
      when condition=6 then jump=\zero
      otherwise jump=\negative & \zero
    end
    if jump then nextPc=ea
    trace["effectiveAddress"]=ea
    trace["operand"]=value
    trace["result"]=value
    trace["branchCondition"]=condition
    trace["branchTaken"]=jump
  end
  else if d["opcode"] >= 216 & d["opcode"] <= 223 then do /* 330..337 SKIP family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")
    ea = self~effectiveAddress18(d)
    probe = memory~probeWord(ea)
    condition = d["opcode"] - 216
    if \probe["ok"] then do
      /* NXM aborts the operand cycle. Do not fabricate a zero operand and do
       * not evaluate the SKIP condition; the sequential PC already represents
       * completion of the instruction fetch/abort cycle. */
      operand = .nil
      skip = 0
      trace["nxm"] = 1
      trace["physicalAddress"] = probe["physical"]
    end
    else do
      operand = probe["value"]
      negative = operand >= (2 ** 35)
      zero = operand = 0
      select
        when condition = 0 then skip = 0
        when condition = 1 then skip = negative
        when condition = 2 then skip = zero
        when condition = 3 then skip = negative | zero
        when condition = 4 then skip = 1
        when condition = 5 then skip = \negative
        when condition = 6 then skip = \zero
        otherwise skip = \negative & \zero
      end
      if d["ac"] \= 0 then self~setAccumulator(d["ac"], operand)
      if skip then nextPc = (nextPc + 1) // (2 ** 18)
      trace["nxm"] = 0
    end
    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["result"] = operand
    trace["skipCondition"] = condition
    trace["skipTaken"] = skip
  end
  else if d["opcode"] >= 240 & d["opcode"] <= 247 then do /* 360..367 SOJ family */
    /* Subtract one from AC, then test the updated signed 36-bit value.  If the
     * selected condition is true, branch to the resolved effective address.
     * SOJ has no memory operand; indexed E therefore affects only the branch
     * target and must not cause an operand read. */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    oldAc = self~accumulator(d["ac"])
    alu = self~arithmetic36("SUB", oldAc, 1)
    newValue = alu["value"]
    self~setAccumulator(d["ac"], newValue)
    self~applyArithmeticFlags(alu)

    condition = d["opcode"] - 240
    negative = newValue >= (2 ** 35)
    zero = newValue = 0
    select
      when condition = 0 then jump = 0
      when condition = 1 then jump = negative
      when condition = 2 then jump = zero
      when condition = 3 then jump = negative | zero
      when condition = 4 then jump = 1
      when condition = 5 then jump = \negative
      when condition = 6 then jump = \zero
      otherwise jump = \negative & \zero
    end
    if jump then nextPc = ea

    trace["effectiveAddress"] = ea
    trace["operand"] = 1
    trace["result"] = newValue
    trace["branchCondition"] = condition
    trace["branchTaken"] = jump
    trace["carry1"] = alu["carry1"]
    trace["carry0"] = alu["carry0"]
    trace["overflow"] = alu["overflow"]
  end
  else if d["opcode"] >= 224 & d["opcode"] <= 231 then do /* 340..347 AOJ family */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    oldValue = self~accumulator(d["ac"])
    alu = self~arithmetic36("ADD", oldValue, 1)
    newValue = alu["value"]
    self~setAccumulator(d["ac"], newValue)
    self~applyArithmeticFlags(alu)

    condition = d["opcode"] - 224
    negative = newValue >= (2 ** 35)
    zero = newValue = 0
    select
      when condition = 0 then jump = 0
      when condition = 1 then jump = negative
      when condition = 2 then jump = zero
      when condition = 3 then jump = negative | zero
      when condition = 4 then jump = 1
      when condition = 5 then jump = \negative
      when condition = 6 then jump = \zero
      otherwise jump = \negative & \zero
    end
    if jump then nextPc = ea

    trace["effectiveAddress"] = ea
    trace["operand"] = 1
    trace["result"] = newValue
    trace["branchCondition"] = condition
    trace["branchTaken"] = jump
    trace["carry1"] = alu["carry1"]
    trace["carry0"] = alu["carry0"]
    trace["overflow"] = alu["overflow"]
  end
  else if d["opcode"] >= 232 & d["opcode"] <= 239 then do /* 350..357 AOS family */
    /* Add one to the word at E, store the result back at E, and optionally
     * load the same result into a nonzero AC.  The low three opcode bits use
     * the same signed/zero condition ordering as SKIP.  All memory cycles go
     * through KL10AddressSpace so E in 0..17(octal) is live fast memory; this
     * is exactly what MTBOOT requires for AOS 0,11 and AOS 0,12. */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array(d["mnemonic"] "indirect addressing not implemented in bounded CPU")

    ea = self~effectiveAddress18(d)
    operand = memory~word(ea)
    alu = self~arithmetic36("ADD", operand, 1)
    newValue = alu["value"]
    memory~put(ea, newValue)
    if d["ac"] \= 0 then self~setAccumulator(d["ac"], newValue)
    self~applyArithmeticFlags(alu)

    condition = d["opcode"] - 232
    negative = newValue >= (2 ** 35)
    zero = newValue = 0
    select
      when condition = 0 then skip = 0
      when condition = 1 then skip = negative
      when condition = 2 then skip = zero
      when condition = 3 then skip = negative | zero
      when condition = 4 then skip = 1
      when condition = 5 then skip = \negative
      when condition = 6 then skip = \zero
      otherwise skip = \negative & \zero
    end
    if skip then nextPc = (nextPc + 1) // (2 ** 18)

    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["destinationBefore"] = operand
    trace["result"] = newValue
    trace["memoryResult"] = newValue
    trace["memoryWrite"] = 1
    trace["acWrite"] = d["ac"] \= 0
    trace["skipCondition"] = condition
    trace["skipTaken"] = skip
    trace["carry1"] = alu["carry1"]
    trace["carry0"] = alu["carry0"]
    trace["overflow"] = alu["overflow"]
  end
  else if d["opcode"] = 175 then do             /* MAP, 257 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("MAP indirect addressing outside bounded CPU")
    ea=self~effectiveAddress18(d)
    beforeTranslation=memory~lastTranslation
    mapInfo=memory~mapWord(ea)
    mapValue=mapInfo["word"]
    self~setAccumulator(d["ac"],mapValue)

    trace["effectiveAddress"]=ea
    trace["operand"]=.nil
    trace["result"]=mapValue
    trace["mapPhysicalAddress"]=mapInfo["physical"]
    trace["mapAccessBits"]=mapInfo["accessBits"]
    trace["mapTranslation"]=mapInfo["translation"]
  end
  else if d["opcode"] = 176 then do             /* PUSHJ, 260 octal */
    ea=self~effectiveAddress18(d)
    oldP=self~accumulator(d["ac"])
    oldLeft=oldP % (2 ** 18)
    oldRight=oldP // (2 ** 18)
    newLeft=(oldLeft+1) // (2 ** 18)
    newRight=(oldRight+1) // (2 ** 18)
    newP=newLeft*(2 ** 18)+newRight
    self~setAccumulator(d["ac"],newP)

    savedWord=(flags // (2 ** 18))*(2 ** 18)+nextPc
    memory~put(newRight,savedWord)
    nextPc=ea

    trace["effectiveAddress"]=ea
    trace["pushPointerBefore"]=oldP
    trace["pushPointerAfter"]=newP
    trace["pushAddress"]=newRight
    trace["savedWord"]=savedWord
    trace["memoryWrite"]=1
    trace["result"]=savedWord
  end
  else if d["opcode"] = 177 then do             /* PUSH, 261 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("PUSH indirect addressing not implemented in bounded CPU")
    ea=self~effectiveAddress18(d)
    operand=memory~word(ea)
    oldP=self~accumulator(d["ac"])
    oldLeft=oldP % (2 ** 18)
    oldRight=oldP // (2 ** 18)
    newLeft=(oldLeft+1) // (2 ** 18)
    newRight=(oldRight+1) // (2 ** 18)
    newP=newLeft*(2 ** 18)+newRight
    self~setAccumulator(d["ac"],newP)
    memory~put(newRight,operand)

    trace["effectiveAddress"]=ea
    trace["operand"]=operand
    trace["pushPointerBefore"]=oldP
    trace["pushPointerAfter"]=newP
    trace["pushAddress"]=newRight
    trace["memoryWrite"]=1
    trace["result"]=operand
  end
  else if d["opcode"] = 178 then do             /* POP, 262 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("POP indirect addressing not implemented in bounded CPU")
    ea=self~effectiveAddress18(d)
    oldP=self~accumulator(d["ac"])
    oldLeft=oldP % (2 ** 18)
    oldRight=oldP // (2 ** 18)
    operand=memory~word(oldRight)
    memory~put(ea,operand)

    newLeft=(oldLeft-1) // (2 ** 18)
    newRight=(oldRight-1) // (2 ** 18)
    newP=newLeft*(2 ** 18)+newRight
    self~setAccumulator(d["ac"],newP)

    trace["effectiveAddress"]=ea
    trace["operand"]=operand
    trace["popPointerBefore"]=oldP
    trace["popPointerAfter"]=newP
    trace["popAddress"]=oldRight
    trace["memoryWrite"]=1
    trace["result"]=operand
  end
  else if d["opcode"] = 179 then do             /* POPJ, 263 octal */
    if d["indirect"] \= 0 then
      raise syntax 40.900 array("POPJ indirect addressing not implemented in bounded CPU")
    oldP=self~accumulator(d["ac"])
    oldLeft=oldP % (2 ** 18)
    oldRight=oldP // (2 ** 18)
    returnWord=memory~word(oldRight)
    returnPc=returnWord // (2 ** 18)
    newLeft=(oldLeft-1) // (2 ** 18)
    newRight=(oldRight-1) // (2 ** 18)
    newP=newLeft*(2 ** 18)+newRight
    self~setAccumulator(d["ac"],newP)
    nextPc=returnPc

    trace["effectiveAddress"]=d["address"]
    trace["popPointerBefore"]=oldP
    trace["popPointerAfter"]=newP
    trace["popAddress"]=oldRight
    trace["savedWord"]=returnWord
    trace["returnPc"]=returnPc
    trace["operand"]=returnWord
    trace["result"]=newP
  end
  else if d["opcode"] = 180 then do             /* JSR, 264 octal */
    /* Save FLAGS,,PC+1 at E, then enter the routine at E+1. */
    ea=self~effectiveAddress18(d)
    savedWord=(flags // (2**18))*(2**18)+nextPc
    memory~put(ea,savedWord)
    nextPc=(ea+1)//(2**18)

    trace["effectiveAddress"]=ea
    trace["savedWord"]=savedWord
    trace["memoryWrite"]=1
    trace["result"]=savedWord
  end
  else if d["opcode"] >= 184 & d["opcode"] <= 191 then do /* 270..277 ADD/SUB family */
    ea = self~effectiveAddress18(d)
    form = d["opcode"] // 4
    oldAc = self~accumulator(d["ac"])

    if form = 1 then operand = ea                    /* immediate */
    else operand = memory~word(ea)                   /* memory source/modify */

    if d["opcode"] < 188 then arithmeticKind = "ADD"
    else arithmeticKind = "SUB"
    alu = self~arithmetic36(arithmeticKind, oldAc, operand)
    newValue = alu["value"]

    /* The low two opcode bits select destination in the canonical PDP-10
     * family: 0 memory source -> AC, 1 immediate -> AC, 2 memory only,
     * 3 both memory and AC.  Memory writes go through KL10AddressSpace so
     * AC-window aliases remain real machine state. */
    if form = 2 | form = 3 then memory~put(ea, newValue)
    if form \= 2 then self~setAccumulator(d["ac"], newValue)

    self~applyArithmeticFlags(alu)
    trace["effectiveAddress"] = ea
    trace["operand"] = operand
    trace["result"] = newValue
    trace["arithmeticKind"] = arithmeticKind
    trace["arithmeticForm"] = form
    trace["carry1"] = alu["carry1"]
    trace["carry0"] = alu["carry0"]
    trace["overflow"] = alu["overflow"]
  end
  else select
    when d["opcode"] = 220 then do                    /* SKIPA */
      if d["indirect"] \= 0 then
        raise syntax 40.900 array("SKIPA indirect addressing not implemented in bounded CPU")
      if d["index"] \= 0 then
        raise syntax 40.900 array("SKIPA indexed addressing not implemented in bounded CPU")
      ea = d["address"]
      operand = memory~word(ea)
      if d["ac"] \= 0 then self~setAccumulator(d["ac"], operand)
      trace["effectiveAddress"] = ea
      trace["operand"] = operand
      nextPc = (nextPc + 1) // (2 ** 18)
    end
    when d["opcode"] = 181 then do                    /* JSP, 265 octal */
      /* v0.12 admits only the direct, non-indexed form exercised by MTBOOT.
       * In the current bounded bootstrap state FLAGS is explicitly zero.
       * The KL10 JSP save word is FLAGS in the left portion plus PC+1 in RH;
       * refusing non-zero FLAGS avoids inventing unmodeled flag semantics. */
      if d["indirect"] \= 0 then
        raise syntax 40.900 array("JSP indirect addressing not implemented in bounded CPU")
      if d["index"] \= 0 then
        raise syntax 40.900 array("JSP indexed addressing not implemented in bounded CPU")
      ea = d["address"]
      savedWord = (flags // (2 ** 18)) * (2 ** 18) + nextPc
      self~setAccumulator(d["ac"], savedWord)
      trace["effectiveAddress"] = ea
      trace["savedWord"] = savedWord
      nextPc = ea
    end
    when d["opcode"] = 172 then do                    /* JRST, 254 octal */
      /* v0.14 admits only plain JRST (AC function 0), with direct section-zero
       * effective-address calculation.  The real MTBOOT trampoline is fetched
       * from AC17 and uses X=16(octal), so the right half of AC16 contributes
       * to E.  JRST does not fetch an operand word and does not alter FLAGS. */
      if d["ac"] \= 0 then
        raise syntax 40.900 array("JRST function other than plain JRST is outside bounded CPU:" d["ac"])
      ea = self~effectiveAddress18(d)
      trace["effectiveAddress"] = ea
      trace["operand"] = .nil
      nextPc = ea
    end
    otherwise do
      extensionName=self~liveExtensionNameForOpcode(d["opcode"])
      if self~hasMethod(extensionName) then do
        extensionResult=self~sendWith(extensionName,.array~of(d,trace,nextPc))
        trace["liveExtension"]=extensionName
        if extensionResult~isA(.Directory) then do
          if extensionResult~hasIndex("nextPc") then nextPc=extensionResult["nextPc"] // (2**18)
          do extensionKey over extensionResult~allIndexes
            if extensionKey \= "nextPc" then trace[extensionKey]=extensionResult[extensionKey]
          end
        end
        else if extensionResult \== .nil then nextPc=extensionResult // (2**18)
      end
      else raise syntax 40.900 array("opcode not implemented by bounded CPU:" d["mnemonic"])
    end
  end

  pc = nextPc
  halted = 1
  instructionCount = instructionCount + 1
  trace["instructionCountAfter"] = instructionCount
  deviceEvents=ioBus~advance
  trace["deviceEvents"]=deviceEvents
  trace["acAfter"] = self~accumulator(d["ac"])
  trace["flagsAfter"] = flags
  trace["pcAfter"] = pc
  trace["halted"] = halted
  return trace

StepSyntax:
  if pendingPageFault = .nil then raise propagate
  return self~deliverPendingPageFault(beforePc,nextPc,trace,d)

::method deliverPendingPageFault private
  expose memory pc halted flags instructionCount pendingPageFault
  use strict arg beforePc,nextPc,trace,d
  numeric digits 30
  fault=pendingPageFault
  pendingPageFault=.nil
  if fault = .nil | fault["kind"] \= "TOPS20_PAGE_FAIL" then
    raise syntax 40.900 array("invalid KL10 pending page fault")

  /* KL10A TOPS-20 section-zero page-fail cycle.  Cornwell's KL path starts
   * the TOPS-20 non-KLB UPT block at UPT+0501: page-fail word, FLAGS,,PC,
   * then the guest-supplied new FLAGS,,PC at UPT+0503. */
  faultWord=.KL10Word~bit(8) + (fault["virtual"] // (2**18))
  if fault["write"] then faultWord=faultWord+.KL10Word~bit(5)
  if fault["public"] then faultWord=faultWord+.KL10Word~bit(6)
  if fault["cache"] then faultWord=faultWord+.KL10Word~bit(7)
  if fault["accessible"] then faultWord=faultWord+.KL10Word~bit(2)

  upt= self~pag~ubPtr
  memory~physicalPut(upt+self~octToDecLocal("0501"),faultWord)
  savedWord=(flags // (2**18))*(2**18)+(nextPc // (2**18))
  memory~physicalPut(upt+self~octToDecLocal("0502"),savedWord)
  newWord=memory~physicalWord(upt+self~octToDecLocal("0503"))
  flags=(newWord % (2**18)) // (2**18)
  pc=newWord // (2**18)
  halted=1
  instructionCount=instructionCount+1

  trace["pageFault"]=1
  trace["pageFaultKind"]=fault["kind"]
  trace["pageFaultWord"]=faultWord
  trace["pageFaultVirtual"]=fault["virtual"]
  trace["pageFaultSavedWord"]=savedWord
  trace["pageFaultVectorWord"]=newWord
  trace["instructionCountAfter"]=instructionCount
  trace["flagsAfter"]=flags
  trace["pcAfter"]=pc
  trace["halted"]=halted
  return trace

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method shiftCount18 private
  use strict arg ea, rotation = 0
  numeric digits 30
  low = ea // 256
  rightShift = ea >= (2 ** 17)
  if rightShift then do
    if rotation & low = 0 then count = 256
    else count = (256 - low) // 256
  end
  else count = low
  out = .directory~new
  out["count"] = count
  out["right"] = rightShift
  return out

::method logicalShift36 private
  use strict arg value, count, rightShift
  bits = .LROct~fromDecimal(value)~bits
  if count = 0 then return value
  if count >= 36 then return 0
  if rightShift then out = copies("0", count) || bits~substr(1, 36 - count)
  else out = bits~substr(count + 1) || copies("0", count)
  return .LROct~fromBits(out)~decimal

::method rotate36 private
  use strict arg value, count, rightShift
  count = count // 36
  if count = 0 then return value
  bits = .LROct~fromDecimal(value)~bits
  if rightShift then out = bits~substr(37 - count) || bits~substr(1, 36 - count)
  else out = bits~substr(count + 1) || bits~substr(1, count)
  return .LROct~fromBits(out)~decimal

::method arithmeticShift36 private
  use strict arg value, count, rightShift
  bits = .LROct~fromDecimal(value)~bits
  sign = bits~substr(1, 1)
  overflow = 0
  if count = 0 then outBits = bits
  else if rightShift then do
    if count >= 35 then outBits = copies(sign, 36)
    else outBits = copies(sign, count) || bits~substr(1, 36 - count)
  end
  else do
    data = bits~substr(2)
    if count >= 35 then do
      shiftedOut = data
      newData = copies("0", 35)
    end
    else do
      shiftedOut = data~substr(1, count)
      newData = data~substr(count + 1) || copies("0", count)
    end
    do i = 1 to shiftedOut~length
      if shiftedOut~substr(i, 1) \= sign then overflow = 1
    end
    outBits = sign || newData
  end
  out = .directory~new
  out["value"] = .LROct~fromBits(outBits)~decimal
  out["overflow"] = overflow
  return out

::method arithmeticShiftCombined private
  use strict arg highWord, lowWord, count, rightShift
  numeric digits 30
  wordMod = 2 ** 36
  dataMod = 2 ** 35
  wordMask = wordMod - 1
  dataMask = dataMod - 1
  signSet = highWord >= dataMod
  if signSet then do
    signMask = dataMod
    signFill = wordMask
  end
  else do
    signMask = 0
    signFill = 0
  end
  highData = highWord // dataMod
  lowData = lowWord // dataMod
  overflow = 0

  if count = 0 then do
    highOut = highWord
    lowOut = lowWord
  end
  else do
    if count > 70 then count = 70
    if rightShift then do
      if count >= 35 then do
        highOut = signFill
        highPart = highData % (2 ** (count - 35))
        signPart = (signFill * (2 ** (70 - count))) // wordMod
        lowOut = self~bitOr36(highPart, signPart)
      end
      else do
        lowOut = self~bitOr36(signMask, lowData % (2 ** count))
        lowOut = self~bitOr36(lowOut, (highData * (2 ** (35 - count))) // dataMod)
        highOut = self~bitOr36(signMask, highData % (2 ** count))
        highOut = self~bitOr36(highOut, (signFill * (2 ** (35 - count))) // wordMod)
      end
    end
    else do
      highBits = .LROct~fromDecimal(highData)~bits~substr(2)
      inspectCount = count
      if inspectCount > 35 then inspectCount = 35
      shiftedOut = highBits~substr(1, inspectCount)
      if signSet then expectedSign = "1"
      else expectedSign = "0"
      do i = 1 to shiftedOut~length
        if shiftedOut~substr(i, 1) \= expectedSign then overflow = 1
      end

      if count >= 35 then do
        highOut = self~bitOr36(signMask, (lowData * (2 ** (count - 35))) // dataMod)
        lowOut = signMask
      end
      else do
        highOut = self~bitOr36(signMask, (highData * (2 ** count)) // dataMod)
        highOut = self~bitOr36(highOut, lowData % (2 ** (35 - count)))
        lowOut = self~bitOr36(signMask, (lowData * (2 ** count)) // dataMod)
      end
    end
  end

  out = .directory~new
  out["high"] = highOut // wordMod
  out["low"] = lowOut // wordMod
  out["overflow"] = overflow
  return out

::method rotateCombined private
  use strict arg highWord, lowWord, count, rightShift
  numeric digits 30
  halfMod = 2 ** 36
  pairMod = 2 ** 72
  count = count // 72
  if count = 0 then do
    rotated = highWord * halfMod + lowWord
  end
  else do
    if rightShift then leftCount = 72 - count
    else leftCount = count
    pair = highWord * halfMod + lowWord
    rotated = ((pair * (2 ** leftCount)) // pairMod) + (pair % (2 ** (72 - leftCount)))
  end
  out = .directory~new
  out["high"] = rotated % halfMod
  out["low"] = rotated // halfMod
  return out

::method logicalShiftCombined private
  use strict arg highWord, lowWord, count, rightShift
  numeric digits 30
  halfMod = 2 ** 36
  pairMod = 2 ** 72
  pair = highWord * halfMod + lowWord
  if count = 0 then shifted = pair
  else if count > 71 then shifted = 0
  else if rightShift then shifted = pair % (2 ** count)
  else shifted = (pair * (2 ** count)) // pairMod
  out = .directory~new
  out["high"] = shifted % halfMod
  out["low"] = shifted // halfMod
  return out

::method leadingZeros36 private
  use strict arg value
  bits = .LROct~fromDecimal(value)~bits
  do i = 1 to 36
    if bits~substr(i, 1) = "1" then return i - 1
  end
  return 0

::method applyShiftOverflow private
  expose flags
  flags = self~withFlag(flags, 2 ** 12)   /* OVR  = 010000 octal */
  flags = self~withFlag(flags, 4)         /* TRP1 = 000004 octal */
  return flags

::method bytePointerAddress private
  expose memory
  use strict arg pointerWord
  numeric digits 30

  reserved=(pointerWord % (2 ** 23)) // 2
  if reserved \= 0 then
    raise syntax 40.900 array("global/two-word byte pointer outside section-zero bounded CPU")

  indirect=(pointerWord % (2 ** 22)) // 2
  index=(pointerWord % (2 ** 18)) // 16
  address=pointerWord // (2 ** 18)

  do depth=0 to 31
    ea=address
    if index \= 0 then do
      indexRight=.LROct~fromDecimal(self~accumulator(index))~rightDecimal
      ea=(ea+indexRight) // (2 ** 18)
    end
    if indirect=0 then return ea

    indirectWord=memory~word(ea)
    indirect=(indirectWord % (2 ** 22)) // 2
    index=(indirectWord % (2 ** 18)) // 16
    address=indirectWord // (2 ** 18)
  end

  raise syntax 40.900 array("byte pointer indirection limit exceeded")

::method incrementBytePointer private
  use strict arg pointerWord
  numeric digits 30

  bytePosition=pointerWord % (2 ** 30)
  top12=pointerWord % (2 ** 24)
  byteSize=top12 // 64
  if byteSize < 0 | byteSize > 36 then
    raise syntax 40.900 array("invalid byte size:" byteSize)

  leftHalf=pointerWord % (2 ** 18)
  control=leftHalf // 64
  address=pointerWord // (2 ** 18)

  if bytePosition >= byteSize then
    newPosition=bytePosition-byteSize
  else do
    newPosition=36-byteSize
    address=(address+1) // (2 ** 18)
  end

  newLeft=newPosition*(2 ** 12)+byteSize*64+control
  out=.directory~new
  out["word"]=newLeft*(2 ** 18)+address
  out["position"]=newPosition
  out["size"]=byteSize
  out["addressField"]=address
  return out

::method octToDecCpu private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method rangeAllNxm private
  expose memory
  use strict arg first,last,writeAccess
  if last<first then return 0
  address=first
  do forever
    tr=memory~translate(address,writeAccess,1)
    if memory~physicalExists(tr["physical"]) then return 0
    if address>=last then leave
    nextPage=((address % 512)+1)*512
    if nextPage>last then address=last
    else address=nextPage
  end
  return 1

::method touchRangePages private
  expose memory
  use strict arg first,last,writeAccess
  address=first
  do forever
    ignored=memory~translate(address,writeAccess,0)
    if address>=last then leave
    nextPage=((address % 512)+1)*512
    if nextPage>last then address=last
    else address=nextPage
  end
  return self

::method effectiveAddress18 private
  expose memory
  use arg d
  numeric digits 30
  indirect=d["indirect"]
  index=d["index"]
  address=d["address"]

  do depth=0 to 31
    ea=address
    if index \= 0 then do
      indexRight=.LROct~fromDecimal(self~accumulator(index))~rightDecimal
      ea=(ea+indexRight)//(2**18)
    end
    if indirect=0 then return ea

    indWord=memory~word(ea)
    indirect=(indWord % (2 ** 22)) // 2
    index=(indWord % (2 ** 18)) // 16
    address=indWord // (2 ** 18)
  end

  raise syntax 40.900 array("section-zero indirect effective-address limit exceeded")

::method halfword36 private
  use strict arg group, sourceWord, destinationWord
  numeric digits 30
  halfMod = 2 ** 18
  halfMask = halfMod - 1
  signBit = 2 ** 17

  sourceLeft = (sourceWord % halfMod) // halfMod
  sourceRight = sourceWord // halfMod
  destinationLeft = (destinationWord % halfMod) // halfMod
  destinationRight = destinationWord // halfMod

  if group < 8 then do
    /* HLL/HRL quartets place the selected half in the LEFT destination. */
    if group // 2 = 0 then selected = sourceLeft
    else selected = sourceRight
    mode = (group // 8) % 2
    select
      when mode = 0 then other = destinationRight
      when mode = 1 then other = 0
      when mode = 2 then other = halfMask
      otherwise do
        if selected >= signBit then other = halfMask
        else other = 0
      end
    end
    resultLeft = selected
    resultRight = other
  end
  else do
    /* HRR/HLR quartets place the selected half in the RIGHT destination. */
    if group // 2 = 0 then selected = sourceRight
    else selected = sourceLeft
    mode = (group // 8) % 2
    select
      when mode = 0 then other = destinationLeft
      when mode = 1 then other = 0
      when mode = 2 then other = halfMask
      otherwise do
        if selected >= signBit then other = halfMask
        else other = 0
      end
    end
    resultLeft = other
    resultRight = selected
  end

  return resultLeft * halfMod + resultRight


::method boolean36 private
  use strict arg group, a, m
  numeric digits 30
  allOnes = (2 ** 36) - 1
  if m = .nil then m = 0
  select
    when group = 0 then return 0                                      /* SETZ  */
    when group = 1 then return self~bitAnd36(m, a)                    /* AND   */
    when group = 2 then return self~bitAnd36(m, self~bitNot36(a))     /* ANDCA */
    when group = 3 then return m                                      /* SETM  */
    when group = 4 then return self~bitAnd36(self~bitNot36(m), a)     /* ANDCM */
    when group = 5 then return a                                      /* SETA  */
    when group = 6 then return self~bitXor36(m, a)                    /* XOR   */
    when group = 7 then return self~bitOr36(m, a)                     /* IOR   */
    when group = 8 then return self~bitAnd36(self~bitNot36(m), self~bitNot36(a)) /* ANDCB */
    when group = 9 then return self~bitNot36(self~bitXor36(m, a))     /* EQV   */
    when group = 10 then return self~bitNot36(a)                      /* SETCA */
    when group = 11 then return self~bitOr36(m, self~bitNot36(a))     /* ORCA  */
    when group = 12 then return self~bitNot36(m)                      /* SETCM */
    when group = 13 then return self~bitOr36(self~bitNot36(m), a)     /* ORCM  */
    when group = 14 then return self~bitNot36(self~bitAnd36(m, a))    /* ORCB  */
    when group = 15 then return allOnes                               /* SETO  */
    otherwise raise syntax 40.900 array("unknown KL10 Boolean group:" group)
  end

::method swapHalves36 private
  use strict arg value
  w = .LROct~fromDecimal(value)
  return .LROct~new(w~right || w~left)~decimal

::method bitNot36 private
  use strict arg value
  w = .LROct~fromDecimal(value)
  return (\w)~decimal

::method bitOr36 private
  use strict arg a, b
  leftWord = .LROct~fromDecimal(a)
  rightWord = .LROct~fromDecimal(b)
  return (leftWord | rightWord)~decimal

::method bitXor36 private
  use strict arg a, b
  leftWord = .LROct~fromDecimal(a)
  rightWord = .LROct~fromDecimal(b)
  return (leftWord && rightWord)~decimal

::method signed36 private
  use strict arg value
  numeric digits 30
  value=value // (2 ** 36)
  if value >= (2 ** 35) then return value-(2 ** 36)
  return value

::method applyMultiplyOverflow private
  expose flags
  flags=self~withFlag(flags,2 ** 12)
  flags=self~withFlag(flags,4)
  return flags

::method arithmetic36 private
  use strict arg operation, a, b
  numeric digits 30
  wordMod = 2 ** 36
  lowMod = 2 ** 35
  wordMask = wordMod - 1
  lowMask = lowMod - 1
  a = a // wordMod
  b = b // wordMod

  out = .directory~new
  if operation = "ADD" then do
    lowTotal = (a // lowMod) + (b // lowMod)
    total = a + b
  end
  else if operation = "SUB" then do
    /* Cornwell KL10: CCM(operand)+(AC&CMASK)+1 for carry into sign,
     * CM(operand)+AC+1 for the 36-bit result/carry out. */
    lowTotal = (lowMask - (b // lowMod)) + (a // lowMod) + 1
    total = (wordMask - b) + a + 1
  end
  else raise syntax 40.900 array("unknown KL10 arithmetic operation:" operation)

  carry1 = lowTotal >= lowMod
  carry0 = total >= wordMod
  out["value"] = total // wordMod
  out["carry1"] = carry1
  out["carry0"] = carry0
  out["overflow"] = carry1 \= carry0
  return out

::method applyArithmeticFlags private
  expose flags
  use strict arg alu
  /* kx10_defs.h internal FLAGS representation: TRP1=000004,
   * CRY1=002000, CRY0=004000, OVR=010000 (octal). */
  if alu["carry1"] then flags = self~withFlag(flags, 2 ** 10)
  if alu["carry0"] then flags = self~withFlag(flags, 2 ** 11)
  if alu["overflow"] then do
    flags = self~withFlag(flags, 2 ** 12)
    flags = self~withFlag(flags, 4)
  end
  return flags

::method withFlag private
  use strict arg value, mask
  if ((value % mask) // 2) = 0 then value = value + mask
  return value

::method bitAnd36 private
  use arg a, b
  leftWord = .LROct~fromDecimal(a)
  rightWord = .LROct~fromDecimal(b)
  return (leftWord & rightWord)~decimal


/* ------------------------------------------------------------------------- */
/* Versioned architectural freeze/load state.                                */
/*                                                                           */
/* This is deliberately not ooRexx object serialization.  The file contains */
/* architectural state and a self-contained physical-memory image, so a      */
/* checkpoint can be loaded into a fresh KL10CPU without the source tape.    */
/* ------------------------------------------------------------------------- */
::class KL10FrozenState public

::method init
  expose encoded memoryDigest schemaSha256 metadata recordCount byteCount
  use strict arg encodedArg,memoryDigestArg,schemaSha256Arg,metadataArg,recordCountArg
  encoded=encodedArg
  memoryDigest=memoryDigestArg
  schemaSha256=schemaSha256Arg
  metadata=.directory~new
  do frozenKey over metadataArg
    metadata[frozenKey]=metadataArg[frozenKey]
  end
  recordCount=recordCountArg
  byteCount=encoded~length

::method memoryDigest
  expose memoryDigest
  return memoryDigest

::method schemaSha256
  expose schemaSha256
  return schemaSha256

::method metadata
  expose metadata
  return metadata

::method recordCount
  expose recordCount
  return recordCount

::method byteCount
  expose byteCount
  return byteCount

::method encoded
  expose encoded
  return encoded

::method save
  expose encoded
  use strict arg path
  stream=.stream~new(path)
  ignored=stream~open("WRITE REPLACE")
  if stream~state \= "READY" then
    raise syntax 40.900 array("cannot create KL10 state file:" path)
  ignored=stream~charout(encoded)
  ignored=stream~close
  return self

::method saveCompressed
  expose encoded
  use strict arg path
  compressed=.KL10Deflate~compressZlib(encoded)
  stream=.stream~new(path)
  ignored=stream~open("WRITE REPLACE")
  if stream~state \= "READY" then
    raise syntax 40.900 array("cannot create compressed KL10 state file:" path)
  ignored=stream~charout(compressed)
  ignored=stream~close
  return self


::class KL10State public

::method init
  expose metadata memoryDigest
  metadata = .directory~new
  memoryDigest = .nil

::method metadata
  expose metadata
  return metadata

::method memoryDigest
  expose memoryDigest
  return memoryDigest

::method schemaId
  return "KL10_STATE/1"

::method schemaSha256
  /* PI device 004 is now explicit frozen architectural state. */
  return "e99f958c094d51fbde38039c9f6d8d9d73280fa0c9ec129acd0f3eebdd7d4708"

::method legacyPiLessSchemaSha256
  /* v0.31-dev4 immediately before PI became architectural state. */
  return "c86e8d86cc028409df01f57f9c9af0d57e36727e6549e0f025c5a184fbe1ea3f"

::method legacyCurrentSchemaSha256
  /* Authenticated v0.30 current schema; RH20 /2 migrates explicitly with
   * attentionInterruptEnabled=0 because that field did not exist there. */
  return "3d662969aa66a35bc263fd759a40f274956999b9bec6419c3cb418d4105c9f2f"

::method legacyRh20SchemaSha256
  return "1d270bf80502a1d8ffe40e350ef4455ffcd68d3f9243b0cee53f30d9bb3ea9a9"

::method legacyDteSchemaSha256
  /* Exact v0.27/v0.28 schema: DTE optional, no RH20 records. */
  return "dd12699496f2a068969f504c24cbce720bfcfee52d4e45a18eac88e84434e222"

::method legacySchemaSha256
  /* Exact v0.26 two-device schema; retained only for authenticated migration. */
  return "6ead1c67a795029b094fc3c381b2edfd311146aee374b196227932e0e761aa30"

::method freeze
  expose metadata memoryDigest
  use arg cpu, suppliedMetadata
  numeric digits 30
  metadata=.directory~new
  if arg() >= 2 then do
    do frozenKey over suppliedMetadata
      metadata[frozenKey]=suppliedMetadata[frozenKey]
    end
  end

  lines=.array~new
  memoryLines=.array~new

  lines~append("KL10_STATE 1")
  lines~append("SCHEMA" self~schemaSha256)

  do key over metadata
    if pos(" ",key) \= 0 | pos(" ",metadata[key]) \= 0 then
      raise syntax 40.900 array("KL10 state metadata must be single-token:" key)
    lines~append("META" key metadata[key])
  end

  lines~append("CPU" cpu~pc cpu~flags cpu~halted cpu~processorMode cpu~instructionCount)

  do block=0 to 7
    do ac=0 to 15
      lines~append("AC" block ac cpu~accumulatorInBlock(block,ac))
    end
  end

  codes=cpu~ioBus~deviceCodes
  lines~append("BUSCOUNT" codes~items)
  do code over codes
    dev=cpu~ioBus~device(code)
    if \dev~hasMethod("STATESCHEMA") | \dev~hasMethod("STATE") | \dev~hasMethod("RESTORESTATE") then
      raise syntax 40.900 array("attached device lacks freeze contract:" code dev~deviceName)
    lines~append("BUS" code dev~deviceName dev~stateSchema)
  end

  apr=cpu~apr~state
  lines~append("APR" cpu~apr~stateSchema -
      "resetCount=" || apr["resetCount"] -
      "resetDone=" || apr["resetDone"] -
      "aprIrq=" || apr["aprIrq"] -
      "irqEnable=" || apr["irqEnable"] -
      "irqFlags=" || apr["irqFlags"])

  pi=cpu~pi~state
  lines~append("PI" cpu~pi~stateSchema -
      "systemOn=" || pi["systemOn"] -
      "channelsOn=" || pi["channelsOn"] -
      "programRequests=" || pi["programRequests"] -
      "inProgress=" || pi["inProgress"] -
      "resetCount=" || pi["resetCount"])

  pag=cpu~pag~state
  lines~append("PAG" cpu~pag~stateSchema -
      "statusWord=" || self~stateAtom(pag["statusWord"]) -
      "conoZeroCount=" || pag["conoZeroCount"] -
      "conoCount=" || pag["conoCount"] -
      "ebPtr=" || self~stateAtom(pag["ebPtr"]) -
      "ubPtr=" || self~stateAtom(pag["ubPtr"]) -
      "pageEnabled=" || self~stateAtom(pag["pageEnabled"]) -
      "tops20Page=" || self~stateAtom(pag["tops20Page"]) -
      "tlbFlushCount=" || pag["tlbFlushCount"] -
      "dataoCount=" || pag["dataoCount"] -
      "lastDatao=" || self~stateAtom(pag["lastDatao"]) -
      "currentAcBlock=" || pag["currentAcBlock"] -
      "previousAcBlock=" || pag["previousAcBlock"] -
      "previousContextSection=" || pag["previousContextSection"])

  dteCode=self~octToDecLocal("0200")
  if cpu~ioBus~hasDevice(dteCode) then do
    dte=cpu~ioBus~device(dteCode)
    dteState=dte~state
    lines~append("DTE" dte~stateSchema -
        "statusInternal=" || dteState["statusInternal"] -
        "count=" || dteState["count"] -
        "resetCount=" || dteState["resetCount"] -
        "servicePending=" || dteState["servicePending"] -
        "monitorMode=" || dteState["monitorMode"] -
        "serviceCount=" || dteState["serviceCount"] -
        "txHex=" || self~stateAtom(dteState["txHex"]) -
        "rxHex=" || self~stateAtom(dteState["rxHex"]))
  end

  do rhCode=352 to 380 by 4
    if cpu~ioBus~hasDevice(rhCode) then do
      rh=cpu~ioBus~device(rhCode)
      rhState=rh~state
      lines~append("RH20" rhCode rh~stateSchema -
          "statusWord=" || rhState["statusWord"] -
          "preparation=" || rhState["preparation"] -
          "resetCount=" || rhState["resetCount"] -
          "massbusEnabled=" || rhState["massbusEnabled"] -
          "channelResetCount=" || rhState["channelResetCount"] -
          "sbar=" || rhState["sbar"] -
          "stcr=" || rhState["stcr"] -
          "pbar=" || rhState["pbar"] -
          "ptcr=" || rhState["ptcr"] -
          "ivect=" || rhState["ivect"] -
          "attentionInterruptEnabled=" || rhState["attentionInterruptEnabled"])

      do unitNumber over rh~unitNumbers
        unit=rh~unit(unitNumber)
        if unit~hasMethod("STATESCHEMA") & unit~stateSchema="KL10_MASSBUS_TAPE_STATE/1" then do
          ts=unit~state
          lines~append("MBTAPE" rhCode unitNumber unit~stateSchema -
              "mounted=" || ts["mounted"] -
              "online=" || ts["online"] -
              "writeLocked=" || ts["writeLocked"] -
              "model=" || self~stateAtom(ts["model"]) -
              "formatter=" || self~stateAtom(ts["formatter"]) -
              "mediaPath=" || self~stateAtom(ts["mediaPath"]) -
              "mediaSha256=" || self~stateAtom(ts["mediaSha256"]) -
              "position=" || ts["position"] -
              "fileNumber=" || ts["fileNumber"] -
              "markRun=" || ts["markRun"] -
              "selectedSlave=" || ts["selectedSlave"] -
              "frameCount=" || ts["frameCount"] -
              "tapeControl=" || ts["tapeControl"] -
              "controlReg=" || ts["controlReg"] -
              "errorReg=" || ts["errorReg"] -
              "lastRecordKind=" || self~stateAtom(ts["lastRecordKind"]) -
              "readCount=" || ts["readCount"] -
              "rewindCount=" || ts["rewindCount"] -
              "pendingKind=" || self~stateAtom(ts["pendingKind"]) -
              "pendingFileNumber=" || ts["pendingFileNumber"] -
              "pendingHeader=" || ts["pendingHeader"] -
              "pendingPayload=" || ts["pendingPayload"] -
              "pendingLength=" || ts["pendingLength"] -
              "pendingError=" || ts["pendingError"])
        end
        else
          raise syntax 40.900 array("RH20 nested unit lacks supported freeze schema:" rhCode unitNumber)
      end
    end
  end

  backing=cpu~memory~backingMemory
  pages=backing~mappedPageNumbers
  lines~append("PAGES" pages~items)

  do page over pages
    pageLine="PAGE" page
    memoryLines~append(pageLine)
    base=page*512
    do offset=0 to 511
      wordLine="WORD" (base+offset) backing~word(base+offset)
      memoryLines~append(wordLine)
    end
  end

  memoryText=memoryLines~makeString("L","0a"x) || "0a"x
  memoryDigest=self~sha256Text(memoryText)

  prefixText=lines~makeString("L","0a"x) || "0a"x
  suffixText="MEMSHA256" memoryDigest || "0a"x || "END" || "0a"x
  encoded=prefixText || memoryText || suffixText
  recordCount=lines~items+memoryLines~items+2
  return .KL10FrozenState~new(encoded,memoryDigest,self~schemaSha256,metadata,recordCount)

::method save
  expose metadata memoryDigest
  use arg cpu,path,suppliedMetadata
  numeric digits 30
  if arg()>=3 then frozen=self~freeze(cpu,suppliedMetadata)
  else frozen=self~freeze(cpu)
  frozen~save(path)
  metadata=frozen~metadata
  memoryDigest=frozen~memoryDigest
  return self

::method saveCompressed
  expose metadata memoryDigest
  use arg cpu,path,suppliedMetadata
  numeric digits 30
  if arg()>=3 then frozen=self~freeze(cpu,suppliedMetadata)
  else frozen=self~freeze(cpu)
  frozen~saveCompressed(path)
  metadata=frozen~metadata
  memoryDigest=frozen~memoryDigest
  return self

::method loadCompressed
  use strict arg path
  stream=.stream~new(path)
  ignored=stream~open("READ")
  if stream~state \= "READY" then
    raise syntax 40.900 array("cannot open compressed KL10 state file:" path)
  bytes=stream~charin(1,stream~chars)
  ignored=stream~close
  plain=.KL10Deflate~decompressZlib(bytes)
  tmp="/tmp/kl10-state-zlib-" || random(1000000,9999999) || "-" || time("S") || ".tmp"
  out=.stream~new(tmp)
  ignored=out~open("WRITE REPLACE")
  if out~state \= "READY" then raise syntax 40.900 array("cannot create compressed-state temporary file")
  ignored=out~charout(plain)
  ignored=out~close
  cpu=self~load(tmp)
  ignored=sysFileDelete(tmp)
  return cpu

::method sha256Text private
  use strict arg text
  tmp="/tmp/kl10-freeze-" || random(1000000,9999999) || "-" || time("S") || ".tmp"
  stream=.stream~new(tmp)
  ignored=stream~open("WRITE REPLACE")
  if stream~state \= "READY" then
    raise syntax 40.900 array("cannot create KL10 digest temporary file")
  ignored=stream~charout(text)
  ignored=stream~close
  digest=self~sha256File(tmp)
  ignored=sysFileDelete(tmp)
  return digest

::method load
  expose metadata memoryDigest
  use strict arg path
  numeric digits 30
  metadata = .directory~new
  memoryDigest = .nil

  stream = .stream~new(path)
  ignored = stream~open("READ")
  if stream~state \= "READY" then
    raise syntax 40.900 array("cannot open KL10 state file:" path)

  header = stream~linein
  parse var header magic version extra
  if magic \= "KL10_STATE" | version \= 1 | extra \= "" then do
    ignored = stream~close
    raise syntax 40.900 array("unsupported KL10 state header:" header)
  end

  mem = .KL10Memory~new
  cpuState = .nil
  aprState = .nil
  piState = .nil
  pagState = .nil
  dteState = .nil
  rh20States = .directory~new
  mbTapeStates = .directory~new
  loadedSchema = ""
  acValues = .directory~new
  mapped = .directory~new
  busRecords = .directory~new
  busCountExpected = .nil
  pagesExpected = .nil
  pageCount = 0
  wordCount = 0
  schemaSeen = 0
  aprSeen = 0
  piSeen = 0
  pagSeen = 0
  dteSeen = 0
  rh20Seen = .directory~new
  mbTapeSeen = .directory~new
  endSeen = 0
  digestSeen = 0

  memoryLines=.array~new
  memTmp = path || ".memory-verify.tmp"
  memStream = .stream~new(memTmp)
  ignored = memStream~open("WRITE REPLACE")
  if memStream~state \= "READY" then do
    ignored = stream~close
    raise syntax 40.900 array("cannot create KL10 memory verification temporary file")
  end

  do while stream~lines > 0
    line = stream~linein
    parse var line tag rest

    select
      when tag = "SCHEMA" then do
        if schemaSeen then ignored = self~stateFail(stream, memStream, memTmp, "duplicate SCHEMA record")
        parse var rest digest extra
        if extra \= "" then
          ignored = self~stateFail(stream, memStream, memTmp, "KL10 state schema record malformed")
        if digest \= self~schemaSha256 & digest \= self~legacyPiLessSchemaSha256 & -
           digest \= self~legacyCurrentSchemaSha256 & digest \= self~legacyRh20SchemaSha256 & -
           digest \= self~legacyDteSchemaSha256 & digest \= self~legacySchemaSha256 then
          ignored = self~stateFail(stream, memStream, memTmp, "KL10 state schema mismatch")
        loadedSchema = digest
        schemaSeen = 1
      end

      when tag = "META" then do
        parse var rest key value extra
        if key = "" | value = "" | extra \= "" | metadata~hasIndex(key) then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid META record")
        metadata[key] = value
      end

      when tag = "CPU" then do
        if cpuState \= .nil then ignored = self~stateFail(stream, memStream, memTmp, "duplicate CPU record")
        parse var rest restoredPc restoredFlags restoredHalted restoredMode restoredIcount extra
        if extra \= "" | restoredPc = "" | restoredFlags = "" | restoredHalted = "" | -
           restoredMode = "" | restoredIcount = "" then
          ignored = self~stateFail(stream, memStream, memTmp, "incomplete CPU record")
        if restoredMode \= "EXEC" then
          ignored = self~stateFail(stream, memStream, memTmp, "unsupported processor mode in state:" restoredMode)
        cpuState = .array~of(restoredPc, restoredFlags, restoredHalted, restoredMode, restoredIcount)
      end

      when tag = "AC" then do
        parse var rest block ac value extra
        if extra \= "" | \datatype(block,"W") | \datatype(ac,"W") | \datatype(value,"W") | -
           block < 0 | block > 7 | ac < 0 | ac > 15 then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid AC record")
        key = block || ":" || ac
        if acValues~hasIndex(key) then ignored = self~stateFail(stream, memStream, memTmp, "duplicate AC record:" key)
        acValues[key] = value
      end

      when tag = "BUSCOUNT" then do
        if busCountExpected \= .nil then ignored = self~stateFail(stream, memStream, memTmp, "duplicate BUSCOUNT")
        parse var rest busCountExpected extra
        if extra \= "" | \datatype(busCountExpected,"W") then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid BUSCOUNT")
      end

      when tag = "BUS" then do
        parse var rest code name schema extra
        if extra \= "" | \datatype(code,"W") | name = "" | schema = "" then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid BUS record")
        if busRecords~hasIndex(code) then ignored = self~stateFail(stream, memStream, memTmp, "duplicate BUS device:" code)
        busRecords[code] = name || "|" || schema
      end

      when tag = "APR" then do
        if aprSeen then ignored = self~stateFail(stream, memStream, memTmp, "duplicate APR record")
        parse var rest schema f1 f2 f3 f4 f5 extra
        if extra \= "" | schema \= "KL10_APR_STATE/1" then
          ignored = self~stateFail(stream, memStream, memTmp, "APR state schema mismatch")
        aprState = .directory~new
        ignored = self~requiredField(aprState, f1, "resetCount")
        ignored = self~requiredField(aprState, f2, "resetDone")
        ignored = self~requiredField(aprState, f3, "aprIrq")
        ignored = self~requiredField(aprState, f4, "irqEnable")
        ignored = self~requiredField(aprState, f5, "irqFlags")
        aprSeen = 1
      end

      when tag = "PI" then do
        if piSeen then ignored=self~stateFail(stream,memStream,memTmp,"duplicate PI record")
        parse var rest schema f1 f2 f3 f4 f5 extra
        if extra \= "" | schema \= "KL10_PI_STATE/1" then
          ignored=self~stateFail(stream,memStream,memTmp,"PI state schema mismatch")
        piState=.directory~new
        ignored=self~requiredField(piState,f1,"systemOn")
        ignored=self~requiredField(piState,f2,"channelsOn")
        ignored=self~requiredField(piState,f3,"programRequests")
        ignored=self~requiredField(piState,f4,"inProgress")
        ignored=self~requiredField(piState,f5,"resetCount")
        piSeen=1
      end

      when tag = "PAG" then do
        if pagSeen then ignored = self~stateFail(stream, memStream, memTmp, "duplicate PAG record")
        parse var rest schema f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 extra
        if extra \= "" | schema \= "KL10_PAG_STATE/1" then
          ignored = self~stateFail(stream, memStream, memTmp, "PAG state schema mismatch")
        pagState = .directory~new
        ignored = self~requiredField(pagState, f1, "statusWord")
        ignored = self~requiredField(pagState, f2, "conoZeroCount")
        ignored = self~requiredField(pagState, f3, "conoCount")
        ignored = self~requiredField(pagState, f4, "ebPtr")
        ignored = self~requiredField(pagState, f5, "ubPtr")
        ignored = self~requiredField(pagState, f6, "pageEnabled")
        ignored = self~requiredField(pagState, f7, "tops20Page")
        ignored = self~requiredField(pagState, f8, "tlbFlushCount")
        ignored = self~requiredField(pagState, f9, "dataoCount")
        ignored = self~requiredField(pagState, f10, "lastDatao")
        ignored = self~requiredField(pagState, f11, "currentAcBlock")
        ignored = self~requiredField(pagState, f12, "previousAcBlock")
        ignored = self~requiredField(pagState, f13, "previousContextSection")
        do key over pagState
          pagState[key] = self~parseAtom(pagState[key])
        end
        pagSeen = 1
      end

      when tag = "DTE" then do
        if dteSeen then ignored = self~stateFail(stream, memStream, memTmp, "duplicate DTE record")
        parse var rest schema f1 f2 f3 f4 f5 f6 f7 f8 extra
        if extra \= "" | schema \= "KL10_DTE_STATE/4" then
          ignored = self~stateFail(stream, memStream, memTmp, "DTE state schema mismatch")
        dteState = .directory~new
        ignored = self~requiredField(dteState, f1, "statusInternal")
        ignored = self~requiredField(dteState, f2, "count")
        ignored = self~requiredField(dteState, f3, "resetCount")
        ignored = self~requiredField(dteState, f4, "servicePending")
        ignored = self~requiredField(dteState, f5, "monitorMode")
        ignored = self~requiredField(dteState, f6, "serviceCount")
        ignored = self~requiredField(dteState, f7, "txHex")
        ignored = self~requiredField(dteState, f8, "rxHex")
        dteState["txHex"]=self~parseAtom(dteState["txHex"])
        dteState["rxHex"]=self~parseAtom(dteState["rxHex"])
        if dteState["txHex"] = .nil then dteState["txHex"]=""
        if dteState["rxHex"] = .nil then dteState["rxHex"]=""
        dteSeen = 1
      end

      when tag = "RH20" then do
        parse var rest rhCode schema tail
        if \datatype(rhCode,"W") | rhCode < 352 | rhCode > 380 | rhCode // 4 \= 0 then
          ignored = self~stateFail(stream, memStream, memTmp, "RH20 state slot mismatch")
        if rh20Seen~hasIndex(rhCode) then
          ignored = self~stateFail(stream, memStream, memTmp, "duplicate RH20 record:" rhCode)
        rs = .directory~new
        if schema="KL10_RH20_STATE/3" then do
          parse var tail f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 extra
          if extra \= "" then ignored=self~stateFail(stream,memStream,memTmp,"RH20 v3 field mismatch")
          ignored=self~requiredField(rs,f1,"statusWord")
          ignored=self~requiredField(rs,f2,"preparation")
          ignored=self~requiredField(rs,f3,"resetCount")
          ignored=self~requiredField(rs,f4,"massbusEnabled")
          ignored=self~requiredField(rs,f5,"channelResetCount")
          ignored=self~requiredField(rs,f6,"sbar")
          ignored=self~requiredField(rs,f7,"stcr")
          ignored=self~requiredField(rs,f8,"pbar")
          ignored=self~requiredField(rs,f9,"ptcr")
          ignored=self~requiredField(rs,f10,"ivect")
          ignored=self~requiredField(rs,f11,"attentionInterruptEnabled")
        end
        else if schema="KL10_RH20_STATE/2" then do
          parse var tail f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 extra
          if extra \= "" then ignored=self~stateFail(stream,memStream,memTmp,"RH20 v2 field mismatch")
          ignored=self~requiredField(rs,f1,"statusWord")
          ignored=self~requiredField(rs,f2,"preparation")
          ignored=self~requiredField(rs,f3,"resetCount")
          ignored=self~requiredField(rs,f4,"massbusEnabled")
          ignored=self~requiredField(rs,f5,"channelResetCount")
          ignored=self~requiredField(rs,f6,"sbar")
          ignored=self~requiredField(rs,f7,"stcr")
          ignored=self~requiredField(rs,f8,"pbar")
          ignored=self~requiredField(rs,f9,"ptcr")
          ignored=self~requiredField(rs,f10,"ivect")
          rs["attentionInterruptEnabled"]=0
        end
        else if schema="KL10_RH20_STATE/1" then do
          parse var tail f1 f2 f3 f4 f5 extra
          if extra \= "" then ignored=self~stateFail(stream,memStream,memTmp,"RH20 v1 field mismatch")
          ignored=self~requiredField(rs,f1,"statusWord")
          ignored=self~requiredField(rs,f2,"preparation")
          ignored=self~requiredField(rs,f3,"resetCount")
          ignored=self~requiredField(rs,f4,"massbusEnabled")
          ignored=self~requiredField(rs,f5,"channelResetCount")
          rs["sbar"]=0
          rs["stcr"]=0
          rs["pbar"]=0
          rs["ptcr"]=0
          rs["ivect"]=0
          rs["attentionInterruptEnabled"]=0
        end
        else ignored=self~stateFail(stream,memStream,memTmp,"RH20 state schema mismatch")
        rs["schema"]=schema
        rh20States[rhCode]=rs
        rh20Seen[rhCode]=1
      end

      when tag = "MBTAPE" then do
        parse var rest rhCode unitNumber schema f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20 f21 f22 f23 f24 extra
        if extra \= "" | \datatype(rhCode,"W") | \datatype(unitNumber,"W") | unitNumber<0 | unitNumber>7 | -
           schema \= "KL10_MASSBUS_TAPE_STATE/1" then
          ignored=self~stateFail(stream,memStream,memTmp,"MBTAPE schema/slot mismatch")
        key=rhCode || ":" || unitNumber
        if mbTapeSeen~hasIndex(key) then ignored=self~stateFail(stream,memStream,memTmp,"duplicate MBTAPE record:" key)
        ts=.directory~new
        ignored=self~requiredField(ts,f1,"mounted")
        ignored=self~requiredField(ts,f2,"online")
        ignored=self~requiredField(ts,f3,"writeLocked")
        ignored=self~requiredField(ts,f4,"model")
        ignored=self~requiredField(ts,f5,"formatter")
        ignored=self~requiredField(ts,f6,"mediaPath")
        ignored=self~requiredField(ts,f7,"mediaSha256")
        ignored=self~requiredField(ts,f8,"position")
        ignored=self~requiredField(ts,f9,"fileNumber")
        ignored=self~requiredField(ts,f10,"markRun")
        ignored=self~requiredField(ts,f11,"selectedSlave")
        ignored=self~requiredField(ts,f12,"frameCount")
        ignored=self~requiredField(ts,f13,"tapeControl")
        ignored=self~requiredField(ts,f14,"controlReg")
        ignored=self~requiredField(ts,f15,"errorReg")
        ignored=self~requiredField(ts,f16,"lastRecordKind")
        ignored=self~requiredField(ts,f17,"readCount")
        ignored=self~requiredField(ts,f18,"rewindCount")
        ignored=self~requiredField(ts,f19,"pendingKind")
        ignored=self~requiredField(ts,f20,"pendingFileNumber")
        ignored=self~requiredField(ts,f21,"pendingHeader")
        ignored=self~requiredField(ts,f22,"pendingPayload")
        ignored=self~requiredField(ts,f23,"pendingLength")
        ignored=self~requiredField(ts,f24,"pendingError")
        do atomKey over .array~of("model","formatter","mediaPath","mediaSha256","lastRecordKind","pendingKind")
          ts[atomKey]=self~parseAtom(ts[atomKey])
          if ts[atomKey]=.nil then ts[atomKey]=""
        end
        ts["rhCode"]=rhCode
        ts["unitNumber"]=unitNumber
        mbTapeStates[key]=ts
        mbTapeSeen[key]=1
      end

      when tag = "PAGES" then do
        if pagesExpected \= .nil then ignored = self~stateFail(stream, memStream, memTmp, "duplicate PAGES record")
        parse var rest pagesExpected extra
        if extra \= "" | \datatype(pagesExpected,"W") | pagesExpected < 0 then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid PAGES record")
      end

      when tag = "PAGE" then do
        parse var rest page extra
        if extra \= "" | \datatype(page,"W") | page < 0 | mapped~hasIndex(page) then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid or duplicate PAGE record")
        ignored = mem~mapZeroPage(page, 0)
        mapped[page] = 1
        pageCount = pageCount + 1
        memoryLines~append(line)
      end

      when tag = "WORD" then do
        parse var rest address value extra
        if extra \= "" | \datatype(address,"W") | \datatype(value,"W") | address < 0 then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid WORD record")
        page = address % 512
        if \mapped~hasIndex(page) then
          ignored = self~stateFail(stream, memStream, memTmp, "WORD appears before PAGE mapping:" address)
        if value \= 0 then ignored = mem~put(address, value)
        wordCount = wordCount + 1
        memoryLines~append(line)
      end

      when tag = "MEMSHA256" then do
        if digestSeen then ignored = self~stateFail(stream, memStream, memTmp, "duplicate MEMSHA256")
        parse var rest memoryDigest extra
        if extra \= "" | memoryDigest~length \= 64 then
          ignored = self~stateFail(stream, memStream, memTmp, "invalid MEMSHA256")
        digestSeen = 1
      end

      when tag = "END" then do
        if rest \= "" then ignored = self~stateFail(stream, memStream, memTmp, "invalid END record")
        endSeen = 1
        leave
      end

      otherwise
        ignored = self~stateFail(stream, memStream, memTmp, "unknown KL10 state record:" tag)
    end
  end

  ignored = stream~close
  ignored = memStream~close

  if \schemaSeen | cpuState = .nil | \aprSeen | \pagSeen | busCountExpected = .nil | -
     pagesExpected = .nil | \digestSeen | \endSeen then do
    ignored = sysFileDelete(memTmp)
    raise syntax 40.900 array("incomplete KL10 state file:" path)
  end

  piCode=4
  hasPiBus=busRecords~hasIndex(piCode)
  if loadedSchema=self~schemaSha256 then do
    if \piSeen | \hasPiBus then
      raise syntax 40.900 array("current KL10 state requires PI BUS/state record")
    if busRecords[piCode] \= "PI|KL10_PI_STATE/1" then
      raise syntax 40.900 array("KL10 state PI device schema mismatch")
  end
  else if piSeen | hasPiBus then
    raise syntax 40.900 array("legacy KL10 state cannot contain PI state")

  dteCode = self~octToDecLocal("0200")
  hasDteBus = busRecords~hasIndex(dteCode)
  if loadedSchema = self~legacySchemaSha256 then do
    if dteSeen | hasDteBus | rh20States~items > 0 | mbTapeStates~items > 0 then
      raise syntax 40.900 array("legacy KL10 state schema cannot contain DTE/RH20/Massbus attachment")
  end
  else do
    if hasDteBus \= dteSeen then
      raise syntax 40.900 array("KL10 state DTE BUS/state record mismatch")
    if hasDteBus & busRecords[dteCode] \= "DTE|KL10_DTE_STATE/4" then
      raise syntax 40.900 array("KL10 state DTE device schema mismatch")
    if loadedSchema = self~legacyDteSchemaSha256 & (rh20States~items > 0 | mbTapeStates~items > 0) then
      raise syntax 40.900 array("legacy DTE schema cannot contain RH20/Massbus state")
    if loadedSchema = self~legacyRh20SchemaSha256 & mbTapeStates~items > 0 then
      raise syntax 40.900 array("v0.29 RH20 schema cannot contain nested Massbus state")
  end

  do rhCode = 352 to 380 by 4
    hasRhBus = busRecords~hasIndex(rhCode)
    hasRhState = rh20States~hasIndex(rhCode)
    if hasRhBus \= hasRhState then
      raise syntax 40.900 array("KL10 state RH20 BUS/state mismatch:" rhCode)
    if hasRhBus then do
      if loadedSchema=self~legacyRh20SchemaSha256 then expectedRh="RH20|KL10_RH20_STATE/1"
      else if loadedSchema=self~legacyCurrentSchemaSha256 then expectedRh="RH20|KL10_RH20_STATE/2"
      else expectedRh="RH20|KL10_RH20_STATE/3"
      if busRecords[rhCode] \= expectedRh then
        raise syntax 40.900 array("KL10 state RH20 device schema mismatch:" rhCode)
    end
  end

  do tapeKey over mbTapeStates
    tsCheck=mbTapeStates[tapeKey]
    rhCode=tsCheck["rhCode"]
    if loadedSchema \= self~schemaSha256 & loadedSchema \= self~legacyPiLessSchemaSha256 & -
       loadedSchema \= self~legacyCurrentSchemaSha256 then
      raise syntax 40.900 array("Massbus tape state requires current KL10 schema")
    if \rh20States~hasIndex(rhCode) then
      raise syntax 40.900 array("Massbus tape references absent RH20:" rhCode)
    if tsCheck["mounted"] \= 1 then
      raise syntax 40.900 array("current MBTAPE freeze contract requires mounted authenticated media")
    if tsCheck["mediaPath"]="" | tsCheck["mediaSha256"]="" then
      raise syntax 40.900 array("mounted MBTAPE lacks media identity")
  end

  if acValues~items \= 128 then do
    ignored = sysFileDelete(memTmp)
    raise syntax 40.900 array("KL10 state must contain exactly 128 accumulator records")
  end
  if busRecords~items \= busCountExpected then do
    ignored = sysFileDelete(memTmp)
    raise syntax 40.900 array("KL10 state BUSCOUNT mismatch")
  end
  if pageCount \= pagesExpected | wordCount \= pagesExpected * 512 then do
    ignored = sysFileDelete(memTmp)
    raise syntax 40.900 array("KL10 state physical-memory shape mismatch")
  end

  memoryText=memoryLines~makeString("L","0a"x) || "0a"x
  actualMemoryDigest=self~sha256Text(memoryText)
  ignored=sysFileDelete(memTmp)
  if actualMemoryDigest \= memoryDigest then
    raise syntax 40.900 array("KL10 state memory digest mismatch")

  /* Construct the target only after the complete state has passed its schema
   * and memory-integrity checks. */
  cpu = .KL10CPU~new
  if loadedSchema \= self~schemaSha256 then ignored=cpu~ioBus~detach(4)
  if hasDteBus then ignored = cpu~attachDte
  do rhCode = 352 to 380 by 4
    if rh20States~hasIndex(rhCode) then ignored = cpu~attachRh20(rhCode)
  end
  targetCodes = cpu~ioBus~deviceCodes
  if targetCodes~items \= busCountExpected then
    raise syntax 40.900 array("KL10 state bus attachment count does not match machine generation")
  do code over targetCodes
    if \busRecords~hasIndex(code) then
      raise syntax 40.900 array("KL10 state omits attached device:" code)
    dev = cpu~ioBus~device(code)
    expected = dev~deviceName || "|" || dev~stateSchema
    if loadedSchema=self~legacyRh20SchemaSha256 & dev~deviceName="RH20" then
      expected="RH20|KL10_RH20_STATE/1"
    else if loadedSchema=self~legacyCurrentSchemaSha256 & dev~deviceName="RH20" then
      expected="RH20|KL10_RH20_STATE/2"
    if busRecords[code] \= expected then
      raise syntax 40.900 array("KL10 state device schema mismatch:" code)
  end

  ignored = cpu~loadImage(mem, cpuState[1])
  do block = 0 to 7
    do ac = 0 to 15
      key = block || ":" || ac
      if \acValues~hasIndex(key) then
        raise syntax 40.900 array("missing accumulator in KL10 state:" key)
      ignored = cpu~setAccumulatorInBlock(block, ac, acValues[key])
    end
  end
  ignored = cpu~apr~restoreState(aprState)
  if loadedSchema=self~schemaSha256 then ignored=cpu~pi~restoreState(piState)
  ignored = cpu~pag~restoreState(pagState)
  if hasDteBus then ignored = cpu~dte~restoreState(dteState)
  do rhCode = 352 to 380 by 4
    if rh20States~hasIndex(rhCode) then ignored = cpu~rh20(rhCode)~restoreState(rh20States[rhCode])
  end
  do tapeKey over mbTapeStates
    ts=mbTapeStates[tapeKey]
    rh=cpu~rh20(ts["rhCode"])
    tape=.KL10MassbusTape~new
    ignored=tape~restoreState(ts,ts["mediaPath"])
    ignored=rh~attachUnit(ts["unitNumber"],tape)
  end
  ignored = cpu~restoreCoreState(cpuState[1], cpuState[2], cpuState[3], cpuState[5], cpuState[4])
  return cpu

::method requiredField private
  use strict arg d, token, expectedName
  parse var token actualName "=" value
  if actualName \= expectedName | value = "" | pos("=", value) \= 0 then
    raise syntax 40.900 array("missing or reordered KL10 state field:" expectedName)
  d[expectedName] = value
  return self

::method stateFail private
  use strict arg stream, memStream, memTmp, message
  ignored = stream~close
  ignored = memStream~close
  ignored = sysFileDelete(memTmp)
  raise syntax 40.900 array(message)

::method sha256File private
  use strict arg path
  if pos('"', path) \= 0 then raise syntax 40.900 array("state path containing quote is unsupported")
  out = path || ".sha256.tmp"
  address system 'sha256sum "' || path || '" > "' || out || '"'
  if rc \= 0 then do
    ignored = sysFileDelete(out)
    raise syntax 40.900 array("sha256sum failed while validating KL10 state memory")
  end
  resultStream = .stream~new(out)
  ignored = resultStream~open("READ")
  line = resultStream~linein
  ignored = resultStream~close
  ignored = sysFileDelete(out)
  parse var line digest .
  if digest~length \= 64 then
    raise syntax 40.900 array("invalid sha256sum output while validating KL10 state memory")
  return digest

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::method stateAtom private
  use strict arg value
  if value = .nil then return "NIL"
  if value = "" then return "EMPTY"
  return value

::method parseAtom private
  use strict arg value
  if value = "NIL" then return .nil
  if value = "EMPTY" then return ""
  return value


::requires "lib/BinarySheet.cls"
::requires "lib/OctalBits.cls"
::requires "lib/JournalPointedState.cls"
::requires "lib/KL10Deflate.cls"
::requires "KL10TapeRaw.cls"
