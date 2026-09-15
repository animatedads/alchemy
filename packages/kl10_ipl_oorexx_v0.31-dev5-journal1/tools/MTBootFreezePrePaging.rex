/* Build a self-contained architectural checkpoint immediately before
 * MTBOOT executes CONO PAG,060765.
 * Usage: rexx MTBootFreezePrePaging.rex tape.tap output.kl10state
 */
numeric digits 30
parse arg tapePath statePath
if tapePath = "" | statePath = "" then do
  say "usage: rexx MTBootFreezePrePaging.rex /path/to/bb-h137f-bm.tap output.kl10state"
  exit 2
end

tape=.SimhTapeReader~new~~mount(tapePath)
mtboot=.Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader=.KL10ExbLoader~new
mem=loader~load(mtboot)

/* Proven AC relocation loop: equivalent state transition, no debug replay. */
src=octToDec("742000"); dst=octToDec("011000"); count=octToDec("036000")
do i=1 to count
  sw=mem~word(src); dw=mem~word(dst)
  mem~put(dst,sw); mem~put(src,dw)
  src=(src+1)//(2**18); dst=(dst+1)//(2**18)
end

cpu=.KL10CPU~new~~loadImage(mem,octToDec("771044"))
/* Historical instruction provenance: the verified first phase reaches
 * 771044 after 92,193 successful architectural instructions. */
ignored=cpu~restoreCoreState(cpu~pc,cpu~flags,cpu~halted,92193,cpu~processorMode)
cpu~setAccumulator(0,0)
cpu~setAccumulator(1,octToDec("200612000000"))
cpu~setAccumulator(2,octToDec("250611000000"))
cpu~setAccumulator(3,octToDec("202612000000"))
cpu~setAccumulator(4,octToDec("350000000011"))
cpu~setAccumulator(5,octToDec("350000000012"))
cpu~setAccumulator(6,octToDec("367540000001"))
cpu~setAccumulator(7,octToDec("254010772044"))
cpu~setAccumulator(8,octToDec("000000777000"))
cpu~setAccumulator(9,octToDec("000000047000"))
cpu~setAccumulator(10,0); cpu~setAccumulator(11,0); cpu~setAccumulator(12,0); cpu~setAccumulator(13,0)
cpu~setAccumulator(14,octToDec("000000000047")); cpu~setAccumulator(15,octToDec("000000011000"))
cpu~pag~ioReset
ignored=cpu~pag~cono(octToDec("000047"),.nil)

do i=1 to 177
  ignored=cpu~step
end
if cpu~pc \= octToDec("771104") then do
  say "unexpected second fill entry" .LROct~fromDecimal(cpu~pc)~right
  exit 1
end

fillWord=cpu~accumulator(3)
base=octToDec("742000")
do i=0 to octToDec("017777")
  mem~put(base+i,fillWord)
end
cpu~setAccumulator(1,octToDec("000000762000"))
cpu~loadImage(mem,octToDec("771106"))
/* 020000(octal)=16384 MOVEM/AOBJN pairs were accelerated above. */
ignored=cpu~restoreCoreState(cpu~pc,cpu~flags,cpu~halted,cpu~instructionCount+32768,cpu~processorMode)

do 14
  ignored=cpu~step
end
if cpu~pc \= 1 then do
  say "unexpected pre-paging PC" .LROct~fromDecimal(cpu~pc)~right
  exit 1
end
next=cpu~decode(cpu~fetch)
if next["mnemonic"] \= "CONO" | next["deviceName"] \= "PAG" then do
  say "unexpected pre-paging instruction" .LROct~fromDecimal(cpu~fetch)~string
  exit 1
end

meta=.directory~new
meta["machine"]="KL10"
meta["source"]="MTBOOT.EXB.1"
meta["checkpoint"]="mtboot.pre-paging-enable"
meta["tape_sha256"]="7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7"
state=.KL10State~new
ignored=state~save(cpu,statePath,meta)

/* Acceptance is part of freeze: reload into a fresh CPU from the state file
 * alone and prove the architectural boundary survived reconstruction. */
restorer=.KL10State~new
restored=restorer~load(statePath)
if restored~pc \= cpu~pc | restored~fetch \= cpu~fetch then do
  say "freeze/load verification failed at PC/fetch"
  exit 1
end
if restored~pag~ebPtr \= cpu~pag~ebPtr | restored~pag~ubPtr \= cpu~pag~ubPtr | -
   restored~pag~previousAcBlock \= cpu~pag~previousAcBlock then do
  say "freeze/load verification failed in PAG state"
  exit 1
end
do block=0 to 7
  do ac=0 to 15
    if restored~accumulatorInBlock(block,ac) \= cpu~accumulatorInBlock(block,ac) then do
      say "freeze/load verification failed at AC block" block "AC" ac
      exit 1
    end
  end
end
tape~close

say "FROZEN" statePath
say " checkpoint=mtboot.pre-paging-enable"
say " PC=" || .LROct~fromDecimal(cpu~pc)~right
say " next=" || .LROct~fromDecimal(cpu~fetch)~string next["mnemonic"] next["deviceName"]
exit 0

octToDec: procedure
 use arg t
 numeric digits 30
 n=0
 do i=1 to t~length
  n=n*8+t~substr(i,1)
 end
 return n

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"
