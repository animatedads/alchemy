/* Optional bridge from Examiner Intention Service to Management Intention Discovery. */
::class SemanticSourceIntentionFederation public
::method init
  use strict arg primaryService, managementDirectory = .nil
  if primaryService == .nil then raise syntax 88.900 array("primary IntentionService is required")
  self~primaryService=primaryService
  if managementDirectory == .nil then managementDirectory=.ManagementIntentionDirectory~new
  self~managementDirectory=managementDirectory
::attribute primaryService get
::attribute primaryService set private
::attribute managementDirectory get
::attribute managementDirectory set private
::method registerSpecialist
  use strict arg sourceId, provider
  source=.ManagementSelfAssessingIntentionSurfaceSource~new(sourceId, provider)
  self~managementDirectory~registerSource(source)
  return source
::method resolveSpecialists
  use strict arg text, context=.nil
  resolution=self~managementDirectory~resolve(text, context); out=.array~new
  do candidate over resolution~relevantCandidates
    item=.directory~new; item["source_id"]=candidate~entry~sourceId; item["score"]=candidate~score
    item["authority"]=candidate~assessment~authority; item["reason"]=candidate~assessment~reason
    surface=candidate~entry~surface
    if surface~isA(.Directory) then do
      if surface~hasIndex("provider") then item["provider"]=surface["provider"]
      if surface~hasIndex("operations") then item["operations"]=surface["operations"]
      if surface~hasIndex("mutating") then item["mutating"]=surface["mutating"]
      if surface~hasIndex("generation") then item["generation"]=surface["generation"]
    end
    item["evidence"]=candidate~assessment~evidence; out~append(item)
  end
  return out
::requires "ManagementIntentionDiscovery.cls"
