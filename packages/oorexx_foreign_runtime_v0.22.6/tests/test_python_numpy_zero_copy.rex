failures=0
lib=.foreign~load('../examples/test.bridge.json')
np=.ForeignPython~import('numpy')
buf=.foreign~buffer(16)
ignored=lib~fill_bytes(buf,16)
arr=np~frombuffer(buf,.ForeignPython~text('uint8'))
call check arr~typeName='numpy.ndarray','NumPy frombuffer returns resident ndarray'
ignored=arr~fill(37)
call check c2d(substr(buf~bytes,1,1))=37,'NumPy mutation visible in ForeignBuffer first byte'
call check c2d(substr(buf~bytes,16,1))=37,'NumPy mutation visible in ForeignBuffer last byte'
call check arr~tobytes==buf~bytes,'NumPy reads same ForeignBuffer storage'
arr~close; buf~close; np~close; lib~close
if failures=0 then do; say 'PASS optional NumPy zero-copy 4 assertions'; exit 0; end
say 'FAIL optional NumPy zero-copy failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return
::requires '../rexx/python_foreign.cls'
