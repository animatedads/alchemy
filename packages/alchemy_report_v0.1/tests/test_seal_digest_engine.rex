eng = .ReportSealDigest~engine
d = .ReportSealDigest~of("hello")
if eng = "SHA-512" then do
  if d~left(8) \= "SHA-512:" then do
    say "FAIL engine SHA-512 but digest" d
    exit 1
  end
end
else do
  if d~left(14) \= "FINGERPRINT/1:" then do
    say "FAIL engine fallback but digest" d
    exit 1
  end
end
say "PASS test_seal_digest_engine" eng d
exit 0

::requires "../src/AlchemyReport.cls"
