/* Prove Coding Intention semantic steps generate disciplined method bodies and
 * reach Development Desk only through the existing WRITE_METHOD gate. */
bridge=.LlmSemanticCodingBridge~new("House","openDoor")
bridge~addSetAttribute("door","open")
bridge~addReturnIfAlready("door","open","false")
body=bridge~renderMethodBody
expected='expose door'||.endOfLine||'if door == "open" then return .false'||.endOfLine||'door = "open"'||.endOfLine||'return .true'
call assertEq expected,body,"guard ordered before mutation and syntax generated"

jsonBridge=.LlmSemanticCodingBridge~new("Loader","load")
jsonBridge~addLoadJsonFile("house.json","doc")
/* dev9 requires keyed-shape evidence before member access.  Bind an observed witness. */
runtimeDoc=.Directory~new; runtimeDoc["house"]=.Directory~new
jsonBridge~bindRuntimeObject("doc",runtimeDoc,"TEST_RUNTIME_INTERROGATION")
jsonBridge~addGetNamedMember("doc","house","house")
jsonBody=jsonBridge~renderMethodBody
call assertContains jsonBody,'.json~fromJsonFile("house.json")',"language knowledge emits json API"
call assertContains jsonBody,'house = doc["house"]',"named-member traversal emitted"
packages=jsonBridge~requiredPackages
call assertEq 1,packages~items,"one required package"
call assertEq "json.cls",packages[1],"json package derived from language knowledge"

say "PASS Coding Intention semantic steps -> deterministic ooRexx method body"
exit 0

::routine assertEq
  use arg expected,actual,label
  if expected\==actual then do
    say "FAIL" label
    say "EXPECTED:" expected
    say "ACTUAL:" actual
    raise syntax 88.900 array("test assertion failed")
  end
::routine assertContains
  use arg haystack,needle,label
  if pos(needle,haystack)=0 then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::requires "../src/LlmSemanticCodingBridge.cls"
