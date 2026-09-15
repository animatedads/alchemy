/* DMOVE 120: indexed two-word load into consecutive ACs. */
numeric digits 30
pc=octToDec("100")
mem=.TestMemory~new
mem~put(pc,octToDec("120056000133"))       /* DMOVE 1,133(16) */
mem~put(octToDec("771133"),octToDec("123456654321"))
mem~put(octToDec("771134"),octToDec("765432012345"))
cpu=.KL10CPU~new~~loadImage(mem,pc)
cpu~setAccumulator(14,octToDec("000000771000"))
tr=cpu~step
call eq tr["mnemonic"],"DMOVE","mnemonic"
call eq tr["effectiveAddress"],octToDec("771133"),"E"
call eq tr["pairEffectiveAddress"],octToDec("771134"),"E+1"
call eq cpu~accumulator(1),octToDec("123456654321"),"AC1"
call eq cpu~accumulator(2),octToDec("765432012345"),"AC2"
say "KL10 DMOVE acceptance: PASS"
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
