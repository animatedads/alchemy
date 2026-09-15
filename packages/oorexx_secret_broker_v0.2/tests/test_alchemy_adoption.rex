p = .TestSecretProvider~new
p~put("x", "hidden")
b = .SecretBroker~new(p)
do object over .array~of(p,b)
  r = .AlchemyAdoptionVerifier~verify(object, "STANDARD")
  if \r~ok then do; say "FAILED STANDARD adoption" object~class~id; exit 61; end
  if r~warnings~items \= 0 then do; say "FAILED adoption warnings" object~class~id r~warnings~items; exit 62; end
  if object~alchemyConstructionProvenance["entrypoint"] \== "INIT" then do; say "FAILED construction provenance" object~class~id object~alchemyConstructionProvenance["entrypoint"]; exit 63; end
end
say "PASS test_alchemy_adoption"
exit 0
::requires "AlchemyAdoption.cls"
::requires "SecretBroker.cls"
