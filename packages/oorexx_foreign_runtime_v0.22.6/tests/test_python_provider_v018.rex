failures=0
py=.ForeignPython~import('python_fixture')
lib=.foreign~load('../examples/test.bridge.json')

-- Python -> Foreign Runtime: import a writable buffer without copying.
p=py~make_bytearray
call check p~typeName='bytearray','Python bytearray remains resident object'
buf=p~asBuffer
call check buf~size=8,'imported Python buffer extent'
call check buf~readonly=0,'writable Python export reports writable'
call check buf~bytes='abcdefgh','imported Python bytes visible in ForeignBuffer'
ignored=lib~fill_bytes(buf,8)
call check buf~hex='0102030405060708','native C mutates imported Python storage'
call check p~hex='0102030405060708','Python owner observes native mutation'

-- Closing the proxy must not invalidate storage while the Py_buffer import pin exists.
p~close
call check buf~hex='0102030405060708','imported buffer retains Python storage after proxy close'
buf~close
call check buf~closed,'imported buffer closes cleanly'

-- Imported Python storage must obey the same close-vs-active-call pinning rule.
p2=py~make_bytearray
buf2=p2~asBuffer
ignored=lib~concurrency_reset
w=.ImportBufferWorker~new
callMsg=w~start('fillIt',lib,buf2)
do while lib~fill_probe_is_started=0
  call SysSleep .001
end
cw=.BufferCloseWorker~new
closeMsg=cw~start('closeIt',buf2)
call SysSleep .03
call check cw~finished=0,'imported buffer close waits for active native call'
call check callMsg~result=1,'native call using imported Python buffer completes'
call check closeMsg~result=1,'imported buffer close completes after native pin drains'
p2~close

-- Read-only Python exports may be inspected but cannot satisfy an out/inout pointer.
ro=py~make_readonly_view
robuf=ro~asBuffer
call check robuf~bytes='readonly','readonly Python buffer imports'
call check robuf~readonly=1,'readonly Python export reports readonly'
blocked=0
signal on syntax name readonlyBlocked
ignored=lib~fill_bytes(robuf,8)
signal off syntax
call check 0,'readonly imported buffer must reject writable native parameter'
signal doneReadonly
readonlyBlocked:
  signal off syntax
  blocked=1
  call check 1,'readonly imported buffer rejects writable native parameter'
doneReadonly:
call check blocked=1,'readonly rejection condition observed'
robuf~close
ro~close

lib~close; py~close
if failures=0 then do; say 'PASS Python provider v0.18 reverse buffer import 15 assertions'; exit 0; end
say 'FAIL Python provider v0.18 failures='failures; exit 1

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return


::class ImportBufferWorker
::method fillIt unguarded
  use strict arg lib,buf
  ignored=lib~fill_bytes_delayed(buf,8,120)
  return 1

::class BufferCloseWorker
::method init
  expose done
  done=0
::method finished unguarded
  expose done
  return done
::method closeIt unguarded
  expose done
  use strict arg buf
  buf~close
  done=1
  return 1

::requires '../rexx/python_foreign.cls'
