/* EX must execute modified target bytes transiently, preserve the template,
 * and resume after EX when the target itself falls through normally. */
m=.IBM4361Machine~new(65536)
m~powerOn
m~cpu~loadIPLPSW("0000000000000100")

/* EX R6,0x200 ; target is MVC with length byte 00.  R6 low byte FF turns it
 * transiently into a 256-byte MVC. */
m~cpu~setGpr(6,255)
m~storage~storeHex(x2d("100"),"44600200")
m~storage~storeHex(x2d("200"),"D20003000400")

/* Source 0x400..0x4ff and destination 0x300..0x3ff. */
src=""
do i=0 to 255
  src=src||d2x(i,2)
end
m~storage~storeHex(x2d("400"),src)
m~storage~zeroRange(x2d("300"),256)

template=m~storage~fetchHex(x2d("200"),6)
st=m~executor~step
call eq st,"OK","status"
call eq m~cpu~psw~instructionAddress,x2d("104"),"post-EX IA"
call eq m~storage~fetchHex(x2d("300"),256),src,"transient MVC result"
call eq m~storage~fetchHex(x2d("200"),6),template,"template preserved"
call eq m~cpu~instructionCount,1,"architectural instruction count"

say "PASS test_cpu_ex_sequencing"
exit 0

eq: procedure
  parse arg actual,expected,label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "IBM4361.cls"
