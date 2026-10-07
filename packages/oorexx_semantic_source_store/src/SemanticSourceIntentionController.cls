/* Wire-facing Intention Service controller for the Code Examiner.
 *
 * Intention resolution is advisory until a semantic action is dispatched.
 * Dispatch always re-enters SemanticSourceSecureExaminer, so natural-language
 * input cannot bypass bearer-session authority, Access Permissions or step-up.
 */
::class SemanticSourceIntentionController public
::method init
  use strict arg intentionService, secureExaminer
  if intentionService == .nil then raise syntax 88.900 array("IntentionService is required")
  if secureExaminer == .nil then raise syntax 88.900 array("SecureExaminer is required")
  self~service = intentionService
  self~secureExaminer = secureExaminer
::attribute service get
::attribute service set private
::attribute secureExaminer get
::attribute secureExaminer set private

::method handleWireIntent
  use strict arg accessToken, detail, nowValue, stepUp = .nil
  text = self~field(detail, "text", "")
  if text = "" then raise syntax 88.900 array("intention text is required")
  decision = self~service~input(text)
  response = self~decisionRecord(decision)
  if decision~status \= "READY" then return response

  action = decision~event
  response["action"] = action
  payload = self~copyDirectory(self~field(detail, "context", .directory~new))
  self~applyTextDefaults(action, text, payload)

  missing = self~missingFields(action, payload)
  if missing~items > 0 then do
    response["status"] = "READY_NEEDS_CONTEXT"
    response["missing_fields"] = missing
    return response
  end

  execute = self~field(detail, "execute", 1)
  if \execute then do
    response["status"] = "READY"
    response["payload"] = payload
    return response
  end

  response["execution"] = self~secureExaminer~handleAction(accessToken, action, payload, nowValue, stepUp)
  response["status"] = "EXECUTED"
  return response

::method decisionRecord private
  use strict arg decision
  d = .directory~new
  d["status"] = decision~status
  d["question"] = decision~question
  d["discovery_generation"] = decision~discoveryGeneration
  if decision~event \= .nil then d["action"] = decision~event
  choices = .array~new
  do choice over decision~choices
    c = .directory~new
    c["label"] = choice~label
    c["intention_id"] = choice~proposal~intentionId
    choices~append(c)
  end
  d["choices"] = choices
  return d

::method applyTextDefaults private
  use strict arg action, text, payload
  if action = "CODE.SEARCH" & \payload~hasIndex("query") then payload["query"] = text
  return

::method missingFields private
  use strict arg action, payload
  required = .array~new
  select
    when action = "CODE.CATALOG" | action = "CODE.REFRESH" then nop
    when action = "CODE.SEARCH" then required = .array~of("query")
    when action = "CODE.COMPARE" then required = .array~of("object_id", "left_revision_id", "right_revision_id")
    when action = "CODE.FINDING.CREATE" then required = .array~of("object_id", "revision_id", "summary", "detail", "severity", "category")
    when action = "CODE.FINDING.RESOLVE" then required = .array~of("finding_id", "resolution")
    when action = "CODE.PACKAGE.REQUEST" then required = .array~of("roots")
    when action = "CODE.TEST.REQUEST" then required = .array~of("package_request_id", "test_profile")
    when action = "WORK.ACCEPT" | action = "WORK.REFUSE" then required = .array~of("work_entry_id", "findings", "evidence")
    when action = "METHOD.REQUIREMENT.CREATE" then required = .array~of("object_id", "requirement_kind", "requirement_text")
    when action = "METHOD.NOTE.CREATE" then required = .array~of("object_id", "note_kind", "note_text")
    when action = "RESOURCE.UPLOAD" then required = .array~of("object_id", "logical_name", "mime_type", "content", "materialisation_path")
    when action = "MODULE.REQUIREMENT.CREATE" then required = .array~of("requiring_module_id", "scope_kind", "scope_id", "target_module_id", "constraint_kind", "required_deployment_id", "reason")
    when action = "DEPLOYMENT.PACKAGE.REQUEST" then required = .array~of("deployment_id")
    when action = "BRANCH.CLASSIFY" then required = .array~of("branch_id", "classification")
    when action = "BRANCH.PROTECT" then required = .array~of("branch_id", "scope_kind", "scope_id", "reason")
    when action = "BRANCH.PACKAGE.REQUEST" then required = .array~of("branch_id")
    when action = "BRANCH.CONFLICT.RESOLVE" then required = .array~of("branch_id", "conflict_id", "resolution")
    otherwise required = .array~of("object_id")
  end
  missing = .array~new
  do key over required
    if \payload~hasIndex(key) then missing~append(key)
    else if payload[key] == .nil | payload[key] = "" then missing~append(key)
  end
  return missing

::method copyDirectory private
  use strict arg source
  out = .directory~new
  if source == .nil then return out
  supplier = source~supplier
  do while supplier~available
    out[supplier~index] = supplier~item
    supplier~next
  end
  return out

::method field private
  use strict arg record, key, defaultValue
  if record == .nil then return defaultValue
  if \record~hasIndex(key) then return defaultValue
  value = record[key]
  if value == .nil then return defaultValue
  return value
