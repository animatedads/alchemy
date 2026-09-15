failures=0
np=.ForeignPython~import('numpy')
lib=.foreign~load('../examples/test.bridge.json')
kw=.ForeignPython~keywords
kw~put('dtype','uint8')
arr=np~zeros(8,kw)
buf=arr~asBuffer
call check buf~size=8,'NumPy ndarray imports as 8-byte ForeignBuffer'
ignored=lib~fill_bytes(buf,8)
vals=arr~tolist
call check vals[1]=1 & vals[8]=8,'native C mutation visible in NumPy ndarray'
arr~close
call check buf~hex='0102030405060708','ForeignBuffer retains ndarray export after proxy close'
buf~close
lib~close; np~close
if failures=0 then do; say 'PASS optional NumPy reverse-import 3 assertions'; exit 0; end
say 'FAIL optional NumPy reverse-import failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::requires '../rexx/python_foreign.cls'
