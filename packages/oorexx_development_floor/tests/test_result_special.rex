/* Qualification evidence for OOREXX-RESULT-001. */
probeArray = .Array~new
probeArray~append("x")
if RESULT <> "1" then do
  say "FAIL expected special RESULT to contain append return value 1; actual=" RESULT
  exit 1
end
say "PASS test_result_special"
exit 0
