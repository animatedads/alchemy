/* A GROUNDED status without bindings must not seal. */
doc = .ReportDocument~new("bad-1", "Unsourced pretty text")
c = .ReportClaim~new("c1", "Everything is fine.", "FACT", "GROUNDED")
doc~addClaim(c)
signal on syntax name sealed_ok
ignore = doc~seal
say "FAIL seal should have refused"
exit 1

sealed_ok:
  say "PASS test_unsourced_cannot_ground"
  exit 0

::requires "../src/AlchemyReport.cls"
