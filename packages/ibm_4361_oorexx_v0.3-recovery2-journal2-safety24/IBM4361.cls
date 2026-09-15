/* IBM4361.cls - inspectable/replayable IBM 4361 machine nucleus. */

::class IBM4361Machine subclass AlchemyObject public

::method init
  expose cpu storage channels clock executor model machinePhase eventSequence lastIPLDevice clearAccelAvailable keyAccelAvailable
  use strict arg storageSize=1048576,storageObject=.nil
  self~init:super
  model="IBM 4361"
  cpu=.IBM370CPU~new
  if storageObject==.nil then storage=.IBM370Storage~new(storageSize,2048)
  else do
    if \storageObject~isA(.IBM370Storage) then raise syntax 88.900 array("IBM4361 storageObject must be IBM370Storage-compatible")
    if storageObject~sizeBytes \= storageSize then raise syntax 40.900 array("IBM4361 storageObject size mismatch",storageObject~sizeBytes,storageSize)
    storage=storageObject
  end
  channels=.IBM370ChannelSubsystem~new
  clock=.IBM370Clock~new
  executor=.IBM370Executor~new(self)
  machinePhase="POWERED_OFF"
  eventSequence=0
  lastIPLDevice=-1
  clearAccelAvailable=1
  keyAccelAvailable=1

::method stateSchema
  return "IBM4361_MACHINE_STATE/2"

::method model
  expose model
  return model

::method cpu
  expose cpu
  return cpu

::method storage
  expose storage
  return storage

::method channels
  expose channels
  return channels

::method clock
  expose clock
  return clock

::method executor
  expose executor
  return executor

::method machinePhase
  expose machinePhase
  return machinePhase

::method eventSequence
  expose eventSequence
  return eventSequence

::method lastIPLDevice
  expose lastIPLDevice
  return lastIPLDevice

::method powerOn
  expose machinePhase
  if machinePhase="POWERED_OFF" then machinePhase="OPERATOR_READY"
  return self

::method powerOff
  expose machinePhase
  machinePhase="POWERED_OFF"
  return self

::method attachDevice
  expose channels
  use strict arg device
  channels~attach(device)
  return self

/* Start the architectural IPL operation but stop at a deterministic channel
 * boundary: the implied Read IPL CCW has completed and low core 0..23 exists;
 * the CPU PSW has NOT yet been loaded.  The next CCW is at absolute 8. */
::method beginInitialProgramLoad
  expose cpu storage channels machinePhase lastIPLDevice clearAccelAvailable keyAccelAvailable
  use strict arg deviceNumber
  if machinePhase="POWERED_OFF" then raise syntax 40.900 array("cannot IPL powered-off IBM 4361")
  if machinePhase="IPL_IN_PROGRESS" then raise syntax 40.900 array("IPL already in progress")
  machinePhase="IPL_IN_PROGRESS"
  lastIPLDevice=deviceNumber
  clearAccelAvailable=1; keyAccelAvailable=1
  cpu~resetForIPL
  channels~beginIPL(deviceNumber,storage)
  return self

/* Execute exactly one fetched IPL CCW.  Completion of the channel program is
 * the point at which the IPL PSW is architecturally loaded. */
::method stepInitialProgramLoad
  expose cpu storage channels machinePhase eventSequence lastIPLDevice
  if machinePhase \= "IPL_IN_PROGRESS" then raise syntax 40.900 array("no IPL in progress")
  p=channels~stepProgram(lastIPLDevice,storage)
  if p~completed then do
    if p~channelStatus \=0 | p~unitStatus//4 \=0 then do
      machinePhase="IPL_FAILED"
      return p
    end
    /* Capture the guest-supplied IPL PSW before depositing the IPL device
     * identity into low core.  The processor PSW interruption-code field is
     * not the low-core IPL-device residue. */
    iplPsw=storage~fetchHex(0,8)
    storage~storeHex(2,d2x(lastIPLDevice,4))
    cpu~loadIPLPSW(iplPsw)
    eventSequence=eventSequence+1
    machinePhase="GUEST_STARTED"
  end
  return p

/* Convenience operator action: execute the whole IPL channel program.  Tests
 * and forensic callers should prefer beginInitialProgramLoad + step... when a
 * freeze point inside the channel program is wanted. */
::method initialProgramLoad
  use strict arg deviceNumber
  self~beginInitialProgramLoad(deviceNumber)
  guard=0
  do while self~machinePhase="IPL_IN_PROGRESS"
    self~stepInitialProgramLoad
    guard=guard+1
    if guard>100000 then raise syntax 40.900 array("IPL channel program exceeded safety step limit")
  end
  return self

::method booting
  expose machinePhase
  return machinePhase="IPL_IN_PROGRESS" | machinePhase="GUEST_STARTED"

::method iplCCW1
  expose storage
  return .IBM370CCW0~new(storage~fetchHex(8,8))

::method iplCCW2
  expose storage
  return .IBM370CCW0~new(storage~fetchHex(16,8))

::method state
  expose model machinePhase eventSequence lastIPLDevice
  d=.directory~new
  d["model"]=model
  d["machinePhase"]=machinePhase
  d["eventSequence"]=eventSequence
  d["lastIPLDevice"]=lastIPLDevice
  return d

::method restoreMachineState
  expose model machinePhase eventSequence lastIPLDevice
  use strict arg d
  do required over .array~of("model","machinePhase","eventSequence","lastIPLDevice")
    if \d~hasIndex(required) then raise syntax 40.900 array("IBM4361 machine state missing" required)
  end
  if d["model"] \= model then raise syntax 40.900 array("IBM4361 model mismatch")
  machinePhase=d["machinePhase"]
  eventSequence=d["eventSequence"]
  lastIPLDevice=d["lastIPLDevice"]
  return self


::method tick
  expose cpu storage channels clock executor machinePhase clearAccelAvailable keyAccelAvailable
  if machinePhase <> "GUEST_STARTED" then return "NOT_RUNNING"
  if cpu~stopped then return "STOPPED"
  if cpu~psw~waitState then do
    if channels~hasActivePrograms then channels~stepOneActive(storage)
    return "WAIT"
  end
  if clearAccelAvailable then do
    if self~accelerateStorageClear then do; clearAccelAvailable=0; return "OK"; end
  end
  if keyAccelAvailable then do
    if self~accelerateStorageKeys then do; keyAccelAvailable=0; return "OK"; end
  end
  status=executor~step
  if status <> "OK" then return status
  clock~advanceOneInstruction(storage,cpu~prefix,cpu~instructionCount)
  if channels~hasActivePrograms then channels~stepOneActive(storage)
  return "OK"

::method runTicks
  use strict arg maximum
  do n=1 to maximum
    status=self~tick
    if status <> "OK" then return status
  end
  return "LIMIT"

::method accelerateStorageClear private
  expose cpu storage clock
  ia=cpu~psw~instructionAddress
  if ia<>x2d("112") then return 0
  if storage~fetchHex(ia,12)~left(24) <> "D2FF4000FC7E07808748F090" then return 0
  inc=cpu~gpr(8); limit=cpu~gpr(9); ptr=cpu~gpr(4)
  if inc<>256 | ptr>limit then return 0
  iterations=((limit-ptr)%inc)+1
  oldCount=cpu~instructionCount
  bytes=iterations*inc
  if ptr+bytes>storage~sizeBytes then bytes=storage~sizeBytes-ptr
  if bytes>0 then storage~zeroRange(ptr,bytes)
  cpu~setGpr(4,self~u32local(ptr+iterations*inc))
  do k=1 to iterations*3; cpu~noteInstruction; end
  cpu~psw~setInstructionLength(4)
  cpu~psw~setInstructionAddress(x2d("11E"))
  clock~advanceInstructionRange(storage,cpu~prefix,oldCount,cpu~instructionCount)
  return 1

::method accelerateStorageKeys private
  expose cpu storage clock
  ia=cpu~psw~instructionAddress
  if ia<>x2d("130") then return 0
  /* Canonical MVT post-clear loop: SSK R3,R2 / AR R2,R4 / CL / BC.
   * Accelerate only when the observed register contract is exact. */
  if storage~fetchHex(ia,2) <> "0832" then return 0
  if cpu~gpr(4)<>2048 then return 0
  ptr=cpu~gpr(2)
  if ptr<0 | ptr>=storage~sizeBytes then return 0
  key=(cpu~gpr(3)%16777216)//16777216
  remaining=((storage~sizeBytes-1-ptr)%2048)+1
  oldCount=cpu~instructionCount
  do n=0 to remaining-1
    storage~setStorageKeyRaw(ptr+n*2048,key)
  end
  /* Four-instruction loop; after final BC execution falls through at 0140. */
  do k=1 to remaining*4; cpu~noteInstruction; end
  cpu~setGpr(2,ptr+remaining*2048)
  cpu~psw~setInstructionLength(4)
  cpu~psw~setInstructionAddress(x2d("13C"))
  clock~advanceInstructionRange(storage,cpu~prefix,oldCount,cpu~instructionCount)
  return 1

::method u32local private
  use strict arg v
  v=v//4294967296; if v<0 then v=v+4294967296; return v

::requires "IBM370Architecture.cls"
::requires "IBM370Executor.cls"
::requires "IBM370IO.cls"
::requires "AlchemyObject.cls"
