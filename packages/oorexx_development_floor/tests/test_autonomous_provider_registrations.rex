failures = 0
catalog = .DFRegistrationCatalog~fromJsonFile("config/default_registrations.json")

llama = catalog~executionProviders~at("local-qwen-llamacpp")
call check llama \== .nil, "llama provider registered"
if llama \== .nil then do
  call check llama~transport = "AI_ACCESS_OPENAI_COMPAT", "llama routes through AI Access OpenAI-compatible transport"
  call check llama~status = "TRANSPORT_QUALIFIED_RUNTIME_UNPROBED", "llama transport qualified without false live runtime claim"
  call check llama~metadata~at("auth_mode") = "NONE", "llama is no-auth"
  call check boolValue(llama~metadata~at("loopback_only"), .true), "llama is loopback-only"
  call check llama~hasCapability("AUTONOMOUS_CODING"), "llama can be selected for autonomous coding"
end

luna = catalog~executionProviders~at("azure-gpt-6-luna")
call check luna \== .nil, "Azure Luna registered"
if luna \== .nil then do
  call check luna~transport = "AI_ACCESS_AZURE_OPENAI", "Azure routes through AI Access Azure transport"
  call check luna~metadata~at("auth_mode") = "API_KEY", "Azure key auth mode explicit"
  call check luna~metadata~at("auth_header") = "api-key", "Azure key header explicit"
  call check luna~metadata~at("wire_api") = "AZURE_RESPONSES_V1", "Azure Luna uses Responses v1 wire API"
  call check boolValue(luna~metadata~at("api_version_required"), .false), "Azure Responses v1 does not require api-version query"
  call check boolValue(luna~metadata~at("live_credential_exercised"), .true), "Azure Luna records exercised live credential path"
  call check luna~status = "LIVE_QUALIFIED", "Azure Luna live worker qualification is explicit"
end

bot = catalog~bots~at("coding-specialist")
call check bot~hasCapability("AUTONOMOUS_CODING_LOOP"), "coding bot has autonomous loop capability"
call check boolValue(bot~constraint("MODEL_SHELL_AUTHORITY"), .false), "model has no shell authority"
call check boolValue(bot~constraint("MODEL_FILESYSTEM_AUTHORITY"), .false), "model has no filesystem authority"
call check boolValue(bot~constraint("DETERMINISTIC_SECOND_BITE_REQUIRED"), .true), "second bite required"

if failures = 0 then do
  say "PASS test_autonomous_provider_registrations"
  exit 0
end
say "FAIL test_autonomous_provider_registrations failures=" failures
exit 1

boolValue: procedure
  use arg value, expected
  if expected then return value = 1
  return value = 0

check: procedure expose failures
  use arg conditionValue, label
  if conditionValue then return
  say "FAIL" label
  failures += 1
  return

::requires "Registrations.cls"
