/* Proves Luna transport uses ApiRequest/API Client and strict Responses function tools. */
client=.FakeApiClient~new
transport=.AzureLunaApiClientTransport~new(client,"https://example.services.ai.azure.com","gpt-6-luna","secret",.ApiRequest)
turn=.directory~new; turn["schema"]="oorexx.llm-coding.turn/0.2"; turn["challenge"]="edit one method"
text=transport~invoke(turn)
parsed=.json~fromJson(text)
call assertEq "VIEW_METHOD",parsed["action"],"function call mapped to coding action"
call assertEq "Door",parsed["args"]["class_name"],"function args retained"
req=client~lastRequest
call assertEq "POST",req~method,"HTTP method"
call assertEq "https://example.services.ai.azure.com/openai/v1/responses",req~url,"Responses endpoint"
call assertEq "secret",req~headers["api-key"],"Azure key header"
body=.json~fromJson(req~body)
call assertEq "gpt-6-luna",body["model"],"deployment"
call assertTrue body["input"]~isA(.array),"structured Responses input"
call assertEq 2,body["input"]~items,"system + user input"
userText=body["input"]~at(2)["content"]~at(1)["text"]
userObject=.json~fromJson(userText)
call assertEq "oorexx.llm-coding.turn/0.2",userObject["schema"],"turn serialized losslessly"
call assertEq "required",body["tool_choice"],"one tool is required"
call assertEq .false,body["parallel_tool_calls"],"parallel calls disabled"
call assertEq 1,body["max_tool_calls"],"one tool-call maximum"
call assertEq .false,body["store"],"stateless coding request not stored by provider"
call assertEq 18,body["tools"]~items,"desk + semantic coding tool count"
writeTool=.nil
applyTool=.nil
stepTool=.nil
operationTool=.nil
do t over body["tools"]
  if t["name"]=="WRITE_METHOD" then writeTool=t
  if t["name"]=="CODING_APPLY_METHOD" then applyTool=t
  if t["name"]=="CODING_SET_ATTRIBUTE" then stepTool=t
  if t["name"]=="CODING_OPERATION" then operationTool=t
end
call assertTrue writeTool\==.nil,"WRITE_METHOD exposed as function tool"
call assertTrue writeTool["strict"],"strict function schema"
call assertEq .false,writeTool["parameters"]["additionalProperties"],"tool args closed"
call assertEq 3,writeTool["parameters"]["required"]~items,"WRITE_METHOD required args"
call assertTrue applyTool\==.nil,"CODING_APPLY_METHOD exposed as function tool"
call assertTrue applyTool["strict"],"semantic apply tool strict"
call assertEq .false,applyTool["parameters"]["additionalProperties"],"semantic apply args closed"
call assertTrue stepTool\==.nil,"CODING_SET_ATTRIBUTE exposed as function tool"
call assertTrue operationTool\==.nil,"CODING_OPERATION exposes dev9 language catalogue operation selection"
call assertEq 11,operationTool["parameters"]["required"]~items,"strict catalogue operation requires every declared field"
call assertTrue operationTool["parameters"]["properties"]["target"]["type"]~isA(.array),"unused catalogue operands are nullable union types"
call assertTrue operationTool["parameters"]["properties"]["message"]["type"]~isA(.array),"message operand is strict nullable union"
call assertEq 4,stepTool["parameters"]["required"]~items,"semantic step required args"
say "PASS API Client Luna Responses function-tool transport"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class ApiRequest public
::attribute id get
::attribute method get
::attribute url get
::attribute headers get
::attribute body get
::method init
  expose id method url headers body
  use strict arg idArg,methodArg,urlArg,headersArg,bodyArg,traffic,priority,connectTimeout,totalTimeout,idempotency,metadata,route,origin
  id=idArg; method=methodArg; url=urlArg; headers=headersArg; body=bodyArg

::class FakeApiClient public
::attribute lastRequest get
::method execute
  expose lastRequest
  use strict arg request
  lastRequest=request
  args=.directory~new; args["class_name"]="Door"; args["method_name"]="isOpen"
  item=.directory~new; item["type"]="function_call"; item["name"]="VIEW_METHOD"; item["call_id"]="call-1"; item["arguments"]=.json~toJson(args)
  output=.array~new; output~append(item)
  response=.directory~new; response["status"]="completed"; response["output"]=output
  return .FakeResponse~new(200,.json~toJson(response))

::class FakeResponse public
::attribute status get
::attribute body get
::attribute errorCode get
::method init
  expose status body errorCode
  use strict arg statusArg,bodyArg
  status=statusArg; body=bodyArg; errorCode=""

::requires "../src/AzureLunaApiClientTransport.cls"
