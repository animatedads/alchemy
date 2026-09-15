/* KL10A TOPS-20 write-protection page-fault delivery. */
numeric digits 30
mem=.KL10Memory~new
do page over .array~of(oct("742"),oct("765"),oct("766"),oct("772"))
  ignored=mem~mapZeroPage(page,0)
end
cpu=.KL10CPU~new~~loadImage(mem,oct("772350"))
cpu~setAccumulatorInBlock(6,0,oct("777777777777"))
cpu~setAccumulatorInBlock(6,1,1)
cpu~setAccumulatorInBlock(6,2,oct("000000742000"))
cpu~setAccumulatorInBlock(6,3,oct("000000765760"))
cpu~pag~ioReset
/* EPT section pointer -> SPT page-map -> read-only direct page 772. */
mem~put(oct("765540"),oct("220000000000"))
mem~put(oct("765760"),oct("000000000766"))
mem~put(oct("766772"),oct("104000000772"))
mem~put(oct("742766"),oct("010000400000"))
mem~put(oct("742772"),oct("010000400000"))
mem~put(oct("772350"),oct("476000772253")) /* SETOM 772253 */
mem~put(oct("772253"),oct("123456654321"))
/* TOPS-20 UPT new PC. */
mem~put(oct("765503"),oct("000000044414"))
ignored=cpu~pag~datao(oct("500600000765"),cpu~ioBus)
ignored=cpu~pag~cono(oct("060765"),cpu~ioBus)
call eq cpu~pag~ubPtr,oct("765000"),"UPT base"
before=cpu~memory~physicalWord(oct("772253"))
tr=cpu~step
call eq tr["pageFault"],1,"page fault delivered"
call eq tr["pageFaultVirtual"],oct("772253"),"fault VA"
call eq cpu~pc,oct("044414"),"fault vector"
call eq cpu~instructionCount,1,"faulting instruction retired as one cycle"
call eq cpu~memory~physicalWord(oct("772253")),before,"protected target unchanged"
call eq cpu~memory~physicalWord(oct("765502")),oct("000000772351"),"saved FLAGS,,next PC"
call eq cpu~memory~physicalWord(oct("765501")),tr["pageFaultWord"],"fault word stored"
call true (tr["pageFaultWord"] // (2**18))=oct("772253"),"fault word RH address"
call true bitset(tr["pageFaultWord"],5),"write-reference bit"
call true bitset(tr["pageFaultWord"],2),"accessible bit"
say "PASS test_cpu_tops20_page_fault_delivery"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
bitset: procedure
 use arg value,bit
 numeric digits 30
 mask=2**(35-bit)
 return (value // (mask*2)) >= mask
true: procedure
 use arg v,l
 if \v then do; say "FAIL" l; exit 1; end
 return
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
