/* IBM370IO.cls - System/370 channel/device state contracts.
 *
 * v0.2 models IPL as a genuine channel program.  The implied Read IPL CCW
 * reads 24 bytes into absolute zero; command chaining then begins at 000008.
 * Active channel-program state is explicit and checkpointable.
 */

::class IBM370CCW0 public

::method init
  use strict arg value
  self~reset(value)

::method reset
  expose rawHex commandCode dataAddress flags reserved count
  use strict arg value
  h=value~string~space(0)~translate
  if h~length \=16 | verify(h,"0123456789ABCDEF") \=0 then raise syntax 93.900 array("CCW0 requires exactly 8 bytes of hex",value)
  rawHex=h
  commandCode=x2d(h~substr(1,2))
  dataAddress=x2d(h~substr(3,6))
  flags=x2d(h~substr(9,2))
  reserved=x2d(h~substr(11,2))
  count=x2d(h~substr(13,4))
  if flags // 4 \= 0 then raise syntax 40.900 array("CCW0 flag bits 38-39 must be zero",h)
  return self

::method stateSchema
  return "IBM370_CCW0_STATE/1"

::method rawHex
  expose rawHex
  return rawHex

::method commandCode
  expose commandCode
  return commandCode

::method commandHex
  expose commandCode
  return d2x(commandCode,2)

::method dataAddress
  expose dataAddress
  return dataAddress

::method flags
  expose flags
  return flags

::method reserved
  expose reserved
  return reserved

::method count
  expose count
  return count

::method dataChain
  expose flags
  return ((flags % 128) // 2)=1

::method commandChain
  expose flags
  return ((flags % 64) // 2)=1

::method suppressLength
  expose flags
  return ((flags % 32) // 2)=1

::method skip
  expose flags
  return ((flags % 16) // 2)=1

::method pci
  expose flags
  return ((flags % 8) // 2)=1

::method ida
  expose flags
  return ((flags % 4) // 2)=1

::method isTIC
  expose commandCode
  return commandCode=8

::method state
  expose rawHex commandCode dataAddress flags reserved count
  d=.directory~new
  d["rawHex"]=rawHex
  d["commandCode"]=commandCode
  d["dataAddress"]=dataAddress
  d["flags"]=flags
  d["reserved"]=reserved
  d["count"]=count
  return d


::class IBM370IOResult public

::method init
  use strict arg moved=0,remain=0,uStatus=12,cStatus=0,description="OK",isPending=0
  self~reset(moved,remain,uStatus,cStatus,description,isPending)

::method reset
  expose transferred residual unitStatus channelStatus detail pendingFlag
  use strict arg moved=0,remain=0,uStatus=12,cStatus=0,description="OK",isPending=0
  transferred=moved
  residual=remain
  unitStatus=uStatus
  channelStatus=cStatus
  detail=description~string
  pendingFlag=(isPending<>0)
  return self

::method transferred
  expose transferred
  return transferred

::method residual
  expose residual
  return residual

::method unitStatus
  expose unitStatus
  return unitStatus

::method channelStatus
  expose channelStatus
  return channelStatus

::method detail
  expose detail
  return detail

::method pending
  expose pendingFlag
  return pendingFlag

::method successful
  expose channelStatus unitStatus
  /* CE+DE are X'0C'.  Unit Check X'02' / Unit Exception X'01' are failures
   * for our v0.2 IPL nucleus. */
  return channelStatus=0 & unitStatus//4=0

::method statusModifier
  expose unitStatus
  return (unitStatus // 128) >= 64


::class IBM370IODevice subclass AlchemyObject public

::method init
  expose deviceNumber deviceType online reusableResult
  use strict arg number,type="GENERIC"
  self~init:super
  if \datatype(number,"W") | number<0 | number>65535 then raise syntax 93.900 array("device number must be 0..65535",number)
  deviceNumber=number
  deviceType=type~string~translate
  online=1
  reusableResult=.IBM370IOResult~new

::method ioResult
  expose reusableResult
  use strict arg moved=0,remain=0,uStatus=12,cStatus=0,description="OK",pending=0
  return reusableResult~reset(moved,remain,uStatus,cStatus,description,pending)

::method stateSchema
  return "IBM370_DEVICE_STATE/1"

::method deviceNumber
  expose deviceNumber
  return deviceNumber

::method deviceType
  expose deviceType
  return deviceType

::method online
  expose online
  return online

::method setOnline
  expose online
  use strict arg value
  online=(value<>0)
  return self

::method state
  expose deviceNumber deviceType online
  d=.directory~new
  d["deviceNumber"]=deviceNumber
  d["deviceType"]=deviceType
  d["online"]=online
  return d

::method restoreState
  expose deviceNumber deviceType online
  use strict arg d
  do required over .array~of("deviceNumber","deviceType","online")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370IODevice state missing" required)
  end
  if d["deviceNumber"] \= deviceNumber | d["deviceType"] \= deviceType then raise syntax 40.900 array("IBM370IODevice identity mismatch")
  online=d["online"]
  return self

::method executeCCW
  use strict arg ccw,storage,program=.nil
  raise syntax 40.900 array("IBM370 device has no CCW implementation",self~deviceType,ccw~commandHex)
  return .nil


/* IBM 3215 printer-keyboard guest console.
 *
 * This is the guest-visible channel device at 001F.  It is deliberately not
 * the physical IBM 4361 operator/control console: LOAD/IPL/START/STOP remain
 * machine controls.  A READ INQUIRY with no queued keyboard record stays
 * pending at the current CCW until an external front end queues input.
 */
::class IBM3215Device subclass IBM370IODevice public

::method init
  expose connected pendingSenseHex inputRecords outputRecords alarmCount
  use strict arg number=31,isConnected=1
  self~init:super(number,"3215")
  connected=(isConnected<>0)
  pendingSenseHex="00"
  inputRecords=.array~new
  outputRecords=.array~new
  alarmCount=0

::method stateSchema
  return "IBM3215_DEVICE_STATE/1"

::method connected
  expose connected
  return connected

::method setConnected
  expose connected
  use strict arg value
  connected=(value<>0)
  return self

::method pendingSenseHex
  expose pendingSenseHex
  return pendingSenseHex

::method queueInputHex
  expose inputRecords
  use strict arg value
  h=value~string~space(0)~translate
  if h~length//2<>0 | verify(h,"0123456789ABCDEF")<>0 then raise syntax 93.900 array("3215 input must be even hexadecimal text",value)
  inputRecords~append(h)
  return self

::method pendingInputCount
  expose inputRecords
  return inputRecords~items

::method outputRecordCount
  expose outputRecords
  return outputRecords~items

::method outputRecordHex
  expose outputRecords
  use strict arg index
  if \datatype(index,"W") | index<0 | index>=outputRecords~items then raise syntax 93.900 array("3215 output record index",index)
  return outputRecords[index+1]["hex"]

::method outputRecordCommand
  expose outputRecords
  use strict arg index
  if \datatype(index,"W") | index<0 | index>=outputRecords~items then raise syntax 93.900 array("3215 output record index",index)
  return outputRecords[index+1]["command"]

::method alarmCount
  expose alarmCount
  return alarmCount

::method executeCCW
  expose connected pendingSenseHex inputRecords outputRecords alarmCount
  use strict arg ccw,storage,program=.nil
  if \ccw~isA(.IBM370CCW0) then raise syntax 88.900 array("executeCCW requires IBM370CCW0")
  if \self~online then return self~ioResult(0,ccw~count,14,0,"3215 OFFLINE")
  cmd=ccw~commandCode
  if \connected & cmd<>4 then do
    pendingSenseHex="40" /* intervention required */
    return self~ioResult(0,ccw~count,14,0,"3215 INTERVENTION REQUIRED")
  end

  select
    when cmd=1 | cmd=9 then do
      moved=ccw~count
      h=""
      if moved>0 then h=storage~fetchHex(ccw~dataAddress,moved)
      rec=.directory~new; rec["command"]=cmd; rec["hex"]=h
      outputRecords~append(rec)
      return self~ioResult(moved,0,12,0,"3215 WRITE")
    end
    when cmd=3 then return self~ioResult(0,ccw~count,12,0,"3215 NOP")
    when cmd=10 then do
      if inputRecords~items=0 then return self~ioResult(0,ccw~count,0,0,"3215 READ INQUIRY PENDING",1)
      h=inputRecords[1]; inputRecords~remove(1)
      available=h~length%2; moved=available; if moved>ccw~count then moved=ccw~count
      if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,h~left(moved*2))
      return self~ioResult(moved,ccw~count-moved,12,0,"3215 READ INQUIRY")
    end
    when cmd=11 then do
      alarmCount=alarmCount+1
      return self~ioResult(0,0,12,0,"3215 AUDIBLE ALARM")
    end
    when cmd=4 then do
      moved=ccw~count; if moved>1 then moved=1
      if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,pendingSenseHex~left(moved*2))
      pendingSenseHex="00"
      return self~ioResult(moved,ccw~count-moved,12,0,"3215 SENSE")
    end
    when cmd=x2d("E4") then do
      id="FF321500321500"; moved=id~length%2; if moved>ccw~count then moved=ccw~count
      if moved>0 & \ccw~skip then storage~storeHex(ccw~dataAddress,id~left(moved*2))
      return self~ioResult(moved,ccw~count-moved,12,0,"3215 SENSE ID")
    end
    otherwise do
      pendingSenseHex="80" /* command reject */
      return self~ioResult(0,ccw~count,14,0,"3215 COMMAND REJECT")
    end
  end

::method state
  expose connected pendingSenseHex inputRecords outputRecords alarmCount
  d=self~state:super
  d["connected"]=connected; d["pendingSenseHex"]=pendingSenseHex; d["alarmCount"]=alarmCount
  iq=.array~new; do h over inputRecords; iq~append(h); end; d["inputRecords"]=iq
  oq=.array~new
  do r over outputRecords
    c=.directory~new; c["command"]=r["command"]; c["hex"]=r["hex"]; oq~append(c)
  end
  d["outputRecords"]=oq
  return d

::method restoreState
  expose connected pendingSenseHex inputRecords outputRecords alarmCount
  use strict arg d
  self~restoreState:super(d)
  do required over .array~of("connected","pendingSenseHex","inputRecords","outputRecords","alarmCount")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM3215Device state missing" required)
  end
  connected=d["connected"]; pendingSenseHex=d["pendingSenseHex"]; alarmCount=d["alarmCount"]
  inputRecords=.array~new; do h over d["inputRecords"]; inputRecords~append(h); end
  outputRecords=.array~new
  do r over d["outputRecords"]
    c=.directory~new; c["command"]=r["command"]; c["hex"]=r["hex"]; outputRecords~append(c)
  end
  return self

/* Development sequential-record IPL fixture.
 *
 * This is deliberately NOT a tape implementation.  It supplies deterministic
 * channel records so the architecture can be tested before real media arrives.
 * records may be an Array of record hex strings or a single record string.
 */
::class IBM370IPLMemoryDevice subclass IBM370IODevice public

::method init
  expose records mediaId mediaDigest readCount recordIndex
  use strict arg number,inputRecords,identity="MEMORY-IPL",digest="UNSEALED"
  self~init:super(number,"IPL_MEMORY")
  records=.array~new
  if inputRecords~isA(.Array) then do r over inputRecords
    records~append(self~canonicalRecord(r))
  end
  else records~append(self~canonicalRecord(inputRecords))
  if records~items<1 then raise syntax 93.900 array("IPL memory fixture requires at least one record")
  mediaId=identity~string
  mediaDigest=digest~string
  readCount=0
  recordIndex=0

::method stateSchema
  return "IBM370_IPL_MEMORY_DEVICE_STATE/2"

::method mediaId
  expose mediaId
  return mediaId

::method mediaDigest
  expose mediaDigest
  return mediaDigest

::method readCount
  expose readCount
  return readCount

::method recordIndex
  expose recordIndex
  return recordIndex

::method recordCount
  expose records
  return records~items

::method recordHex
  expose records
  use strict arg index
  if \datatype(index,"W") | index<0 | index>=records~items then raise syntax 93.900 array("invalid IPL fixture record index",index)
  return records[index+1]

::method iplRead24
  h=self~nextRecord
  if h~length < 48 then raise syntax 40.900 array("Read IPL record shorter than 24 bytes",h~length%2)
  /* The implied IPL CCW has count 24 and SLI.  A longer physical record is
   * consumed as one record but only the first 24 bytes transfer. */
  return h~left(48)

::method executeCCW
  use strict arg ccw,storage,program=.nil
  if \ccw~isA(.IBM370CCW0) then raise syntax 88.900 array("executeCCW requires IBM370CCW0")
  if \self~online then return self~ioResult(0,ccw~count,14,0,"OFFLINE")

  select
    when ccw~commandCode=2 then do
      h=self~nextRecord
      recordBytes=h~length%2
      wanted=ccw~count
      moved=recordBytes
      if moved>wanted then moved=wanted
      if \ccw~skip & moved>0 then storage~storeHex(ccw~dataAddress,h~left(moved*2))
      residual=wanted-moved
      cstat=0
      if recordBytes \= wanted & \ccw~suppressLength then cstat=64 /* incorrect length */
      return self~ioResult(moved,residual,12,cstat,"READ")
    end
    when ccw~commandCode=3 then return self~ioResult(0,ccw~count,12,0,"NO-OP")
    otherwise return self~ioResult(0,ccw~count,14,32,"COMMAND REJECT")
  end

::method state
  expose records mediaId mediaDigest readCount recordIndex
  d=self~state:super
  d["mediaId"]=mediaId
  d["mediaDigest"]=mediaDigest
  d["readCount"]=readCount
  d["recordIndex"]=recordIndex
  copy=.array~new
  do r over records
    copy~append(r)
  end
  d["records"]=copy
  return d

::method restoreState
  expose records mediaId mediaDigest readCount recordIndex
  use strict arg d
  self~restoreState:super(d)
  do required over .array~of("mediaId","mediaDigest","readCount","recordIndex","records")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370IPLMemoryDevice state missing" required)
  end
  if d["mediaId"] \= mediaId | d["mediaDigest"] \= mediaDigest then raise syntax 40.900 array("IBM370IPLMemoryDevice media identity mismatch")
  other=d["records"]
  if \other~isA(.Array) | other~items \= records~items then raise syntax 40.900 array("IBM370IPLMemoryDevice record shape mismatch")
  do i=1 to records~items
    if other[i] \= records[i] then raise syntax 40.900 array("IBM370IPLMemoryDevice media content mismatch",i-1)
  end
  if \datatype(d["recordIndex"],"W") | d["recordIndex"]<0 | d["recordIndex"]>records~items then raise syntax 40.900 array("invalid IBM370IPLMemoryDevice record position")
  readCount=d["readCount"]
  recordIndex=d["recordIndex"]
  return self

::method nextRecord private
  expose records readCount recordIndex
  if \self~online then raise syntax 40.900 array("IPL device is offline",self~deviceNumber)
  if recordIndex>=records~items then raise syntax 40.900 array("IPL fixture end of media",recordIndex)
  h=records[recordIndex+1]
  recordIndex=recordIndex+1
  readCount=readCount+1
  return h

::method canonicalRecord private
  use strict arg value
  h=value~string~space(0)~translate
  if h~length//2\=0 | verify(h,"0123456789ABCDEF")\=0 then raise syntax 93.900 array("IPL fixture record must be even hexadecimal text",value)
  return h


::class IBM370ChannelProgram public

::method init
  expose deviceNumber kind currentCCWAddress active completed steps lastCCWAddress lastCommand residual unitStatus channelStatus fileMask indexMark
  use strict arg number,address=8,programKind="IPL"
  deviceNumber=number
  kind=programKind~string~translate
  currentCCWAddress=address
  active=1
  completed=0
  steps=0
  lastCCWAddress=-1
  lastCommand=-1
  residual=0
  unitStatus=0
  channelStatus=0
  fileMask=0
  indexMark=0

::method stateSchema
  return "IBM370_CHANNEL_PROGRAM_STATE/1"

::method deviceNumber
  expose deviceNumber
  return deviceNumber

::method kind
  expose kind
  return kind

::method currentCCWAddress
  expose currentCCWAddress
  return currentCCWAddress

::method active
  expose active
  return active

::method completed
  expose completed
  return completed

::method steps
  expose steps
  return steps

::method residual
  expose residual
  return residual

::method unitStatus
  expose unitStatus
  return unitStatus

::method channelStatus
  expose channelStatus
  return channelStatus

::method fileMask
  expose fileMask
  return fileMask

::method setFileMask
  expose fileMask
  use strict arg value
  if \datatype(value,"W") | value<0 | value>255 then raise syntax 93.900 array("file mask must be byte",value)
  fileMask=value
  return self

::method indexMark
  expose indexMark
  return indexMark

::method setIndexMark
  expose indexMark
  use strict arg value
  indexMark=(value<>0)
  return self

::method lastCCWAddress
  expose lastCCWAddress
  return lastCCWAddress

::method lastCommand
  expose lastCommand
  return lastCommand

::method advanceTo
  expose currentCCWAddress
  use strict arg address
  if \datatype(address,"W") | address<0 | address//8\=0 then raise syntax 40.900 array("channel CCW address must be nonnegative doubleword aligned",address)
  currentCCWAddress=address
  return self

::method noteStep
  expose steps lastCCWAddress lastCommand residual unitStatus channelStatus
  use strict arg address,command,result
  steps=steps+1
  lastCCWAddress=address
  lastCommand=command
  residual=result~residual
  unitStatus=result~unitStatus
  channelStatus=result~channelStatus
  return self

::method noteTIC
  expose steps lastCCWAddress lastCommand residual unitStatus channelStatus
  use strict arg address,target
  steps=steps+1
  lastCCWAddress=address
  lastCommand=8
  residual=0
  unitStatus=0
  channelStatus=0
  self~advanceTo(target)
  return self

::method complete
  expose active completed
  active=0
  completed=1
  return self

::method state
  expose deviceNumber kind currentCCWAddress active completed steps lastCCWAddress lastCommand residual unitStatus channelStatus fileMask indexMark
  d=.directory~new
  d["deviceNumber"]=deviceNumber
  d["kind"]=kind
  d["currentCCWAddress"]=currentCCWAddress
  d["active"]=active
  d["completed"]=completed
  d["steps"]=steps
  d["lastCCWAddress"]=lastCCWAddress
  d["lastCommand"]=lastCommand
  d["residual"]=residual
  d["unitStatus"]=unitStatus
  d["channelStatus"]=channelStatus
  d["fileMask"]=fileMask
  d["indexMark"]=indexMark
  return d

::method restoreState
  expose deviceNumber kind currentCCWAddress active completed steps lastCCWAddress lastCommand residual unitStatus channelStatus fileMask indexMark
  use strict arg d
  do required over .array~of("deviceNumber","kind","currentCCWAddress","active","completed","steps","lastCCWAddress","lastCommand","residual","unitStatus","channelStatus")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370ChannelProgram state missing" required)
  end
  if d["deviceNumber"] \= deviceNumber | d["kind"] \= kind then raise syntax 40.900 array("IBM370ChannelProgram identity mismatch")
  currentCCWAddress=d["currentCCWAddress"]
  active=d["active"]
  completed=d["completed"]
  steps=d["steps"]
  lastCCWAddress=d["lastCCWAddress"]
  lastCommand=d["lastCommand"]
  residual=d["residual"]
  unitStatus=d["unitStatus"]
  channelStatus=d["channelStatus"]
  if d~hasIndex("fileMask") then fileMask=d["fileMask"]; else fileMask=0
  if d~hasIndex("indexMark") then indexMark=d["indexMark"]; else indexMark=0
  return self


::class IBM370ChannelSubsystem subclass AlchemyObject public

::method init
  expose devices pendingInterrupts activePrograms completionStatuses startCount reusableCCW
  self~init:super
  devices=.directory~new
  pendingInterrupts=.array~new
  activePrograms=.directory~new
  completionStatuses=.directory~new
  startCount=0
  reusableCCW=.IBM370CCW0~new("0300000000000000")

::method stateSchema
  return "IBM370_CHANNEL_SUBSYSTEM_STATE/2"

::method attach
  expose devices
  use strict arg device
  if \device~isA(.IBM370IODevice) then raise syntax 88.900 array("channel attachment must be IBM370IODevice")
  key=d2x(device~deviceNumber,4)
  if devices~hasIndex(key) then raise syntax 40.900 array("duplicate IBM370 device",key)
  if \device~hasMethod("STATESCHEMA") | \device~hasMethod("STATE") | \device~hasMethod("RESTORESTATE") then raise syntax 40.900 array("IBM370 device lacks freeze contract",key)
  devices[key]=device
  return device

::method hasDevice
  expose devices
  use strict arg number
  return devices~hasIndex(d2x(number,4))

::method device
  expose devices
  use strict arg number
  d=devices~at(d2x(number,4))
  if d == .nil then raise syntax 40.900 array("IBM370 device not attached",d2x(number,4))
  return d

::method deviceNumbers
  expose devices
  a=.array~new
  do key over devices~allIndexes
    a~append(x2d(key))
  end
  if a~items>1 then a~sort
  return a

::method beginIPL
  expose activePrograms startCount
  use strict arg number,storage
  key=d2x(number,4)
  if activePrograms~hasIndex(key) then raise syntax 40.900 array("channel program already active",key)
  dev=self~device(number)
  if \dev~hasMethod("IPLREAD24") then raise syntax 40.900 array("device does not support Read IPL",key)
  first24=dev~iplRead24
  if first24~length \=48 then raise syntax 40.900 array("Read IPL did not return exactly 24 bytes",key)
  storage~storeHex(0,first24)
  p=.IBM370ChannelProgram~new(number,8,"IPL")
  activePrograms[key]=p
  startCount=startCount+1
  return p

::method activeProgram
  expose activePrograms
  use strict arg number
  p=activePrograms~at(d2x(number,4))
  if p==.nil then raise syntax 40.900 array("no active channel program",d2x(number,4))
  return p

::method hasActiveProgram
  expose activePrograms
  use strict arg number
  return activePrograms~hasIndex(d2x(number,4))

::method hasActivePrograms
  expose activePrograms
  return activePrograms~items>0

::method startIO
  expose activePrograms completionStatuses startCount
  use strict arg number,storage
  key=d2x(number,4)
  if \self~hasDevice(number) then return 3
  if activePrograms~hasIndex(key) then return 2
  /* pending status must be presented before a new operation is started */
  if completionStatuses~hasIndex(key) then return 1
  caw=storage~fetchHex(x2d("48"),4)
  addr=x2d(caw~substr(3,6))
  if addr//8<>0 then return 3
  p=.IBM370ChannelProgram~new(number,addr,"SIO")
  activePrograms[key]=p; startCount=startCount+1
  return 0

::method testIO
  expose activePrograms completionStatuses
  use strict arg number,storage
  key=d2x(number,4)
  if \self~hasDevice(number) then return 3
  if completionStatuses~hasIndex(key) then do
    st=completionStatuses[key]; self~writeCSW(storage,st); completionStatuses~remove(key); return 1
  end
  if activePrograms~hasIndex(key) then return 2
  return 0

::method testChannel
  expose devices pendingInterrupts
  use strict arg address
  /* TCH addresses a channel by the high-order byte of the 16-bit I/O
   * address.  A channel exists if at least one attached device belongs to it. */
  chan=(address%256)*256
  count=0
  do key over devices~allIndexes
    number=x2d(key)
    if (number%256)*256=chan then count=count+1
  end
  if count=0 then return 3

  /* pendingInterrupts is reserved for the later interrupting-I/O model.
   * When populated with structured entries, preserve the architectural TCH
   * CC1 rule without confusing TIO completion status with an interruption. */
  do intr over pendingInterrupts
    if intr~isA(.Directory) & intr~hasIndex("deviceNumber") then do
      number=intr["deviceNumber"]
      if (number%256)*256=chan then return 1
    end
  end
  return 0

::method writeCSW private
  use strict arg storage,st
  first="00"||d2x(st["ccwAddress"]//16777216,6)
  second=d2x(st["unitStatus"],2)||d2x(st["channelStatus"],2)||d2x(st["residual"],4)
  storage~storeHex(x2d("40"),first||second)
  return self

::method stepOneActive
  expose activePrograms
  use strict arg storage
  if activePrograms~items=0 then return .nil
  best=""
  do key over activePrograms~allIndexes
    if best="" | key<best then best=key
  end
  return self~stepProgram(x2d(best),storage)

::method activeProgramNumbers
  expose activePrograms
  a=.array~new
  do key over activePrograms~allIndexes
    a~append(x2d(key))
  end
  if a~items>1 then a~sort
  return a

::method stepProgram
  expose activePrograms reusableCCW
  use strict arg number,storage
  key=d2x(number,4)
  p=self~activeProgram(number)
  addr=p~currentCCWAddress
  if addr//8 \= 0 then raise syntax 40.900 array("unaligned channel program address",addr)
  ccw=reusableCCW~reset(storage~fetchHex(addr,8))

  if ccw~isTIC then do
    if ccw~dataAddress//8 \=0 then raise syntax 40.900 array("TIC target must be doubleword aligned",ccw~dataAddress)
    p~noteTIC(addr,ccw~dataAddress)
    return p
  end

  if ccw~dataChain then raise syntax 40.900 array("v0.2 channel nucleus does not yet implement data chaining",addr)
  if ccw~ida then raise syntax 40.900 array("v0.2 channel nucleus does not yet implement IDA",addr)
  /* PCI is architecturally ignored during IPL.  For later SIO channel programs
   * it will become an explicit interrupt event. */

  dev=self~device(number)
  ioResult=dev~executeCCW(ccw,storage,p)
  if ioResult~pending then return p
  p~noteStep(addr,ccw~commandCode,ioResult)

  if \ioResult~successful then do
    p~complete
    activePrograms~remove(key)
    if p~kind<>"IPL" then self~queueCompletion(p,addr)
    return p
  end

  if ccw~commandChain then do
    if ioResult~statusModifier then p~advanceTo(addr+16)
    else p~advanceTo(addr+8)
  end
  else do
    p~complete
    activePrograms~remove(key)
    if p~kind<>"IPL" then self~queueCompletion(p,addr)
  end
  return p

::method queueCompletion private
  expose completionStatuses
  use strict arg p,lastAddress
  st=.directory~new
  st["ccwAddress"]=(lastAddress+8)//16777216
  st["unitStatus"]=p~unitStatus
  st["channelStatus"]=p~channelStatus
  st["residual"]=p~residual
  completionStatuses[d2x(p~deviceNumber,4)]=st
  return self

::method completedStatusCount
  expose completionStatuses
  return completionStatuses~items

::method restoreActiveProgram
  expose activePrograms
  use strict arg p
  if \p~isA(.IBM370ChannelProgram) then raise syntax 88.900 array("restoreActiveProgram requires IBM370ChannelProgram")
  if \p~active | p~completed then raise syntax 40.900 array("cannot restore non-active channel program")
  key=d2x(p~deviceNumber,4)
  if activePrograms~hasIndex(key) then raise syntax 40.900 array("duplicate restored channel program",key)
  if \self~hasDevice(p~deviceNumber) then raise syntax 40.900 array("restored channel program references unattached device",key)
  activePrograms[key]=p
  return p

::method pendingInterruptCount
  expose pendingInterrupts
  return pendingInterrupts~items

::method state
  expose pendingInterrupts activePrograms completionStatuses startCount
  d=.directory~new
  d["startCount"]=startCount
  d["pendingInterruptCount"]=pendingInterrupts~items
  d["activeProgramCount"]=activePrograms~items
  d["completedStatusCount"]=completionStatuses~items
  return d

::method restoreState
  expose startCount pendingInterrupts activePrograms completionStatuses
  use strict arg d
  do required over .array~of("startCount","pendingInterruptCount","activeProgramCount")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM370ChannelSubsystem state missing" required)
  end
  /* Interrupt-event encoding is deliberately not guessed in v0.2. */
  if d["pendingInterruptCount"] \=0 then raise syntax 40.900 array("v0.2 loader cannot reconstruct pending channel interrupts")
  if d~hasIndex("completedStatusCount") & d["completedStatusCount"] \=0 then raise syntax 40.900 array("v0.2 loader cannot reconstruct completed TIO status")
  startCount=d["startCount"]
  pendingInterrupts=.array~new
  activePrograms=.directory~new
  completionStatuses=.directory~new
  return self


::requires "AlchemyObject.cls"
