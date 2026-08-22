/*
 * WLULedger v0.1
 *
 * Durable WLU accounting journal.  Every hot-path record is authenticated by
 * SipHash-2-4-128 and chained to the previous tag.  Public-key signatures are
 * optional checkpoint/export operations, not per-record overhead.
 */

::options digits 30

::class WLUAuthenticatedLedgerBuild public
::constant VERSION "0.1"
::constant RECORD_FORMAT "wlu.auth.ledger/1"
::constant CHECKPOINT_FORMAT "wlu.auth.checkpoint/1"
::constant GENESIS_TAG "00000000000000000000000000000000"

::class WLURecordCodec public
::method split class
  use strict arg text, delimiter = "|"
  parts = .array~new
  rest = text~string
  do forever
    p = rest~pos(delimiter)
    if p = 0 then do
      parts~append(rest)
      leave
    end
    parts~append(rest~left(p - 1))
    rest = rest~substr(p + delimiter~length)
  end
  return parts

::method decodeHex class
  use strict arg value
  value = value~string~lower
  if value~length // 2 \= 0 then raise syntax 88.900 array("WLU ledger hex field has odd length")
  if value \= "" & verify(value, "0123456789abcdef") \= 0 then raise syntax 88.900 array("WLU ledger hex field is malformed")
  return x2c(value)

::class WLUAuthenticatedFileLedger public
::attribute path get
::attribute sequence get
::attribute previousTag get
::attribute keyRing get

::method init
  expose path sequence previousTag keyRing
  use strict arg path, keyRing
  path = path~string
  if path = "" then raise syntax 88.900 array("WLU ledger path must not be empty")
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLU authenticated ledger requires WLUFastMacKeyRing")
  sequence = 0
  previousTag = .WLUAuthenticatedLedgerBuild~GENESIS_TAG
  stream = .Stream~new(path)
  if stream~query("exists") \= "" then do
    if stream~query("size") \= "0" then do
      recovered = self~recover
      if \recovered~ok then raise syntax 88.900 array("Cannot recover authenticated WLU ledger: " || recovered~code || " " || recovered~detail)
    end
  end

::method append
  expose path sequence previousTag keyRing
  use strict arg tick, eventType, reservationId = "", identity = "", accountId = "", scope = "", microWlu = 0, detail = ""
  guard on
  sequence += 1
  event = .WLULedgerEvent~new(sequence, tick, eventType, reservationId, identity, accountId, scope, microWlu, detail)
  authText = self~authText(previousTag, event)
  proof = keyRing~sign(authText)
  line = self~encodeLine(previousTag, event, proof)
  stream = .Stream~new(path)
  status = stream~open("write append")
  if status \= "READY:" then raise syntax 88.900 array("Cannot open WLU ledger for append " || path || ": " || status)
  ignore = stream~lineOut(line)
  ignore = stream~close
  previousTag = proof~tag
  return event

::method readVerified
  expose path keyRing
  guard on
  events = .array~new
  stream = .Stream~new(path)
  if stream~query("exists") = "" then return .WLUResult~success(events)
  status = stream~open("read")
  if status \= "READY:" then return .WLUResult~failure("WLU_LEDGER_OPEN_FAILED", status)
  expectedSequence = 1
  expectedPrevious = .WLUAuthenticatedLedgerBuild~GENESIS_TAG
  do while stream~lines > 0
    line = stream~lineIn
    decoded = self~decodeLine(line)
    if \decoded~ok then do
      ignore = stream~close
      return decoded
    end
    row = decoded~value
    event = row[1]
    proof = row[2]
    previous = row[3]
    if event~sequence \= expectedSequence then do
      ignore = stream~close
      return .WLUResult~failure("WLU_LEDGER_SEQUENCE_BROKEN", "expected=" || expectedSequence || " actual=" || event~sequence)
    end
    if previous \= expectedPrevious then do
      ignore = stream~close
      return .WLUResult~failure("WLU_LEDGER_CHAIN_BROKEN", "record=" || event~sequence)
    end
    if \keyRing~verify(self~authText(previous, event), proof) then do
      ignore = stream~close
      return .WLUResult~failure("WLU_LEDGER_MAC_INVALID", "record=" || event~sequence)
    end
    events~append(event)
    expectedPrevious = proof~tag
    expectedSequence += 1
  end
  ignore = stream~close
  resultValue = .array~of(events, expectedPrevious)
  return .WLUResult~success(resultValue)

::method recover
  expose sequence previousTag
  guard on
  result = self~readVerified
  if \result~ok then return result
  events = result~value[1]
  sequence = events~items
  previousTag = result~value[2]
  return .WLUResult~success(events)

::method checkpoint
  expose sequence previousTag
  use strict arg checkpointAuthority, tick = .nil
  guard on
  if checkpointAuthority == .nil | \checkpointAuthority~hasMethod("SIGNCHECKPOINT") then return .WLUResult~failure("WLU_CHECKPOINT_SIGNER_REQUIRED", "checkpoint signer is unavailable")
  if tick == .nil then do
    numeric digits 30
    tick = time("F")
  end
  checkpoint = .WLULedgerCheckpoint~new(sequence, previousTag, tick, .nil)
  proof = checkpointAuthority~signCheckpoint(checkpoint~canonicalText)
  return .WLUResult~success(.WLULedgerCheckpoint~new(sequence, previousTag, tick, proof))

::method verifyCheckpoint
  use strict arg checkpointAuthority, checkpoint
  if checkpointAuthority == .nil | checkpoint == .nil then return .false
  if \checkpointAuthority~hasMethod("VERIFYCHECKPOINT") then return .false
  return checkpointAuthority~verifyCheckpoint(checkpoint~canonicalText, checkpoint~proof)

::method authText private
  use strict arg previousTag, event
  value = previousTag~string
  return .WLUAuthenticatedLedgerBuild~RECORD_FORMAT || "0a"x || "previous-tag:" || value~length || ":" || value || "0a"x || event~canonicalText

::method encodeLine private
  use strict arg previousTag, event, proof
  fields = .array~of(.WLUAuthenticatedLedgerBuild~RECORD_FORMAT, event~sequence, previousTag, c2x(proof~algorithm)~lower, c2x(proof~keyId)~lower, proof~tag, event~tick, c2x(event~eventType)~lower, c2x(event~reservationId)~lower, c2x(event~identity)~lower, c2x(event~accountId)~lower, c2x(event~scope)~lower, event~microWlu, c2x(event~detail)~lower)
  line = ""
  do i = 1 to fields~items
    if i > 1 then line ||= "|"
    line ||= fields[i]
  end
  return line

::method decodeLine private
  use strict arg line
  parts = .WLURecordCodec~split(line, "|")
  if parts~items \= 14 then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "field-count=" || parts~items)
  if parts[1] \= .WLUAuthenticatedLedgerBuild~RECORD_FORMAT then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "unexpected record format")
  if \datatype(parts[2], "W") | parts[2] < 1 then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "invalid sequence")
  if parts[3]~length \= 32 | verify(parts[3]~lower, "0123456789abcdef") \= 0 then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "invalid previous tag")
  if parts[6]~length \= 32 | verify(parts[6]~lower, "0123456789abcdef") \= 0 then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "invalid MAC")
  if \datatype(parts[7], "W") then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "invalid tick")
  if \datatype(parts[13], "W") | parts[13] < 0 then return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", "invalid WLU amount")
  signal on syntax name decodeFailure
  algorithm = .WLURecordCodec~decodeHex(parts[4])
  keyId = .WLURecordCodec~decodeHex(parts[5])
  event = .WLULedgerEvent~new(parts[2], parts[7], .WLURecordCodec~decodeHex(parts[8]), .WLURecordCodec~decodeHex(parts[9]), .WLURecordCodec~decodeHex(parts[10]), .WLURecordCodec~decodeHex(parts[11]), .WLURecordCodec~decodeHex(parts[12]), parts[13], .WLURecordCodec~decodeHex(parts[14]))
  signal off syntax
  proof = .WLUProof~new(algorithm, keyId, parts[6])
  return .WLUResult~success(.array~of(event, proof, parts[3]))
decodeFailure:
  signal off syntax
  return .WLUResult~failure("WLU_LEDGER_RECORD_MALFORMED", condition("D"))

::class WLULedgerCheckpoint public
::attribute sequence get
::attribute chainTag get
::attribute createdTick get
::attribute proof get

::method init
  expose sequence chainTag createdTick proof
  use strict arg sequence, chainTag, createdTick, proof = .nil

::method canonicalText
  expose sequence chainTag createdTick
  return .WLUAuthenticatedLedgerBuild~CHECKPOINT_FORMAT || "0a"x || "sequence:" || sequence || "0a"x || "chain-tag:" || chainTag || "0a"x || "created-tick:" || createdTick || "0a"x

::class WLUEd25519CheckpointAuthority public
::attribute keyId get
::attribute publicKey get
::attribute canSign get

::method init
  expose keyId privateSeed publicKey canSign
  use strict arg keyId, privateSeed = "", publicKey = ""
  keyId = keyId~string~strip
  privateSeed = privateSeed~string~strip~lower
  publicKey = publicKey~string~strip~lower
  if keyId = "" then raise syntax 88.900 array("WLU checkpoint keyId must not be empty")
  if privateSeed \= "" then do
    if privateSeed~length \= 64 | verify(privateSeed, "0123456789abcdef") \= 0 then raise syntax 88.900 array("WLU Ed25519 private seed must be 32 bytes / 64 hex")
    pair = .Ed25519~keypair(privateSeed)
    derivedPublic = pair["public"]~lower
    if publicKey = "" then publicKey = derivedPublic
    else if publicKey \= derivedPublic then raise syntax 88.900 array("WLU Ed25519 public key does not match private seed")
  end
  if publicKey~length \= 64 | verify(publicKey, "0123456789abcdef") \= 0 then raise syntax 88.900 array("WLU Ed25519 public key must be 32 bytes / 64 hex")
  canSign = privateSeed \= ""

::method signCheckpoint
  expose keyId privateSeed canSign
  use strict arg checkpointText
  if \canSign then raise syntax 88.900 array("WLU checkpoint authority is verify-only")
  return .WLUProof~new("ED25519", keyId, .Ed25519~sign(checkpointText, privateSeed))

::method verifyCheckpoint
  expose keyId publicKey
  use strict arg checkpointText, proof
  if proof == .nil then return .false
  if proof~algorithm~upper \= "ED25519" then return .false
  if proof~keyId \= keyId then return .false
  if proof~tag~length \= 128 | verify(proof~tag~lower, "0123456789abcdef") \= 0 then return .false
  return .Ed25519~verify(checkpointText, proof~tag~lower, publicKey)

::requires "WorkLoadUnits.cls"
