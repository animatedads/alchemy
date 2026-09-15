say 'QUEUE AUTHORITY TRANSPORT V0.27 START'
ring = .CryptoMacKeyRing~new
ignored = ring~addSipHash128Key('transport-k1', '303132333435363738393a3b3c3d3e3f')
manager = .ObjectQueueManager~new('', .nil, 'admin')
call AssertOk manager~createQueue('TRANSFERQ', 'TEMPORARY', 'AUTHORITY', 50, 'admin'), 'create transfer queue'
opts = .table~new
opts['sourceManager'] = 'MANAGER-A'
opts['sourceQueue'] = 'OUTBOUND'
opts['sourcePackageId'] = 'SRC-PKG-V027'
accepted = manager~acceptTransfer('TRANSFER-V027-001', 'TRANSFERQ', 'transferred-work', opts, 'admin')
call AssertOk accepted, 'accept transfer'
receipt = accepted~value
claim = manager~claim('TRANSFERQ', 'admin')
call AssertOk claim, 'claim transfer'
pkg = claim~value
set = BuildPromotionSet('TRANSFER-V027-P1', 'QUEUE_TRANSFER_V027_APPLIED')
world = .RYTAWorldState~new('V027-TRANSFER-WORLD')
path = '/tmp/ryta_v027_transport_' || .DateTime~new~microseconds || '.ledger'
ignored = SysFileDelete(path)
ledger = .QueueAuthorityExecutionLedger~new(path, ring)
exec = .QueueAuthorityPromotionExecutor~execute(manager, 'TRANSFERQ', pkg, pkg~claimToken, 'admin', set, world, 'NODE-V027/TRANSFER', ledger, receipt)
call AssertTrue exec~ok, 'transfer authority execution'
call AssertEqual 'TRANSFER', exec~workIdentity~transportKind, 'transport kind'
call AssertEqual 'TRANSFER-V027-001', exec~workIdentity~transferId, 'transfer id'
call AssertEqual 'MANAGER-A', exec~workIdentity~sourceManager, 'source manager'
call AssertEqual 'SRC-PKG-V027', exec~workIdentity~parentPackageId, 'source package'
call AssertEqual 'OUTBOUND', exec~workIdentity~requestedQueue, 'source queue'
call AssertEqual 'V3', ledger~recordVersionFor(exec~workIdentity~executionKey), 'transfer execution V3'
call AssertTrue ledger~trustedRecordFor(exec~workIdentity~executionKey), 'transfer execution authenticated'
call AssertTrue world~isKnownTrue('QUEUE_TRANSFER_V027_APPLIED'), 'transfer authority applied'
dupe = manager~acceptTransfer('TRANSFER-V027-001', 'TRANSFERQ', 'transferred-work', opts, 'admin')
call AssertOk dupe, 'duplicate transfer idempotent'
call AssertTrue dupe~value~duplicate, 'duplicate marked'
call AssertEqual receipt~packageId, dupe~value~packageId, 'duplicate returns original package'
call AssertEqual 0, manager~depth('TRANSFERQ', 'admin')~value['total'], 'duplicate does not reinsert consumed work'

/* Receipt-shaped values must still be backed by Queue Fabric's own registry. */
accepted2 = manager~acceptTransfer('TRANSFER-V027-002', 'TRANSFERQ', 'mismatch', opts, 'admin')
call AssertOk accepted2, 'accept second transfer'
claim2 = manager~claim('TRANSFERQ', 'admin')
call AssertOk claim2, 'claim second transfer'
pkg2 = claim2~value
fake = .QueueTransferReceipt~new('TRANSFER-V027-002', 'WRONG-PACKAGE', 'TRANSFERQ', accepted2~value~acceptedAt, 'MANAGER-A', .false)
world2 = .RYTAWorldState~new('V027-TRANSFER-MISMATCH')
bad = .QueueAuthorityPromotionExecutor~execute(manager, 'TRANSFERQ', pkg2, pkg2~claimToken, 'admin', BuildPromotionSet('TRANSFER-V027-P2', 'MUST_NOT_APPLY'), world2, 'NODE-V027/TRANSFER', ledger, fake)
call AssertTrue \bad~ok, 'forged receipt binding refused'
call AssertEqual 'TRANSFER_RECEIPT_REGISTRY_MISMATCH', bad~code, 'receipt registry mismatch'
call AssertEqual 'UNKNOWN', world2~knowledgeOf('MUST_NOT_APPLY'), 'forged receipt cannot mutate'
call AssertOk manager~ack('TRANSFERQ', pkg2~packageId, pkg2~claimToken, 'admin'), 'operator cleanup'
ignored = SysFileDelete(path)
say 'QUEUE AUTHORITY TRANSPORT V0.27: OK'
exit 0

::routine BuildPromotionSet
  use arg id, fact
  p = .EvidencePromotion~new(id, 'QUEUE_V027_TRANSFER', 'SRC-' || id, fact, 'KNOWN', .true, 'TEST_AUTHORITY', 'TEST_POLICY', 'TEST_RULE', 'REQUIRED', 'AUTHORIZED')
  s = .EvidencePromotionSet~new
  if \s~add(p) then raise syntax 88.900 array('promotion add failed')
  ignored = s~seal
  return s
::routine AssertOk
  use arg obj,label
  if obj == .nil | \obj~ok then raise syntax 88.900 array('ASSERT OK FAILED: ' || label)
  return
::routine AssertTrue
  use arg value,label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return
::routine AssertEqual
  use arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return
::requires 'crypto.cls'
::requires 'ObjectQueueFabric.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires '../HardWorld.cls'
