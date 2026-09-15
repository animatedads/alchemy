secret = "ENV-SECRET-FIXTURE-81AC"
call value "SB_V02_TEST_SECRET", secret, "ENVIRONMENT"
m = .directory~new; m["provider.primary"] = "SB_V02_TEST_SECRET"
p = .MappedEnvironmentSecretProvider~new(m)
b = .SecretBroker~new(p)
lease = b~acquire("provider.primary")
if \lease~ok then do; say "FAILED mapped environment acquisition"; exit 51; end
if lease~secretForTrustedConsumer~value \== secret then do; say "FAILED mapped environment value"; exit 52; end
evidence = .AlchemyCanonical~encode(p~instrumentationEvents) || .AlchemyCanonical~encode(b~instrumentationEvents)
if evidence~pos(secret) > 0 then do; say "FAILED mapped environment evidence leak"; exit 53; end
lease~release
call value "SB_V02_TEST_SECRET", "", "ENVIRONMENT"
second = b~acquire("provider.primary")
if second~ok then do; say "FAILED empty environment should be unavailable"; exit 54; end
say "PASS test_mapped_environment"
exit 0
::requires "SecretBroker.cls"
