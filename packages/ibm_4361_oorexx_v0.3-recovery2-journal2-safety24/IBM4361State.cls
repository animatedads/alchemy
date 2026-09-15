/* IBM4361State.cls - explicit architectural freeze/load format.
 *
 * State is a versioned architectural contract, not an ooRexx object dump.
 * v2 adds active System/370 channel-program state and sequential-media position.
 */

::class IBM4361FrozenState public

::method init
  expose encoded recordCount
  use strict arg text,count
  encoded=text
  recordCount=count

::method encoded
  expose encoded
  return encoded

::method recordCount
  expose recordCount
  return recordCount

::method save
  expose encoded
  use strict arg path
  s=.stream~new(path)
  ignored=s~open("WRITE REPLACE")
  if s~state \= "READY" then raise syntax 40.900 array("cannot create IBM4361 state file",path)
  ignored=s~charout(encoded)
  ignored=s~close
  return self


::class IBM4361State public

::method schemaId
  return "IBM4361_STATE/2"

::method freeze
  use strict arg machine
  if \machine~isA(.IBM4361Machine) then raise syntax 88.900 array("freeze requires IBM4361Machine")
  lines=.array~new
  lines~append("IBM4361_STATE 2")

  ms=machine~state
  lines~append("MACHINE" self~atom(ms["model"]) self~atom(ms["machinePhase"]) ms["eventSequence"] ms["lastIPLDevice"])

  cpu=machine~cpu
  cs=cpu~state
  lines~append("CPU" cpu~stateSchema self~atom(cs["psw"]) cs["prefix"] cs["stopped"] cs["checkStopped"] cs["instructionCount"])
  do i=0 to 15
    lines~append("GPR" i cs["gprs"][i+1])
    lines~append("CR" i cs["crs"][i+1])
  end
  do i=0 to 3
    lines~append("FPR" i cs["fprs"][i+1])
  end

  clk=machine~clock
  ks=clk~state
  lines~append("CLOCK" clk~stateSchema self~atom(ks["todHex"]) ks["cpuTimer"] self~atom(ks["clockComparatorHex"]) self~atom(ks["epochTag"]))

  ch=machine~channels
  hs=ch~state
  if hs["pendingInterruptCount"] \= 0 then raise syntax 40.900 array("v0.2 freeze has no pending-interrupt codec")
  lines~append("CHANNELS" ch~stateSchema hs["startCount"] hs["pendingInterruptCount"] hs["activeProgramCount"])
  programs=ch~activeProgramNumbers
  do n over programs
    p=ch~activeProgram(n)
    ps=p~state
    lines~append("CHANNELPROGRAM" d2x(n,4) p~stateSchema self~atom(ps["kind"]) ps["currentCCWAddress"] ps["active"] ps["completed"] ps["steps"] ps["lastCCWAddress"] ps["lastCommand"] ps["residual"] ps["unitStatus"] ps["channelStatus"])
  end

  nums=ch~deviceNumbers
  lines~append("DEVICECOUNT" nums~items)
  do n over nums
    dev=ch~device(n)
    if \dev~hasMethod("STATESCHEMA") | \dev~hasMethod("STATE") | \dev~hasMethod("RESTORESTATE") then raise syntax 40.900 array("attached IBM device lacks complete freeze contract",d2x(n,4))
    ds=dev~state
    lines~append("DEVICE" d2x(n,4) dev~deviceType dev~stateSchema ds["online"])
    if dev~isA(.IBM370IPLMemoryDevice) then do
      lines~append("IPLDEV" d2x(n,4) self~atom(ds["mediaId"]) self~atom(ds["mediaDigest"]) ds["readCount"] ds["recordIndex"] ds["records"]~items)
      do r=1 to ds["records"]~items
        lines~append("IPLREC" d2x(n,4) r-1 ds["records"][r])
      end
    end
    else raise syntax 40.900 array("v0.2 freeze has no explicit device codec",d2x(n,4),dev~deviceType)
  end

  mem=machine~storage
  ss=mem~state
  lines~append("STORAGE" mem~stateSchema ss["sizeBytes"] ss["keyBlockSize"] ss["pageSize"] ss["pages"]~items ss["storageKeys"]~items)
  pages=ss["pages"]
  pkeys=pages~allIndexes
  if pkeys~items>1 then pkeys~sort
  do p over pkeys
    lines~append("PAGE" p pages[p])
  end
  sk=ss["storageKeys"]
  skeys=sk~allIndexes
  if skeys~items>1 then skeys~sort
  do k over skeys
    lines~append("STORAGEKEY" k sk[k])
  end

  payload=lines~makeString("L","0a"x) || "0a"x
  digest=.SHA512~new(payload)~digest
  lines~append("STATEHASH" digest)
  lines~append("END")
  text=lines~makeString("L","0a"x) || "0a"x
  return .IBM4361FrozenState~new(text,lines~items)

::method save
  use strict arg machine,path
  self~freeze(machine)~save(path)
  return self

::method load
  use strict arg path
  s=.stream~new(path)
  ignored=s~open("READ")
  if s~state \= "READY" then raise syntax 40.900 array("cannot open IBM4361 state file",path)

  header=s~linein
  parse var header magic version extra
  if magic\="IBM4361_STATE" | version\=2 | extra\="" then do
    ignored=s~close
    raise syntax 40.900 array("unsupported IBM4361 state header",header)
  end

  machineRec=.nil; cpuRec=.nil; clockRec=.nil; channelRec=.nil; storageRec=.nil
  gprs=.array~new(16); crs=.array~new(16); fprs=.array~new(4)
  gSeen=.table~new; cSeen=.table~new; fSeen=.table~new
  devices=.directory~new; iplRows=.directory~new; programRows=.directory~new
  pages=.directory~new; storageKeys=.directory~new
  deviceCount=.nil; endSeen=0; stateHash=.nil
  hashLines=.array~new
  hashLines~append(header)

  do while s~lines>0
    line=s~linein
    parse var line tag rest
    if tag \= "STATEHASH" & tag \= "END" then hashLines~append(line)
    select
      when tag="MACHINE" then do
        if machineRec \== .nil then ignored=self~fail(s,"duplicate MACHINE")
        parse var rest model phase eventSequence lastIPLDevice extra
        if extra\="" then ignored=self~fail(s,"invalid MACHINE")
        machineRec=.array~of(self~unatom(model),self~unatom(phase),eventSequence,lastIPLDevice)
      end
      when tag="CPU" then do
        if cpuRec \== .nil then ignored=self~fail(s,"duplicate CPU")
        parse var rest schema psw prefix stopped checkStopped instructionCount extra
        if schema\="IBM370_CPU_STATE/1" | extra\="" then ignored=self~fail(s,"invalid CPU")
        cpuRec=.array~of(self~unatom(psw),prefix,stopped,checkStopped,instructionCount)
      end
      when tag="GPR" then do
        parse var rest n value extra
        if extra\="" | \datatype(n,"W") | n<0 | n>15 | gSeen~hasIndex(n) then ignored=self~fail(s,"invalid/duplicate GPR")
        gprs[n+1]=value; gSeen[n]=1
      end
      when tag="CR" then do
        parse var rest n value extra
        if extra\="" | \datatype(n,"W") | n<0 | n>15 | cSeen~hasIndex(n) then ignored=self~fail(s,"invalid/duplicate CR")
        crs[n+1]=value; cSeen[n]=1
      end
      when tag="FPR" then do
        parse var rest n value extra
        if extra\="" | \datatype(n,"W") | n<0 | n>3 | fSeen~hasIndex(n) then ignored=self~fail(s,"invalid/duplicate FPR")
        fprs[n+1]=value; fSeen[n]=1
      end
      when tag="CLOCK" then do
        if clockRec \== .nil then ignored=self~fail(s,"duplicate CLOCK")
        parse var rest schema tod cpuTimer comparator epoch extra
        if schema\="IBM370_CLOCK_STATE/1" | extra\="" then ignored=self~fail(s,"invalid CLOCK")
        clockRec=.array~of(self~unatom(tod),cpuTimer,self~unatom(comparator),self~unatom(epoch))
      end
      when tag="CHANNELS" then do
        if channelRec \== .nil then ignored=self~fail(s,"duplicate CHANNELS")
        parse var rest schema startCount pending active extra
        if schema\="IBM370_CHANNEL_SUBSYSTEM_STATE/2" | extra\="" then ignored=self~fail(s,"invalid CHANNELS")
        channelRec=.array~of(startCount,pending,active)
      end
      when tag="CHANNELPROGRAM" then do
        parse var rest number schema kind current active completed steps lastAddress lastCommand residual unitStatus channelStatus extra
        if extra\="" | number~length\=4 | programRows~hasIndex(number) then ignored=self~fail(s,"invalid/duplicate CHANNELPROGRAM")
        if schema\="IBM370_CHANNEL_PROGRAM_STATE/1" then ignored=self~fail(s,"unsupported CHANNELPROGRAM schema")
        row=.directory~new
        row["number"]=number; row["kind"]=self~unatom(kind); row["currentCCWAddress"]=current
        row["active"]=active; row["completed"]=completed; row["steps"]=steps
        row["lastCCWAddress"]=lastAddress; row["lastCommand"]=lastCommand; row["residual"]=residual
        row["unitStatus"]=unitStatus; row["channelStatus"]=channelStatus
        programRows[number]=row
      end
      when tag="DEVICECOUNT" then do
        if deviceCount \== .nil then ignored=self~fail(s,"duplicate DEVICECOUNT")
        parse var rest deviceCount extra
        if extra\="" | \datatype(deviceCount,"W") | deviceCount<0 then ignored=self~fail(s,"invalid DEVICECOUNT")
      end
      when tag="DEVICE" then do
        parse var rest number dtype schema online extra
        if extra\="" | number~length\=4 | devices~hasIndex(number) then ignored=self~fail(s,"invalid/duplicate DEVICE")
        row=.directory~new; row["number"]=number; row["type"]=dtype; row["schema"]=schema; row["online"]=online
        devices[number]=row
      end
      when tag="IPLDEV" then do
        parse var rest number mediaId mediaDigest readCount recordIndex recordCount extra
        if extra\="" | iplRows~hasIndex(number) | \datatype(recordCount,"W") | recordCount<1 then ignored=self~fail(s,"invalid/duplicate IPLDEV")
        row=.directory~new
        row["mediaId"]=self~unatom(mediaId); row["mediaDigest"]=self~unatom(mediaDigest)
        row["readCount"]=readCount; row["recordIndex"]=recordIndex; row["recordCount"]=recordCount
        row["records"]=.directory~new
        iplRows[number]=row
      end
      when tag="IPLREC" then do
        parse var rest number index payload extra
        if extra\="" | \iplRows~hasIndex(number) then ignored=self~fail(s,"IPLREC without IPLDEV")
        row=iplRows[number]
        if \datatype(index,"W") | index<0 | row["records"]~hasIndex(index) then ignored=self~fail(s,"invalid/duplicate IPLREC")
        if payload~length//2\=0 | verify(payload~translate,"0123456789ABCDEF")\=0 then ignored=self~fail(s,"invalid IPLREC payload")
        row["records"][index]=payload~translate
      end
      when tag="STORAGE" then do
        if storageRec \== .nil then ignored=self~fail(s,"duplicate STORAGE")
        parse var rest schema sizeBytes keyBlock pageSize pageCount keyCount extra
        if schema\="IBM370_STORAGE_STATE/1" | extra\="" then ignored=self~fail(s,"invalid STORAGE")
        storageRec=.array~of(sizeBytes,keyBlock,pageSize,pageCount,keyCount)
      end
      when tag="PAGE" then do
        parse var rest p payload extra
        if extra\="" | pages~hasIndex(p) then ignored=self~fail(s,"invalid/duplicate PAGE")
        pages[p]=payload
      end
      when tag="STORAGEKEY" then do
        parse var rest k value extra
        if extra\="" | storageKeys~hasIndex(k) then ignored=self~fail(s,"invalid/duplicate STORAGEKEY")
        storageKeys[k]=value
      end
      when tag="STATEHASH" then do
        if stateHash \== .nil then ignored=self~fail(s,"duplicate STATEHASH")
        parse var rest stateHash extra
        if extra\="" | stateHash~length\=128 | verify(stateHash~translate,"0123456789ABCDEF")\=0 then ignored=self~fail(s,"invalid STATEHASH")
      end
      when tag="END" then do
        if rest\="" then ignored=self~fail(s,"invalid END")
        endSeen=1
        leave
      end
      otherwise ignored=self~fail(s,"unknown IBM4361 state record" tag)
    end
  end
  ignored=s~close

  if machineRec==.nil | cpuRec==.nil | clockRec==.nil | channelRec==.nil | storageRec==.nil | deviceCount==.nil | stateHash==.nil | \endSeen then raise syntax 40.900 array("incomplete IBM4361 state file",path)
  expectedHash=.SHA512~new(hashLines~makeString("L","0a"x) || "0a"x)~digest
  if expectedHash \= stateHash then raise syntax 40.900 array("IBM4361 architectural state digest mismatch")
  if gSeen~items\=16 | cSeen~items\=16 | fSeen~items\=4 then raise syntax 40.900 array("incomplete IBM4361 CPU register state")
  if devices~items\=deviceCount then raise syntax 40.900 array("IBM4361 DEVICECOUNT mismatch")
  if programRows~items\=channelRec[3] then raise syntax 40.900 array("IBM4361 active channel-program count mismatch")
  if channelRec[2]\=0 then raise syntax 40.900 array("v0.2 state refuses unencoded pending channel interrupts")
  if pages~items\=storageRec[4] | storageKeys~items\=storageRec[5] then raise syntax 40.900 array("IBM4361 storage shape mismatch")

  machine=.IBM4361Machine~new(storageRec[1])
  do number over devices~allIndexes
    drow=devices[number]
    if drow["type"]="IPL_MEMORY" & drow["schema"]="IBM370_IPL_MEMORY_DEVICE_STATE/2" then do
      if \iplRows~hasIndex(number) then raise syntax 40.900 array("IPL_MEMORY device missing IPLDEV state",number)
      ir=iplRows[number]
      if ir["records"]~items \= ir["recordCount"] then raise syntax 40.900 array("IPLDEV record count mismatch",number)
      records=.array~new
      do i=0 to ir["recordCount"]-1
        if \ir["records"]~hasIndex(i) then raise syntax 40.900 array("IPLDEV missing record",number,i)
        records~append(ir["records"][i])
      end
      dev=.IBM370IPLMemoryDevice~new(x2d(number),records,ir["mediaId"],ir["mediaDigest"])
      ds=dev~state
      ds["online"]=drow["online"]; ds["readCount"]=ir["readCount"]; ds["recordIndex"]=ir["recordIndex"]
      dev~restoreState(ds)
      machine~attachDevice(dev)
    end
    else raise syntax 40.900 array("unsupported IBM4361 device codec",number,drow["type"],drow["schema"])
  end

  md=.directory~new
  md["model"]=machineRec[1]; md["machinePhase"]=machineRec[2]; md["eventSequence"]=machineRec[3]; md["lastIPLDevice"]=machineRec[4]
  machine~restoreMachineState(md)

  cd=.directory~new
  cd["psw"]=cpuRec[1]; cd["prefix"]=cpuRec[2]; cd["stopped"]=cpuRec[3]; cd["checkStopped"]=cpuRec[4]; cd["instructionCount"]=cpuRec[5]
  cd["gprs"]=gprs; cd["crs"]=crs; cd["fprs"]=fprs
  machine~cpu~restoreState(cd)

  kd=.directory~new
  kd["todHex"]=clockRec[1]; kd["cpuTimer"]=clockRec[2]; kd["clockComparatorHex"]=clockRec[3]; kd["epochTag"]=clockRec[4]
  machine~clock~restoreState(kd)

  hd=.directory~new
  hd["startCount"]=channelRec[1]; hd["pendingInterruptCount"]=channelRec[2]; hd["activeProgramCount"]=channelRec[3]
  machine~channels~restoreState(hd)
  do number over programRows~allIndexes
    pr=programRows[number]
    p=.IBM370ChannelProgram~new(x2d(number),pr["currentCCWAddress"],pr["kind"])
    pd=p~state
    do name over .array~of("currentCCWAddress","active","completed","steps","lastCCWAddress","lastCommand","residual","unitStatus","channelStatus")
      pd[name]=pr[name]
    end
    p~restoreState(pd)
    machine~channels~restoreActiveProgram(p)
  end

  sd=.directory~new
  sd["sizeBytes"]=storageRec[1]; sd["keyBlockSize"]=storageRec[2]; sd["pageSize"]=storageRec[3]; sd["pages"]=pages; sd["storageKeys"]=storageKeys
  machine~storage~restoreState(sd)

  if machine~machinePhase="IPL_IN_PROGRESS" then do
    if machine~lastIPLDevice<0 | \machine~channels~hasActiveProgram(machine~lastIPLDevice) then raise syntax 40.900 array("IPL_IN_PROGRESS state lacks matching active channel program")
  end
  return machine

::method atom private
  use strict arg value
  return c2x(value~string)

::method unatom private
  use strict arg value
  if value="" then return ""
  if value~length//2\=0 | verify(value~translate,"0123456789ABCDEF")\=0 then raise syntax 40.900 array("invalid IBM4361 state atom",value)
  return x2c(value)

::method fail private
  use strict arg stream,message
  ignored=stream~close
  raise syntax 40.900 array(message)
  return 0


::requires "IBM4361.cls"
::requires "crypto.cls"
