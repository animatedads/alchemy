secret = "TOP-SECRET-FIXTURE-7E4B"
p = .TestSecretProvider~new
call assertTrue p~put("provider.primary", secret), "put"
b = .SecretBroker~new(p)
lease = b~acquire("provider.primary")
call assertTrue lease~ok, "acquire ok"
call assertTrue lease~isa(.SecretLease), "lease type"
call assertEq lease, lease~value, "result-style value is lease"
out = lease~secretForTrustedConsumer
call assertTrue out~ok, "trusted read ok"
call assertEq secret, out~value, "trusted read value"
call assertEq secret, lease~secretValue, "legacy direct value"
call assertEq 1, b~acquisitionCount, "acquisition count"
call assertEq 1, b~activeLeaseCount, "active lease count"
call assertTrue lease~retire, "retire"
call assertEq 0, b~activeLeaseCount, "retired lease count"
call assertEq "", lease~secretValue, "retired secret unavailable"
call assertTrue \lease~secretForTrustedConsumer~ok, "trusted read denied after retire"
evidence = .AlchemyCanonical~encode(b~instrumentationEvents) || .AlchemyCanonical~encode(p~instrumentationEvents)
call assertEq 0, evidence~pos(secret), "secret excluded from evidence"
missing = b~acquire("missing")
call assertTrue \missing~ok, "missing fails"
call assertEq "", missing~secretValue, "missing has no value"
say "PASS test_secret_broker"
exit 0
assertEq: procedure; use arg e,a,l; if e \== a then do; say "FAILED" l "expected="e "actual="a; exit 41; end; return
assertTrue: procedure; use arg v,l; if \v then do; say "FAILED" l; exit 42; end; return
::requires "SecretBroker.cls"
