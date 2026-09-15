/* Provider-declared serialized invocation policy. */
lib=.foreign~load('../examples/test-serialized.bridge.json')
call ok lib~threadingMode='serialized', 'serialized provider metadata'
ignored=lib~concurrency_reset
messages=.array~new
workers=.array~new
do i=1 to 6
  w=.SerializedWorker~new(lib)
  workers~append(w)
  messages~append(w~start('probe',40))
end
do m over messages
  call ok m~result>=1, 'serialized worker result'
end
call ok lib~concurrency_max=1, 'serialized provider prevents overlapping foreign calls'
lib~close
say 'PASS provider serialized threading policy'
exit 0
ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return
::class SerializedWorker
::method init
  expose lib
  use strict arg lib
::method probe
  expose lib
  use strict arg ms
  return lib~concurrent_probe(ms)
::requires '../rexx/foreign.cls'
