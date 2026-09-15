numeric digits 30
pc=oct("100"); subr=oct("200"); stack=oct("300")
mem=.KL10Memory~new; mem~mapZeroPage(0,0)
mem~put(pc,inst(oct("260"),15,subr))
mem~put(subr,inst(oct("261"),15,7))
mem~put(subr+1,inst(oct("263"),15,0))
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~setAccumulator(15,oct("777775000300"))
cpu~setAccumulator(7,oct("123456654321"))
tr=cpu~step
call eq tr["mnemonic"],"PUSHJ","PUSHJ"
call eq cpu~accumulator(15),oct("777776000301"),"PUSHJ pointer"
call eq mem~word(oct("301")),pc+1,"PUSHJ return word"
call eq cpu~pc,subr,"PUSHJ target"
tr=cpu~step
call eq tr["mnemonic"],"PUSH","PUSH"
call eq cpu~accumulator(15),oct("777777000302"),"PUSH pointer"
call eq mem~word(oct("302")),oct("123456654321"),"PUSH data"
/* Remove argument as a caller would, then POPJ the saved return. */
cpu~setAccumulator(15,oct("777776000301"))
tr=cpu~step
call eq tr["mnemonic"],"POPJ","POPJ"
call eq cpu~pc,pc+1,"POPJ return"
call eq cpu~accumulator(15),oct("777775000300"),"POPJ pointer"
say "PASS test_cpu_stack_ops"; exit
inst: procedure; use arg o,a,y; return o*(2**27)+a*(2**23)+y
oct: procedure; use arg t; t=changestr(",",t,""); n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
