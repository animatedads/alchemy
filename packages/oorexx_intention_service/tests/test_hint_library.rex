/* Hint library regression. */
parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~register("search products", "SEARCH")
service~register("delete products", "DELETE")

library = .IntentionHintLibrary~new("DATABASE_PATTERNS")
searchHint = library~hint("SEARCH_PRODUCTS")
searchHint~phrase("stock lookup", "CONTAINS", 12)
searchPlan = .IntentionPlan~new("SEARCH_PRODUCTS", "Search products")
searchPlan~addStep("RESOLVE_ENTITY", "Resolve product identity", "PRODUCT")
searchPlan~addStep("QUERY", "Query matching products", "PRODUCTS")
searchHint~plan(searchPlan)
searchHint~evidence("curated database phrase/plan pattern")

alwaysHint = library~hint("DELETE_PRODUCTS")
alwaysPlan = .IntentionPlan~new("DELETE_PRODUCTS", "Delete matching products")
alwaysPlan~addStep("VERIFY", "Verify exact product selection", "PRODUCT")
alwaysHint~plan(alwaysPlan)
alwaysHint~planAlways(.true)

service~registerHintLibrary(library)

decision = service~input("stock lookup")
call assert decision~status == "CONFIRM", "phrase hint should propose registered intention"
call assert decision~proposal~providerName == "HINT", "hint provider should be visible"
call assert decision~proposedPlan \== .nil, "matched phrase hint should attach plan"
call assert decision~proposedPlan~steps~items == 2, "hint plan should retain steps"

/* Plan-only hint applies when another provider wins the meaning. */
service2 = .IntentionService~new
r = service2~register("delete products", "DELETE")
r~alias("remove products")
service2~registerHintLibrary(library)
service2~registerProvider(.DeterministicIntentionProvider~new)
d2 = service2~input("delete products")
call assert d2~proposal~providerName \== "HINT", "plan-only hint must not manufacture recognition"
call assert d2~proposedPlan \== .nil, "plan-only hint should shape known intention plan"
call assert d2~proposedPlan~steps~items == 1, "plan-only hint should add one advisory step"

say "PASS test_hint_library"
exit 0

assert: procedure
  use arg ok, message
  if \ok then do
    say "FAIL:" message
    exit 1
  end
  return


::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
