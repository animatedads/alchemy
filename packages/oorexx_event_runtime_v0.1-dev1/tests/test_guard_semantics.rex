/* Proves the idiomatic GUARD condition-variable pattern used by ooRexx itself:
   mutate an exposed object variable to wake waiting activities; mutating only
   the internals of a referenced Queue is not the wake-up contract. */
parse source . . here

q=.GuardedQueue~new
consumer=.Consumer~new(q)
consumer~start('run')
call syssleep .05
q~put('hello')
call syssleep .05
if consumer~value<>'hello' then do; say 'FAIL: guard wake'; exit 1; end
q~stop
say 'EVENT RUNTIME GUARD: OK'
exit 0

::class GuardedQueue
::method init
  expose queue changed stopped
  queue=.queue~new; changed=.false; stopped=.false
::method put guarded
  expose queue changed
  use strict arg item
  queue~queue(item)
  changed=.true
::method stop guarded
  expose changed stopped
  stopped=.true; changed=.true
::method next guarded
  expose queue changed stopped
  do forever
    if \queue~isEmpty then return queue~pull
    if stopped then return .nil
    changed=.false
    guard on when changed
  end

::class Consumer
::attribute value get
::method init
  expose queue value
  use strict arg queueArg
  queue=queueArg; value=''
::method run
  expose queue value
  item=queue~next
  if item<>.nil then value=item
