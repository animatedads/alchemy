numeric digits 30
pc=oct("100"); text=oct("200")
mem=.KL10Memory~new; mem~mapZeroPage(0,0)
mem~put(pc,inst(oct("134"),5,6))
mem~put(pc+1,inst(oct("105"),15,oct("777777")))
/* 7-bit "A" in first byte position. */
mem~put(text,65*(2**29))
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~setAccumulator(6,oct("440700000200"))
cpu~setAccumulator(15,oct("777776000300"))
tr=cpu~step
call eq tr["mnemonic"],"ILDB","ILDB"
call eq cpu~accumulator(5),65,"first byte"
call eq cpu~accumulator(6),oct("350700000200"),"pointer increment"
tr=cpu~step
call eq tr["mnemonic"],"ADJSP","ADJSP"
call eq cpu~accumulator(15),oct("777775000277"),"ADJSP -1 both halves"
say "PASS test_cpu_ildb_adjsp"; exit
inst: procedure; use arg o,a,y; return o*(2**27)+a*(2**23)+y
oct: procedure; use arg t; t=changestr(",",t,""); n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
