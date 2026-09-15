failures=0
py=.ForeignPython~import('python_fixture')
lib=.foreign~load('../examples/test.bridge.json')

buf=.foreign~buffer(8)
ignored=lib~fill_bytes(buf,8)
call check py~buffer_type(buf)='memoryview','ForeignBuffer becomes Python memoryview'
call check py~buffer_len(buf)=8,'zero-copy memoryview preserves extent'
call check py~buffer_bytes(buf)==buf~bytes,'Python reads exact ForeignBuffer bytes'

-- Python writes must mutate the same native storage, not a copied bytes object.
call check py~buffer_write(buf,3,201)=201,'Python writes through memoryview'
call check c2d(substr(buf~bytes,4,1))=201,'Python mutation visible in ForeignBuffer'

-- Native mutation after Python use must remain visible to a subsequent view.
ignored=lib~fill_bytes(buf,8)
call check py~buffer_bytes(buf)==buf~bytes,'native mutation visible to Python'

-- A Python-held view pins ForeignBuffer storage until Python releases it.
call check py~hold_buffer(buf)=8,'Python retains exported buffer'
w=.BufferCloseWorker~new
m=w~start('closeIt',buf)
call SysSleep .05
call check w~finished=0,'ForeignBuffer close waits while Python holds view'
call check py~release_held_buffer=1,'Python releases held memoryview'
call check m~result=1,'ForeignBuffer close completes after Python release'
call check buf~closed,'ForeignBuffer reports closed after export drains'

lib~close; py~close
if failures=0 then do; say 'PASS Python provider v0.17 zero-copy 11 assertions'; exit 0; end
say 'FAIL Python provider v0.17 failures='failures; exit 1

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return

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
