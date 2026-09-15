root=.NoSQLServerTestSupport~createBlankDatabase("merchant-ref-hedge-book")
fed=.FederatedDatabaseEngine~new(root)
instrumentRows=.array~new
bookRows=.array~new
trades=.array~of("T0","T1","T2")
hedges=.array~of("H1","H2")
bookRows~append(.MBCFDHedgeBookAssessment~new("BOOK-1","T0","10:00","GBP",3,2,300,100,1,0,1,25000,5000,"DIRECTIONAL_RESIDUAL",trades,hedges))
trades2=.array~of("T0","T1","T1R","T2")
hedges2=.array~of("H1","HU","H2")
bookRows~append(.MBCFDHedgeBookAssessment~new("BOOK-2","T0","10:15","GBP",4,3,400,0,1,0,1,25000,5000,"NET_ZERO_WITH_IMPAIRED_CONTRACTS",trades2,hedges2))
provider=.MBInstrumentReferenceRelationProvider~new(.DatabaseResult,instrumentRows,"merchant_instrument_lines",.nil,"merchant_hedge_equivalence",.nil,"merchant_hedge_remediation",bookRows)
ignore=fed~addEngine(provider)
q=fed~execute("SELECT assessment_id, net_base_exposure, impaired_hedge_count, state FROM merchant_cfd_hedge_book WHERE root_trade_id='T0'")
call ok q
call assertEq 2,q~rows~items,"whole-book assessment history queryable"
q2=fed~execute("SELECT assessment_id, state FROM merchant_cfd_hedge_book WHERE net_base_exposure=0")
call ok q2
call assertEq 1,q2~rows~items,"netted replacement proof directly queryable"
call assertEq "BOOK-2",q2~rows[1]["assessment_id"],"correct aggregate proof selected"
rich=.nil
do rr over provider~table("merchant_cfd_hedge_book")~readRows
  if rr["assessment_id"]="BOOK-2" then rich=rr
end
if rich==.nil then raise syntax 88.900 array("ASSERT_ROWS","missing rich hedge-book row")
call assertEq 1,rich~origin~hasHedge("H2"),"rich row retains replacement hedge membership"
call assertEq 4,rich~origin~contractCount,"rich row retains full contractual graph"
bad=fed~execute("UPDATE merchant_cfd_hedge_book SET net_base_exposure=0 WHERE assessment_id='BOOK-1'")
if bad~error=.Error~SUCCESS then raise syntax 88.900 array("ASSERT_READ_ONLY","hedge-book relation must reject mutation")
ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "PASS test_cfd_hedge_book_query"
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
