::class FBBranchDayServiceTest public
::method assertTrue class
  use arg condition,message="assertion failed"
  if \condition then raise syntax 88.999 array(message)
::method assertEq class
  use arg actual,expected,message="values differ"
  if actual<>expected then raise syntax 88.999 array(message||" actual="||actual||" expected="||expected)
::method endpoint class
  use arg id="E-V",kind="VAULT",endpointId="VAULT-1",status="OPEN",expected=80000,counted=.nil,discrepancy=.nil
  if counted==.nil then counted=expected
  if discrepancy==.nil then discrepancy=counted-expected
  return .FederationBankBranchDayEndpointEvidence~new(id,kind,endpointId,"IOM-DOUGLAS","GBP",status,expected,counted,discrepancy,"CUSTODY:"||endpointId,"SOURCE:"||endpointId)
::method endpoints class
  use arg status="OPEN",vaultAmount=80000,tillAmount=20000
  return .array~of(self~endpoint("E-V","VAULT","VAULT-1",status,vaultAmount),self~endpoint("E-T","TILL","TILL-04",status,tillAmount))
::method positions class
  use arg expected=100000,inTransit=0,recon=0
  return .array~of(.FederationBankBranchDayPositionEvidence~new("P-GBP","IOM-DOUGLAS","GBP",expected,expected,0,inTransit,recon,"BRANCH-CASH:GBP"))
::method totals class
  use arg opening=100000,cashin=10000,cashout=5000,closing=.nil
  if closing==.nil then closing=opening+cashin-cashout
  return .array~of(.FederationBankBranchDayControlTotals~new("GBP",opening,cashin,cashout,0,0,0,"",closing,"TELLER-CASH-CONTROL:GBP"))
::method service class
  use arg store=.nil,sink=.nil
  return .FederationBankBranchDayService~new(.FederationBankBranchDayFixturePolicy~new,store,sink)
::method create class
  use arg s,dayId="DAY-1"
  r=s~createDay("CMD-CREATE:"||dayId,"CORR:"||dayId,dayId,"IOM-DOUGLAS","2026-08-26"); self~assertTrue(r~ok,"create failed "||r~code); return r~value
::method open class
  use arg s,d
  es=self~endpoints; ps=self~positions; maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR-OPEN",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B"); return s~openDay("CMD-OPEN:"||d~dayId,"CORR:"||d~dayId,d~dayId,es,ps,maker,apr)
::method beginClose class
  use arg s,d
  maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR-BC",d~beginCloseActionIdentity(maker),"MGR-B","AUTH:MGR-B"); return s~beginClose("CMD-BC:"||d~dayId,"CORR:"||d~dayId,d~dayId,maker,apr)
::method close class
  use arg s,d,closing=105000
  es=self~endpoints("CLOSED",closing-20000,20000); ps=self~positions(closing); ts=self~totals(100000,10000,5000,closing); maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR-CLOSE",d~closeActionIdentity(es,ps,ts,maker),"MGR-B","AUTH:MGR-B"); return s~closeDay("CMD-CLOSE:"||d~dayId,"CORR:"||d~dayId,d~dayId,es,ps,ts,maker,apr)
::requires "FederationBankBranchDayService.cls"
