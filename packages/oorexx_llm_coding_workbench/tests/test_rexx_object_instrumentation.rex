/* Proves instrumentation happens in Rexx while live objects still exist.
 * Subject/context identity is retained; summaries are an explicit edge view. */
trace=.LlmCodingInstrumentation~new
subject=.directory~new
subject["name"]="live-object"
context=.array~of("tool","api")
event=trace~record("OBJECT_READ","VIEW_OBJECT",subject,context)

call assertSame subject,event~subject,"trace retains exact subject object"
call assertSame context,event~context,"trace retains exact context object"
subject["after"]="still-live"
call assertEq "still-live",event~subject["after"],"trace sees later mutation on retained object"
summary=event~asSummary
call assertEq "Directory",summary["subject_class"],"summary projects class only at explicit boundary"
call assertEq "Array",summary["context_class"],"summary projects context class"
call assertEq 1,trace~events~items,"one event retained"

session=.LlmCodingDeskSession~new(.TraceDesk~new,"demo/trace.rex","pkg-1","trace-project","trace-actor",trace)
args=.directory~new; args["class_name"]="TraceClass"
deskReply=session~execute("VIEW_CLASS",args)
call assertEq "TraceClass",deskReply["class_name"],"desk result"
call assertEq "TOOL_CALL",trace~events[2]~kind,"desk call traced in Rexx"
call assertEq "TOOL_RESULT",trace~events[3]~kind,"desk result traced in Rexx"
call assertSame deskReply,trace~events[3]~subject,"desk result object retained without flattening"
call assertSame session~desk,trace~events[2]~context,"tool object retained"

say "PASS Rexx-native instrumentation retains live objects across tool boundary"
exit 0

::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do
    raise syntax 88.900 array("FAIL "||label||" expected="||expected||" actual="||actual)
  end
  return

::routine assertSame
  use arg expected,actual,label
  if expected\==actual then do
    raise syntax 88.900 array("FAIL "||label||" object identity was not retained")
  end
  return

::class TraceDesk public
::method buttons
  return .array~of("VIEW_CLASS")
::method classFileModel
  return "semantic"
::method press
  use strict arg action,request
  if action<>"VIEW_CLASS" then raise syntax 88.900 array("unexpected action "||action)
  reply=.directory~new
  reply["kind"]="CLASS"
  reply["class_name"]=request["class_name"]
  return reply

::requires "LlmCodingWorkbench.cls"
