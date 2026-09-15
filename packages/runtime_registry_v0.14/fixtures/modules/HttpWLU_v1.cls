::class HttpWLUCapability public
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

  select
    when abilityId = "query" then do
      tokens = body~at("actual_tokens")
      if tokens == .nil then tokens = 3
      meterOutcome = context~meterFact("TOKEN", tokens, "http-wlu-query")
      if \meterOutcome~ok then return meterOutcome
      responseData = .directory~new
      responseData["invocation_count"] = invocationCount
      responseData["wlu_managed"] = context~boolean(context~wluManaged)
      responseData["reservation_id"] = context~wluReservationId
      responseData["scope"] = context~wluScope
      rows = .array~new
      row = .directory~new
      row["business_value"] = "performed"
      rows~append(row)
      responseData["rows"] = rows
      return context~success(responseData)
    end
    when abilityId = "reject.before" then do
      return context~failure("PROVIDER_REJECT_BEFORE", "rejected before work")
    end
    when abilityId = "reject.after" then do
      meterOutcome = context~meterFact("TOKEN", 2, "http-wlu-reject-after")
      if \meterOutcome~ok then return meterOutcome
      return context~failure("PROVIDER_REJECT_AFTER", "rejected after work")
    end
    otherwise return context~failure("ABILITY_UNKNOWN", abilityId)
  end
