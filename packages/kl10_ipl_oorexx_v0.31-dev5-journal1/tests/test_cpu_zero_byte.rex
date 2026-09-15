numeric digits 30
mem=.KL10Memory~new
mem~mapZeroPage(0,0)
pc=oct("100")
mem~put(pc,inst(oct("134"),1,6))       /* ILDB 1,6 */
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~setAccumulator(6,0)
cpu~setAccumulator(1,oct("777777777777"))
tr=cpu~step
call eq tr["mnemonic"],"ILDB","mnemonic"
call eq cpu~accumulator(6),0,"zero-size pointer unchanged"
call eq cpu~accumulator(1),0,"zero-size load yields zero"
call eq cpu~pc,pc+1,"PC advances"
say "PASS test_cpu_zero_byte"
exit
inst: procedure
 use arg o,a,y
 return o*(2**27)+a*(2**23)+y
oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
