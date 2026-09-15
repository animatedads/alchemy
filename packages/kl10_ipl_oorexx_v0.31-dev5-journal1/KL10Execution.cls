/* KL10 execution runner and proven-equivalent execution accelerators.
 *
 * Accelerators are architectural equivalences.  They may reduce host work,
 * but they must preserve the state that ordinary cpu~step execution would
 * produce, including PC, ACs, FLAGS, memory and architectural ICOUNT.
 */
numeric digits 30

::class KL10ExecutionResult public
::attribute reason get
::attribute workUnits get
::attribute architecturalInstructions get
::attribute accelerations get
::attribute refused get
::attribute conditionMessage get
::attribute mediaMotion get
::attribute mediaBefore get
::attribute mediaAfter get

::method init
  expose reason workUnits architecturalInstructions accelerations refused conditionMessage -
         mediaMotion mediaBefore mediaAfter
  use strict arg reason, workUnits, architecturalInstructions, accelerations, refused, conditionMessage, -
                 mediaMotion, mediaBefore, mediaAfter


::class KL10ExecutionRunner public

::method init
  expose cpu
  use strict arg cpuArg
  cpu=cpuArg

::method run
  expose cpu
  numeric digits 30
  use arg maxWorkUnits=100000, stopOnMediaMotion=.false
  if \datatype(maxWorkUnits,"W") | maxWorkUnits<1 then
    raise syntax 40.900 array("execution maxWorkUnits must be a positive integer")

  startCount=cpu~instructionCount
  workUnits=0
  accelerations=0
  mediaBefore=self~mediaPositions
  mediaAfter=mediaBefore

  do while workUnits<maxWorkUnits
    accelerated=self~tryMtbootRegionCycle
    if accelerated=0 then accelerated=self~tryMtbootMemoryProbeCycle
    if accelerated=0 then accelerated=self~tryMtbootClearLoop
    if accelerated>0 then do
      workUnits=workUnits+1
      accelerations=accelerations+1
    end
    else do
      signal on syntax name refusedBoundary
      ignored=cpu~step
      signal off syntax
      workUnits=workUnits+1
    end

    mediaAfter=self~mediaPositions
    if stopOnMediaMotion & \self~sameDirectory(mediaBefore,mediaAfter) then
      return .KL10ExecutionResult~new("MEDIA_MOTION",workUnits,cpu~instructionCount-startCount, -
          accelerations,0,"",1,mediaBefore,mediaAfter)
    mediaBefore=mediaAfter
  end

  return .KL10ExecutionResult~new("LIMIT",workUnits,cpu~instructionCount-startCount, -
      accelerations,0,"",0,mediaBefore,mediaAfter)

refusedBoundary:
  signal off syntax
  message=condition("D")
  if message="" then message=condition("A")
  return .KL10ExecutionResult~new("EXECUTION_REFUSED",workUnits,cpu~instructionCount-startCount, -
      accelerations,1,message,0,mediaBefore,mediaAfter)



/* Complete phase-one MTBOOT low-memory region cycle.
 *
 * Entry/exit are both PC 774673.  Ordinary/reference execution:
 *   advances the next low-memory region by 001000,
 *   performs the high-memory 742000..776000 probe sweep,
 *   executes the real 777000 carry exit,
 *   clears the next 512-word low-memory region,
 *   updates 772272 to the new inclusive region end,
 *   and performs 62 architecturally visible PAG CLRPT generations.
 *
 * The complete cycle is exactly 2542 historical instructions.  This collapse
 * is deliberately pinned to the phase-one stack context and refuses the
 * configured-range boundary.
 */
::method tryMtbootRegionCycle
  expose cpu
  numeric digits 30
  if cpu~pc \= self~oct("774673") then return 0

  mem=cpu~memory
  if mem~word(self~oct("774670")) \= self~oct("402001000000") then return 0
  if mem~word(self~oct("774671")) \= self~oct("305053000000") then return 0
  if mem~word(self~oct("774672")) \= self~oct("344040774670") then return 0
  if mem~word(self~oct("774542")) \= self~oct("200040000013") then return 0
  if mem~word(self~oct("774613")) \= self~oct("260740774542") then return 0

  /* This is the phase-one caller.  Later MTBOOT phases use a different SP and
   * must execute or prove their own cycle. */
  if cpu~accumulator(self~oct("17")) \= self~oct("777733772270") then return 0

  ac1=cpu~accumulator(1)
  ac2=cpu~accumulator(2)
  ac13=cpu~accumulator(self~oct("13"))
  if ac1 % (2**18) \= 0 | ac2 % (2**18) \= 0 | ac13 % (2**18) \= 0 then return 0

  start=ac2 // (2**18)
  finish=ac1 // (2**18)
  if (ac13 // (2**18)) \= finish then return 0
  if finish \= start+self~oct("000777") then return 0
  if start<self~oct("001000") then return 0

  nextStart=start+self~oct("001000")
  nextFinish=finish+self~oct("001000")
  /* MTBOOT changes control phase at the configured page bound. */
  if nextStart>=self~oct("340000") then return 0

  if \self~identityTranslatedRange(nextStart,nextFinish) then return 0
  tr=mem~translate(self~oct("772272"),1,1)
  if tr["physical"] \= self~oct("772272") then return 0

  mem~backingMemory~zeroRange(nextStart,nextFinish)
  mem~physicalPut(self~oct("772272"),nextFinish)

  cpu~setAccumulator(1,ac1+self~oct("001000"))
  cpu~setAccumulator(2,ac2+self~oct("001000"))
  cpu~setAccumulator(self~oct("13"),ac13+self~oct("001000"))

  do 62
    ignored=cpu~pag~clrpt(self~oct("741000"))
  end

  ignored=cpu~restoreCoreState(self~oct("774673"),cpu~flags,cpu~halted, -
      cpu~instructionCount+2542,cpu~processorMode)
  return 2542

/* Steady MTBOOT physical-memory probe cycle after the initial special pass.
 *
 * At PC 774542, once AC2 is zero and AC13 is a page boundary, MTBOOT maps the
 * candidate page, normalises the MAP result, performs two PAG CLRPTs, and
 * increments AC13 by one 512-word page before returning to 774542.  The real
 * cycle is 32 instructions long.
 *
 * This accelerator is deliberately self-limiting: it calls mapWord() for the
 * current candidate and requires the exact normal mapped result
 * 120000,,<candidate>.  At the first hole/end-of-memory mapping, it declines
 * and the ordinary instruction stream discovers the boundary itself.
 */
::method tryMtbootMemoryProbeCycle
  expose cpu
  numeric digits 30
  if cpu~pc \= self~oct("774542") then return 0

  mem=cpu~memory
  /* Fingerprint the observed routine, not merely its entry address. */
  if mem~word(self~oct("774542")) \= self~oct("200040000013") then return 0
  if mem~word(self~oct("774546")) \= self~oct("257053000000") then return 0
  if mem~word(self~oct("774562")) \= self~oct("701100741000") then return 0
  if mem~word(self~oct("774570")) \= self~oct("701100741000") then return 0
  if mem~word(self~oct("774613")) \= self~oct("260740774542") then return 0

  ac13=cpu~accumulator(self~oct("13"))
  candidate=ac13 // (2**18)
  if candidate<self~oct("742000") then return 0
  if candidate>=self~oct("777000") then return 0
  if candidate // 512 \= 0 then return 0
  if ac13 % (2**18) \= 0 then return 0

  /* The same probe subroutine is called at more than one stack depth.
   * Bind the proof to the live stack pointer instead of one historical slot. */
  sp=cpu~accumulator(self~oct("17")) // (2**18)
  if sp<1 | sp>=self~oct("777777") then return 0
  if mem~word(sp) \= self~oct("006000774614") then return 0

  /* CAMN AC1,AC2 must remain false for the collapsed high-memory candidate. */
  if (cpu~accumulator(2) // (2**18)) = candidate then return 0

  /* Persistent scratch preconditions observed at the steady-cycle boundary. */
  if mem~word(self~oct("766741")) \= self~oct("120000000741") then return 0
  if mem~word(self~oct("772245")) \= 0 then return 0

  mapInfo=mem~mapWord(candidate)
  mapWord=mapInfo["word"]
  mapLeft=mapWord % (2**18)
  mapRight=mapWord // (2**18)
  validBit=self~oct("100000")
  if mapRight \= candidate then return 0
  if (mapLeft // (2*validBit)) < validBit then return 0

  /* Preserve the two architecturally observable CLRPT generations. */
  ignored=cpu~pag~clrpt(self~oct("741000"))
  ignored=cpu~pag~clrpt(self~oct("741000"))

  /* Net persistent memory effect of the steady cycle.  766741 is restored
   * before return; 772245 remains zero; this stack slot retains the inner
   * return address. */
  mem~put(sp+1,self~oct("006000774555"))

  cpu~setAccumulator(1,candidate)
  cpu~setAccumulator(self~oct("13"),ac13+self~oct("001000"))
  ignored=cpu~restoreCoreState(self~oct("774542"),cpu~flags,cpu~halted, -
      cpu~instructionCount+32,cpu~processorMode)
  return 32

/* Exact MTBOOT page-clear loop reached after the first tape load:
 *
 *   774670  402001,,000000  SETZM 0,0(1)
 *   774671  305053,,000000  CAIGE 1,0(13)
 *   774672  344040,,774670  AOJA  1,774670
 *   774673  ...             fallthrough
 *
 * From entry at 774670 the loop clears [AC1(RH), AC13(RH)] inclusive.
 * Ordinary execution performs N SETZM, N CAIGE and N-1 AOJA instructions:
 * exactly 3*N-1 architectural instructions.  AC1 finishes at the final
 * address and execution falls through to 774673.
 *
 * The accelerator is refused unless the instruction words are exact and the
 * entire virtual range translates identically to physical memory.  It is an
 * optimization, not an alternate MTBOOT semantic path.
 */
::method tryMtbootClearLoop
  expose cpu
  numeric digits 30
  if cpu~pc \= self~oct("774670") then return 0

  mem=cpu~memory
  if mem~word(self~oct("774670")) \= self~oct("402001000000") then return 0
  if mem~word(self~oct("774671")) \= self~oct("305053000000") then return 0
  if mem~word(self~oct("774672")) \= self~oct("344040774670") then return 0

  first=cpu~accumulator(1) // (2**18)
  last=cpu~accumulator(self~oct("13")) // (2**18)
  if first>last then return 0
  if first<16 then return 0
  if \self~identityTranslatedRange(first,last) then return 0

  n=last-first+1
  mem~backingMemory~zeroRange(first,last)
  cpu~setAccumulator(1,last)
  delta=3*n-1
  ignored=cpu~restoreCoreState(self~oct("774673"),cpu~flags,cpu~halted, -
      cpu~instructionCount+delta,cpu~processorMode)
  return delta

::method identityTranslatedRange private
  expose cpu
  numeric digits 30
  use strict arg first,last
  mem=cpu~memory
  firstPage=first % 512
  lastPage=last % 512
  do page=firstPage to lastPage
    lo=page*512
    hi=lo+511
    if lo<first then lo=first
    if hi>last then hi=last
    tr=mem~translate(lo,1,1)
    if tr["physical"] \= lo then return 0
    if hi\=lo then do
      tr=mem~translate(hi,1,1)
      if tr["physical"] \= hi then return 0
    end
  end
  return 1

::method mediaPositions private
  expose cpu
  numeric digits 30
  d=.directory~new
  do code=352 to 380 by 4
    if cpu~ioBus~hasDevice(code) then do
      rh=cpu~rh20(code)
      do unitNumber over rh~unitNumbers
        unit=rh~unit(unitNumber)
        if unit~hasMethod("POSITION") then d[code || ":" || unitNumber]=unit~position
      end
    end
  end
  return d

::method sameDirectory private
  use strict arg a,b
  if a~items \= b~items then return 0
  do key over a
    if \b~hasIndex(key) then return 0
    if a[key] \= b[key] then return 0
  end
  return 1

::method oct private
  use strict arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    ch=text~substr(i,1)
    if ch="," then iterate
    if pos(ch,"01234567")=0 then raise syntax 40.900 array("invalid octal literal:" text)
    n=n*8+ch
  end
  return n

::requires "KL10IPL.cls"
