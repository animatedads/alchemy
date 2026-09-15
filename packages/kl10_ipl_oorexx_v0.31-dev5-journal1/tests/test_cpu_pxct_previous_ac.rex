/* KL10 PXCT 4: main data reference uses Previous AC Block. */
numeric digits 30
pc=octToDec("100")
target=octToDec("200")
mem=.TestMemory~new
mem~put(pc,octToDec("256200000200"))       /* PXCT 4,200 */
mem~put(target,octToDec("202040000003"))  /* MOVEM 1,3 */
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~pag~ioReset
ignored=cpu~pag~datao(octToDec("500600000765"),.nil)
cpu~setAccumulator(1,octToDec("123456654321"))
cpu~setAccumulator(3,octToDec("777777000000"))
cpu~setAccumulatorInBlock(6,3,octToDec("000000777777"))
tr=cpu~step
call eq tr["mnemonic"],"XCT","mnemonic"
call eq tr["xctMnemonic"],"MOVEM","executed mnemonic"
call eq tr["xctReferenceKind"],"PREVIOUS_AC","reference kind"
call eq tr["pxctPreviousAcBlock"],6,"PAB"
call eq cpu~accumulator(3),octToDec("777777000000"),"current AC3 unchanged"
call eq cpu~accumulatorInBlock(6,3),octToDec("123456654321"),"previous block AC3 written"
call eq cpu~pc,pc+1,"XCT sequential return"
say "KL10 PXCT previous-AC acceptance: PASS"
say "  PXCT 4,[MOVEM 1,3] writes PAB6 AC3, not current AC3"
exit 0

octToDec: procedure
 use arg t
 numeric digits 30
 n=0
 do i=1 to t~length
  n=n*8+t~substr(i,1)
 end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL:" l "expected" e "actual" a; exit 1; end
 return
::class TestMemory public
::method init
 expose w
 w=.directory~new
::method put
 expose w
 use strict arg a,v
 numeric digits 30
 w[a]=v // (2 ** 36)
 return self
::method word
 expose w
 use strict arg a
 if w~hasIndex(a) then return w[a]
 return 0
::requires "../KL10IPL.cls"
