/* ooRexx Provenance Ledger v0.1-dev4
 * API: provenance.ledger/0.1
 * A deliberately boring cryptographically-linked provenance ledger.
 * Crypto owns cryptography. Storage Fabric owns objects/state. This package owns history.
 */
::requires 'crypto.cls'

::class ProvenanceCanonical public
::method field class
  use strict arg value
  s = value~string
  return s~length || ":" || s
::method transaction class
  use strict arg tx
  return self~field("provenance.tx/1") || self~field(tx~eventId) || self~field(tx~sequence) || self~field(tx~timestamp) || self~field(tx~operation) || self~field(tx~objectRef) || self~field(tx~beforeHash) || self~field(tx~afterHash) || self~field(tx~authorityRef) || self~field(tx~evidenceRef) || self~field(tx~policyRef) || self~field(tx~metadataDigest)
::method blockHeader class
  use strict arg block
  return self~field("provenance.block/1") || self~field(block~chainId) || self~field(block~height) || self~field(block~previousHash) || self~field(block~timestamp) || self~field(block~merkleRoot) || self~field(block~transactionCount) || self~field(block~proposer) || self~field(block~policyRef)

::class ProvenanceTransaction public
::method init
  expose eventId sequence timestamp operation objectRef beforeHash afterHash authorityRef evidenceRef policyRef metadataDigest hash
  use strict arg eventId, sequence, timestamp, operation, objectRef, beforeHash="", afterHash="", authorityRef="", evidenceRef="", policyRef="", metadataDigest=""
  if eventId == "" | operation == "" | objectRef == "" then raise syntax 88.900 array("eventId, operation and objectRef are required")
  hash = .CryptoHash~hashString(.ProvenanceCanonical~transaction(self), "SHA256")
::attribute eventId get
::attribute sequence get
::attribute timestamp get
::attribute operation get
::attribute objectRef get
::attribute beforeHash get
::attribute afterHash get
::attribute authorityRef get
::attribute evidenceRef get
::attribute policyRef get
::attribute metadataDigest get
::attribute hash get
::method canonical; return .ProvenanceCanonical~transaction(self)

::class ProvenanceMerkle public
::method root class
  use strict arg hashes
  if hashes~items == 0 then return .CryptoHash~hashString("provenance.merkle.empty/1", "SHA256")
  level = .Array~new
  do h over hashes; level~append(h~string~lower); end
  do while level~items > 1
    next = .Array~new
    i = 1
    do while i <= level~items
      left = level[i]
      if i + 1 <= level~items then right = level[i+1]; else right = left
      next~append(.CryptoHash~hashString("provenance.merkle.node/1:" || left || ":" || right, "SHA256"))
      i += 2
    end
    level = next
  end
  return level[1]

::class ProvenanceBlock public
::method init
  expose chainId height previousHash timestamp transactions merkleRoot proposer policyRef signature signerPublic hash
  use strict arg chainId, height, previousHash, timestamp, transactions, proposer="", policyRef=""
  if chainId == "" then raise syntax 88.900 array("chainId is required")
  if transactions == .nil then transactions = .Array~new
  hs = .Array~new; do tx over transactions; hs~append(tx~hash); end
  merkleRoot = .ProvenanceMerkle~root(hs)
  signature = ""; signerPublic = ""
  hash = .CryptoHash~hashString(.ProvenanceCanonical~blockHeader(self), "SHA256")
::attribute chainId get
::attribute height get
::attribute previousHash get
::attribute timestamp get
::attribute transactions get
::attribute merkleRoot get
::attribute proposer get
::attribute policyRef get
::attribute signature get
::attribute signerPublic get
::attribute hash get
::method transactionCount; expose transactions; return transactions~items
::method canonical; return .ProvenanceCanonical~blockHeader(self)
::method sign
  expose signature signerPublic hash
  use strict arg privateSeedHex, publicHex
  signature = .Ed25519~sign(hash, privateSeedHex)
  signerPublic = publicHex
  return signature
::method restoreSignature
  expose signature signerPublic
  use strict arg restoredSignature, restoredPublic
  signature=restoredSignature; signerPublic=restoredPublic
  return self
::method verifySignature
  expose signature signerPublic hash
  if signature == "" | signerPublic == "" then return .false
  return .Ed25519~verify(hash, signature, signerPublic)

::class ProvenanceLedger public
::method init
  expose chainId blocks headHash nextSequence
  use strict arg chainId
  if chainId == "" then raise syntax 88.900 array("chainId is required")
  blocks = .Array~new; headHash = ""; nextSequence = 1
::attribute chainId get
::attribute headHash get
::method height; expose blocks; return blocks~items
::method blocks; expose blocks; return blocks
::method nextSequence; expose nextSequence; return nextSequence
::method newTransaction
  expose nextSequence
  use strict arg eventId, timestamp, operation, objectRef, beforeHash="", afterHash="", authorityRef="", evidenceRef="", policyRef="", metadataDigest=""
  tx = .ProvenanceTransaction~new(eventId, nextSequence, timestamp, operation, objectRef, beforeHash, afterHash, authorityRef, evidenceRef, policyRef, metadataDigest)
  nextSequence += 1
  return tx
::method candidate
  expose chainId blocks headHash
  use strict arg timestamp, transactions, proposer="", policyRef=""
  return .ProvenanceBlock~new(chainId, blocks~items + 1, headHash, timestamp, transactions, proposer, policyRef)
::method commit
  expose blocks headHash chainId
  use strict arg block, requireSignature=.true
  if block~chainId \== chainId then raise syntax 88.900 array("CHAIN_ID_MISMATCH")
  if block~height \== blocks~items + 1 then raise syntax 88.900 array("HEIGHT_MISMATCH")
  if block~previousHash \== headHash then raise syntax 88.900 array("PREVIOUS_HASH_MISMATCH")
  if \self~verifyBlock(block, requireSignature) then raise syntax 88.900 array("BLOCK_VERIFICATION_FAILED")
  blocks~append(block); headHash = block~hash
  return headHash
::method verifyBlock
  use strict arg block, requireSignature=.true
  hs=.Array~new
  do tx over block~transactions
    if tx~hash \== .CryptoHash~hashString(tx~canonical,"SHA256") then return .false
    hs~append(tx~hash)
  end
  if block~merkleRoot \== .ProvenanceMerkle~root(hs) then return .false
  if block~hash \== .CryptoHash~hashString(block~canonical,"SHA256") then return .false
  if requireSignature & \block~verifySignature then return .false
  return .true
::method verify
  expose blocks chainId
  previous=""
  expected=1
  do block over blocks
    if block~chainId \== chainId | block~height \== expected | block~previousHash \== previous then return .false
    if \self~verifyBlock(block, .true) then return .false
    previous=block~hash; expected += 1
  end
  return .true

/* dev2: generic state/provenance seam.  Deliberately duck-typed: Storage Fabric
 * remains an optional authority and this package does not ::requires it. */
::class ProvenanceStateRef public
::attribute objectRef get
::attribute digest get
::attribute evidenceRef get
::method init
  expose objectRef digest evidenceRef
  use strict arg objectRef, digest, evidenceRef=""
  objectRef=objectRef~string; digest=digest~string~lower; evidenceRef=evidenceRef~string
  if objectRef=="" | digest=="" then raise syntax 88.900 array("objectRef and digest are required")

::class ProvenanceCommitReceipt public
::attribute chainId get
::attribute height get
::attribute blockHash get
::attribute merkleRoot get
::attribute transactionHashes get
::method init
  expose chainId height blockHash merkleRoot transactionHashes
  use strict arg chainId, height, blockHash, merkleRoot, transactionHashes
::method verifies
  expose blockHash merkleRoot transactionHashes
  use strict arg block
  if block~hash \== blockHash | block~merkleRoot \== merkleRoot then return .false
  if block~transactions~items \== transactionHashes~items then return .false
  do i=1 to transactionHashes~items
    if block~transactions[i]~hash \== transactionHashes[i] then return .false
  end
  return .true

::class ProvenanceStorageAdapter public
/* Convert the stable public StorageRef shape into a ledger state reference. */
::method stateRef class
  use strict arg storageRef, evidenceRef=""
  if storageRef==.nil | \storageRef~hasMethod("OBJECTID") | \storageRef~hasMethod("DIGEST") then raise syntax 88.900 array("StorageRef-compatible object required")
  if storageRef~digest=="" then raise syntax 88.900 array("storage reference has no verification digest")
  return .ProvenanceStateRef~new(storageRef~objectId, storageRef~digest, evidenceRef)
::method transition class
  use strict arg ledger, eventId, timestamp, operation, beforeRef=.nil, afterRef=.nil, authorityRef="", evidenceRef="", policyRef="", metadataDigest=""
  objectRef=""; beforeHash=""; afterHash=""
  if beforeRef \== .nil then do
    b=self~stateRef(beforeRef,evidenceRef); objectRef=b~objectRef; beforeHash=b~digest
  end
  if afterRef \== .nil then do
    a=self~stateRef(afterRef,evidenceRef)
    if objectRef=="" then objectRef=a~objectRef
    if objectRef \== a~objectRef then raise syntax 88.900 array("STORAGE_OBJECT_IDENTITY_MISMATCH")
    afterHash=a~digest
  end
  if objectRef=="" then raise syntax 88.900 array("beforeRef or afterRef required")
  return ledger~newTransaction(eventId,timestamp,operation,objectRef,beforeHash,afterHash,authorityRef,evidenceRef,policyRef,metadataDigest)
::method verifyCurrent class
  use strict arg tx, storageRef
  s=self~stateRef(storageRef)
  if s~objectRef \== tx~objectRef then return .false
  if tx~afterHash=="" then return .false
  return s~digest~lower == tx~afterHash~lower

/* Accounting is a consumer/producer of provenance evidence, not the ledger's
 * semantic model.  This adapter intentionally knows only immutable identities. */
::class ProvenanceAccountingAdapter public
::method event class
  use strict arg ledger, eventId, timestamp, accountingObjectRef, beforeFingerprint="", afterFingerprint="", authorityRef="", evidenceRef="", policyRef="", metadataDigest=""
  if accountingObjectRef=="" then raise syntax 88.900 array("accountingObjectRef required")
  return ledger~newTransaction(eventId,timestamp,"ACCOUNTING_EVIDENCE_COMMITTED",accountingObjectRef,beforeFingerprint,afterFingerprint,authorityRef,evidenceRef,policyRef,metadataDigest)


/* dev3: checkpoint and durable segment representation.  State roots commit to
 * references and digests, never to the materialised objects themselves. */
::class ProvenanceCheckpoint public
::attribute chainId get
::attribute height get
::attribute headHash get
::attribute stateRoot get
::attribute snapshotRef get
::attribute stateCount get
::method init
  expose chainId height headHash stateRoot snapshotRef stateCount
  use strict arg ledger, stateRefs, snapshotRefArg=""
  chainId=ledger~chainId; height=ledger~height; headHash=ledger~headHash
  hs=.Array~new
  do s over stateRefs
    canonical=.ProvenanceCanonical~field("provenance.state/1") || .ProvenanceCanonical~field(s~objectRef) || .ProvenanceCanonical~field(s~digest)
    hs~append(.CryptoHash~hashString(canonical,"SHA256"))
  end
  stateCount=hs~items; stateRoot=.ProvenanceMerkle~root(hs); snapshotRef=snapshotRefArg
::method event
  expose chainId height headHash stateRoot snapshotRef stateCount
  use strict arg ledger, eventId, timestamp, authorityRef="", evidenceRef="", policyRef=""
  metadata=.CryptoHash~hashString(.ProvenanceCanonical~field("provenance.checkpoint/1") || .ProvenanceCanonical~field(chainId) || .ProvenanceCanonical~field(height) || .ProvenanceCanonical~field(headHash) || .ProvenanceCanonical~field(stateRoot) || .ProvenanceCanonical~field(snapshotRef) || .ProvenanceCanonical~field(stateCount),"SHA256")
  object="ledger://" || chainId || "/checkpoint/" || height
  return ledger~newTransaction(eventId,timestamp,"LEDGER_CHECKPOINT",object,headHash,stateRoot,authorityRef,evidenceRef,policyRef,metadata)

::class ProvenanceSegmentCodec public
::method hx class
  use strict arg value
  return value~string~c2x
::method unhx class
  use strict arg value
  if value=="" then return ""
  return value~x2c
::method write class
  use strict arg path, ledger, fromHeight=1, toHeight=0
  if toHeight==0 then toHeight=ledger~height
  if fromHeight<1 | toHeight<fromHeight | toHeight>ledger~height then raise syntax 88.900 array("INVALID_SEGMENT_RANGE")
  f=.stream~new(path); rc=f~open("write replace")
  if rc<>"READY:" then raise syntax 88.900 array("SEGMENT_OPEN_FAILED",rc)
  f~lineout("PROVENANCE-SEGMENT|1|" || self~hx(ledger~chainId) || "|" || fromHeight || "|" || toHeight)
  blocks=ledger~blocks
  do n=fromHeight to toHeight
    b=blocks[n]
    f~lineout("B|" || b~height || "|" || self~hx(b~previousHash) || "|" || self~hx(b~timestamp) || "|" || self~hx(b~proposer) || "|" || self~hx(b~policyRef) || "|" || self~hx(b~signature) || "|" || self~hx(b~signerPublic))
    do tx over b~transactions
      f~lineout("T|" || self~hx(tx~eventId) || "|" || tx~sequence || "|" || self~hx(tx~timestamp) || "|" || self~hx(tx~operation) || "|" || self~hx(tx~objectRef) || "|" || self~hx(tx~beforeHash) || "|" || self~hx(tx~afterHash) || "|" || self~hx(tx~authorityRef) || "|" || self~hx(tx~evidenceRef) || "|" || self~hx(tx~policyRef) || "|" || self~hx(tx~metadataDigest))
    end
    f~lineout("E")
  end
  f~lineout("END|" || self~hx(blocks[toHeight]~hash)); f~close
  return path
::method read class
  use strict arg path, requireSignature=.true
  f=.stream~new(path); rc=f~open("read")
  if rc<>"READY:" then raise syntax 88.900 array("SEGMENT_OPEN_FAILED",rc)
  header=f~linein; parse var header magic "|" version "|" chainHex "|" fromHeight "|" toHeight
  if magic<>"PROVENANCE-SEGMENT" | version<>"1" then raise syntax 88.900 array("BAD_SEGMENT_HEADER")
  chainId=self~unhx(chainHex); ledger=.ProvenanceLedger~new(chainId)
  if fromHeight<>1 then raise syntax 88.900 array("SEGMENT_RESTORE_REQUIRES_GENESIS")
  current=.nil; txs=.Array~new
  do while f~lines>0
    line=f~linein
    parse var line kind "|" rest
    if kind=="B" then do
      parse var rest height "|" prev "|" ts "|" proposer "|" policy "|" sig "|" pub
      current=.directory~new; current["height"]=height; current["prev"]=self~unhx(prev); current["ts"]=self~unhx(ts); current["proposer"]=self~unhx(proposer); current["policy"]=self~unhx(policy); current["sig"]=self~unhx(sig); current["pub"]=self~unhx(pub); txs=.Array~new
    end
    else if kind=="T" then do
      parse var rest eid "|" seq "|" ts "|" op "|" obj "|" before "|" after "|" auth "|" evidence "|" policy "|" metadata
      tx=.ProvenanceTransaction~new(self~unhx(eid),seq,self~unhx(ts),self~unhx(op),self~unhx(obj),self~unhx(before),self~unhx(after),self~unhx(auth),self~unhx(evidence),self~unhx(policy),self~unhx(metadata)); txs~append(tx)
    end
    else if kind=="E" then do
      if current==.nil then raise syntax 88.900 array("SEGMENT_BLOCK_END_WITHOUT_BLOCK")
      b=.ProvenanceBlock~new(chainId,current["height"],current["prev"],current["ts"],txs,current["proposer"],current["policy"]); b~restoreSignature(current["sig"],current["pub"]); ledger~commit(b,requireSignature); current=.nil
    end
    else if kind=="END" then leave
    else raise syntax 88.900 array("BAD_SEGMENT_RECORD",kind)
  end
  f~close
  if ledger~height<>toHeight then raise syntax 88.900 array("SEGMENT_HEIGHT_MISMATCH")
  return ledger

/* dev4: sequential/physical media provenance seam.  Storage Fabric remains
 * optional and authoritative for media semantics and bytes.  This adapter
 * commits only stable identity/digest plus a cryptographic description of the
 * canonical media shape or an explicitly named edge representation. */
::class ProvenanceSequentialMediaAdapter public
::method requireStorageRef class
  use strict arg storageRef
  if storageRef==.nil | \storageRef~hasMethod("OBJECTID") | \storageRef~hasMethod("DIGEST") then raise syntax 88.900 array("StorageRef-compatible object required")
  if storageRef~objectId=="" | storageRef~digest=="" then raise syntax 88.900 array("storage reference requires objectId and verification digest")
  return storageRef
::method requireMedia class
  use strict arg image
  if image==.nil then raise syntax 88.900 array("sequential media image required")
  required=.array~of("MEDIAID","FAMILY","ENCODING","FIXEDRECORDBYTES","DATARECORDCOUNT","BOUNDARYCOUNT","SOURCEREF")
  do name over required
    if \image~hasMethod(name) then raise syntax 88.900 array("sequential media compatible object required",name)
  end
  family=image~family~string~strip~upper
  if family<>"CARD_DECK" & family<>"PAPER_LISTING" & family<>"TAPE_VOLUME" then raise syntax 88.900 array("unsupported sequential media family",family)
  return image
::method mediaCanonical class
  use strict arg image
  image=self~requireMedia(image)
  src=""
  if image~sourceRef \== .nil then src=image~sourceRef~string
  return .ProvenanceCanonical~field("provenance.storage-media/1") || -
         .ProvenanceCanonical~field(image~mediaId) || -
         .ProvenanceCanonical~field(image~family~string~upper) || -
         .ProvenanceCanonical~field(image~encoding~string~upper) || -
         .ProvenanceCanonical~field(image~fixedRecordBytes) || -
         .ProvenanceCanonical~field(image~dataRecordCount) || -
         .ProvenanceCanonical~field(image~boundaryCount) || -
         .ProvenanceCanonical~field(src)
::method mediaMetadataDigest class
  use strict arg image
  return .CryptoHash~hashString(self~mediaCanonical(image),"SHA256")
::method observe class
  use strict arg ledger, eventId, timestamp, storageRef, image, operation="MEDIA_STATE_COMMITTED", authorityRef="", evidenceRef="", policyRef=""
  storageRef=self~requireStorageRef(storageRef); image=self~requireMedia(image)
  metadata=self~mediaMetadataDigest(image)
  return ledger~newTransaction(eventId,timestamp,operation,storageRef~objectId,"",storageRef~digest,authorityRef,evidenceRef,policyRef,metadata)
::method representationCanonical class
  use strict arg storageRef, image, externalFormat, artifactDigest, direction, targetRef="", lossProfile="LOSSLESS"
  storageRef=self~requireStorageRef(storageRef); image=self~requireMedia(image)
  fmt=externalFormat~string~strip~upper; dig=artifactDigest~string~strip~lower; dir=direction~string~strip~upper; loss=lossProfile~string~strip~upper
  if fmt=="" | dig=="" then raise syntax 88.900 array("representation format and artifact digest are required")
  if dir<>"IN" & dir<>"OUT" then raise syntax 88.900 array("representation direction must be IN or OUT")
  return .ProvenanceCanonical~field("provenance.storage-media-representation/1") || -
         .ProvenanceCanonical~field(storageRef~objectId) || -
         .ProvenanceCanonical~field(storageRef~digest~string~lower) || -
         .ProvenanceCanonical~field(self~mediaMetadataDigest(image)) || -
         .ProvenanceCanonical~field(fmt) || -
         .ProvenanceCanonical~field(dig) || -
         .ProvenanceCanonical~field(dir) || -
         .ProvenanceCanonical~field(targetRef) || -
         .ProvenanceCanonical~field(loss)
::method representationEvent class
  use strict arg ledger, eventId, timestamp, storageRef, image, externalFormat, artifactDigest, direction, targetRef="", lossProfile="LOSSLESS", authorityRef="", evidenceRef="", policyRef=""
  storageRef=self~requireStorageRef(storageRef); image=self~requireMedia(image)
  dir=direction~string~strip~upper
  canonical=self~representationCanonical(storageRef,image,externalFormat,artifactDigest,dir,targetRef,lossProfile)
  metadata=.CryptoHash~hashString(canonical,"SHA256")
  if dir=="OUT" then operation="MEDIA_REPRESENTATION_EXPORTED"
  else operation="MEDIA_REPRESENTATION_IMPORTED"
  /* Representation does not silently become authoritative object state.  The
   * Storage digest remains the state commitment; artifactDigest is committed
   * inside metadataDigest as edge evidence. */
  return ledger~newTransaction(eventId,timestamp,operation,storageRef~objectId,storageRef~digest,storageRef~digest,authorityRef,evidenceRef,policyRef,metadata)
::method roundTripEvent class
  use strict arg ledger, eventId, timestamp, originalRef, restoredRef, image, externalFormat, artifactDigest, authorityRef="", evidenceRef="", policyRef=""
  originalRef=self~requireStorageRef(originalRef); restoredRef=self~requireStorageRef(restoredRef); image=self~requireMedia(image)
  if originalRef~objectId \== restoredRef~objectId then raise syntax 88.900 array("MEDIA_ROUNDTRIP_OBJECT_IDENTITY_MISMATCH")
  canonical=.ProvenanceCanonical~field("provenance.storage-media-roundtrip/1") || -
            .ProvenanceCanonical~field(originalRef~objectId) || -
            .ProvenanceCanonical~field(originalRef~digest~string~lower) || -
            .ProvenanceCanonical~field(restoredRef~digest~string~lower) || -
            .ProvenanceCanonical~field(self~mediaMetadataDigest(image)) || -
            .ProvenanceCanonical~field(externalFormat~string~strip~upper) || -
            .ProvenanceCanonical~field(artifactDigest~string~strip~lower)
  metadata=.CryptoHash~hashString(canonical,"SHA256")
  return ledger~newTransaction(eventId,timestamp,"MEDIA_ROUNDTRIP_VERIFIED",originalRef~objectId,originalRef~digest,restoredRef~digest,authorityRef,evidenceRef,policyRef,metadata)