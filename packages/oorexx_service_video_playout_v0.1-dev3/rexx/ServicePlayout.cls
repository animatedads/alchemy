/*
 * ooRexx-owned presentation coordination above native media transport.
 * Native transport NEVER authorises business disclosure or resolves intentions.
 * This is an additive local provider for the future ConnectSelector boundary.
 * The initial API expects pre-approved/staged paths from a separate policy layer.
 */

::class ServicePlayout public
::method init
  expose native approved
  use arg descriptor
  if arg(1,'Omitted') then descriptor='service_playout.bridge.json'
  native=.foreign~load(descriptor)
  approved=.false

::method native
  expose native
  return native

::method approveMediaDemo
  /* Demo-only authority for synthetic/mock material; not an institutional grant. */
  expose approved
  approved=.true
  return self

::method configure
  expose native
  use strict arg videoOutput,audioOutput,realtime
  if native~open(videoOutput,audioOutput,realtime)<>1 then
    raise syntax 93.900 array ('Native service playout open failed')
  return self

::method idleFrame
  expose native
  use strict arg framePath
  if native~idle(framePath)<>1 then
    raise syntax 93.900 array ('Idle I420 frame rejected')
  return self

::method enqueueClip
  expose native approved
  use strict arg videoPath,audioPath,frames
  if \approved then raise syntax 93.900 array ('No approved media demonstration context')
  if native~clip(videoPath,audioPath,frames)<>1 then
    raise syntax 93.900 array ('Clip rejected by native queue')
  return self

::method enqueueCard
  expose native approved
  use strict arg imageFrame,audioPath,frames
  if \approved then raise syntax 93.900 array ('No approved media demonstration context')
  if native~card(imageFrame,audioPath,frames)<>1 then
    raise syntax 93.900 array ('Card rejected by native queue')
  return self

::method runFrames
  expose native
  use strict arg frames
  if native~runFrames(frames)<>1 then
    raise syntax 93.900 array ('Native synchronous playout failed')
  return self

::method start
  expose native
  if native~invokeArray('start', .array~new)<>1 then raise syntax 93.900 array ('Native service playout start failed')
  return self

::method hold
  /* Device continues at 24 fps, displaying the idle frame and sending silence. */
  expose native
  if native~hold(1)<>1 then raise syntax 93.900 array ('Native playout hold failed')
  return self

::method release
  expose native
  if native~hold(0)<>1 then raise syntax 93.900 array ('Native playout release failed')
  return self

::method stop
  expose native
  if native~stop<>1 then raise syntax 93.900 array ('Native service playout stopped with error')
  return self

::method stats
  expose native
  return native~stats
::requires 'foreign.cls'
