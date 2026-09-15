/* KL10 TOPS-20 section-zero page walk + NXM probe. */
numeric digits 30

/* Identity-mapped real-style path: EPT shared section pointer -> SPT page map
 * -> direct page pointer. */
mem=.KL10Memory~new
do page over .array~of(oct("742"),oct("765"),oct("766"),oct("772"))
  ignored=mem~mapZeroPage(page,0)
end
cpu=.KL10CPU~new~~loadImage(mem,oct("772350"))
cpu~setAccumulatorInBlock(6,0,oct("777777777777")) /* CSTM */
cpu~setAccumulatorInBlock(6,1,1)                  /* CSTDAT: visible touch */
cpu~setAccumulatorInBlock(6,2,oct("000000742000"))
cpu~setAccumulatorInBlock(6,3,oct("000000765760"))
cpu~pag~ioReset
mem~put(oct("765540"),oct("220000000000"))
mem~put(oct("765760"),oct("000000000766"))
mem~put(oct("766772"),oct("124000000772"))
mem~put(oct("742766"),oct("010000400000"))
mem~put(oct("742772"),oct("010000400000"))
mem~put(oct("772350"),oct("202000772253"))

ignored=cpu~pag~cono(oct("060765"),cpu~ioBus)
call eq cpu~pag~pageEnabled,1,"pager enabled"
call eq cpu~pag~tops20Page,1,"TOPS20 mode"
call eq cpu~pag~ebPtr,oct("765000"),"EBR"

beforeMapCst=cpu~memory~physicalWord(oct("742766"))
beforeDataCst=cpu~memory~physicalWord(oct("742772"))
p=cpu~preview
call eq p["instruction"],oct("202000772253"),"preview mapped word"
call eq p["fetchSource"],"VIRTUAL","preview mapped source"
tr=p["translation"]
call eq tr["sectionPointerAddress"],oct("765540"),"section ptr addr"
call eq tr["pageMapPage"],oct("766"),"page map page"
call eq tr["pagePointerAddress"],oct("766772"),"pte addr"
call eq tr["physical"],oct("772350"),"physical identity"
call eq cpu~memory~physicalWord(oct("742766")),beforeMapCst,"preview no CST map mutation"
call eq cpu~memory~physicalWord(oct("742772")),beforeDataCst,"preview no CST data mutation"

value=cpu~fetch
call eq value,oct("202000772253"),"architectural fetch"
call eq cpu~memory~physicalWord(oct("742766")),beforeMapCst+1,"fetch CST map touch"
call eq cpu~memory~physicalWord(oct("742772")),beforeDataCst+1,"fetch CST data touch"

/* NXM: map virtual page 741 to physical page 1000, but do not install
 * physical page 1000 in backing memory. CST itself remains resident. */
ignored=mem~mapZeroPage(oct("743"),0)
mem~put(oct("766741"),oct("120000001000"))
mem~put(oct("743000"),oct("010000400000"))
probe=cpu~memory~probeWord(oct("741020"))
call eq probe["ok"],0,"NXM probe fails operand cycle"
call eq probe["nxm"],1,"NXM evidence"
call eq probe["physical"],oct("1000020"),"NXM physical address"
call eq cpu~apr~irqFlags,oct("002000"),"APR NXM flag"
ignored=cpu~apr~cono(oct("022000"),cpu~ioBus)
call eq cpu~apr~irqFlags,0,"APR clear-pending clears NXM"

say "PASS test_cpu_tops20_pager"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
