::class HttpRulesCapability public
::method init
  expose invocationCount
  invocationCount = 0
::method runtimeSelfTest
  return .true
::method runtimeInvokeAbility
  expose invocationCount
  use arg abilityId, context
  invocationCount = invocationCount + 1
  if abilityId <> "evaluate" then return context~failure("ABILITY_UNKNOWN", abilityId)
  body = context~body
  action = body~at("action")
  responseData = .directory~new
  responseData["generation"] = "RULES-ONE"
  responseData["action"] = action
  responseData["invocation_count"] = invocationCount
  if action = "SELL_BAG" then responseData["disposition"] = "PROHIBITED"
  else responseData["disposition"] = "PERMITTED"
  if context~module("data") == .nil then responseData["data_visible"] = context~boolean(.false)
  else responseData["data_visible"] = context~boolean(.true)
  return context~success(responseData)
