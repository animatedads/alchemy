/* Workbench-owned advisory hints built on Intention Service dev8.
 * Hints are evidence only: they do not dispatch, commit, or mutate source. */
::class LlmCodingHintBridge public
::attribute library get

::method init
  expose library
  library=.IntentionHintLibrary~new("LLM_CODING")
  self~addStateHint("WRITE_METHOD","SEMANTIC_METHOD_TARGET",22,"Prefer semantic Coding Intention operations before raw method source")
  self~addStateHint("WRITE_METHOD","VERIFICATION_FAILED",25,"Repair the current method from structured compile/test evidence")
  self~addStateHint("MATERIALISE","METHOD_CHANGED",18,"Materialise accepted semantic source before verification")
  self~addStateHint("REPORT","VERIFICATION_PASSED",20,"Report only when verification evidence supports completion")
  self~addPlanHint("WRITE_METHOD","Repair/write one method, then verify", -
      .array~of(.array~of("INSPECT","Use current semantic method context","METHOD"), -
                .array~of("WRITE_METHOD","Apply one bounded method change","METHOD"), -
                .array~of("VERIFY","Compile/test after the change","METHOD")))
  self~addPlanHint("MATERIALISE","Materialise for verification", -
      .array~of(.array~of("MATERIALISE","Reconstruct source from semantic revisions","PACKAGE"), -
                .array~of("VERIFY","Compile/test materialised source","PACKAGE")))
  self~addPlanHint("REPORT","Report verified completion", -
      .array~of(.array~of("REPORT","Ground completion in verification evidence","RESULT")))

::method addStateHint private
  expose library
  use strict arg intentionId,stateTag,weight,evidence
  hint=library~hint(intentionId)
  hint~phrase(stateTag,"EXACT",weight)
  hint~evidence(evidence)
  return hint

::method addPlanHint private
  expose library
  use strict arg intentionId,evidence,steps
  hint=library~hint(intentionId)
  hint~evidence(evidence)
  plan=.IntentionPlan~new(intentionId,evidence)
  do row over steps
    plan~addStep(row[1],row[2],row[3])
  end
  hint~plan(plan)
  hint~planAlways(.true)
  return hint

::method registerWith
  expose library
  use strict arg service
  service~registerHintLibrary(library)
  return self

::method advise
  expose library
  use strict arg stateTags
  out=.array~new
  do tag over stateTags
    matches=library~matches(tag)
    do m over matches
      if \m~phraseMatched then iterate
      hint=m~hint
      d=.directory~new
      d["intention"]=hint~intentionId
      d["state"]=tag
      d["weight"]=m~phraseWeight
      d["evidence"]=m~evidence
      out~append(d)
    end
  end
  return out

::requires "IntentionContext.cls"
