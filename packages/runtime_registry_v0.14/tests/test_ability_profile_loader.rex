parse arg root
if root = "" then root = "."
say "ABILITY PROFILE LOADER V0.1 START"

loaded = .AbilityProfileLoader~readFile(root || "/fixtures/profiles/customer_bot_v1.ability")
call mustOk loaded, "load ability profile fixture"
profile = loaded~value
call assertEq "customer-bot", profile~profileId, "profile id"
call assertEq "1", profile~revision, "revision"
call assertEq "client-acme", profile~clientId, "client id"
call assertEq "data.orders", profile~runtimeBinding("data")~moduleId, "data runtime module"
call assertEq "ability:data:1", profile~runtimeBinding("data")~artifactId, "data runtime artifact pin"
call assertEq "QUERY", profile~ability("query")~kind, "query ability kind"
call assertEq "object", profile~ability("query")~inputSchema~document~at("type"), "query input schema type"
call assertEq "resource", profile~ability("query")~inputSchema~document~at("required")~at(1), "query schema required resource"
call assertEq "customer_orders", profile~dataBinding("orders")~resourceName, "logical data resource"
call assertEq "customer-policy", profile~ruleBinding("customer-policy")~ruleSetName, "logical rule binding"

/* Reordering set-like declarations cannot change canonical profile identity. */
reordered = .array~of("ABILITY-PROFILE/1",,
  "client-id: client-acme",,
  "revision: 1",,
  "profile-id: customer-bot",,
  "description: Customer chatbot ability profile",,
  "rule: customer-policy|rules|customer-policy",,
  "data: orders|data|customer_orders|READ",,
  "ability: evaluate|EVALUATE|true|data,rules|Rule evaluation",,
  'ability-output-schema: evaluate|{"additionalProperties":true,"type":"object"}',,
  'ability-input-schema: evaluate|{"additionalProperties":true,"properties":{"action":{"minLength":1,"type":"string"}},"required":["action"],"type":"object"}',,
  "ability: query|QUERY|true|data|Bounded federated query",,
  'ability-output-schema: query|{"additionalProperties":true,"type":"object"}',,
  'ability-input-schema: query|{"additionalProperties":false,"properties":{"limit":{"maximum":200,"minimum":1,"type":"integer"},"resource":{"minLength":1,"type":"string"}},"required":["resource"],"type":"object"}',,
  "runtime: rules|rules.customer|ability:rules:1",,
  "runtime: data|data.orders|ability:data:1")
reorderedResult = .AbilityProfileParser~parseLines(reordered)
call mustOk reorderedResult, "parse reordered equivalent profile"
call assertEq profile~canonicalText, reorderedResult~value~canonicalText, "canonical profile text independent of declaration order"

unknown = .array~of("ABILITY-PROFILE/1", "profile-id: x", "revision: 1", "client-id: c", "magic: no")
unknownResult = .AbilityProfileParser~parseLines(unknown)
call assertFalse unknownResult~ok, "unknown field rejected"
call assertEq "ABILITY_PROFILE_FIELD_UNKNOWN", unknownResult~code, "unknown field error code"

duplicate = .array~of("ABILITY-PROFILE/1", "profile-id: x", "profile-id: y", "revision: 1", "client-id: c")
duplicateResult = .AbilityProfileParser~parseLines(duplicate)
call assertFalse duplicateResult~ok, "duplicate singleton field rejected"
call assertEq "ABILITY_PROFILE_FIELD_DUPLICATE", duplicateResult~code, "duplicate field error code"

orphanSchema = .array~of("ABILITY-PROFILE/1", "profile-id: x", "revision: 1", "client-id: c", 'ability-input-schema: missing|{"type":"object"}')
orphanResult = .AbilityProfileParser~parseLines(orphanSchema)
call assertFalse orphanResult~ok, "orphan ability schema rejected"
call assertEq "ABILITY_PROFILE_SCHEMA_ABILITY_NOT_FOUND", orphanResult~code, "orphan schema error code"

say "  profile_identity=" || profile~identity
say "  runtime_bindings=" || profile~runtimeAliases~items
say "  abilities=" || profile~abilityIds~items
say "ABILITY PROFILE LOADER V0.1: OK"
exit 0

mustOk:
  procedure
  use arg r, label
  if \r~ok then do; say "FAILED:" label r~code r~detail; exit 90; end
  return
assertFalse:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 91; end
  return
assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do; say "FAILED:" label; say " expected=" expected; say " actual=" actual; exit 92; end
  return

::requires "AbilityRegistry.cls"
