::class FBTellerCashDomainTestSupport public
::method assertTrue class
  use arg c,m="assertTrue failed"
  if \c then raise syntax 40.900 array(m)
::method assertFalse class
  use arg c,m="assertFalse failed"
  if c then raise syntax 40.900 array(m)
::method assertEq class
  use arg e,a,m="assertEq failed"
  if e~string<>a~string then raise syntax 40.900 array(m||" expected="||e||" actual="||a)
::method pass class
  use arg m
  say "PASS:" m
::method custody class
  use arg tillId="TILL-04",staffId="TELLER-04",sessionId="S-TEL",branch="DOUGLAS"
  return .FederationBankTillCustodyContext~new(tillId,branch,staffId,sessionId,"WS:DESK-04","CUSTODY:"||tillId||":"||staffId,.DateTime~new)
::method bundle class
  use arg amount=10000,currency="GBP"
  d=.directory~new; d[amount~string]=1; return .FederationBankCashBundle~new(currency,d)
::method instruction class
  use arg id="U1",direction="WITHDRAWAL",amount=10000,tillId="TILL-04",staffId="TELLER-04",branch="DOUGLAS",settlement="FB-SETTLEMENT-GBP"
  return .FederationBankTellerCashInstruction~new("CASHWORK:"||id,"CASHCMD:"||id,direction,tillId,settlement,self~bundle(amount),self~custody(tillId,staffId,"S-TEL",branch))
::method command class
  use arg id="U1",direction="WITHDRAWAL",amount=10000,withAuthority=.true,account="GBP-SRC",staffId="TELLER-04",branch="DOUGLAS"
  details=.directory~new
  if withAuthority then do; details["staffAuthorityEnvelopeIdentity"]="AUTH:"||id; details["staffBranchId"]=branch; end
  if direction~upper="WITHDRAWAL" then do; op="CASH_WITHDRAWAL"; source=account; target=""; end
  else do; op="CASH_DEPOSIT"; source=""; target=account; end
  return .FederationBankCommand~new("CASHCMD:"||id,op,"CASHIDEM:"||id,"CUST-001",source,target,"GBP",amount,"STAFF",staffId,.DateTime~new,"","","","","","","","","RETAIL","STANDARD",details)
::method corePort class
  e=.FederationBankStaffCorePolicyFixtures~engine
  return .FederationBankStaffChannelEngineCorePort~new(e)
::requires "FederationBankTellerCash.cls"
::requires "FederationBankStaffCorePolicyFixtures.cls"
