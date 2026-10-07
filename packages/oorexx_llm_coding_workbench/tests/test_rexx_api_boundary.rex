/* Proves the workbench carries the live turn object to the transport and
 * projects only inside the explicit API boundary. */
desk=.BoundaryDesk~new
gateway=.BoundaryGateway~new
transport=.ObjectAwareTransport~new
trace=.LlmCodingInstrumentation~new
wb=.LlmCodingWorkbench~new(.LlmCodingDeskSession~new(desk,"demo/boundary.rex","pkg-boundary"),gateway,transport,.nil,trace)
turn=wb~prepareMethodTurn("Inspect Door.isOpen","Door","isOpen")
decision=wb~ask(turn)
call assertSame turn,transport~seenTurn,"transport received exact live turn object"
call assertTrue transport~seenProjection~isA(.directory),"boundary produced directory only at transport edge"
call assertEq turn~id,transport~seenProjection["turn_id"],"projected turn identity"
call assertEq "VIEW_METHOD",decision~action,"decision decoded after external boundary"
call assertSame turn,trace~events[4]~subject,"API_CALL instrumentation retains live turn object"
say "PASS Rexx API boundary preserves live turn until explicit projection"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("FAIL "||label||" expected="||expected||" actual="||actual)
  return
::routine assertSame
  use strict arg expected,actual,label
  if expected\==actual then raise syntax 88.900 array("FAIL "||label||" object identity not retained")
  return
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("FAIL "||label)
  return

::class ObjectAwareTransport public
::attribute seenTurn get
::attribute seenProjection get
::method invokeTurn
  expose seenTurn seenProjection
  use strict arg turn,boundary
  seenTurn=turn
  seenProjection=boundary~turnDirectory(turn)
  args=.directory~new; args["class_name"]="Door"; args["method_name"]="isOpen"
  d=.directory~new; d["action"]="VIEW_METHOD"; d["args"]=args; d["report"]=""
  return .json~toJson(d)

::class BoundaryGateway public

::class BoundaryDesk public
::method buttons; return .array~of("VIEW_CLASS","VIEW_METHOD")
::method classFileModel; return "semantic"
::method press
  use strict arg action,request
  if action=="VIEW_CLASS" then do
    d=.directory~new; d["object_kind"]="CLASS"; d["source_spelling"]="Door"; d["methods"]=.array~new
    return d
  end
  if action=="VIEW_METHOD" then do
    d=.directory~new; d["object_kind"]="METHOD"; d["source_spelling"]="isOpen"; d["source_text"]="::method isOpen"||"0a"x||" return .false"
    return d
  end
  raise syntax 88.900 array("unexpected action "||action)

::requires "../src/LlmCodingWorkbench.cls"
