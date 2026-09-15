numeric digits 30
mem=.KL10Memory~new
do page over .array~of(oct("742"),oct("765"),oct("766"),oct("772")); mem~mapZeroPage(page,0); end
cpu=.KL10CPU~new~~loadImage(mem,oct("772350"))
cpu~setAccumulatorInBlock(6,0,oct("777777777777"))
cpu~setAccumulatorInBlock(6,1,1)
cpu~setAccumulatorInBlock(6,2,oct("000000742000"))
cpu~setAccumulatorInBlock(6,3,oct("000000765760"))
cpu~pag~ioReset
mem~put(oct("765540"),oct("220000000000"))
mem~put(oct("765760"),oct("000000000766"))
mem~put(oct("766772"),oct("104000000772"))
mem~put(oct("742766"),oct("010000400000"))
mem~put(oct("742772"),oct("010000400000"))
mem~put(oct("772350"),oct("476000772253"))
mem~put(oct("772253"),oct("123456654321"))
mem~put(oct("765503"),oct("000000044414"))
cpu~pag~datao(oct("500600000765"),cpu~ioBus)
cpu~pag~cono(oct("060765"),cpu~ioBus)
s=.KL10JournalSession~new(cpu)
oldTarget=cpu~memory~physicalWord(oct("772253"))
oldPf=cpu~memory~physicalWord(oct("765501"))
oldSave=cpu~memory~physicalWord(oct("765502"))
t1=s~step
call eq cpu~pc,oct("044414"),"fault branch PC"
call eq t1["pageFault"],1,"fault marker"
call eq cpu~memory~physicalWord(oct("772253")),oldTarget,"protected target"
call true cpu~memory~physicalWord(oct("765501"))\=oldPf,"fault word written"
call true cpu~memory~physicalWord(oct("765502"))\=oldSave,"save word written"
s~restore(t1["journalBefore"])
call eq cpu~pc,oct("772350"),"rewound faulting PC"
call eq cpu~instructionCount,0,"rewound ICOUNT"
call eq cpu~memory~physicalWord(oct("765501")),oldPf,"rewound fault word"
call eq cpu~memory~physicalWord(oct("765502")),oldSave,"rewound save word"
call eq cpu~memory~physicalWord(oct("772253")),oldTarget,"rewound target"
t2=s~step
call eq cpu~pc,oct("044414"),"replay fault vector"
call eq t2["pageFaultWord"],t1["pageFaultWord"],"replay fault word"
say "PASS test_journal_tops20_page_fault_rewind"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,""); n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say "FAIL" l; exit 1; end
 return
::requires "../KL10Journal.cls"
