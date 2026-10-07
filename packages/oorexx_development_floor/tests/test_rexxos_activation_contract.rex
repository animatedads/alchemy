states = .DFRexxOSActivationContract~states
call assertEqual 4, states~items, "activation state count"
call assertEqual "STAGED", states[1], "first activation state"
call assertEqual "RECONSTRUCTED", states[2], "reconstruction state"
call assertEqual "BOUND", states[3], "binding state"
call assertEqual "ACTIVE", states[4], "active state"
call assertEqual "RECONSTRUCTED", .DFRexxOSActivationContract~nextState("STAGED"), "staged advances only to reconstructed"
call assertEqual "BOUND", .DFRexxOSActivationContract~nextState("RECONSTRUCTED"), "reconstructed advances to bound"
call assertEqual "ACTIVE", .DFRexxOSActivationContract~nextState("BOUND"), "bound advances to active"
call assertEqual .nil, .DFRexxOSActivationContract~nextState("ACTIVE"), "active is terminal in activation contract"
call assertEqual 0, .DFRexxOSActivationContract~canClaimActive("STAGED"), "cannot claim active from staged"
call assertEqual 0, .DFRexxOSActivationContract~canClaimActive("BOUND"), "cannot claim active from bound"
call assertEqual 1, .DFRexxOSActivationContract~canClaimActive("ACTIVE"), "active claim requires active state"
say "PASS test_rexxos_activation_contract"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "Registrations.cls"
