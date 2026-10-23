/*
 * Wire-facing adapter for the human Code Examiner.
 *
 * This class deliberately owns no browser identity and no permission policy.
 * It accepts only a server-resolved security context containing an opaque SSC
 * access token.  SemanticSourceSecureExaminer resolves the verified principal
 * and re-authorises the requested action.
 */
::class SemanticSourceWireActionAdapter public

::method init
  use strict arg secureExaminer, clock, intentionController = .nil
  self~secureExaminer = secureExaminer
  self~clock = clock
  self~intentionController = intentionController

::attribute secureExaminer get
::attribute secureExaminer set private
::attribute clock get
::attribute clock set private
::attribute intentionController get
::attribute intentionController set private

::method initialView
  use strict arg securityContext
  token = self~requiredField(securityContext, "access_token")
  nowValue = self~now
  return self~secureExaminer~initialView(token, nowValue)

::method handleWireAction
  use strict arg actionEnvelope, securityContext
  if actionEnvelope == .nil then raise syntax 88.900 array("Wire action envelope is required")
  token = self~requiredField(securityContext, "access_token")
  actionName = self~requiredField(actionEnvelope, "action")
  detail = self~field(actionEnvelope, "detail", .directory~new)
  if detail == .nil then detail = .directory~new
  stepUp = self~field(actionEnvelope, "step_up", .nil)

  if actionName = "INTENTION.SUBMIT" then do
    if self~intentionController == .nil then raise syntax 88.900 array("Examiner Intention Service is not configured")
    return self~intentionController~handleWireIntent(token, detail, self~now, stepUp)
  end

  -- Never accept browser-selected identity.  If present it remains inert data
  -- and SemanticSourceSecureExaminer derives principal identity from token.
  nowValue = self~now
  return self~secureExaminer~handleAction(token, actionName, detail, nowValue, stepUp)

::method now private
  if self~clock == .nil then return .DateTime~now~isoDate || "T" || .DateTime~now~longTime
  return self~clock~now

::method requiredField private
  use strict arg record, key
  value = self~field(record, key, "")
  if value == "" then raise syntax 88.900 array("required Wire security/action field missing: " || key)
  return value

::method field private
  use strict arg record, key, defaultValue
  if record == .nil then return defaultValue
  if \record~hasIndex(key) then return defaultValue
  value = record[key]
  if value == .nil then return defaultValue
  return value

::requires "SemanticSourceSecureExaminer.cls"

::requires "SemanticSourceIntentionController.cls"
