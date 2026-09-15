doc = .ReportDocument~new("rt-1", "Round trip")
b = .ReportBinding~new("b1", "PRIMARY", "HOST_RECORD", "HOST:X", "dig", "span1")
c = .ReportClaim~new("c1", "X is set.", "FACT")
ignore = c~addBindingId("b1")
s = .ReportSection~new("s1", "Sec")
ignore = s~addClaimId("c1")
ignore = doc~addBinding(b)~addClaim(c)~addSection(s)
d1 = doc~seal
mf = doc~machineForm
doc2 = .ReportCodec~load(mf)
if doc2~reportId \= "rt-1" then do
  say "FAIL id"
  exit 1
end
if doc2~claim("c1")~text \= "X is set." then do
  say "FAIL text"
  exit 1
end
if doc2~binding("b1")~sourcePoint \= "HOST:X" then do
  say "FAIL binding"
  exit 1
end
d2 = doc2~seal
if d1 \= d2 then do
  say "FAIL digest" d1 d2
  exit 1
end
say "PASS test_codec_roundtrip" d1
exit 0

::requires "../src/AlchemyReport.cls"
