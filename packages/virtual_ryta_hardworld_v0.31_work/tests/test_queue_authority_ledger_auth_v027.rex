say 'QUEUE AUTHORITY LEDGER AUTH V0.27 START'

base = '/tmp/ryta_queue_authority_v027_' || .DateTime~new~microseconds
ledgerPath = base || '.ledger'
legacyPath = base || '.legacy.ledger'
ignore = SysFileDelete(ledgerPath)
ignore = SysFileDelete(legacyPath)

ring = BuildRing(.true, .true)
manager = .ObjectQueueManager~new('', .nil, 'admin')
call AssertOk manager~createQueue('Q.AUTH', 'TEMPORARY', 'AUTHORITY', 50, 'admin'), 'create authenticated queue'

/* Authenticated V3 execution reaches COMPLETE before an injected ACK failure. */
call AssertOk manager~put('Q.AUTH', 'auth-work', .nil, 'admin'), 'put authenticated work'
claim = manager~claim('Q.AUTH', 'admin')
call AssertOk claim, 'claim authenticated work'
pkg = claim~value
token = pkg~claimToken
world = .RYTAWorldState~new('V027-AUTH-WORLD')
set = BuildPromotionSet('AUTH-V027-P1', 'V027_AUTH_APPLIED')
ledger = .QueueAuthorityExecutionLedger~new(ledgerPath, ring)
ackFail = .AckFailOnceQueueManager~new(manager)
exec1 = .QueueAuthorityPromotionExecutor~execute(ackFail, 'Q.AUTH', pkg, token, 'admin', set, world, 'NODE-V027/AUTH', ledger)
call AssertTrue \exec1~ok, 'injected ACK failure reported'
call AssertEqual 'ACK_FAILED_AFTER_COMPLETE', exec1~code, 'failure occurs after COMPLETE'
call AssertTrue world~isKnownTrue('V027_AUTH_APPLIED'), 'authority mutation occurred exactly before ACK failure'
key = exec1~workIdentity~executionKey
call AssertEqual 'COMPLETE', ledger~stateFor(key), 'authenticated ledger complete'
call AssertEqual 'V3', ledger~recordVersionFor(key), 'V3 record version'
call AssertTrue ledger~trustedRecordFor(key), 'V3 record trusted'
call AssertEqual 'AUTHENTICATED_V3', ledger~authenticationMode, 'authenticated mode'
call AssertEqual 2, ledger~authenticatedRecordCount, 'START and COMPLETE authenticated'
call AssertEqual 2, ledger~authenticatedTailSequence, 'authenticated sequence advanced'
checkpoint2 = ledger~chainCheckpointText
call AssertTrue checkpoint2~length > 40, 'checkpoint exported'
ledgerText = ReadFile(ledgerPath)
call AssertTrue pos('RYTA_QUEUE_AUTHORITY_LEDGER_V3|1|START|', ledgerText) > 0, 'V3 START present'
call AssertTrue pos('RYTA_QUEUE_AUTHORITY_LEDGER_V3|2|COMPLETE|', ledgerText) > 0, 'V3 COMPLETE present'
call AssertEqual 0, pos(token, ledgerText), 'raw claim token absent from V3 ledger'
call AssertEqual 0, pos(c2x(token), ledgerText), 'hex claim token absent from V3 ledger'

/* Restart with the same key ring verifies the chain and permits transport-only cleanup. */
reopened = .QueueAuthorityExecutionLedger~new(ledgerPath, ring, checkpoint2)
call AssertEqual 'COMPLETE', reopened~stateFor(key), 'restarted authenticated ledger complete'
call AssertTrue reopened~trustedRecordFor(key), 'restarted record trusted'
call AssertTrue reopened~matchesCheckpoint(checkpoint2), 'trusted external checkpoint matches'
call AssertOk manager~release('Q.AUTH', pkg~packageId, token, 'admin', 'transport retry'), 'release completed package'
claim2 = manager~claim('Q.AUTH', 'admin')
call AssertOk claim2, 'claim completed package retry'
pkg2 = claim2~value
ackOnly = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.AUTH', pkg2, pkg2~claimToken, 'admin', set, world, 'NODE-V027/AUTH', reopened)
call AssertTrue ackOnly~ok, 'authenticated COMPLETE permits ACK-only recovery'
call AssertEqual 'ALREADY_COMPLETE_ACKED', ackOnly~code, 'ACK-only code'
call AssertTrue ackOnly~replaySuppressed, 'authority replay suppressed'
call AssertTrue ackOnly~applyResult == .nil, 'no second promotion application'
call AssertEqual 'ACKED', pkg2~state, 'transport cleanup ACKed'

/* V3 cannot be read without the host key ring. */
call ExpectOpenFailure ledgerPath, .nil, .nil, 'QUEUE_AUTHORITY_LEDGER_MAC_KEYRING_REQUIRED', 'missing keyring rejected'

/* A modified authenticated record is rejected before its state can be trusted. */
tamperPath = base || '.tampered.ledger'
call WriteFile tamperPath, ReplaceFirst(ledgerText, '|COMPLETE|', '|START|')
call ExpectOpenFailure tamperPath, ring, .nil, 'QUEUE_AUTHORITY_LEDGER_MAC_INVALID', 'record mutation rejected'

/* Reordering authentic records breaks the global chain sequence. */
reorderPath = base || '.reordered.ledger'
lines = ReadLines(ledgerPath)
call AssertEqual 2, lines~items, 'two authenticated lines before rotation test'
call WriteLines reorderPath, .array~of(lines[2], lines[1])
call ExpectOpenFailure reorderPath, ring, .nil, 'QUEUE_AUTHORITY_LEDGER_CHAIN_SEQUENCE_INVALID', 'record reorder rejected'

/* A forged syntactically-correct COMPLETE with a fake tag is rejected. */
forgePath = base || '.forged.ledger'
call WriteFile forgePath, ledgerText
forgedLine = 'RYTA_QUEUE_AUTHORITY_LEDGER_V3|3|COMPLETE|' || c2x('FORGED-KEY') || '|' || c2x('FORGED-ENV') || '|' || c2x('FORGED-AUTH') || '|' || c2x('FORGED-ATTEMPT') || '|' || c2x(.DateTime~new~string) || '|' || ledger~authenticatedTailTag || '|' || c2x('SIPHASH-2-4-128') || '|' || c2x('ledger-k1') || '|00000000000000000000000000000000'
call AppendLine forgePath, forgedLine
call ExpectOpenFailure forgePath, ring, .nil, 'QUEUE_AUTHORITY_LEDGER_MAC_INVALID', 'forged COMPLETE rejected'

/* Key rotation is per-record: old and new keys verify the same chain. */
directAttempt = exec1~attemptEvidence
call AssertEqual 'STARTED', ledger~beginCurrent('DIRECT-V027', 'DIRECT-ENV', 'DIRECT-AUTH', directAttempt)~code, 'direct V3 START under key 1'
call AssertTrue ring~activate('ledger-k2'), 'activate second MAC key'
call AssertEqual 'COMPLETED', ledger~completeCurrent('DIRECT-V027', 'DIRECT-ENV', 'DIRECT-AUTH', directAttempt)~code, 'direct V3 COMPLETE under key 2'
call AssertEqual 4, ledger~authenticatedRecordCount, 'rotated chain has four records'
call AssertEqual 'V3', ledger~recordVersionFor('DIRECT-V027'), 'rotated direct record V3'
checkpoint4 = ledger~chainCheckpointText
rotated = .QueueAuthorityExecutionLedger~new(ledgerPath, ring, checkpoint4)
call AssertEqual 'COMPLETE', rotated~stateFor('DIRECT-V027'), 'rotated chain reopens'
ringOnly2 = BuildRing(.false, .true)
call ExpectOpenFailure ledgerPath, ringOnly2, .nil, 'QUEUE_AUTHORITY_LEDGER_MAC_KEY_UNKNOWN:ledger-k1', 'missing historical key rejected'

/* Local authentication alone cannot prove a newer valid tail was not rolled back.
   The exported checkpoint is the host boundary for that monotonic evidence. */
truncatedPath = base || '.truncated.ledger'
allLines = ReadLines(ledgerPath)
call AssertEqual 4, allLines~items, 'four lines available for rollback adversary'
call WriteLines truncatedPath, .array~of(allLines[1], allLines[2], allLines[3])
truncated = .QueueAuthorityExecutionLedger~new(truncatedPath, ring)
call AssertEqual 3, truncated~authenticatedRecordCount, 'truncated prefix is individually authentic'
call AssertTrue \truncated~matchesCheckpoint(checkpoint4), 'external checkpoint detects valid older tail'
call ExpectOpenFailure truncatedPath, ring, checkpoint4, 'QUEUE_AUTHORITY_LEDGER_CHECKPOINT_MISMATCH', 'anchored rollback rejected'

/* Legacy V2 state remains readable but is never trusted for ACK-only recovery. */
call AssertOk manager~createQueue('Q.LEGACY', 'TEMPORARY', 'AUTHORITY', 50, 'admin'), 'create legacy queue'
call AssertOk manager~put('Q.LEGACY', 'legacy-work', .nil, 'admin'), 'put legacy work'
legacyClaim1 = manager~claim('Q.LEGACY', 'admin')
call AssertOk legacyClaim1, 'claim legacy work'
legacyPkg1 = legacyClaim1~value
legacyToken1 = legacyPkg1~claimToken
legacyWorld = .RYTAWorldState~new('V027-LEGACY-WORLD')
legacySet = BuildPromotionSet('LEGACY-V027-P1', 'V027_LEGACY_APPLIED')
legacyLedger = .QueueAuthorityExecutionLedger~new(legacyPath)
legacyAckFail = .AckFailOnceQueueManager~new(manager)
legacyExec1 = .QueueAuthorityPromotionExecutor~execute(legacyAckFail, 'Q.LEGACY', legacyPkg1, legacyToken1, 'admin', legacySet, legacyWorld, 'NODE-V027/LEGACY', legacyLedger)
call AssertEqual 'ACK_FAILED_AFTER_COMPLETE', legacyExec1~code, 'legacy compatibility can finish initial side effect'
legacyKey = legacyExec1~workIdentity~executionKey
call AssertEqual 'V2', legacyLedger~recordVersionFor(legacyKey), 'unkeyed compatibility writes V2'
call AssertTrue \legacyLedger~trustedRecordFor(legacyKey), 'V2 completion explicitly untrusted'
call AssertOk manager~release('Q.LEGACY', legacyPkg1~packageId, legacyToken1, 'admin', 'legacy retry'), 'release legacy package'
legacyClaim2 = manager~claim('Q.LEGACY', 'admin')
call AssertOk legacyClaim2, 'claim legacy retry'
legacyPkg2 = legacyClaim2~value
legacyReader = .QueueAuthorityExecutionLedger~new(legacyPath, ring)
legacyRetry = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.LEGACY', legacyPkg2, legacyPkg2~claimToken, 'admin', legacySet, legacyWorld, 'NODE-V027/LEGACY', legacyReader)
call AssertTrue \legacyRetry~ok, 'legacy COMPLETE not accepted for automatic recovery'
call AssertEqual 'LEGACY_LEDGER_RECORD_UNTRUSTED', legacyRetry~code, 'legacy refusal code'
call AssertEqual 'INFLIGHT', legacyPkg2~state, 'legacy record cannot cause blind ACK'
call AssertOk manager~ack('Q.LEGACY', legacyPkg2~packageId, legacyPkg2~claimToken, 'admin'), 'operator cleanup legacy package'

/* Clean temporary files. */
do p over .array~of(ledgerPath, legacyPath, tamperPath, reorderPath, forgePath, truncatedPath)
  ignore = SysFileDelete(p)
end
say 'QUEUE AUTHORITY LEDGER AUTH V0.27: OK'
exit 0

::routine BuildRing
  use arg include1, include2
  r = .CryptoMacKeyRing~new
  if include1 then ignored = r~addSipHash128Key('ledger-k1', '000102030405060708090a0b0c0d0e0f')
  if include2 then ignored = r~addSipHash128Key('ledger-k2', '101112131415161718191a1b1c1d1e1f')
  if include1 then ignored = r~activate('ledger-k1')
  else if include2 then ignored = r~activate('ledger-k2')
  return r

::routine BuildPromotionSet
  use arg promotionId, targetFact
  p = .EvidencePromotion~new(promotionId, 'QUEUE_V027', 'SRC-' || promotionId, targetFact, 'KNOWN', .true, 'TEST_AUTHORITY', 'TEST_POLICY', 'TEST_RULE', 'REQUIRED', 'AUTHORIZED')
  s = .EvidencePromotionSet~new
  if \s~add(p) then raise syntax 88.900 array('could not add promotion ' || promotionId)
  ignored = s~seal
  return s

::routine ReadFile
  use arg path
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return ''
  n = s~chars
  if n = 0 then do; ignored = s~close; return ''; end
  text = s~charIn(1, n)
  ignored = s~close
  return text

::routine WriteFile
  use arg path, text
  s = .Stream~new(path)
  ignored = s~open('WRITE REPLACE')
  ignored = s~charOut(text)
  ignored = s~close
  return 0

::routine AppendLine
  use arg path, line
  s = .Stream~new(path)
  ignored = s~open('WRITE APPEND')
  ignored = s~lineOut(line)
  ignored = s~close
  return 0

::routine ReadLines
  use arg path
  out = .array~new
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return out
  do while s~lines > 0
    out~append(s~lineIn)
  end
  ignored = s~close
  return out

::routine WriteLines
  use arg path, lines
  s = .Stream~new(path)
  ignored = s~open('WRITE REPLACE')
  do line over lines
    ignored = s~lineOut(line)
  end
  ignored = s~close
  return 0

::routine ReplaceFirst
  use arg text, needle, replacement
  at = pos(needle, text)
  if at = 0 then raise syntax 88.900 array('replace needle not found: ' || needle)
  return text~substr(1, at - 1) || replacement || text~substr(at + needle~length)

::routine ExpectOpenFailure
  use arg path, ringArg, checkpointArg, expectedFragment, label
  signal on syntax name caught
  candidate = .QueueAuthorityExecutionLedger~new(path, ringArg, checkpointArg)
  signal off syntax
  raise syntax 88.900 array('EXPECTED OPEN FAILURE DID NOT OCCUR: ' || label)
caught:
  cond = condition('O')
  detail = cond['MESSAGE']~string
  signal off syntax
  if pos(expectedFragment, detail) = 0 then raise syntax 88.900 array('WRONG OPEN FAILURE: ' || label || ' expected=' || expectedFragment || ' actual=' || detail)
  return 0

::routine AssertOk
  use arg obj, label
  if obj == .nil then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' nil')
  if \obj~ok then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' code=' || obj~code || ' detail=' || obj~detail)
  return 0

::routine AssertTrue
  use arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::class AckFailOnceQueueManager public
::method init
  expose manager failed
  use arg managerArg
  manager = managerArg
  failed = .false
::method ack
  expose manager failed
  use arg queueName, packageId, claimToken, principal
  if \failed then do
    failed = .true
    return .QueueOperationResult~failure('TEST_ACK_FAILURE', packageId)
  end
  return manager~ack(queueName, packageId, claimToken, principal)
::method transferReceipt
  expose manager
  use arg transferId
  return manager~transferReceipt(transferId)

::requires 'crypto.cls'
::requires 'ObjectQueueFabric.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires '../HardWorld.cls'
