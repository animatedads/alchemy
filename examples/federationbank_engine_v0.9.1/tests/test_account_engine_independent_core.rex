env=.FederationBankFixtures~freshAccountEnvironment(.true)
authority=env["authority"]
accountEngine=.FederationBankAccountEngine~new(authority)

call assert authority~hasMethod("OPENACCOUNT"), "authority exposes account lifecycle"
call assert \authority~hasMethod("TRANSFER"), "authority has no payment operation"
call assert \authority~hasMethod("BALANCEMINOR"), "authority has no balance API"

cmd=.FederationBankCommand~new("IA-OPEN-1","OPEN_ACCOUNT","IA-IDEM-1","CUST-IA","","","GBP",0,"WEB","CUST-IA",.nil,"OFFSHORE_CURRENT","IA-GBP-1","Independent Account Customer","1978-04-02","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
opened=accountEngine~handle(cmd)
call must opened,"independent account opening"
call assert env["customers"]~customer("CUST-IA")<>.nil,"customer projected inside account authority"
call assert env["accounts"]~account("IA-GBP-1")<>.nil,"account projected inside account authority"
call assert opened~value["regulatoryProfileId"]="FB-IOM-GBP","GBP profile selected"
call assert env["external"]["civicTransport"]~calls=1,"CivicPort called by account authority"
call assert env["external"]["creditAgency"]~calls=1,"IJCIB called by account authority"

replay=accountEngine~handle(cmd)
call must replay,"independent replay recovery"
call assert replay~code="REPLAY_RECOVERED","durable receipt recovered by account authority"

pay=.FederationBankCommand~new("IA-PAY-1","TRANSFER","IA-TX-1","CUST-IA","IA-GBP-1","IA-GBP-1","GBP",1,"WEB","CUST-IA")
unsupported=accountEngine~handle(pay)
call assert unsupported~ok=.false,"payment rejected at account service boundary"
call assert unsupported~code="ACCOUNT_ENGINE_OPERATION_UNSUPPORTED","account service cannot execute payment"

say "PASS Account Engine uses independent account authority core"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
