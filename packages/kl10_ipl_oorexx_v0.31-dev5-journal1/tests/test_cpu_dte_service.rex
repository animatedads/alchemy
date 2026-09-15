numeric digits 30
mem=.KL10Memory~new
do p=0 to oct("777"); mem~mapZeroPage(p,0); end
cpu=.KL10CPU~new~~loadImage(mem,oct("100"))
cpu~pag~ioReset
ps=cpu~pag~state; ps["ebPtr"]=oct("765000"); ps["pageEnabled"]=0; ps["tops20Page"]=0
cpu~pag~restoreState(ps)
dte=cpu~attachDte
call eq dte~coni(cpu~ioBus),0,"reset visible"
call eq dte~statusInternal,oct("04000000"),"reset internal secondary"

/* MONON */
cpu~memory~physicalPut(oct("765451"),oct("004400"))
ignored=dte~cono(oct("020000"),cpu~ioBus)
call eq dte~servicePending,1,"doorbell pending"
events=cpu~ioBus~advance
call eq events~items,1,"service event"
call eq dte~monitorMode,1,"monitor enabled"
call eq dte~servicePending,0,"pending drained"
call eq cpu~memory~physicalWord(oct("765451")),0,"command clear"
call eq cpu~memory~physicalWord(oct("765444")),(2**36)-1,"flag done"

/* MONO 'A' */
cpu~memory~physicalPut(oct("765451"),oct("004000")+65)
ignored=dte~cono(oct("020000"),cpu~ioBus)
events=cpu~ioBus~advance
call eq dte~txHex,"41","queued character"
call eq cpu~memory~physicalWord(oct("765454")),65,"DTCHR"
call eq cpu~memory~physicalWord(oct("765455")),(2**36)-1,"DTMTD"
say "PASS test_cpu_dte_service"; exit
oct: procedure; use arg t; n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure; use arg a,e,l; if a\=e then do; say "FAIL" l e a; exit 1; end; return
::requires "../KL10IPL.cls"
