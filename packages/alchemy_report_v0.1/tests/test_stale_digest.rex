doc = .ReportDocument~new("stale-1", "Stale source")
b = .ReportBinding~new("b1", "PRIMARY", "HOST_RECORD", "AS400:PNR:X", "sha256:old")
c = .ReportClaim~new("c1", "PNR status is DIVERT.", "FACT")
ignore = c~addBindingId("b1")
ignore = doc~addBinding(b)
ignore = doc~addClaim(c)
got = doc~markStaleIfDigestDiffers("b1", "sha256:new")
if got \= "STALE" then do
  say "FAIL expected STALE got" got
  exit 1
end
st = doc~groundClaim("c1")
if st \= "STALE" then do
  say "FAIL claim status" st
  exit 1
end
say "PASS test_stale_digest"
exit 0

::requires "../src/AlchemyReport.cls"
