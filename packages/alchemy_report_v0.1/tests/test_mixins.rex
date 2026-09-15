doc = .ReportDocumentChecked~new("mix-1", "Mixin report")
b = .ReportBinding~new("b1", "PRIMARY", "QUEUE_JOURNAL", "QUEUEJOURNAL:1",,
      .ReportSealDigest~of("payload-a"))
c = .ReportClaim~new("c1", "Journal record 1 is current.", "FACT")
ignore = c~addBindingId("b1")
ignore = doc~addBinding(b)~addClaim(c)
st = doc~bindingMatchesLive(b, "payload-a")
if st \= "MATCH" then do
  say "FAIL match" st
  exit 1
end
st2 = doc~bindingMatchesLive(b, "payload-b")
if st2 \= "STALE" then do
  say "FAIL stale" st2
  exit 1
end
say "PASS test_mixins" doc~digestEngine
exit 0

::requires "../src/ReportDocumentChecked.cls"
