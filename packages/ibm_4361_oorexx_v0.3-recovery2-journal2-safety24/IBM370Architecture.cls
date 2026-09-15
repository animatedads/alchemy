::options digits 30

/* IBM370Architecture.cls - System/370 architectural nucleus for IBM 4361 model. */

::class IBM370PSW subclass AlchemyObject public

::method init
  expose rawHex
  use strict arg initialHex="0000000000000000"
  self~init:super
  rawHex = self~normaliseHex(initialHex, 16)

::method stateSchema
  return "IBM370_PSW_STATE/1"

::method rawHex
  expose rawHex
  return rawHex

::method loadRawHex
  expose rawHex
  use strict arg value
  rawHex = self~normaliseHex(value, 16)
  return self

::method instructionAddress
  expose rawHex
  return x2d(rawHex~substr(11,6))

::method setInstructionAddress
  expose rawHex
  use strict arg address
  if \datatype(address,"W") | address<0 | address>16777215 then raise syntax 93.900 array("BC-mode instruction address must be 24-bit",address)
  rawHex=rawHex~substr(1,10) || d2x(address,6)
  return self

::method waitState
  expose rawHex
  return c2d(bitand(x2c(rawHex~substr(3,2)),d2c(2)))<>0

::method problemState
  expose rawHex
  return c2d(bitand(x2c(rawHex~substr(3,2)),d2c(1)))<>0

::method ecMode
  expose rawHex
  return c2d(bitand(x2c(rawHex~substr(3,2)),d2c(8)))<>0

::method systemMask
  expose rawHex
  return x2d(rawHex~substr(1,2))

::method setSystemMask
  expose rawHex
  use strict arg value
  if \datatype(value,"W") | value<0 | value>255 then raise syntax 93.900 array("system mask must be byte",value)
  if self~ecMode & c2d(bitand(d2c(value),d2c(x2d("B8"))))<>0 then raise syntax 40.900 array("EC-mode SSM specification exception",d2x(value,2))
  rawHex=d2x(value,2)||rawHex~substr(3)
  return self

::method ioInterruptEnabled
  if self~ecMode then return c2d(bitand(d2c(self~systemMask),d2c(2)))<>0
  return c2d(bitand(d2c(self~systemMask),d2c(252)))<>0

::method ioChannelEnabled
  use strict arg channel
  if \datatype(channel,"W") | channel<0 then return 0
  if self~ecMode then return self~ioInterruptEnabled
  if channel>5 then return 0
  mask=128%(2**channel)
  return c2d(bitand(d2c(self~systemMask),d2c(mask)))<>0

::method rawWithInterruptionCode
  expose rawHex
  use strict arg code
  if \datatype(code,"W") | code<0 | code>65535 then raise syntax 93.900 array("interruption code must be 16-bit",code)
  if self~ecMode then return rawHex
  return rawHex~substr(1,4) || d2x(code,4) || rawHex~substr(9)

::method conditionCode
  expose rawHex
  nibble=x2d(rawHex~substr(9,1))
  return nibble // 4

::method setConditionCode
  expose rawHex
  use strict arg cc
  if \datatype(cc,"W") | cc<0 | cc>3 then raise syntax 93.900 array("condition code must be 0..3",cc)
  nibble=x2d(rawHex~substr(9,1)); ilc=nibble % 4
  rawHex=rawHex~substr(1,8) || d2x(ilc*4+cc,1) || rawHex~substr(10)
  return self

::method programMask
  expose rawHex
  return x2d(rawHex~substr(10,1))

::method setProgramMask
  expose rawHex
  use strict arg mask
  if \datatype(mask,"W") | mask<0 | mask>15 then raise syntax 93.900 array("program mask must be 0..15",mask)
  rawHex=rawHex~substr(1,9)||d2x(mask,1)||rawHex~substr(11)
  return self

::method setInstructionLength
  expose rawHex
  use strict arg bytes
  select
    when bytes=2 then ilc=1
    when bytes=4 then ilc=2
    when bytes=6 then ilc=3
    otherwise raise syntax 93.900 array("invalid System/370 instruction length",bytes)
  end
  nibble=x2d(rawHex~substr(9,1)); cc=nibble // 4
  rawHex=rawHex~substr(1,8) || d2x(ilc*4+cc,1) || rawHex~substr(10)
  return self

::method state
  expose rawHex
  d=.directory~new
  d["rawHex"]=rawHex
  return d

::method restoreState
  use strict arg d
  if \d~isA(.Directory) then raise syntax 88.900 array("IBM370PSW state must be Directory")
  if \d~hasIndex("rawHex") then raise syntax 40.900 array("IBM370PSW state missing rawHex")
  return self~loadRawHex(d["rawHex"])

::method normaliseHex private
  use strict arg value, width
  value=value~string~space(0)~translate
  if value~length \= width | verify(value,"0123456789ABCDEF") \= 0 then
    raise syntax 93.900 array("expected" width "hex digits",value)
  return value


::class IBM370Storage subclass AlchemyObject public

::method init
  expose sizeBytes keyBlockSize pageSize bytes mappedPages storageKeys
  use strict arg requestedSize=1048576, requestedKeyBlockSize=2048
  self~init:super
  if \datatype(requestedSize,"W") | requestedSize < 65536 then
    raise syntax 93.900 array("storage size must be integer >= 65536",requestedSize)
  if \datatype(requestedKeyBlockSize,"W") | requestedKeyBlockSize < 1 then
    raise syntax 93.900 array("storage-key block size must be positive integer",requestedKeyBlockSize)
  sizeBytes=requestedSize
  keyBlockSize=requestedKeyBlockSize
  pageSize=256
  bytes=.table~new
  mappedPages=.table~new
  storageKeys=.table~new

::method stateSchema
  return "IBM370_STORAGE_STATE/1"

::method sizeBytes
  expose sizeBytes
  return sizeBytes

::method keyBlockSize
  expose keyBlockSize
  return keyBlockSize

::method pageSize
  expose pageSize
  return pageSize

::method byteAt
  expose bytes
  use strict arg address
  self~assertAddress(address)
  v=bytes~at(address)
  if v == .nil then return 0
  return v

::method storeByte
  expose bytes mappedPages pageSize
  use strict arg address,value
  self~assertAddress(address)
  if \datatype(value,"W") | value < 0 | value > 255 then raise syntax 93.900 array("byte must be integer 0..255",value)
  page=address % pageSize
  if value=0 then do
    bytes~remove(address)
    if mappedPages~hasIndex(page) then do
      any=0; base=page*pageSize
      do i=0 to pageSize-1 while \any
        if bytes~hasIndex(base+i) then any=1
      end
      if \any then mappedPages~remove(page)
    end
  end
  else do
    bytes[address]=value
    mappedPages[page]=1
  end
  return self

::method zeroRange
  expose bytes mappedPages pageSize
  use strict arg address,count
  if \datatype(count,"W") | count<0 then raise syntax 93.900 array("zeroRange count must be nonnegative integer",count)
  if count=0 then return self
  self~assertAddress(address); self~assertAddress(address+count-1)
  firstPage=address % pageSize; lastPage=(address+count-1) % pageSize
  do page=firstPage to lastPage
    if \mappedPages~hasIndex(page) then iterate
    base=page*pageSize; first=address; if first<base then first=base
    endAddr=address+count-1; if endAddr>base+pageSize-1 then endAddr=base+pageSize-1
    do a=first to endAddr; bytes~remove(a); end
    any=0
    do a=base to base+pageSize-1 while \any
      if bytes~hasIndex(a) then any=1
    end
    if \any then mappedPages~remove(page)
  end
  return self

::method storeHex
  expose bytes mappedPages pageSize
  use strict arg address,hexData
  h=hexData~string~space(0)~translate
  if h~length // 2 \= 0 | verify(h,"0123456789ABCDEF") \= 0 then raise syntax 93.900 array("storeHex requires even hexadecimal text",hexData)
  count=h~length%2
  if count=0 then return self
  self~assertAddress(address); self~assertAddress(address+count-1)
  if verify(h,"0")=0 then return self~zeroRange(address,count)
  bin=x2c(h)
  /* CPU stores are overwhelmingly 1/2/4/8 bytes.  Avoid allocating a
   * Directory merely to remember which one or two sparse pages may need
   * reconciliation. */
  if count<=8 then do
    firstPage=address%pageSize; lastPage=(address+count-1)%pageSize; sawZero=0
    do i=0 to count-1
      a=address+i; page=a%pageSize; v=c2d(bin~substr(i+1,1))
      if v=0 then do; bytes~remove(a); sawZero=1; end
      else do; bytes[a]=v; mappedPages[page]=1; end
    end
    if sawZero then do page=firstPage to lastPage
      if \mappedPages~hasIndex(page) then iterate
      any=0; base=page*pageSize
      do a=base to base+pageSize-1 while \any
        if bytes~hasIndex(a) then any=1
      end
      if \any then mappedPages~remove(page)
    end
    return self
  end
  checkPages=.directory~new
  do i=0 to count-1
    a=address+i; page=a%pageSize; v=c2d(bin~substr(i+1,1))
    if v=0 then do; bytes~remove(a); checkPages[page]=1; end
    else do; bytes[a]=v; mappedPages[page]=1; end
  end
  do page over checkPages~allIndexes
    if \mappedPages~hasIndex(page) then iterate
    any=0; base=page*pageSize
    do a=base to base+pageSize-1 while \any
      if bytes~hasIndex(a) then any=1
    end
    if \any then mappedPages~remove(page)
  end
  return self

::method rangeIsZero
  expose bytes mappedPages pageSize
  use strict arg address,count
  if \datatype(count,"W") | count<0 then raise syntax 93.900 array("rangeIsZero count must be nonnegative integer",count)
  if count=0 then return 1
  self~assertAddress(address); self~assertAddress(address+count-1)
  firstPage=address % pageSize; lastPage=(address+count-1) % pageSize
  do page=firstPage to lastPage
    if \mappedPages~hasIndex(page) then iterate
    base=page*pageSize; first=address; if first<base then first=base
    endAddr=address+count-1; if endAddr>base+pageSize-1 then endAddr=base+pageSize-1
    do a=first to endAddr
      if bytes~hasIndex(a) then return 0
    end
  end
  return 1

::method fetchHex
  expose bytes
  use strict arg address,count
  if \datatype(count,"W") | count < 0 then raise syntax 93.900 array("count must be nonnegative integer",count)
  if count=0 then return ""
  self~assertAddress(address); self~assertAddress(address+count-1)
  if count<=8 then do
    out=""
    do i=0 to count-1
      v=bytes~at(address+i); if v==.nil then v=0
      out=out||d2x(v,2)
    end
    return out
  end
  out=.MutableBuffer~new
  do i=0 to count-1
    v=bytes~at(address+i); if v==.nil then v=0
    out~append(d2c(v))
  end
  return c2x(out~string)

::method clear
  expose bytes mappedPages storageKeys
  bytes=.table~new
  mappedPages=.table~new
  storageKeys=.table~new
  return self

::method storageKeyRaw
  expose storageKeys keyBlockSize
  use strict arg blockNumber
  if \datatype(blockNumber,"W") | blockNumber < 0 then raise syntax 93.900 array("invalid storage-key block",blockNumber)
  v=storageKeys~at(blockNumber)
  if v == .nil then return 0
  return v

::method setStorageKeyRaw
  expose storageKeys
  use strict arg blockNumber,value
  if \datatype(blockNumber,"W") | blockNumber < 0 then raise syntax 93.900 array("invalid storage-key block",blockNumber)
  if \datatype(value,"W") | value < 0 | value > 255 then raise syntax 93.900 array("invalid raw storage key",value)
  if value=0 then storageKeys~remove(blockNumber)
  else storageKeys[blockNumber]=value
  return self

::method mappedPageNumbers
  expose mappedPages
  a=.array~new
  do p over mappedPages~allIndexes
    a~append(p)
  end
  if a~items>1 then a~sort
  return a

::method storageKeyBlocks
  expose storageKeys
  a=.array~new
  do k over storageKeys~allIndexes
    a~append(k)
  end
  if a~items>1 then a~sort
  return a

::method state
  expose sizeBytes keyBlockSize pageSize mappedPages storageKeys
  d=.directory~new
  d["sizeBytes"]=sizeBytes
  d["keyBlockSize"]=keyBlockSize
  d["pageSize"]=pageSize
  pages=.directory~new
  do p over self~mappedPageNumbers
    pages[p]=self~fetchHex(p*pageSize,pageSize)
  end
  keys=.directory~new
  do k over self~storageKeyBlocks
    keys[k]=self~storageKeyRaw(k)
  end
  d["pages"]=pages
  d["storageKeys"]=keys
  return d

::method restoreState
  expose sizeBytes keyBlockSize pageSize bytes mappedPages storageKeys
  use strict arg d
  if \d~isA(.Directory) then raise syntax 88.900 array("IBM370Storage state must be Directory")
  do required over .array~of("sizeBytes","keyBlockSize","pageSize","pages","storageKeys")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370Storage state missing" required)
  end
  if d["sizeBytes"] \= sizeBytes | d["keyBlockSize"] \= keyBlockSize | d["pageSize"] \= pageSize then
    raise syntax 40.900 array("IBM370Storage geometry mismatch")
  bytes=.table~new
  mappedPages=.table~new
  storageKeys=.table~new
  pages=d["pages"]
  if \pages~isA(.Directory) then raise syntax 40.900 array("IBM370Storage pages must be Directory")
  do p over pages~allIndexes
    if \datatype(p,"W") | p<0 then raise syntax 40.900 array("invalid IBM370Storage page",p)
    h=pages[p]~string~space(0)~translate
    if h~length \= pageSize*2 | verify(h,"0123456789ABCDEF") \= 0 then raise syntax 40.900 array("invalid IBM370Storage page payload",p)
    self~storeHex(p*pageSize,h)
  end
  keys=d["storageKeys"]
  if \keys~isA(.Directory) then raise syntax 40.900 array("IBM370Storage storageKeys must be Directory")
  do k over keys~allIndexes
    self~setStorageKeyRaw(k,keys[k])
  end
  return self

::method assertAddress private
  expose sizeBytes
  use strict arg address
  if \datatype(address,"W") | address < 0 | address >= sizeBytes then
    raise syntax 93.900 array("IBM370 storage address outside installed storage",address)
  return 1


::class IBM370CPU subclass AlchemyObject public

::method init
  expose psw gprs crs fprs prefix stopped checkStopped instructionCount
  self~init:super
  psw=.IBM370PSW~new
  gprs=.array~new(16)
  crs=.array~new(16)
  fprs=.array~new(4)
  do i=1 to 16
    gprs[i]=0
    crs[i]=0
  end
  do i=1 to 4
    fprs[i]="0000000000000000"
  end
  prefix=0
  stopped=1
  checkStopped=0
  instructionCount=0

::method stateSchema
  return "IBM370_CPU_STATE/1"

::method psw
  expose psw
  return psw

::method gpr
  expose gprs
  use strict arg n
  self~assertRegister(n,15)
  return gprs[n+1]

::method setGpr
  expose gprs
  use strict arg n,value
  self~assertRegister(n,15)
  if \datatype(value,"W") | value<0 | value>4294967295 then raise syntax 93.900 array("GPR must be unsigned 32-bit integer",value)
  gprs[n+1]=value
  return self

/* Executor-only register accessors.  System/370 instruction register fields are
 * physically four bits, so decoded operands are already in 0..15.  Keep the
 * public gpr/setGpr API validated; these remove redundant datatype/range checks
 * from the instruction hot path only. */
::method gprFast
  expose gprs
  use strict arg n
  return gprs[n+1]

::method setGprFast
  expose gprs
  use strict arg n,value
  gprs[n+1]=value
  return self

::method cr
  expose crs
  use strict arg n
  self~assertRegister(n,15)
  return crs[n+1]

::method setCr
  expose crs
  use strict arg n,value
  self~assertRegister(n,15)
  if \datatype(value,"W") | value<0 | value>4294967295 then raise syntax 93.900 array("CR must be unsigned 32-bit integer",value)
  crs[n+1]=value
  return self

::method fprHex
  expose fprs
  use strict arg n
  self~assertRegister(n,3)
  return fprs[n+1]

::method setFprHex
  expose fprs
  use strict arg n,value
  self~assertRegister(n,3)
  h=value~string~space(0)~translate
  if h~length \=16 | verify(h,"0123456789ABCDEF") \=0 then raise syntax 93.900 array("FPR requires 16 hex digits",value)
  fprs[n+1]=h
  return self

::method prefix
  expose prefix
  return prefix

::method setPrefix
  expose prefix
  use strict arg value
  if \datatype(value,"W") | value<0 | value>16777215 then raise syntax 93.900 array("S/370 prefix outside 24-bit address",value)
  prefix=value
  return self

::method stopped
  expose stopped
  return stopped

::method start
  expose stopped
  stopped=0
  return self

::method stop
  expose stopped
  stopped=1
  return self

::method instructionCount
  expose instructionCount
  return instructionCount

::method noteInstruction
  expose instructionCount
  instructionCount=instructionCount+1
  return instructionCount

::method resetForIPL
  expose psw gprs crs fprs prefix stopped checkStopped instructionCount
  psw~loadRawHex("0000000000000000")
  gprs=.array~new(16)
  crs=.array~new(16)
  fprs=.array~new(4)
  do i=1 to 16
    gprs[i]=0
    crs[i]=0
  end
  do i=1 to 4
    fprs[i]="0000000000000000"
  end
  prefix=0
  stopped=1
  checkStopped=0
  instructionCount=0
  return self

::method loadIPLPSW
  expose psw stopped
  use strict arg rawHex
  psw~loadRawHex(rawHex)
  stopped=0
  return self

::method state
  expose psw gprs crs fprs prefix stopped checkStopped instructionCount
  d=.directory~new
  d["psw"]=psw~rawHex
  d["prefix"]=prefix
  d["stopped"]=stopped
  d["checkStopped"]=checkStopped
  d["instructionCount"]=instructionCount
  rg=.array~new(16)
  rc=.array~new(16)
  rf=.array~new(4)
  do i=1 to 16
    rg[i]=gprs[i]
    rc[i]=crs[i]
  end
  do i=1 to 4
    rf[i]=fprs[i]
  end
  d["gprs"]=rg
  d["crs"]=rc
  d["fprs"]=rf
  return d

::method restoreState
  expose psw gprs crs fprs prefix stopped checkStopped instructionCount
  use strict arg d
  if \d~isA(.Directory) then raise syntax 88.900 array("IBM370CPU state must be Directory")
  do required over .array~of("psw","prefix","stopped","checkStopped","instructionCount","gprs","crs","fprs")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370CPU state missing" required)
  end
  if d["gprs"]~items \=16 | d["crs"]~items \=16 | d["fprs"]~items \=4 then raise syntax 40.900 array("IBM370CPU register shape mismatch")
  psw~loadRawHex(d["psw"])
  prefix=d["prefix"]
  stopped=d["stopped"]
  checkStopped=d["checkStopped"]
  instructionCount=d["instructionCount"]
  do i=1 to 16
    gprs[i]=d["gprs"][i]
    crs[i]=d["crs"][i]
  end
  do i=1 to 4
    fprs[i]=d["fprs"][i]
  end
  return self

::method assertRegister private
  use strict arg n,max
  if \datatype(n,"W") | n<0 | n>max then raise syntax 93.900 array("invalid IBM370 register",n)
  return 1


::class IBM370Clock subclass AlchemyObject public

::method init
  expose todValue cpuTimer clockComparatorHex epochTag intervalTimerPending
  use strict arg initialTod="0000000000000000", initialEpoch="FROZEN"
  self~init:super
  todValue=x2d(self~hex64(initialTod))
  cpuTimer=0
  clockComparatorHex="FFFFFFFFFFFFFFFF"
  epochTag=initialEpoch~string
  intervalTimerPending=0

::method stateSchema
  return "IBM370_CLOCK_STATE/1"

::method todHex
  expose todValue
  return d2x(todValue,16)

::method cpuTimer
  expose cpuTimer
  return cpuTimer

::method clockComparatorHex
  expose clockComparatorHex
  return clockComparatorHex

::method epochTag
  expose epochTag
  return epochTag

::method intervalTimerPending
  expose intervalTimerPending
  return intervalTimerPending

::method clearIntervalTimerPending
  expose intervalTimerPending
  intervalTimerPending=0
  return self

::method setTodHex
  expose todValue
  use strict arg value
  todValue=x2d(self~hex64(value))
  return self

::method setCpuTimer
  expose cpuTimer
  use strict arg value
  if \datatype(value,"W") then raise syntax 93.900 array("CPU timer must be integer",value)
  cpuTimer=value
  return self

::method setClockComparatorHex
  expose clockComparatorHex
  use strict arg value
  clockComparatorHex=self~hex64(value)
  return self

::method intervalTimerInstructionQuantum
  return 10000

::method advanceOneInstruction
  expose todValue intervalTimerPending
  use strict arg storage,prefix,newInstructionCount
  /* Exact one-instruction fast path for the ordinary executor.  The general
   * range method remains authoritative for equivalence accelerators. */
  todValue=todValue+4096
  if todValue>=18446744073709551616 then todValue=todValue-18446744073709551616
  if newInstructionCount//10000=0 then do
    address=prefix+x2d("50")
    raw=x2d(storage~fetchHex(address,4)); signed=raw; if signed>=2147483648 then signed=signed-4294967296
    newSigned=signed-x2d("300")
    if signed>=0 & newSigned<0 then intervalTimerPending=1
    wrapped=newSigned//4294967296; if wrapped<0 then wrapped=wrapped+4294967296
    storage~storeHex(address,d2x(wrapped,8))
    return 1
  end
  return 0

::method advanceInstructionRange
  expose todValue intervalTimerPending
  use strict arg storage,prefix,oldInstructionCount,newInstructionCount
  if newInstructionCount<oldInstructionCount then raise syntax 93.900 array("clock instruction range went backwards")
  quantum=self~intervalTimerInstructionQuantum
  ticks=(newInstructionCount%quantum)-(oldInstructionCount%quantum)
  if ticks>0 then do
    address=prefix+x2d("50")
    raw=x2d(storage~fetchHex(address,4)); signed=raw; if signed>=2147483648 then signed=signed-4294967296
    newSigned=signed-ticks*x2d("300")
    if signed>=0 & newSigned<0 then intervalTimerPending=1
    wrapped=newSigned//4294967296; if wrapped<0 then wrapped=wrapped+4294967296
    storage~storeHex(address,d2x(wrapped,8))
  end
  /* Make TOD deterministic and monotonically advance with guest instructions.
   * We use one microsecond per instruction; STCK consumes this state, never host time. */
  delta=newInstructionCount-oldInstructionCount
  if delta>0 then do
    todValue=(todValue + delta*4096)//18446744073709551616
  end
  return ticks

::method state
  expose todValue cpuTimer clockComparatorHex epochTag intervalTimerPending
  d=.directory~new
  d["todHex"]=d2x(todValue,16)
  d["cpuTimer"]=cpuTimer
  d["clockComparatorHex"]=clockComparatorHex
  d["epochTag"]=epochTag
  d["intervalTimerPending"]=intervalTimerPending
  return d

::method restoreState
  expose todValue cpuTimer clockComparatorHex epochTag intervalTimerPending
  use strict arg d
  do required over .array~of("todHex","cpuTimer","clockComparatorHex","epochTag")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370Clock state missing" required)
  end
  todValue=x2d(self~hex64(d["todHex"]))
  cpuTimer=d["cpuTimer"]
  clockComparatorHex=self~hex64(d["clockComparatorHex"])
  epochTag=d["epochTag"]
  if d~hasIndex("intervalTimerPending") then intervalTimerPending=d["intervalTimerPending"]; else intervalTimerPending=0
  return self

::method hex64 private
  use strict arg value
  h=value~string~space(0)~translate
  if h~length \=16 | verify(h,"0123456789ABCDEF") \=0 then raise syntax 93.900 array("expected 16 hex digits",value)
  return h


::requires "AlchemyObject.cls"
