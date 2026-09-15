numeric digits 30
m=.IBM4361Machine~new(1048576)
m~powerOn

/* BAL must form the RX effective address from the pre-instruction register
 * state.  R1 is written only after address formation.  This matters when
 * R1 aliases B2 and/or X2. */

/* Real-MVT safety8 shape: BAL R10,0(R10),EA from IA 018984. */
m~cpu~loadIPLPSW('00040000B0018984')
m~cpu~setGpr(10,x2d('00018980'))
m~storage~storeHex(x2d('018984'),'45A0A0EA')
st=m~executor~step
call eq 'OK',st,'base-alias status'
call eq x2d('018A6A'),m~cpu~psw~instructionAddress,'base-alias target uses old R10'
call eq x2d('B0018988'),m~cpu~gpr(10),'base-alias link written after EA formation'

/* Index alias: old R9 participates in EA before R9 becomes the link. */
m~cpu~loadIPLPSW('00040000B0000200')
m~cpu~setGpr(9,x2d('00000100'))
m~cpu~setGpr(8,x2d('00000400'))
m~storage~storeHex(x2d('000200'),'45998020') /* BAL R9,020(R9,R8) */
st=m~executor~step
call eq 'OK',st,'index-alias status'
call eq x2d('000520'),m~cpu~psw~instructionAddress,'index-alias target uses old R9'
call eq x2d('B0000204'),m~cpu~gpr(9),'index-alias link'

say 'PASS test_cpu_bal_aliasing'
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
return

::requires 'IBM4361.cls'
