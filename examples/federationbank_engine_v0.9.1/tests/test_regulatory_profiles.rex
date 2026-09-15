e = .FederationBankFixtures~engine
expected = .directory~new
expected["USD"] = "FB-IOM-USD|FB-LEGAL-USD"
expected["AUD"] = "FB-IOM-AUD|FB-LEGAL-AUD"
expected["GBP"] = "FB-IOM-GBP|FB-LEGAL-GBP"
expected["EUR"] = "FB-IOM-EUR|FB-LEGAL-EUR"
seq = 0
do cur over .array~of("USD","AUD","GBP","EUR")
  seq += 1
  p = e~profiles~byCurrency(cur)
  call assert p <> .nil, "profile missing " || cur
  call assert p~profileId || "|" || p~legalProfileId = expected[cur], "wrong profile " || cur
  cmd = .FederationBankCommand~new("OPEN-" || seq, "OPEN_ACCOUNT", "OPEN-IDEM-" || seq, "CUST-001", "", "", cur, 0, "WEB", "CUST-001", .nil, "OFFSHORE_CURRENT", cur || "-ACCT")
  r = e~handle(cmd)
  call must r, "open " || cur
  call assert r~value["regulatoryProfileId"] = "FB-IOM-" || cur, "account regulatory profile " || cur
  call assert r~value["legalProfileId"] = "FB-LEGAL-" || cur, "account legal profile " || cur
  call assert r~value["legalGenerationId"] = "FB-LEGAL-" || cur, "legal generation route " || cur
  call assert r~value["bookingJurisdiction"] = "IOM", "booking jurisdiction " || cur
end
say "PASS regulatory profiles USD AUD GBP EUR"
exit 0
must: procedure
  use arg r, label
  if r~ok = .false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition, label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
