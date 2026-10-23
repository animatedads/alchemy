/*
 * Security boundary for the human Code Examiner.
 *
 * Browser-supplied identity is never authoritative.  Every request resolves an
 * opaque bearer session through SemanticSourceAuthenticator, re-runs Access
 * Permissions for the semantic action, and derives the principal from that
 * verified session.  Privileged review/branch changes additionally require an
 * action-bound signed challenge proof for the same principal.
 */
::class SemanticSourceSecureExaminer public

::method init
  use strict arg examiner, authenticator, audience = "semantic-source-mcp"
  self~examiner = examiner
  self~authenticator = authenticator
  self~audience = audience

::attribute examiner get
::attribute examiner set private
::attribute authenticator get
::attribute authenticator set private
::attribute audience get
::attribute audience set private

::method initialView
  use strict arg accessToken, nowValue
  session = self~authenticator~resolveSession(accessToken, nowValue, self~audience)
  principalId = self~field(session, "principal_id", "")
  ignore = self~authenticator~authorizeBearerAction(accessToken, nowValue, "CODE.CATALOG", "", self~audience)
  return self~examiner~initialView(principalId)

::method handleAction
  use strict arg accessToken, actionName, payload, nowValue, stepUp = .nil
  if payload == .nil then payload = .directory~new
  resourceId = self~resourceId(payload)
  session = self~authenticator~authorizeBearerAction(accessToken, nowValue, actionName, resourceId, self~audience)
  principalId = self~field(session, "principal_id", "")

  if self~requiresStepUp(actionName) then self~validateStepUp(stepUp, principalId, actionName, resourceId)
  return self~examiner~handleAction(actionName, payload, principalId)

::method requiresStepUp private
  use strict arg actionName
  select
    when actionName = "WORK.ACCEPT" then return 1
    when actionName = "WORK.REFUSE" then return 1
    when actionName = "BRANCH.CLASSIFY" then return 1
    when actionName = "BRANCH.PROTECT" then return 1
    when actionName = "BRANCH.CONFLICT.RESOLVE" then return 1
    otherwise return 0
  end

::method validateStepUp private
  use strict arg proof, principalId, actionName, resourceId
  if proof == .nil then raise syntax 88.900 array("fresh signed challenge required for privileged action: " || actionName)
  if self~field(proof, "principal_id", "") \= principalId then raise syntax 88.900 array("step-up principal mismatch")
  if self~field(proof, "action", "") \= actionName then raise syntax 88.900 array("step-up action mismatch")
  proofResource = self~field(proof, "resource_id", "")
  if resourceId \= "" & proofResource \= resourceId then raise syntax 88.900 array("step-up resource mismatch")
  if self~field(proof, "audience", "") \= self~audience then raise syntax 88.900 array("step-up audience mismatch")
  return 1

::method resourceId private
  use strict arg payload
  keys = .array~of("object_id", "work_entry_id", "branch_id", "module_id", "deployment_id", "resource_id")
  do key over keys
    if payload~hasIndex(key) then do
      value = payload[key]
      if value \= .nil & value \= "" then return value
    end
  end
  return ""

::method field private
  use strict arg record, key, defaultValue
  if record == .nil then return defaultValue
  if \\record~hasIndex(key) then return defaultValue
  value = record[key]
  if value == .nil then return defaultValue
  return value

::requires "SemanticSourceCodeExaminer.cls"
::requires "SemanticSourceAuthenticator.cls"
