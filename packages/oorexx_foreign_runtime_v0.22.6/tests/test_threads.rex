/* Real ooRexx activity concurrency tests for Foreign Runtime v0.11. */
lib=.foreign~load('../examples/test.bridge.json')
/* Warm ooRexx lazy-compiled wrapper paths before concurrent native stress. */
ignored=lib~add(1,1)
ignored=lib~method('add')~signatures[1]~returnTypeName
ignored=lib~methodByInputs('overloaded',1)~symbol
lib~concurrency_reset
workers=.array~new
messages=.array~new
threads=8

do i=1 to threads
  w=.ForeignThreadWorker~new(lib)
  workers~append(w)
  messages~append(w~start('probe',80))
end

do m over messages
  call ok m~result >= 1, 'concurrent probe result'
end
call ok lib~concurrency_max >= 2, 'foreign calls overlap across ooRexx activities'

/* Concurrent metadata/signature lookup and ordinary invocation. */
messages=.array~new
workers=.array~new
do i=1 to threads
  w=.ForeignThreadWorker~new(lib)
  workers~append(w)
  messages~append(w~start('stress',200))
end
do m over messages
  call ok m~result=1, 'concurrent introspection/invocation worker'
end

/* Close must not destruct an object while a foreign call has it pinned. */
lib~concurrency_reset
box=lib~box_new(77)
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedBox',box,120)
do while lib~box_probe_is_started=0
  call SysSleep .001
end
box~close
call ok m~result=77, 'object close waits for active foreign call'
call ok box~closed, 'object reports closed after pinned call drains'

/* Scalar-owned handles are pinned exactly like pointer resources. */
ignored=lib~fake_handle_close_reset
ignored=lib~fake_handle_probe_reset
fh=lib~fake_handle_new
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedHandle',fh,120)
do while lib~fake_handle_probe_is_started=0
  call SysSleep .001
end
fh~close
call ok m~result=123, 'handle close waits for active foreign call'
call ok lib~fake_handle_close_count=1, 'handle destructor runs after active call drains'

/* The same pinning rule applies to writable buffers. */
buf=.foreign~buffer(32)
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedBuffer',buf,120)
do while lib~concurrency_max=0
  call SysSleep .001
end
buf~close
call ok m~result=1, 'buffer close waits for active foreign call'
call ok buf~closed, 'buffer reports closed after pinned call drains'

/* New v0.11 struct storage must also be pinned across a call. */
st=lib~struct('foreign_layout')
ignored=lib~layout_fill(st,6,63)
ignored=lib~layout_probe_reset
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedStruct',st,120)
do while lib~layout_probe_is_started=0
  call SysSleep .001
end
st~close
call ok m~result=6, 'struct close waits for active foreign call'

/* Pointer arrays pin both the outer pointer vector and referenced buffers. */
b1=.foreign~buffer(1); b2=.foreign~buffer(1)
ignored=lib~fill_bytes(b1,1); ignored=lib~fill_bytes(b2,1)
pa=.foreign~pointerArray(2,'u8'); pa~put(b1,1); pa~put(b2,2)
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedPointerArray',pa,120)
call SysSleep .02
pa~close
call ok m~result=2, 'pointer-array close waits for active foreign call'
b1~close; b2~close

/* Managed struct pointer fields pin the complete reachable graph. */
payload=.foreign~buffer(4)
payload~putBytes(0,'01020304'x)
control=.foreign~buffer(2)
control~putBytes(0,'0506'x)
iov=lib~struct('foreign_graph_iovec')
iov~set('iov_base',payload)
iov~set('iov_len',4)
msg=lib~struct('foreign_graph_msg')
msg~set('msg_iov',iov)
msg~set('msg_control',control)
msg~set('msg_controllen',2)
ignored=lib~graph_probe_reset
w=.ForeignThreadWorker~new(lib)
m=w~start('delayedGraph',msg,120)
do while lib~graph_probe_is_started=0
  call SysSleep .001
end
/* payload is two edges away: msg -> iov -> payload.  close must wait. */
payload~close
call ok m~result=21, 'transitive child buffer close waits for parent struct native call'
call ok payload~closed, 'transitively pinned child reports closed after call drains'
msg~close; iov~close; control~close

lib~close

/* Library close removes future lookup but shared call pin keeps module loaded. */
lib2=.foreign~load('../examples/test.bridge.json')
lib2~concurrency_reset
w=.ForeignThreadWorker~new(lib2)
m=w~start('probe',120)
do while lib2~concurrency_max=0
  call SysSleep .001
end
lib2~close
call ok m~result>=1, 'library close preserves in-flight call lifetime'
say 'PASS thread-safety activities'
exit 0

ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::class ForeignThreadWorker
::method init
  expose lib
  use strict arg lib
::method probe
  expose lib
  use strict arg ms
  return lib~concurrent_probe(ms)
::method stress
  expose lib
  use strict arg count
  do i=1 to count
    if lib~add(i,1)<>i+1 then return 0
    if lib~method('add')~signatures[1]~returnTypeName<>'i32' then return 0
    if lib~methodByInputs('overloaded',i)~symbol<>'echo_i32' then return 0
  end
  return 1
::method delayedBox
  expose lib
  use strict arg box, ms
  return lib~box_value_delayed(box,ms)
::method delayedHandle
  expose lib
  use strict arg fh, ms
  return lib~fake_handle_value_delayed(fh,ms)
::method delayedBuffer
  expose lib
  use strict arg buf, ms
  lib~fill_bytes_delayed(buf,32,ms)
  return 1
::method delayedStruct
  expose lib
  use strict arg st, ms
  return lib~layout_channels_delayed(st,ms)
::method delayedPointerArray
  expose lib
  use strict arg pa, ms
  return lib~pointer_array_first_sum_delayed(pa,2,ms)
::method delayedGraph
  expose lib
  use strict arg msg, ms
  return lib~graph_sum_delayed(msg,ms)

::requires '../rexx/foreign.cls'
