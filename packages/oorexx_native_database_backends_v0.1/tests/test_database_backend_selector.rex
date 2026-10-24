/*
 * Proves configuration-only provider selection and ooRexx package namespace isolation.
 * ProviderA.cls and ProviderB.cls deliberately export the same DatabaseRow public
 * class name with different semantics. Neither class may leak into this caller.
 */
root = value("NATIVE_DB_ROOT", , "ENVIRONMENT")
if root = "" then do
  say "FAIL: NATIVE_DB_ROOT is required"
  exit 2
end
fixture = root || "/tests/backend_selector_fixtures/"

opts = .directory~new
opts["provider"] = "MOCKA"
opts["package"] = fixture || "ProviderA.cls"
opts["class"] = "BackendProviderA"
selector = .DatabaseBackendSelector~new
row = selector~open(opts)
call assert \row~isA(.DatabaseBackendSelectionError), "provider A loaded"
call assert row~source = "A", "provider A result"
call assert selector~selectedProvider = "MOCKA", "provider name retained"

optsB = .directory~new
optsB["provider"] = "MOCKB"
optsB["package"] = fixture || "ProviderB.cls"
optsB["class"] = "BackendProviderB"
selectorB = .DatabaseBackendSelector~new
rowB = selectorB~open(optsB)
call assert \rowB~isA(.DatabaseBackendSelectionError), "provider B loaded"
call assert rowB~source = "B", "provider B result"

call assert .context~package~findClass("DatabaseRow") == .nil, "provider DatabaseRow stays package-local"

oldProvider = value("OOREXX_DATABASE_PROVIDER", , "ENVIRONMENT")
oldPackage = value("OOREXX_DATABASE_PROVIDER_PACKAGE", , "ENVIRONMENT")
oldClass = value("OOREXX_DATABASE_PROVIDER_CLASS", , "ENVIRONMENT")
ignore = value("OOREXX_DATABASE_PROVIDER", "MOCKA", "ENVIRONMENT")
ignore = value("OOREXX_DATABASE_PROVIDER_PACKAGE", fixture || "ProviderA.cls", "ENVIRONMENT")
ignore = value("OOREXX_DATABASE_PROVIDER_CLASS", "BackendProviderA", "ENVIRONMENT")
envRow = .DatabaseBackendSelector~new~open
call assert \envRow~isA(.DatabaseBackendSelectionError), "environment provider loaded"
call assert envRow~source = "A", "environment-only selection"
ignore = value("OOREXX_DATABASE_PROVIDER", oldProvider, "ENVIRONMENT")
ignore = value("OOREXX_DATABASE_PROVIDER_PACKAGE", oldPackage, "ENVIRONMENT")
ignore = value("OOREXX_DATABASE_PROVIDER_CLASS", oldClass, "ENVIRONMENT")

bad = .directory~new
bad["provider"] = "OTHER"
badResult = .DatabaseBackendSelector~new~open(bad)
call assert badResult~isA(.DatabaseBackendSelectionError), "unknown unconfigured provider fails closed"

say "DATABASE BACKEND SELECTOR: PASS"
exit 0

assert: procedure
  use strict arg conditionValue, label
  if conditionValue then return
  say "FAIL:" label
  exit 1

::requires "DatabaseBackendSelector.cls"
