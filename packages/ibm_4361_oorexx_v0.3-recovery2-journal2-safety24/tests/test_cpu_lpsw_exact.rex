numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn
m~cpu~start
m~cpu~psw~loadRawHex('0000000000000000')
m~storage~storeHex(0,'82000100')
m~storage~storeHex(x2d('100'),'000200FF00000007')
st=m~executor~step
if st<>"OK" then do; say 'FAIL status' st; exit 1; end
if m~cpu~psw~rawHex<>"000200FF00000007" then do; say 'FAIL LPSW altered new PSW' m~cpu~psw~rawHex; exit 1; end
if m~cpu~instructionCount<>1 then do; say 'FAIL count' m~cpu~instructionCount; exit 1; end
say 'PASS test_cpu_lpsw_exact'
::requires 'IBM4361.cls'
