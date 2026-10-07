/* Materialised-source verification seam for the LLM Coding Workbench.
 *
 * Semantic Source Store / Development Desk remains source authority.  This
 * verifier asks the Desk to materialise the current package after a mutation,
 * re-reads the target semantic method, and gives both objects to an injected
 * checker.  The checker owns language/toolchain execution and returns a
 * structured verification result; no compiler output is flattened into prompt
 * prose here.
 */
::class LlmCodingMaterialisedVerifier public
::attribute session get
::attribute checker get
::attribute verificationCount get

::method init
  expose session checker verificationCount
  use strict arg sessionArg,checkerArg
  if sessionArg==.nil then raise syntax 88.900 array("coding Desk session is required")
  if checkerArg==.nil then raise syntax 88.900 array("verification checker is required")
  session=sessionArg
  checker=checkerArg
  verificationCount=0

::method verify
  expose session checker verificationCount
  use strict arg workbench,choice,outcome,challenge,className,methodName
  action=translate(choice~action~string)
  if action<>"WRITE_METHOD" & action<>"CODING_APPLY_METHOD" & action<>"MATERIALISE" then return .nil

  verificationCount+=1
  args=.directory~new
  build=session~execute("MATERIALISE",args)
  memberPath=session~memberPath
  if build==.nil then raise syntax 88.900 array("Development Desk MATERIALISE returned NIL")
  if \build~hasIndex("files") then raise syntax 88.900 array("Development Desk MATERIALISE omitted files")
  files=build["files"]
  if files==.nil then raise syntax 88.900 array("Development Desk MATERIALISE files is NIL")
  if \files~hasIndex(memberPath) then raise syntax 88.900 array("materialised package omitted member "||memberPath)

  currentMethod=session~viewMethod(className,methodName)
  request=.directory~new
  request["schema"]="oorexx.llm-coding.verification-request/0.1"
  request["verification_id"]="verify-"||verificationCount
  request["challenge"]=challenge
  request["action"]=action
  request["member_path"]=memberPath
  request["class_name"]=className
  request["method_name"]=methodName
  request["source_text"]=files[memberPath]
  request["semantic_method"]=currentMethod
  request["action_outcome"]=outcome

  checked=checker~verifyMaterialised(request)
  if checked==.nil then raise syntax 88.900 array("verification checker returned NIL")
  if \checked~isA(.directory) then raise syntax 88.900 array("verification checker must return a Directory")
  if \checked~hasIndex("status") then raise syntax 88.900 array("verification checker omitted status")

  evidence=.directory~new
  evidence["schema"]="oorexx.llm-coding.verification/0.2"
  evidence["kind"]="VERIFICATION"
  if checked~hasIndex("stage") then evidence["stage"]=translate(checked["stage"]~string)
  else evidence["stage"]="PROJECT"
  evidence["status"]=translate(checked["status"]~string)
  if checked~hasIndex("details") then evidence["details"]=checked["details"]
  else evidence["details"]=.directory~new
  evidence["member_path"]=memberPath
  evidence["class_name"]=className
  evidence["method_name"]=methodName
  evidence["semantic_method"]=currentMethod
  return evidence
