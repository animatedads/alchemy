::class FBBranchDayTest public
::method assertTrue class
  use arg condition,message="assertion failed"
  if \condition then do; say "FAIL:" message; exit 1; end
::method assertEq class
  use arg expected,actual,message="values differ"
  if expected~string<>actual~string then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
::method endpoint class
  use arg id="E-V1",kind="VAULT",endpointId="VAULT-1",status="OPEN",expected=100000,counted=.nil,discrepancy=.nil,currency="GBP",branch="IOM-DOUGLAS"
  if counted==.nil then counted=expected
  if discrepancy==.nil then discrepancy=counted-expected
  return .FederationBankBranchDayEndpointEvidence~new(id,kind,endpointId,branch,currency,status,expected,counted,discrepancy,"CUSTODY:"||endpointId,"SOURCE:"||endpointId)
::method position class
  use arg id="P-GBP",expected=100000,counted=.nil,discrepancy=.nil,inTransit=0,recon=0,currency="GBP",branch="IOM-DOUGLAS"
  if counted==.nil then counted=expected
  if discrepancy==.nil then discrepancy=counted-expected
  return .FederationBankBranchDayPositionEvidence~new(id,branch,currency,expected,counted,discrepancy,inTransit,recon,"BRANCH-CASH:"||id)
::method endpoints class
  use arg status="OPEN",vaultAmount=80000,tillAmount=20000
  a=.array~new; a~append(self~endpoint("E-V","VAULT","VAULT-1",status,vaultAmount)); a~append(self~endpoint("E-T","TILL","TILL-04",status,tillAmount)); return a
::method positions class
  use arg expected=100000,inTransit=0,recon=0
  return .array~of(self~position("P-GBP",expected,expected,0,inTransit,recon))
::method openDay class
  use arg opening=100000
  d=.FederationBankBranchDay~new("DAY-20260826","IOM-DOUGLAS","2026-08-26")
  es=self~endpoints("OPEN",opening-20000,20000); ps=self~positions(opening)
  maker="BRANCH-MGR-A"; ident=d~openActionIdentity(es,ps,maker); apr=.FederationBankBranchDayApproval~new("APR-OPEN",ident,"BRANCH-MGR-B","STAFF-AUTH:BRANCH-MGR-B")
  r=d~open(es,ps,maker,apr,.FederationBankBranchDayFixturePolicy~new); self~assertTrue(r~ok,"open day failed "||r~code); return d
::method beginClose class
  use arg d,maker="BRANCH-MGR-A"
  ident=d~beginCloseActionIdentity(maker); apr=.FederationBankBranchDayApproval~new("APR-BEGIN-CLOSE",ident,"BRANCH-MGR-B","STAFF-AUTH:BRANCH-MGR-B"); r=d~beginClose(maker,apr,.FederationBankBranchDayFixturePolicy~new); self~assertTrue(r~ok,"begin close failed "||r~code); return r
::method totals class
  use arg opening=100000,customerIn=10000,customerOut=5000,externalIn=0,externalOut=0,adjustment=0,adjustmentRef="",closing=.nil
  if closing==.nil then closing=opening+customerIn-customerOut+externalIn-externalOut+adjustment
  return .FederationBankBranchDayControlTotals~new("GBP",opening,customerIn,customerOut,externalIn,externalOut,adjustment,adjustmentRef,closing,"TELLER-CASH-CONTROL:GBP")
::method closeApproval class
  use arg d,endpoints,positions,totals,maker="BRANCH-MGR-A"
  ident=d~closeActionIdentity(endpoints,positions,totals,maker); return .FederationBankBranchDayApproval~new("APR-CLOSE",ident,"BRANCH-MGR-B","STAFF-AUTH:BRANCH-MGR-B")
::requires "FederationBankBranchDay.cls"
