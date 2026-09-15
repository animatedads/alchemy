::class HttpEvidence public
::attribute value get
::attribute lexicalValue get
::attribute name get
::attribute semanticType get
::attribute state get
::method init
  expose value lexicalValue name semanticType state
  use arg valueArg, nameArg = "amount"
  value = valueArg
  lexicalValue = valueArg~string
  name = nameArg
  semanticType = "INTEGER"
  state = "PRESENT"
::method isEvidenceBearing
  return .true
::method sourcePath
  expose value
  return "/fixture/orders/" || value
::method sourceDocument
  return .nil

::class HttpDataCapability public
::method init
  expose invocationCount
  invocationCount = 0
::method runtimeSelfTest
  return .true
::method invocationCount
  expose invocationCount
  return invocationCount
::method runtimeInvokeAbility
  expose invocationCount
  use arg abilityId, context
  invocationCount = invocationCount + 1
  body = context~body
  responseData = .directory~new
  select
    when abilityId = "query" then do
      responseData["generation"] = "DATA-TWO"
      responseData["resource"] = context~dataBinding("orders")~resourceName
      responseData["query"] = body~at("q")
      responseData["invocation_count"] = invocationCount
      responseData["rank"] = 1
      if context~module("rules") == .nil then responseData["rules_visible"] = context~boolean(.false)
      else responseData["rules_visible"] = context~boolean(.true)
      runtimeEvidence = context~runtimeExecutionEvidence("data")
      if runtimeEvidence == .nil then return context~failure("RUNTIME_EVIDENCE_MISSING", "data")
      responseData["runtime_generation"] = runtimeEvidence~generationId
      responseData["runtime_artifact"] = runtimeEvidence~artifactId
      if context~runtimeExecutionEvidence("rules") == .nil then responseData["rules_evidence_visible"] = context~boolean(.false)
      else responseData["rules_evidence_visible"] = context~boolean(.true)
      rows = .array~new
      row1 = .directory~new; row1["id"] = 1; row1["amount"] = 10; row1["amount_evidence"] = .HttpEvidence~new(10)
      row2 = .directory~new; row2["id"] = 2; row2["amount"] = 20; row2["amount_evidence"] = .HttpEvidence~new(20)
      rows~append(row1); rows~append(row2)
      responseData["rows"] = rows
      return context~success(responseData)
    end
    when abilityId = "echo.custom" then do
      responseData["generation"] = "DATA-TWO"
      responseData["echo"] = body~at("message")
      responseData["invocation_count"] = invocationCount
      if context~module("rules") == .nil then responseData["rules_visible"] = context~boolean(.false)
      else responseData["rules_visible"] = context~boolean(.true)
      return context~success(responseData)
    end
    otherwise return context~failure("ABILITY_UNKNOWN", abilityId)
  end
