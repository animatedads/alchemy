numeric digits 30
pc=oct("100"); target=oct("240")
names="JUMP JUMPL JUMPE JUMPLE JUMPA JUMPGE JUMPN JUMPG"
do op=oct("320") to oct("327")
 mem=.KL10Memory~new; mem~mapZeroPage(0,0)
 mem~put(pc,inst(op,3,target))
 cpu=.KL10CPU~new~~loadImage(mem,pc)
 cpu~setAccumulator(3,0)
 tr=cpu~step
 call eq tr["mnemonic"],word(names,op-oct("320")+1),"decode"
 cond=op-oct("320")
 expected=(cond=2 | cond=3 | cond=4 | cond=5)
 call eq tr["branchTaken"],expected,"zero condition"
 if expected then call eq cpu~pc,target,"branch"
 else call eq cpu~pc,pc+1,"fallthrough"
end
say "PASS test_cpu_jump_family"; exit
inst: procedure; use arg o,a,y; return o*(2**27)+a*(2**23)+y
oct: procedure; use arg t; n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
