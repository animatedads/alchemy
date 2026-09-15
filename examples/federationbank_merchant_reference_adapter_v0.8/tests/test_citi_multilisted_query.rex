root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-citi")
fed=.FederatedDatabaseEngine~new(root)

rows=.array~new
rows~append(.MBInstrumentResolutionEvidence~new("RES-GB-GBP","DOC-CITI","CITI-MULTI","ISIN-001","XLON","GBP","GB-SEDOL-GBP","CRSTGB22","ORDINARY","GBP","GBP","P2-XLON-GBP","2026-08-26T14:30:00+01:00"))
rows~append(.MBInstrumentResolutionEvidence~new("RES-GB-USD","DOC-CITI","CITI-MULTI","ISIN-001","XLON","USD","GB-SEDOL-USD","CRSTGB22","ORDINARY","GBP","GBP","P2-XLON-USD","2026-08-26T14:30:00+01:00"))
rows~append(.MBInstrumentResolutionEvidence~new("RES-IE-EUR","DOC-CITI","CITI-MULTI","ISIN-001","XDUB","EUR","IE-SEDOL","CITIIE2X","ORDINARY","EUR","EUR","P1-XDUB-P4-SAFE","2026-08-26T14:30:00+01:00"))

provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,rows)
ignore=fed~addEngine(provider)

r=fed~execute("SELECT evidence_id, isin, venue_mic, denomination_currency, security_line_ref FROM merchant_instrument_lines WHERE isin='ISIN-001' AND venue_mic='XLON' AND denomination_currency='USD'")
call ok r
call assertEq 1,r~rows~items,"one exact London USD line"
call assertEq "GB-SEDOL-USD",r~rows[1]["security_line_ref"],"denomination selects the intended settlement line"
call assertEq "MERCHANT_REFERENCE_RICH_PROJECTION",r~accessPath,"rich projection access path"
rich=.nil
do rr over provider~table("merchant_instrument_lines")~readRows
  if rr["evidence_id"]="RES-GB-USD" then rich=rr
end
if rich==.nil then raise syntax 88.900 array("ASSERT_RICH_ROW","selected evidence row missing from rich relation")
call assertEq "RES-GB-USD",rich~origin~evidenceId,"rich relation row retains originating evidence object"
call assertEq "P2-XLON-USD",rich~fact("source_locator")~value,"rich projected fact retains selected source value"

r2=fed~execute("SELECT evidence_id, place_of_safekeeping FROM merchant_instrument_lines WHERE isin='ISIN-001' AND venue_mic='XDUB'")
call ok r2
call assertEq 1,r2~rows~items,"Dublin listing selected separately"
call assertEq "CITIIE2X",r2~rows[1]["place_of_safekeeping"],"safekeeping provenance remains queryable"

bad=fed~execute("UPDATE merchant_instrument_lines SET denomination_currency='EUR' WHERE evidence_id='RES-GB-GBP'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","reference evidence relation must reject mutation")

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_citi_multilisted_query"
exit 0

ok: procedure
  use arg rs
  if rs~status<>.Error~SUCCESS then raise syntax 88.900 array("QUERY_FAILED",rs~status,rs~error,rs~message)
return .true

assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
return .true

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "FederationBankMerchantBank.cls"
::requires "SourceEvidenceRelationAdapter.cls"
::requires "FederationBankMerchantReferenceAdapter.cls"
