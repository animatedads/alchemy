/* Sparse historical assessment view.
   The application supplies already-produced assessments. Wire retains no ML
   training authority and never changes collection order or source evidence. */
::class WireAssessmentKey public
::attribute subjectId get
::attribute kind get
::attribute modelId get
::attribute modelPoint get
::attribute branch get
::method init
  expose subjectId kind modelId modelPoint branch
  use strict arg subjectId, kind, modelId = "", modelPoint = "", branch = ""
::method string
  expose subjectId kind modelId modelPoint branch
  return subjectId || "|" || kind || "|" || modelId || "|" || modelPoint || "|" || branch

::class WireAssessmentStore public
::method init
  expose assessments
  assessments = .directory~new
::method put
  expose assessments
  use strict arg subjectRef, assessment
  key = .WireAssessmentKey~new(subjectRef~string, assessment~kind, assessment~modelId, assessment~modelPoint, assessment~branch)
  assessments[key~string] = assessment
  return key
::method get
  expose assessments
  use strict arg subjectRef, kind, modelId = "", modelPoint = "", branch = ""
  key = .WireAssessmentKey~new(subjectRef~string, kind, modelId, modelPoint, branch)~string
  if assessments~hasIndex(key) then return assessments[key]
  return .nil

::class WireAssessmentView public
::method init
  expose store kind modelId modelPoint branch
  use strict arg store, kind, modelId = "", modelPoint = "", branch = ""
::method select
  expose kind modelId modelPoint branch
  use strict arg newModelId = "", newModelPoint = "", newBranch = ""
  modelId = newModelId; modelPoint = newModelPoint; branch = newBranch
::method assessmentForSubject
  expose store kind modelId modelPoint branch
  use strict arg subjectRef
  return store~get(subjectRef, kind, modelId, modelPoint, branch)
::method valueForSubject
  a = self~assessmentForSubject(arg(1))
  if a == .nil then return .nil
  return a~value
