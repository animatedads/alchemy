/* Proves compatibility JSON encoding delegates projection to the explicit
 * Rexx boundary instead of flattening the turn inside the codec. */
spy=.BoundarySpy~new
codec=.LlmCodingJsonCodec~new(spy)
target=.directory~new; target["class_name"]="Door"
semantic=.directory~new; semantic["method"]="live"
controls=.directory~new
turn=.LlmCodingTurn~new("turn-boundary","Inspect Door",target,semantic,controls)
wire=codec~encodeTurn(turn)
call assertSame turn,spy~seenTurn,"codec passed exact live turn to boundary"
parsed=.json~fromJson(wire)
call assertEq "turn-boundary",parsed["turn_id"],"boundary JSON projection retained turn id"
call assertEq 1,spy~calls,"one projection boundary call"
say "PASS compatibility codec delegates turn projection to explicit Rexx boundary"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("FAIL "||label||" expected="||expected||" actual="||actual)
  return
::routine assertSame
  use strict arg expected,actual,label
  if expected\==actual then raise syntax 88.900 array("FAIL "||label||" object identity not retained")
  return

::class BoundarySpy public
::attribute seenTurn get
::attribute calls get
::method init
  expose seenTurn calls
  seenTurn=.nil
  calls=0
::method turnJson
  expose seenTurn calls
  use strict arg turn
  calls+=1
  seenTurn=turn
  return .json~toJson(turn~asDirectory)

::requires "../src/LlmCodingWorkbench.cls"
