parse arg output
if output=="" then do; say "usage: export_coding_intention_catalogue.rex OUTPUT"; exit 2; end
k=.RexxLanguageKnowledge~new
root=.directory~new
root["schema"]="coding-intention.rexx-language-catalogue/0.3"
root["source"]="coding_intention_steps_v0.1-dev13"
root["language"]="rexx"
root["capability_authority"]="RexxLanguageKnowledge.resolveOperation"
ops=.array~new
do id over k~operations
  o=k~resolveOperation(id)
  d=.directory~new
  d["operation"]=o~operation; d["supported"]=.true; d["category"]=o~category; d["package"]=o~package; d["receiver"]=o~receiver; d["method"]=o~method; d["form"]=o~form; d["result_type"]=o~resultType; d["evidence"]=o~evidence
  ops~append(d)
end
root["operations"]=ops
skills=.array~new
do id over k~skills
  s=k~resolveSkill(id)
  d=.directory~new; d["id"]=s~id; d["purpose"]=s~purpose; d["operations"]=s~operations
  skills~append(d)
end
root["skills"]=skills

/* dev10 retains explicit class/method contracts and result types.  The class identifiers below are
 * only discovery keys; the actual methods/forms/evidence come from the live
 * RexxLanguageKnowledge object. */
classes=.array~new
do classId over .array~of("JSON","YAML","CSVSTREAM","DIRECTORY","ARRAY")
  c=k~resolveClassContract(classId)
  if c==.nil then iterate
  cd=.directory~new
  cd["id"]=c~id; cd["package"]=c~package; cd["evidence"]=c~evidence
  methods=.array~new
  do methodName over c~methodNames
    m=c~method(methodName)
    md=.directory~new
    md["name"]=m~name; md["form"]=m~form; md["result_type"]=m~resultType; md["evidence"]=m~evidence
    methods~append(md)
  end
  cd["methods"]=methods
  classes~append(cd)
end
root["class_contracts"]=classes
.json~toJsonFile(output,root)
say "CATALOGUE" output "operations="ops~items "skills="skills~items "classes="classes~items
::requires "src/RexxLanguageKnowledge.cls"
::requires "json.cls"
