path=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if path=="" then do; say "FAIL LLM_CODING_CATALOGUE missing"; exit 2; end
k=.LlmRexxKnowledgeCatalogue~new(path)
call assertEqual "rexx", k~language, "selected language"
call assertEqual "RexxLanguageKnowledge.resolveOperation", k~capabilityAuthority, "capability authority"
call assertTrue k~supportsOperation("LOAD_YAML_FILE"), "ooRexx authority must advertise YAML load"
call assertTrue k~supportsOperation("SAVE_YAML_FILE"), "ooRexx authority must advertise YAML save"
call assertTrue \k~supportsOperation("INVENT_PYYAML_MAGIC"), "invented operation must not be supported"
b=.LlmSemanticCodingBridge~new("CapabilityDemo","load",k)
call assertTrue b~supportsOperation("LOAD_YAML_FILE"), "bridge must consume language capability"
ops=b~availableOperations
found=.false
do o over ops
  if o["operation"]=="LOAD_YAML_FILE" then do
    found=.true
    call assertTrue o["language_supported"], "turn capability flag"
    call assertTrue o["renderable"], "YAML must be deterministically renderable"
    call assertContains o["capability_evidence"], "yaml.cls", "capability evidence must name authoritative API"
  end
end
call assertTrue found, "YAML capability must be projected to Luna turn"
args=.directory~new; args["filename"]="house.yaml"; args["target"]="x"
ignore=b~addOperation("LOAD_YAML_FILE",args)
call assertContains b~renderMethodBody, '.Yaml~new~parseFile("house.yaml")', "renderer uses authoritative YAML contract"
call assertTrue contains(b~requiredPackages,"yaml.cls"), "renderer carries yaml.cls requirement"
say "PASS Coding Intention dev13 language capability negotiation projected to workbench"
exit 0

contains: procedure
  use arg values,wanted
  do v over values; if v==wanted then return .true; end
  return .false
assertTrue: procedure
  use arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
return
assertEqual: procedure
  use arg expected,actual,message
  if expected \== actual then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
return
assertContains: procedure
  use arg actual,wanted,message
  if pos(wanted,actual)==0 then do; say "FAIL:" message "actual="actual; exit 1; end
return
::requires "LlmRexxKnowledgeCatalogue.cls"
::requires "LlmSemanticCodingBridge.cls"
