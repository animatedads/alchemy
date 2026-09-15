/* Safety20: successful live MVN candidate and permanent OPD1 must agree from
 * the identical recorded MVT frontier microstate. */
numeric digits 30
storage=.IBM370JournaledStorage~new(65536,2048,'MVN-PROMOTION-RAM')
m=.IBM4361Machine~new(65536,storage); m~powerOn
call resetState
source="expose storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; db=storage~fetchHex(d,1); sb=storage~fetchHex(s,1); storage~storeHex(d,db~left(1)||sb~right(1)); end; return ia+6"
call truth m~executor~installLiveMethod('OPD1',source),'install live MVN'
session=.IBM4361JournalSession~new(m)

session~beginInstruction
st=m~executor~step
call eq 'OK',st,'live status'
liveMem=m~storage~fetchHex(x2d('4E7'),1); liveSrc=m~storage~fetchHex(x2d('5D1'),1); liveCC=m~cpu~psw~conditionCode; liveIA=d2x(m~cpu~psw~instructionAddress,6)
session~abortInstruction
call eq '10',m~storage~fetchHex(x2d('4E7'),1),'rewind destination'; call eq 'B8',m~storage~fetchHex(x2d('5D1'),1),'rewind source'; call eq '00047C',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'; call eq 0,m~cpu~psw~conditionCode,'rewind CC'

session~beginInstruction
call truth m~executor~removeLiveMethod('OPD1'),'remove live MVN'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'withdrawal rewind GPR'; call eq '0000',m~storage~fetchHex(x2d('1234'),2),'withdrawal rewind RAM'

st=m~executor~step
call eq 'OK',st,'permanent status'; call eq liveMem,m~storage~fetchHex(x2d('4E7'),1),'destination equivalence'; call eq liveSrc,m~storage~fetchHex(x2d('5D1'),1),'source equivalence'; call eq liveCC,m~cpu~psw~conditionCode,'CC equivalence'; call eq liveIA,d2x(m~cpu~psw~instructionAddress,6),'IA equivalence'
call eq '18',liveMem,'recorded MVT destination'; call eq 'B8',liveSrc,'recorded MVT source'; call eq 0,liveCC,'recorded MVT cc'; call eq '000482',liveIA,'recorded MVT next IA'

say 'PASS test_cpu_mvn_promotion_equivalence'; exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('000400008000047C'); m~storage~storeHex(x2d('47C'),'D10004E705D1'); m~storage~storeHex(x2d('4E7'),'10'); m~storage~storeHex(x2d('5D1'),'B8'); m~cpu~psw~setConditionCode(0)
return
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361Journal.cls'
