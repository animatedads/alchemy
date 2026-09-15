root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-reconciled")
fed=.FederatedDatabaseEngine~new(root)

instrumentRows=.array~new
instrumentRows~append(.MBInstrumentResolutionEvidence~new("RES-A","DOC","U","ISIN-U","XLON","GBP","LINE-A","SAFE-A","ORDINARY","GBP","GBP","A","09:00"))
att=.array~new
att~append(.MBInstrumentResolutionAttestation~new("ATT-1","CFD-A","3","RES-A","ISIN-U|XLON|GBP|LINE-A|SAFE-A","PRODUCT-AUTH","ATTEST-SIG-1","09:01"))
ms=.array~new
ms~append(.MBMarketStructureEvent~new("MSE-1","JURISDICTIONAL_RESTRICTION","11:17","GB","SANCTIONS-AUTH","SANCTION-77","LEGAL-77","RES-A",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED"))
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",.nil,"merchant_hedge_equivalence",.nil,"merchant_hedge_remediation",.nil,"merchant_cfd_hedge_book",att,"merchant_instrument_attestations",ms,"merchant_market_structure_events")
ignore=fed~addEngine(provider)

r=fed~execute("SELECT attestation_id, product_id, resolution_evidence_ref, settlement_line_key FROM merchant_instrument_attestations WHERE product_id='CFD-A'")
call ok r
call assertEq 1,r~rows~items,"attestation query returns exact product attestation"
call assertEq "RES-A",r~rows[1]["resolution_evidence_ref"],"attestation resolution evidence retained"
rich=provider~table("merchant_instrument_attestations")~readRows[1]
call assertEq "ATTEST-SIG-1",rich~origin~sourceRef,"rich attestation object retained"

r2=fed~execute("SELECT event_id, event_type, affected_instrument_evidence_ref, equivalence_state FROM merchant_market_structure_events WHERE equivalence_state='IMPAIRED'")
call ok r2
call assertEq 1,r2~rows~items,"impaired market structure event queryable"
call assertEq "RES-A",r2~rows[1]["affected_instrument_evidence_ref"],"exact affected settlement-line evidence retained"
rich2=provider~table("merchant_market_structure_events")~readRows[1]
call assertEq "SANCTION-77",rich2~origin~sourceRef,"rich market-structure source retained"

bad=fed~execute("UPDATE merchant_market_structure_events SET equivalence_state='EQUIVALENT' WHERE event_id='MSE-1'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","market structure evidence relation must reject mutation")

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_reconciled_reference_evidence_query"
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
