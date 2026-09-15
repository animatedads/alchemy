/* The port exposes only BackendRuntime channel methods.  Verify route choice
 * with a capture runtime; there is no method that can stage Ledger commands. */
cap=.CaptureBackendRuntime~new
port=.FederationBankRelationshipBankQueuePort~new(cap)
cmd=.FederationBankCommand~new("C1","TRANSFER","I1","CUST","A","B","USD",1,"STAFF","TEL")
r=port~submit(cmd)
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"route")
.FBRelationshipServiceTestSupport~assertEq("TRANSFER",cap~lastRoute,"payments route")
cmd2=.FederationBankCommand~new("C2","OPEN_ACCOUNT","I2","CUST","","","GBP",0,"STAFF","TEL",.nil,"OFFSHORE_CURRENT","A2")
r2=port~submit(cmd2)
.FBRelationshipServiceTestSupport~assertTrue(r2~ok,"account route")
.FBRelationshipServiceTestSupport~assertEq("ACCOUNT",cap~lastRoute,"account route")
.FBRelationshipServiceTestSupport~pass("bank port has Account/Payments routes and no Ledger ingress")
::class CaptureBackendRuntime public
::attribute lastRoute get
::method submitOpenAccount
  expose lastRoute
  use arg c
  lastRoute="ACCOUNT"; return .QueueOperationResult~success(c~commandId)
::method submitAccountCommand
  expose lastRoute
  use arg c
  lastRoute="ACCOUNT"; return .QueueOperationResult~success(c~commandId)
::method submitTransfer
  expose lastRoute
  use arg c
  lastRoute="TRANSFER"; return .QueueOperationResult~success(c~commandId)
::method submitHold
  expose lastRoute
  use arg c
  lastRoute="HOLD"; return .QueueOperationResult~success(c~commandId)
::requires "FederationBankRelationshipBankQueuePort.cls"
::requires "TestSupport.cls"
