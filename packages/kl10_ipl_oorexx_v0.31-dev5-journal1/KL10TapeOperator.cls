/* KL10 TU45 operator-panel facade.
 *
 * Operator actions are deliberately separate from guest TM03/RH20 commands.
 * Every accepted or rejected button action can be emitted as a rich ooRexx
 * event object.  The optional Queue Fabric sink preserves that object graph.
 */

::class KL10TapeOperatorSnapshot public
::attribute stateToken get
::attribute mounted get
::attribute online get
::attribute ready get
::attribute writeLocked get
::attribute bot get
::attribute tapeMark get
::attribute motion get
::attribute position get
::attribute fileNumber get
::attribute model get
::attribute formatter get
::attribute mediaSha256 get
::attribute buttons get
::attribute lamps get

::method init
  expose stateToken mounted online ready writeLocked bot tapeMark motion position fileNumber -
         model formatter mediaSha256 buttons lamps
  use strict arg tape
  st=tape~operatorState
  mounted=st["mounted"]
  online=st["online"]
  ready=st["ready"]
  writeLocked=st["writeLocked"]
  bot=st["bot"]
  tapeMark=st["tapeMark"]
  motion=st["motion"]
  position=st["position"]
  fileNumber=st["fileNumber"]
  model=st["model"]
  formatter=st["formatter"]
  mediaSha256=st["mediaSha256"]
  stateToken=self~makeToken(st)

  buttons=.directory~new
  buttons["ONLINE"]=mounted & \online
  buttons["OFFLINE"]=online
  buttons["REWIND"]=mounted
  buttons["UNLOAD"]=mounted

  lamps=.directory~new
  lamps["ONLINE"]=online
  lamps["READY"]=ready
  lamps["BOT"]=bot
  lamps["WRITE_LOCK"]=writeLocked
  lamps["TAPE_MARK"]=tapeMark
  lamps["MOTION"]=motion \= "STOPPED"

::method makeToken private
  use strict arg st
  /* Token is an opaque deterministic generation description, not a secret. */
  return st["mounted"] || ":" || st["online"] || ":" || st["writeLocked"] || ":" || -
         st["position"] || ":" || st["fileNumber"] || ":" || st["tapeMark"] || ":" || -
         st["motion"] || ":" || st["mediaSha256"]


::class KL10TapeOperatorEvent public
::attribute eventType get
::attribute actor get
::attribute correlationId get
::attribute button get
::attribute accepted get
::attribute code get
::attribute detail get
::attribute before get
::attribute after get
::attribute beforeToken get
::attribute afterToken get

::method init
  expose eventType actor correlationId button accepted code detail before after beforeToken afterToken
  use strict arg actor, correlationId, button, accepted, code, detail, before, after
  eventType="KL10_TAPE_OPERATOR_BUTTON"
  beforeToken=before~stateToken
  afterToken=after~stateToken


::class KL10TapeOperatorResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute event get
::attribute snapshot get

::method init
  expose ok code detail event snapshot
  use strict arg ok,code,detail,event,snapshot


::class KL10TapeOperatorNullSink public
::method emit
  use strict arg event
  return .true


::class KL10TapeOperatorQueueFabricSink public
::method init
  expose manager queueName principal
  use strict arg manager, queueName, principal
::method emit
  expose manager queueName principal
  use strict arg event
  options=.table~new
  options["correlationId"]=event~correlationId
  headers=.table~new
  headers["event-type"]=event~eventType
  headers["actor"]=event~actor
  headers["button"]=event~button
  headers["accepted"]=event~accepted
  options["headers"]=headers
  operationResult=manager~put(queueName,event,options,principal)
  if \operationResult~ok then
    raise syntax 40.900 array("operator instrumentation queue PUT failed:" operationResult~code operationResult~detail)
  return .true


::class KL10TapeOperatorPanel public
::method init
  expose tape sink
  use arg tape, sink=.nil
  if sink=.nil then sink=.KL10TapeOperatorNullSink~new

::method snapshot
  expose tape
  return .KL10TapeOperatorSnapshot~new(tape)

::method press
  expose tape sink
  use strict arg button, expectedToken, actor, correlationId
  button=button~upper
  before=self~snapshot

  if expectedToken \= before~stateToken then
    return self~finish(actor,correlationId,button,0,"STALE_ACTION_TOKEN", -
        "operator state changed before button action",before,before)

  select
    when button="ONLINE" then do
      if \before~mounted then
        return self~finish(actor,correlationId,button,0,"NO_REEL","no tape reel is mounted",before,before)
      if before~online then
        return self~finish(actor,correlationId,button,0,"ALREADY_ONLINE","transport already online",before,before)
      accepted=tape~operatorOnline
    end
    when button="OFFLINE" then do
      if \before~online then
        return self~finish(actor,correlationId,button,0,"ALREADY_OFFLINE","transport already offline",before,before)
      accepted=tape~operatorOffline
    end
    when button="REWIND" then do
      if \before~mounted then
        return self~finish(actor,correlationId,button,0,"NO_REEL","no tape reel is mounted",before,before)
      accepted=tape~operatorRewind
    end
    when button="UNLOAD" then do
      if \before~mounted then
        return self~finish(actor,correlationId,button,0,"NO_REEL","no tape reel is mounted",before,before)
      accepted=tape~operatorUnload
    end
    otherwise
      return self~finish(actor,correlationId,button,0,"UNKNOWN_BUTTON","unsupported operator control",before,before)
  end

  after=self~snapshot
  if accepted then
    return self~finish(actor,correlationId,button,1,"OK","operator action applied",before,after)
  return self~finish(actor,correlationId,button,0,"REFUSED","transport refused operator action",before,after)

::method finish private
  expose sink
  use strict arg actor,correlationId,button,accepted,code,detail,before,after
  event=.KL10TapeOperatorEvent~new(actor,correlationId,button,accepted,code,detail,before,after)
  ignored=sink~emit(event)
  return .KL10TapeOperatorResult~new(accepted,code,detail,event,after)

::requires "KL10IPL.cls"
