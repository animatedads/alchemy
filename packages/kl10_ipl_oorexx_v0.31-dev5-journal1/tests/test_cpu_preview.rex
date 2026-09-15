/* preview() observes the proposed next instruction without executing it. */
numeric digits 30
mem=.KL10Memory~new
ignored=mem~mapZeroPage(0,0)
pc=octToDec("000100")
mem~put(pc,makeInstruction(octToDec("201"),3,0,0,octToDec("001234")))
cpu=.KL10CPU~new~~loadImage(mem,pc)

beforePc=cpu~pc
beforeCount=cpu~instructionCount
beforeAc=cpu~accumulator(3)
p=cpu~preview
call eq p["pc"],beforePc,"preview pc"
call eq p["mnemonic"],"MOVEI","preview mnemonic"
call eq p["effectiveAddress"],octToDec("001234"),"preview E"
call eq cpu~pc,beforePc,"preview leaves pc"
call eq cpu~instructionCount,beforeCount,"preview leaves icount"
call eq cpu~accumulator(3),beforeAc,"preview leaves AC"

tr=cpu~step
call eq cpu~instructionCount,beforeCount+1,"successful step increments icount"
call eq cpu~accumulator(3),octToDec("001234"),"step executed proposal"

say "PASS test_cpu_preview"
exit 0

makeInstruction: procedure
  use arg opcode,ac,indirect,index,address
  numeric digits 30
  return opcode*(2**27)+ac*(2**23)+indirect*(2**22)+index*(2**18)+address
octToDec: procedure
  use arg t
  numeric digits 30
  n=0
  do i=1 to t~length
    n=n*8+t~substr(i,1)
  end
  return n
eq: procedure
  use arg a,e,l
  if a \= e then do
    say "FAIL" l "expected=" e "actual=" a
    exit 1
  end
  return
::requires "../KL10IPL.cls"
