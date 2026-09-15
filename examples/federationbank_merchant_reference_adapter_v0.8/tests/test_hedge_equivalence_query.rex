root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-equivalence")
fed=.FederatedDatabaseEngine~new(root)

instrumentRows=.array~new
instrumentRows~append(.MBInstrumentResolutionEvidence~new("RA","DOC","U","ISIN-U","XLON","GBP","LINE-A","SAFE-A","ORDINARY","GBP","GBP","A","09:00"))
instrumentRows~append(.MBInstrumentResolutionEvidence~new("RB","DOC","U","ISIN-U","XLON","USD","LINE-B","SAFE-B","ORDINARY","GBP","GBP","B","09:00"))

eq=.array~new
eq~append(.MBHedgeEquivalenceEvidence~new("EQ1","H-1",1,"","09:00","GB","REF-AUTH","REF-1","LEGAL-1","RA","RB",.true,.true,.true,.true,.true,"BASELINE"))
eq~append(.MBHedgeEquivalenceEvidence~new("EQ2","H-1",2,"EQ1","11:17","GB","SANCTIONS-AUTH","SANCTION-77","LEGAL-77","RA","RB",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED"))
eq~append(.MBHedgeEquivalenceEvidence~new("EQ3","H-1",3,"EQ2","14:30","GB","LEGAL-MARKET-AUTH","RELEASE-88","LEGAL-88","RA","RB",.true,.true,.true,.true,.true,"RESTORED"))
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",eq)
ignore=fed~addEngine(provider)

r=fed~execute("SELECT evidence_id, evidence_version, equivalence_state, reason_code, is_current FROM merchant_hedge_equivalence WHERE hedge_id='H-1'")
call ok r
call assertEq 3,r~rows~items,"full equivalence evidence history queryable"
current=.nil
impaired=.nil
do rr over provider~table("merchant_hedge_equivalence")~readRows
  if rr["evidence_id"]="EQ3" then current=rr
  if rr["evidence_id"]="EQ2" then impaired=rr
end
if current==.nil | impaired==.nil then raise syntax 88.900 array("ASSERT_ROWS","missing rich equivalence rows")
call assertEq 1,current["is_current"],"latest version identified without deleting history"
call assertEq 0,impaired["is_current"],"superseded impairment remains history"
call assertEq "IMPAIRED",impaired["equivalence_state"],"historical impairment retained"
call assertEq "SANCTION-77",impaired~origin~sourceRef,"rich row retains original sanctions evidence object"
call assertEq "RB",impaired~origin~offsetInstrumentEvidenceRef,"rich row retains exact offset instrument evidence"

r2=fed~execute("SELECT evidence_id, source_ref, legal_effect_ref FROM merchant_hedge_equivalence WHERE hedge_id='H-1' AND equivalence_state='IMPAIRED'")
call ok r2
call assertEq 1,r2~rows~items,"impairment can be selected directly"
call assertEq "SANCTION-77",r2~rows[1]["source_ref"],"sanctions source reference survives SQL projection"

bad=fed~execute("UPDATE merchant_hedge_equivalence SET equivalence_state='EQUIVALENT' WHERE evidence_id='EQ2'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","equivalence evidence relation must reject mutation")

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_hedge_equivalence_query"
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
