/* The current Desk Intention adapter receives exact structured slot values.
 * No class/method/body payload is flattened into command prose. */
desk=.BridgeDesk~new
service=.IntentionService~new
ignored=.SemanticSourceDevelopmentDeskIntention~configure(service,desk,"demo/house.rex")
gateway=.LlmCodingIntentionGateway~new(service)
body="if openState then return .true"||d2c(10)||"return .false /* METHOD_BODY VIEW_METHOD */"
args=.directory~new
args["class_name"]="Door"
args["method_name"]="isOpen"
args["method_body"]=body
model=.LlmCodingDecision~new("WRITE_METHOD",args)
decision=gateway~interpret(model)
call assertEq "READY",decision~status,"real Intention Service READY"
call assertEq "Door",decision~proposal~slot("CLASS_NAME")~value,"class slot"
call assertEq "isOpen",decision~proposal~slot("METHOD_NAME")~value,"method slot"
call assertEq body,decision~proposal~slot("METHOD_BODY")~value,"multiline body preserved byte-for-byte"
call assertEq "LLM_CODING_STRUCTURED",decision~proposal~providerName,"structured provider selected"
dispatched=gateway~commit(decision)
call assertEq "WRITE_METHOD",dispatched,"real Intention dispatch"

report=.LlmCodingDecision~new("REPORT",.directory~new,"complete")
reportDecision=gateway~interpret(report)
call assertEq "READY",reportDecision~status,"REPORT also gated"
call assertEq "REPORT",gateway~commit(reportDecision),"REPORT dispatch"
say "PASS structured Development Desk Intention bridge without payload flattening"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected=" expected "actual=" actual; raise syntax 88.900 array("test assertion failed"); end

::class BridgeDesk public
::method press
  use strict arg action,request
  action=translate(action)
  if action=="LIST_CLASSES" then do
    rows=.array~new; r=.directory~new; r["source_spelling"]="Door"; rows~append(r); return rows
  end
  if action=="VIEW_CLASS" then do
    d=.directory~new
    methods=.array~new; m=.directory~new; m["source_spelling"]="isOpen"; methods~append(m); d["methods"]=methods
    attrs=.array~new; a=.directory~new; a["source_spelling"]="openState"; attrs~append(a); d["attributes"]=attrs
    return d
  end
  raise syntax 88.900 array("unexpected bridge desk action "||action)

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingIntentionGateway.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
::requires "SemanticSourceDevelopmentDeskIntention.cls"
