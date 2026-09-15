/* PDP-10 AOJ family, 340..347 octal. */
numeric digits 30
pc=oct("000100")
target=oct("000240")
names="AOJ AOJL AOJE AOJLE AOJA AOJGE AOJN AOJG"

do opcode=oct("340") to oct("347")
  mem=.KL10Memory~new
  ignored=mem~mapZeroPage(0,0)
  mem~put(pc,makeInstruction(opcode,4,0,0,target))
  cpu=.KL10CPU~new~~loadImage(mem,pc)
  cpu~setAccumulator(4,(2**36)-1) /* -1 -> 0 */
  tr=cpu~step
  call eq tr["mnemonic"],word(names,opcode-oct("340")+1),"decode"
  call eq cpu~accumulator(4),0,"increment"
  cond=opcode-oct("340")
  expected=(cond=2 | cond=3 | cond=4 | cond=5)
  call eq tr["branchTaken"],expected,"zero branch condition"
  if expected then call eq cpu~pc,target,"branch PC"
  else call eq cpu~pc,pc+1,"fallthrough PC"
end
say "PASS test_cpu_aoj_family"
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
