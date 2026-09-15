classes = .array~of(.CivicObservationField, .CivicObservationResult, .CivicObservation, .CivicObservationFactory, .CivicPromotionGrant, .CivicPromotionApplyResult, .CivicPromotionApplier)
do cls over classes
  call assert cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assert cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end
say "PASS test_alchemy_base_hardworld_v07"
exit 0

assert: procedure
  use arg ok, label
  if ok then return
  say "FAIL test_alchemy_base_hardworld_v07:" label
  exit 1

::requires "CivicHardWorld.cls"
