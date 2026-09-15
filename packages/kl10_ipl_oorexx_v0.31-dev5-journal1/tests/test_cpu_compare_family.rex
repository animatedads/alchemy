/* PDP-10 CAI/CAM signed compare families, 300..317 octal. */
numeric digits 30
pc=oct("000100")
memAddr=oct("000200")
names="CAI CAIL CAIE CAILE CAIA CAIGE CAIN CAIG CAM CAML CAME CAMLE CAMA CAMGE CAMN CAMG"

do opcode=oct("300") to oct("317")
  mem=.KL10Memory~new
  ignored=mem~mapZeroPage(0,0)
  ac=3
  cond=opcode // 8
  if opcode < oct("310") then operandAddress=5
  else operandAddress=memAddr
  mem~put(pc,makeInstruction(opcode,ac,0,0,operandAddress))
  if opcode >= oct("310") then mem~put(memAddr,5)
  cpu=.KL10CPU~new~~loadImage(mem,pc)
  cpu~setAccumulator(ac,5)
  tr=cpu~step
  call eq tr["mnemonic"],word(names,opcode-oct("300")+1),"decode" opcode
  /* Equal operands: E/LE/A/GE skip; L/N/G do not; base does not. */
  expectedSkip=(cond=2 | cond=3 | cond=4 | cond=5)
  call eq tr["skipTaken"],expectedSkip,"equal compare condition" opcode
  expectedPc=pc+1+expectedSkip
  call eq cpu~pc,expectedPc,"compare PC" opcode
end

/* Signed ordering: -1 is less than +1. */
mem=.KL10Memory~new
ignored=mem~mapZeroPage(0,0)
mem~put(pc,makeInstruction(oct("301"),2,0,0,1)) /* CAIL */
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~setAccumulator(2,(2**36)-1)
tr=cpu~step
call eq tr["skipTaken"],1,"signed -1 < +1"

say "PASS test_cpu_compare_family"
exit 0

makeInstruction: procedure
 use arg opcode,ac,ind,index,address
 return opcode*(2**27)+ac*(2**23)+ind*(2**22)+index*(2**18)+address
oct: procedure
 use arg t
 n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
