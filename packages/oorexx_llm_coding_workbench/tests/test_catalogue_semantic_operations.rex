/* Coding Intention dev13 catalogue -> deterministic ooRexx proof. */
bridge=.LlmSemanticCodingBridge~new("CatalogueDemo","build")

a=.directory~new; a["target"]="doc"
bridge~addOperation("CREATE_DIRECTORY",a)
a=.directory~new; a["target"]="doc"; a["member"]="status"; a["value"]="ready"
bridge~addOperation("SET_NAMED_MEMBER",a)
a=.directory~new; a["source"]="doc"; a["target"]="encoded"
bridge~addOperation("ENCODE_JSON_TEXT",a)
a=.directory~new; a["value"]="$encoded"
bridge~addOperation("RETURN_VALUE",a)

body=bridge~renderMethodBody
call assertContains body,"doc = .Directory~new","directory construction"
call assertContains body,'doc["status"] = "ready"',"named member assignment"
call assertContains body,"encoded = .json~toJSON(doc)","JSON API from language knowledge"
call assertContains body,"return encoded","variable return"
packages=bridge~requiredPackages
call assertEq 1,packages~items,"one package"
call assertEq "json.cls",packages[1],"json package derived from catalogue"

skills=bridge~availableSkills
call assertEq 7,skills~items,"dev9 skills exposed"
ops=bridge~availableOperations
call assertTrue ops~items>=30,"dev9 operation catalogue exposed"
call assertRenderable ops,"CREATE_DIRECTORY",.true
call assertRenderable ops,"SEND_MESSAGE",.true
call assertRenderable ops,"IF_THEN",.false

signal on syntax name unsupported
bad=.directory~new; bad["condition"]="x"
bridge~addOperation("IF_THEN",bad)
signal off syntax
say "FAIL known but unsupported operation should fail closed"
exit 1
unsupported:
  signal off syntax

say "PASS Coding Intention dev13 catalogue -> deterministic semantic operations"
exit 0

::routine assertRenderable
  use arg ops,name,expected
  do d over ops
    if d["operation"]==name then do
      call assertEq expected,d["renderable"],name "renderable"
      return
    end
  end
  say "FAIL missing operation" name
  exit 1
::routine assertEq
  use arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
::routine assertTrue
  use arg value,label
  if \value then do; say "FAIL" label; exit 1; end
::routine assertContains
  use arg haystack,needle,label
  if pos(needle,haystack)=0 then do; say "FAIL" label; say haystack; exit 1; end
::requires "../src/LlmSemanticCodingBridge.cls"
