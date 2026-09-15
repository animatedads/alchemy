/* FederationBank Teller Cash v0.1
 *
 * Cross-authority orchestration primitives for branch counter cash.  This
 * module deliberately leaves Staff Authority, Core Banking and physical till
 * custody as independent authorities and correlates their exact results.
 */

::class FederationBankTellerCashBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.teller.cash/0.1"
::constant WITHDRAWAL "CASH_WITHDRAWAL"
::constant DEPOSIT "CASH_DEPOSIT"

::class FBTellerCashUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyDir class
  use arg d
  x=.directory~new
  if d==.nil then return x
  do k over d; x[k]=d[k]; end
  return x
::method copyArray class
  use arg a
  x=.array~new
  if a==.nil then return x
  do v over a; x~append(v); end
  return x
::method dateValue class
  use arg value
  if value==.nil then return .nil
  if value~isA(.DateTime) then return value
  text=value~string
  if text="" then return .nil
  if text~right(1)="Z" then text=text~left(text~length-1)
  return .DateTime~fromIsoDate(text)

::class FederationBankTellerCashResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBTellerCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,code="OK",detail=""
  return self~new(.true,code,detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

/* Physical instruction is separate from the banking command.  A bundle is an
 * observed/countable cash fact, not a field copied into Core Banking. */
::class FederationBankTellerCashInstruction public
::attribute cashWorkId get
::attribute commandId get
::attribute direction get
::attribute tillId get
::attribute settlementAccountId get
::attribute bundle get
::attribute custodyContext get
::attribute tillApproval get
::method init
  expose cashWorkId commandId direction tillId settlementAccountId bundle custodyContext tillApproval
  use arg cashWorkIdArg,commandIdArg,directionArg,tillIdArg,settlementAccountIdArg,bundleArg,custodyContextArg,tillApprovalArg=.nil
  cashWorkId=cashWorkIdArg~string; commandId=commandIdArg~string; direction=.FBTellerCashUtil~token(directionArg); tillId=tillIdArg~string; settlementAccountId=settlementAccountIdArg~string; bundle=bundleArg; custodyContext=custodyContextArg; tillApproval=tillApprovalArg
  if cashWorkId="" | commandId="" | tillId="" | settlementAccountId="" then raise syntax 88.960 array("teller cash instruction identity required")
  if direction<>"WITHDRAWAL" & direction<>"DEPOSIT" then raise syntax 88.961 array("teller cash direction invalid")
  if bundle==.nil | custodyContext==.nil then raise syntax 88.962 array("cash bundle/custody context required")
::method semanticIdentity
  expose cashWorkId commandId direction tillId settlementAccountId bundle custodyContext tillApproval
  approvalIdentity="NONE"
  if tillApproval<>.nil then approvalIdentity=tillApproval~approvalId||":"||tillApproval~actionId||":"||tillApproval~approverStaffId||":"||tillApproval~actionIdentity
  return "FB-TELLER-CASH-INSTRUCTION/1|"||cashWorkId||"|"||commandId||"|"||direction||"|"||tillId||"|"||settlementAccountId||"|"||bundle~currency||"|"||bundle~totalMinor||"|"||custodyContext~staffId||"|"||custodyContext~sessionId||"|"||approvalIdentity
::method cashOperation
  expose direction
  if direction="WITHDRAWAL" then return .FederationBankTellerCashBuild~WITHDRAWAL
  return .FederationBankTellerCashBuild~DEPOSIT
::method tillOperation
  expose direction
  if direction="WITHDRAWAL" then return "CASH_OUT"
  return "CASH_IN"
::method snapshotText
  expose cashWorkId commandId direction tillId settlementAccountId bundle custodyContext tillApproval
  denoms=""
  keys=.array~new; do k over bundle~denominations; keys~append(k~string); end; keys~sort
  do k over keys
    if denoms<>"" then denoms||=","
    denoms||=k||"="||bundle~denominations[k]
  end
  approvalId=""; approvalActionId=""; approvalStaff=""; approvalIdentity=""; approvalAt=""
  if tillApproval<>.nil then do
    approvalId=tillApproval~approvalId; approvalActionId=tillApproval~actionId; approvalStaff=tillApproval~approverStaffId; approvalIdentity=tillApproval~actionIdentity; approvalAt=tillApproval~approvedAt~utcIsoDate
  end
  /* Keep a non-empty terminal marker. ooRexx makeArray() does not retain a
   * trailing empty field, and an instruction without a till approval has five
   * legitimate empty approval fields.  The marker makes the durable snapshot
   * unambiguous without inventing approval data. */
  parts=.array~of(cashWorkId,commandId,direction,tillId,settlementAccountId,bundle~currency,denoms,custodyContext~branchId,custodyContext~staffId,custodyContext~sessionId,custodyContext~workstationId,custodyContext~custodyRef,custodyContext~openedAt~utcIsoDate,approvalId,approvalActionId,approvalStaff,approvalIdentity,approvalAt,"END")
  out="FBTELCASHI1"
  do v over parts; out||="|"||v~string~encodeBase64; end
  return out
::method fromSnapshotText class
  use arg text
  p=text~makeArray("|")
  if p~items<>20 | p[1]<>"FBTELCASHI1" | p[20]~decodeBase64<>"END" then raise syntax 88.967 array("invalid teller cash instruction snapshot")
  vals=.array~new; do i=2 to 19; vals~append(p[i]~decodeBase64); end
  d=.directory~new
  if vals[7]<>"" then do item over vals[7]~makeArray(","); kv=item~makeArray("="); d[kv[1]]=kv[2]+0; end
  bundle=.FederationBankCashBundle~new(vals[6],d)
  opened=vals[13]; if opened~right(1)="Z" then opened=opened~left(opened~length-1)
  ctx=.FederationBankTillCustodyContext~new(vals[4],vals[8],vals[9],vals[10],vals[11],vals[12],.DateTime~fromIsoDate(opened))
  approval=.nil
  if vals[14]<>"" then do
    at=vals[18]; if at~right(1)="Z" then at=at~left(at~length-1)
    approval=.FederationBankTillApproval~new(vals[14],vals[15],vals[16],vals[17],.DateTime~fromIsoDate(at))
  end
  return self~new(vals[1],vals[2],vals[3],vals[4],vals[5],bundle,ctx,approval)
::method queuePersistentType
  return "federationbank.teller.cash.instruction/1"
::method queuePersistentState
  s=.table~new; s["snapshotText"]=self~snapshotText; return s
::method queueRestoreState
  expose cashWorkId commandId direction tillId settlementAccountId bundle custodyContext tillApproval
  use arg s
  restored=.FederationBankTellerCashInstruction~fromSnapshotText(s["snapshotText"]~string)
  cashWorkId=restored~cashWorkId; commandId=restored~commandId; direction=restored~direction; tillId=restored~tillId; settlementAccountId=restored~settlementAccountId; bundle=restored~bundle; custodyContext=restored~custodyContext; tillApproval=restored~tillApproval
  return self

/* Translate the already staff-authorised CASH_* command into the ordinary Core
 * transfer that changes monetary truth.  Physical custody remains in the till
 * module; this translation does not say that cash has moved. */
::class FederationBankTellerCashCoreTranslator public
::method validateBoundCommand class
  use arg instruction,command
  if instruction==.nil | command==.nil then return .FederationBankTellerCashResult~failure("CASH_BINDING_INPUT_REQUIRED")
  if command~commandId<>instruction~commandId then return .FederationBankTellerCashResult~failure("CASH_COMMAND_ID_MISMATCH")
  if command~operation<>instruction~cashOperation then return .FederationBankTellerCashResult~failure("CASH_OPERATION_MISMATCH",command~operation)
  if command~channel<>"STAFF" then return .FederationBankTellerCashResult~failure("CASH_STAFF_CHANNEL_REQUIRED",command~channel)
  if command~actorId<>instruction~custodyContext~staffId then return .FederationBankTellerCashResult~failure("CASH_CUSTODIAN_ACTOR_MISMATCH")
  if command~currency<>instruction~bundle~currency then return .FederationBankTellerCashResult~failure("CASH_CURRENCY_MISMATCH")
  if command~amountMinor<>instruction~bundle~totalMinor then return .FederationBankTellerCashResult~failure("CASH_COUNT_AMOUNT_MISMATCH")
  if command~detail("staffAuthorityEnvelopeIdentity")="" then return .FederationBankTellerCashResult~failure("STAFF_AUTHORITY_EVIDENCE_REQUIRED")
  if command~detail("staffBranchId")<>instruction~custodyContext~branchId then return .FederationBankTellerCashResult~failure("CASH_BRANCH_MISMATCH")
  return .FederationBankTellerCashResult~success(command)
::method translate class
  use arg instruction,command
  valid=self~validateBoundCommand(instruction,command); if \valid~ok then return valid
  details=.FBTellerCashUtil~copyDir(command~details)
  details["tellerCashInstructionIdentity"]=instruction~semanticIdentity
  details["tellerCashOperation"]=instruction~direction
  details["tellerTillId"]=instruction~tillId
  details["tellerCashSettlementAccountId"]=instruction~settlementAccountId
  details["tellerCustodyRef"]=instruction~custodyContext~custodyRef
  details["tellerCashOriginalCommandId"]=command~commandId
  details["tellerCashOriginalOperation"]=command~operation
  coreId="CORE:"||command~commandId
  coreIdem="CORE:"||command~idempotencyKey
  if instruction~direction="WITHDRAWAL" then do
    customerAccount=command~sourceAccountId
    if customerAccount="" then return .FederationBankTellerCashResult~failure("CUSTOMER_DEBIT_ACCOUNT_REQUIRED")
    source=customerAccount; target=instruction~settlementAccountId
  end
  else do
    customerAccount=command~targetAccountId
    if customerAccount="" then return .FederationBankTellerCashResult~failure("CUSTOMER_CREDIT_ACCOUNT_REQUIRED")
    source=instruction~settlementAccountId; target=customerAccount
  end
  core=.FederationBankCommand~new(coreId,"TRANSFER",coreIdem,command~customerId,source,target,command~currency,command~amountMinor,"STAFF",command~actorId,command~requestedAt,"","","","","","","","",command~applicantSegment,command~applicantRiskTier,details)
  return .FederationBankTellerCashResult~success(core)

/* Till Service calls this port with a physical action.  We resolve it back to
 * the exact translated Core command and then call Core.  No cash action can
 * select an arbitrary banking command. */
::class FederationBankTellerCashBoundCorePort subclass FBTillCorePort public
::method init
  expose corePort bindings
  use arg corePortArg
  if corePortArg==.nil then raise syntax 88.963 array("Core port required")
  corePort=corePortArg; bindings=.directory~new
::method register
  expose bindings
  use arg coreCommand
  bindings[coreCommand~commandId]=coreCommand; return coreCommand
::method execute
  expose corePort bindings
  use arg tillAction
  if tillAction==.nil then return .FBTillResult~failure("CORE_PORT_TILL_ACTION_REQUIRED")
  id=tillAction~bankingCommandId
  if \bindings~hasIndex(id) then return .FBTillResult~failure("CORE_PORT_CASH_COMMAND_NOT_REGISTERED",id)
  command=bindings[id]
  if command~amountMinor<>tillAction~amountMinor | command~currency<>tillAction~currency | command~actorId<>tillAction~staffId then return .FBTillResult~failure("CORE_PORT_CASH_ACTION_MISMATCH")
  if tillAction~operation="CASH_OUT" then do
    if command~sourceAccountId<>tillAction~accountId then return .FBTillResult~failure("CORE_PORT_CASH_ACCOUNT_MISMATCH")
  end
  else if tillAction~operation="CASH_IN" then do
    if command~targetAccountId<>tillAction~accountId then return .FBTillResult~failure("CORE_PORT_CASH_ACCOUNT_MISMATCH")
  end
  else return .FBTillResult~failure("CORE_PORT_CASH_OPERATION_INVALID",tillAction~operation)
  r=corePort~submit("PAYMENTS",command)
  if r~ok then return .FBTillResult~new(.true,r~code,r~detail,r~value)
  return .FBTillResult~new(.false,r~code,r~detail,r~value)

/* Composite Staff Channel Core port.  Ordinary operations continue to the
 * existing Core port.  CASH_* operations are intercepted and correlated with
 * the physical-till service; CASH_* is never submitted directly to Core. */
::class FederationBankTellerCashDispatchPort subclass FederationBankStaffChannelCorePort public
::method init
  expose delegateCore boundCore instructions tillServices results
  use arg delegateCoreArg
  if delegateCoreArg==.nil then raise syntax 88.964 array("delegate Core port required")
  delegateCore=delegateCoreArg; boundCore=.FederationBankTellerCashBoundCorePort~new(delegateCoreArg); instructions=.directory~new; tillServices=.directory~new; results=.directory~new
::method boundCorePort
  expose boundCore
  return boundCore
::method registerTillService
  expose tillServices
  use arg tillId,tillService
  tillServices[tillId~string]=tillService; return tillService
::method registerInstruction
  expose instructions
  use arg instruction
  if instruction==.nil then return .FederationBankTellerCashResult~failure("CASH_INSTRUCTION_REQUIRED")
  key=instruction~commandId
  if instructions~hasIndex(key) then do
    prior=instructions[key]
    if prior~semanticIdentity<>instruction~semanticIdentity then return .FederationBankTellerCashResult~failure("CASH_INSTRUCTION_CONFLICT",key,prior)
    return .FederationBankTellerCashResult~success(prior,"IDEMPOTENT_INSTRUCTION")
  end
  instructions[key]=instruction
  return .FederationBankTellerCashResult~success(instruction)
::method cashResult
  expose results
  use arg commandId
  if results~hasIndex(commandId) then return results[commandId]
  return .nil
::method submit
  expose delegateCore boundCore instructions tillServices results
  use arg route,command
  if command==.nil then return .FederationBankStaffChannelResult~failure("CORE_COMMAND_REQUIRED")
  op=command~operation
  if op<>.FederationBankTellerCashBuild~WITHDRAWAL & op<>.FederationBankTellerCashBuild~DEPOSIT then return delegateCore~submit(route,command)
  if route<>"PAYMENTS" then return .FederationBankStaffChannelResult~failure("CORE_ROUTE_OPERATION_MISMATCH",route||"/"||op)
  if \instructions~hasIndex(command~commandId) then return .FederationBankStaffChannelResult~failure("CORE_PORT_CASH_INSTRUCTION_NOT_REGISTERED",command~commandId)
  instruction=instructions[command~commandId]
  if \tillServices~hasIndex(instruction~tillId) then return .FederationBankStaffChannelResult~failure("CORE_PORT_TILL_SERVICE_NOT_REGISTERED",instruction~tillId)
  translated=.FederationBankTellerCashCoreTranslator~translate(instruction,command)
  if \translated~ok then return .FederationBankStaffChannelResult~failure("CORE_PORT_"||translated~code,translated~detail,translated~value)
  coreCommand=translated~value; boundCore~register(coreCommand)
  accountId=command~sourceAccountId; if instruction~direction="DEPOSIT" then accountId=command~targetAccountId
  tillAction=.FederationBankTillAction~new("TILLACT:"||instruction~cashWorkId,instruction~tillOperation,command~amountMinor,command~currency,command~actorId,command~customerId,accountId,coreCommand~commandId,command~requestedAt)
  tillService=tillServices[instruction~tillId]
  tillWorkId="TILLWORK:"||instruction~cashWorkId
  /* A Staff Channel READY_FOR_CORE retry must resume the already prepared
   * physical-cash work. Teller Till's SUBMIT receipt is intentionally
   * idempotent and therefore cannot be used as an execution retry: replaying
   * SUBMIT would merely return the PREPARED work without calling Core again. */
  existingTillWork=tillService~work(tillWorkId)
  if existingTillWork==.nil then tillResult=tillService~submit("FBTELCASH:"||command~idempotencyKey,tillWorkId,instruction~direction,tillAction,instruction~bundle,instruction~custodyContext,instruction~tillApproval)
  else tillResult=tillService~resume(tillWorkId,instruction~bundle,instruction~custodyContext,instruction~tillApproval)
  results[command~commandId]=tillResult
  if tillResult~ok then return .FederationBankStaffChannelResult~new(.true,"TELLER_CASH_COMPLETED","Core and physical cash stages completed",tillResult~value)
  tillWork=tillResult~value
  if tillWork<>.nil then do
    if tillWork~state="COMPENSATION_REQUIRED" then return .FederationBankStaffChannelResult~new(.true,"TELLER_CASH_COMPENSATION_REQUIRED",tillResult~detail,tillWork)
    if tillWork~state="RECONCILIATION_REQUIRED" then return .FederationBankStaffChannelResult~failure("TELLER_CASH_RECONCILIATION_REQUIRED",tillResult~detail,tillWork)
    if tillWork~coreResultCode<>"" then return .FederationBankStaffChannelResult~failure(tillWork~coreResultCode,tillResult~detail,tillWork)
  end
  /* Preserve true Core transport/delivery failures so Staff Channel leaves
   * READY_FOR_CORE durable for exact retry.  Policy/funds/account rejections
   * and pre-Core cash validation failures are institutional outcomes, not
   * infrastructure outages. */
  if tillResult~code~left(10)="CORE_PORT_" | tillResult~code~left(14)="CORE_DELIVERY_" then return .FederationBankStaffChannelResult~failure(tillResult~code,tillResult~detail,tillResult~value)
  return .FederationBankStaffChannelResult~failure("TELLER_CASH_"||tillResult~code,tillResult~detail,tillResult~value)

::requires "FederationBankStaffChannel.cls"
::requires "FederationBankTellerTillService.cls"
