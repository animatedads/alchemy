/* ooRexx Provenance Ledger v0.1-dev5
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
  expose chainId blocks nextSequence baseHeight baseHash
  use strict arg chainId, baseHeight=0, baseHash=""
  if chainId=="" then raise syntax 88.900 array("chainId required")
  blocks=.Array~new; nextSequence=1
  self~setBase(baseHeight,baseHash)
::attribute chainId get
::attribute blocks get
::attribute nextSequence get
::attribute baseHeight get
::attribute baseHash get
::method setBase
  expose baseHeight baseHash
  use strict arg h, hash=""
  if h<0 then raise syntax 88.900 array("INVALID_BASE_HEIGHT")
  if h>0 & hash=="" then raise syntax 88.900 array("BASE_HASH_REQUIRED")
  baseHeight=h; baseHash=hash; return self
::method height
  expose baseHeight blocks
  return baseHeight+blocks~items
::method headHash
  expose blocks baseHash
  if blocks~items=0 then return baseHash
  return blocks[blocks~items]~hash
::method newTransaction
  expose nextSequence
  use strict arg eventId,timestamp,operation,objectRef,beforeHash="",afterHash="",authorityRef="",evidenceRef="",policyRef="",metadataDigest=""
  tx=.ProvenanceTransaction~new(eventId,nextSequence,timestamp,operation,objectRef,beforeHash,afterHash,authorityRef,evidenceRef,policyRef,metadataDigest)
  nextSequence+=1; return tx
::method candidate
  use strict arg timestamp, transactions, proposer="", policyRef=""
  return .ProvenanceBlock~new(self~chainId,self~height+1,self~headHash,timestamp,transactions,proposer,policyRef)
::method commit
  expose blocks nextSequence
  use strict arg block, requireSignature=.true
  if block~chainId \== self~chainId then raise syntax 88.900 array("CHAIN_ID_MISMATCH")
  if block~height \== self~height+1 then raise syntax 88.900 array("BLOCK_HEIGHT_MISMATCH")
  if block~previousHash \== self~headHash then raise syntax 88.900 array("PREVIOUS_HASH_MISMATCH")
  expected=.Array~new; maxSeq=0
  do tx over block~transactions
    expected~append(tx~hash)
    if tx~sequence>maxSeq then maxSeq=tx~sequence
  end
  if .ProvenanceMerkle~root(expected) \== block~merkleRoot then raise syntax 88.900 array("MERKLE_ROOT_MISMATCH")
  if requireSignature & \block~verifySignature then raise syntax 88.900 array("BLOCK_SIGNATURE_INVALID")
  blocks~append(block)
  if maxSeq>=nextSequence then nextSequence=maxSeq+1
  return block
::method verify
  expose blocks baseHeight baseHash
  prev=baseHash; expectedHeight=baseHeight+1
  do b over blocks
    if b~height<>expectedHeight | b~previousHash \== prev then return .false
    hs=.Array~new; do tx over b~transactions; hs~append(tx~hash); end
    if .ProvenanceMerkle~root(hs) \== b~merkleRoot then return .false
    if \b~verifySignature then return .false
    prev=b~hash; expectedHeight+=1
  end
  return .true

::class ProvenanceCommitReceipt public
::attribute chainId get
::attribute height get
::attribute blockHash get
::attribute merkleRoot get
::attribute transactionHashes get
::method init
  expose chainId height blockHash merkleRoot transactionHashes
  use strict arg chainId,height,blockHash,merkleRoot,transactionHashes
::method verifies
  use strict arg block
  if block~chainId \== self~chainId | block~height \== self~height | block~hash \== self~blockHash | block~merkleRoot \== self~merkleRoot then return .false
  hs=.Array~new; do tx over block~transactions; hs~append(tx~hash); end
  if hs~items<>self~transactionHashes~items then return .false
  do i=1 to hs~items; if hs[i] \== self~transactionHashes[i] then return .false; end
  return .true

::class ProvenanceStorageAdapter public
::method transition class
  use strict arg ledger,eventId,timestamp,operation,beforeRef,afterRef,authorityRef="",evidenceRef="",policyRef=""
  objectId=afterRef~objectId
  if objectId=="" then objectId=beforeRef~objectId
  return ledger~newTransaction(eventId,timestamp,operation,objectId,beforeRef~digest,afterRef~digest,authorityRef,evidenceRef,policyRef)
::method verifyCurrent class
  use strict arg tx,currentRef
  return tx~objectRef == currentRef~objectId & tx~afterHash == currentRef~digest

::class ProvenanceAccountingAdapter public
::method event class
  use strict arg ledger,eventId,timestamp,objectRef,beforeFingerprint="",afterFingerprint="",authorityRef="",evidenceRef="",policyRef=""
  return ledger~newTransaction(eventId,timestamp,"ACCOUNTING_EVIDENCE_COMMITTED",objectRef,beforeFingerprint,afterFingerprint,authorityRef,evidenceRef,policyRef)

::class ProvenanceStateRef public
::attribute objectRef get
::attribute digest get
::method init
  expose objectRef digest
  use strict arg objectRef,digest

::class ProvenanceCheckpoint public
::attribute chainId get
::attribute height get
::attribute headHash get
::attribute stateRoot get
::attribute stateCount get
::attribute snapshotRef get
::method init
  expose chainId height headHash stateRoot stateCount snapshotRef
  use strict arg ledger, states, snapshotRef=""
  chainId=ledger~chainId; height=ledger~height; headHash=ledger~headHash; stateCount=states~items
  hashes=.Array~new
  do s over states
    hashes~append(.CryptoHash~hashString(.ProvenanceCanonical~field("provenance.state/1")||.ProvenanceCanonical~field(s~objectRef)||.ProvenanceCanonical~field(s~digest),"SHA256"))
  end
  stateRoot=.ProvenanceMerkle~root(hashes)
::method event
  use strict arg ledger,eventId,timestamp,authorityRef="",evidenceRef="",policyRef=""
  metadata=.CryptoHash~hashString(self~chainId||":"||self~height||":"||self~headHash||":"||self~stateRoot||":"||self~snapshotRef,"SHA256")
  return ledger~newTransaction(eventId,timestamp,"LEDGER_CHECKPOINT","ledger://"||self~chainId||"/checkpoint/"||self~height,self~headHash,self~stateRoot,authorityRef,evidenceRef,policyRef,metadata)

::class ProvenanceSegmentCodec public
::method hx class
  use strict arg s
  return s~string~c2x
::method unhx class
  use strict arg s
  if s=="" then return ""
  return s~x2c
::method write class
  use strict arg path, ledger, fromHeight=1, toHeight=0
  if toHeight=0 then toHeight=ledger~height
  if fromHeight<1 | toHeight<fromHeight | toHeight>ledger~height then raise syntax 88.900 array("INVALID_SEGMENT_RANGE")
  f=.stream~new(path); rc=f~open("write replace"); if rc<>"READY:" then raise syntax 88.900 array("SEGMENT_OPEN_FAILED",rc)
  f~lineout("PROVENANCE-SEGMENT|1|"||self~hx(ledger~chainId)||"|"||fromHeight||"|"||toHeight)
  do b over ledger~blocks
    if b~height<fromHeight | b~height>toHeight then iterate
    f~lineout("B|"||b~height||"|"||self~hx(b~previousHash)||"|"||self~hx(b~timestamp)||"|"||self~hx(b~proposer)||"|"||self~hx(b~policyRef)||"|"||self~hx(b~signature)||"|"||self~hx(b~signerPublic))
    do tx over b~transactions
      f~lineout("T|"||self~hx(tx~eventId)||"|"||tx~sequence||"|"||self~hx(tx~timestamp)||"|"||self~hx(tx~operation)||"|"||self~hx(tx~objectRef)||"|"||self~hx(tx~beforeHash)||"|"||self~hx(tx~afterHash)||"|"||self~hx(tx~authorityRef)||"|"||self~hx(tx~evidenceRef)||"|"||self~hx(tx~policyRef)||"|"||self~hx(tx~metadataDigest))
    end
    f~lineout("E")
  end
  f~lineout("END|"||.CryptoHash~hashString(ledger~headHash||":"||fromHeight||":"||toHeight,"SHA256"))
  f~close; return path
::method read class
  use strict arg path, requireSignature=.true, anchor=.nil
  f=.stream~new(path); rc=f~open("read"); if rc<>"READY:" then raise syntax 88.900 array("SEGMENT_OPEN_FAILED",rc)
  header=f~linein; parse var header magic "|" version "|" chainHex "|" fromHeight "|" toHeight
  if magic<>"PROVENANCE-SEGMENT" | version<>"1" then raise syntax 88.900 array("BAD_SEGMENT_HEADER")
  chainId=self~unhx(chainHex)
  if fromHeight>1 then do
    if anchor==.nil then raise syntax 88.900 array("TRUSTED_ANCHOR_REQUIRED")
    if anchor~chainId \== chainId | anchor~height<>fromHeight-1 | \anchor~verify then raise syntax 88.900 array("TRUSTED_ANCHOR_INVALID")
    ledger=.ProvenanceLedger~new(chainId,anchor~height,anchor~headHash)
  end
  else ledger=.ProvenanceLedger~new(chainId)
  current=.nil
  do while f~lines>0
    line=f~linein
    parse var line kind "|" rest
    if kind=="B" then do
      parse var rest height "|" prev "|" ts "|" proposer "|" policy "|" sig "|" pub
      current=.directory~new
      current["height"]=height; current["prev"]=self~unhx(prev); current["timestamp"]=self~unhx(ts); current["proposer"]=self~unhx(proposer); current["policy"]=self~unhx(policy); current["sig"]=self~unhx(sig); current["pub"]=self~unhx(pub); current["txs"]=.Array~new
    end
    else if kind=="T" then do
      parse var rest eid "|" seq "|" ts "|" op "|" obj "|" before "|" after "|" auth "|" evidence "|" policy "|" meta
      tx=.ProvenanceTransaction~new(self~unhx(eid),seq,self~unhx(ts),self~unhx(op),self~unhx(obj),self~unhx(before),self~unhx(after),self~unhx(auth),self~unhx(evidence),self~unhx(policy),self~unhx(meta))
      current["txs"]~append(tx)
    end
    else if kind=="E" then do
      b=.ProvenanceBlock~new(chainId,current["height"],current["prev"],current["timestamp"],current["txs"],current["proposer"],current["policy"])
      b~restoreSignature(current["sig"],current["pub"]); ledger~commit(b,requireSignature); current=.nil
    end
    else if kind=="END" then leave
    else raise syntax 88.900 array("BAD_SEGMENT_RECORD",kind)
  end
  f~close
  if ledger~height<>toHeight then raise syntax 88.900 array("SEGMENT_HEIGHT_MISMATCH")
  return ledger

::class ProvenanceTrustedAnchor public
::attribute chainId get
::attribute height get
::attribute headHash get
::attribute stateRoot get
::attribute snapshotRef get
::attribute signerRef get
::attribute signerPublic get
::attribute signature get
::method init
  expose chainId height headHash stateRoot snapshotRef signerRef signerPublic signature
  use strict arg chainId, height, headHash, stateRoot="", snapshotRef="", signerRef="", signerPublic="", signature=""
  if chainId=="" | height<0 then raise syntax 88.900 array("INVALID_TRUSTED_ANCHOR")
  if height>0 & headHash=="" then raise syntax 88.900 array("ANCHOR_HEAD_HASH_REQUIRED")
::method canonical
  expose chainId height headHash stateRoot snapshotRef signerRef
  return .ProvenanceCanonical~field("provenance.anchor/1") || .ProvenanceCanonical~field(chainId) || .ProvenanceCanonical~field(height) || .ProvenanceCanonical~field(headHash) || .ProvenanceCanonical~field(stateRoot) || .ProvenanceCanonical~field(snapshotRef) || .ProvenanceCanonical~field(signerRef)
::method hash
  return .CryptoHash~hashString(self~canonical,"SHA256")
::method sign
  expose signature signerPublic
  use strict arg privateSeedHex, publicHex
  signature=.Ed25519~sign(self~hash,privateSeedHex); signerPublic=publicHex; return signature
::method verify
  expose signature signerPublic
  if signature=="" | signerPublic=="" then return .false
  return .Ed25519~verify(self~hash,signature,signerPublic)
::method write
  expose chainId height headHash stateRoot snapshotRef signerRef signerPublic signature
  use strict arg path
  f=.stream~new(path); rc=f~open("write replace")
  if rc<>"READY:" then raise syntax 88.900 array("ANCHOR_OPEN_FAILED",rc)
  f~lineout("PROVENANCE-ANCHOR|1")
  f~lineout(.ProvenanceSegmentCodec~hx(chainId)||"|"||height||"|"||.ProvenanceSegmentCodec~hx(headHash)||"|"||.ProvenanceSegmentCodec~hx(stateRoot)||"|"||.ProvenanceSegmentCodec~hx(snapshotRef)||"|"||.ProvenanceSegmentCodec~hx(signerRef)||"|"||.ProvenanceSegmentCodec~hx(signerPublic)||"|"||.ProvenanceSegmentCodec~hx(signature))
  f~close; return path
::method read class
  use strict arg path
  f=.stream~new(path); rc=f~open("read"); if rc<>"READY:" then raise syntax 88.900 array("ANCHOR_OPEN_FAILED",rc)
  if f~linein<>"PROVENANCE-ANCHOR|1" then raise syntax 88.900 array("BAD_ANCHOR_HEADER")
  line=f~linein; f~close
  parse var line chain "|" height "|" head "|" state "|" snap "|" signer "|" pub "|" sig
  return self~new(.ProvenanceSegmentCodec~unhx(chain),height,.ProvenanceSegmentCodec~unhx(head),.ProvenanceSegmentCodec~unhx(state),.ProvenanceSegmentCodec~unhx(snap),.ProvenanceSegmentCodec~unhx(signer),.ProvenanceSegmentCodec~unhx(pub),.ProvenanceSegmentCodec~unhx(sig))

::class ProvenanceArchiveManifest public
::attribute chainId get
::attribute anchorHash get
::attribute entries get
::method init
  expose chainId anchorHash entries
  use strict arg chainId, anchorHash=""
  if chainId=="" then raise syntax 88.900 array("chainId required")
  entries=.Array~new
::method addSegment
  expose entries
  use strict arg name, fromHeight, toHeight, digest
  if name=="" | fromHeight<1 | toHeight<fromHeight | digest=="" then raise syntax 88.900 array("INVALID_ARCHIVE_ENTRY")
  e=.directory~new; e["name"]=name; e["from"]=fromHeight; e["to"]=toHeight; e["digest"]=digest~lower; entries~append(e); return self
::method canonical
  expose chainId anchorHash entries
  c=.ProvenanceCanonical~field("provenance.archive/1")||.ProvenanceCanonical~field(chainId)||.ProvenanceCanonical~field(anchorHash)||.ProvenanceCanonical~field(entries~items)
  do e over entries
    c=c||.ProvenanceCanonical~field(e["name"])||.ProvenanceCanonical~field(e["from"])||.ProvenanceCanonical~field(e["to"])||.ProvenanceCanonical~field(e["digest"])
  end
  return c
::method digest
  return .CryptoHash~hashString(self~canonical,"SHA256")
::method write
  expose chainId anchorHash entries
  use strict arg path
  f=.stream~new(path); rc=f~open("write replace"); if rc<>"READY:" then raise syntax 88.900 array("MANIFEST_OPEN_FAILED",rc)
  f~lineout("PROVENANCE-ARCHIVE|1|"||.ProvenanceSegmentCodec~hx(chainId)||"|"||.ProvenanceSegmentCodec~hx(anchorHash))
  do e over entries
    f~lineout("S|"||.ProvenanceSegmentCodec~hx(e["name"])||"|"||e["from"]||"|"||e["to"]||"|"||e["digest"])
  end
  f~lineout("END|"||self~digest); f~close; return path
::method read class
  use strict arg path
  f=.stream~new(path); rc=f~open("read"); if rc<>"READY:" then raise syntax 88.900 array("MANIFEST_OPEN_FAILED",rc)
  header=f~linein; parse var header magic "|" version "|" chain "|" anchor
  if magic<>"PROVENANCE-ARCHIVE" | version<>"1" then raise syntax 88.900 array("BAD_MANIFEST_HEADER")
  m=self~new(.ProvenanceSegmentCodec~unhx(chain),.ProvenanceSegmentCodec~unhx(anchor)); expected=""
  do while f~lines>0
    line=f~linein; parse var line kind "|" rest
    if kind=="S" then do
      parse var rest name "|" first "|" last "|" digest
      m~addSegment(.ProvenanceSegmentCodec~unhx(name),first,last,digest)
    end
    else if kind=="END" then do; expected=rest; leave; end
    else raise syntax 88.900 array("BAD_MANIFEST_RECORD",kind)
  end
  f~close
  if expected=="" | m~digest \== expected then raise syntax 88.900 array("MANIFEST_DIGEST_MISMATCH")
  return m

::class ProvenanceMediaRecordKind public
::constant MANIFEST "MANIFEST"
::constant ANCHOR "ANCHOR"
::constant SEGMENT "SEGMENT"

::class ProvenanceMediaAdapter public
::method payloadDigest class
  use strict arg payload
  return .CryptoHash~hashString(payload~string,"SHA256")
::method envelope class
  use strict arg kind, name, payload
  k=kind~string~upper; n=name~string; p=payload~string
  if k=="" | n=="" then raise syntax 88.900 array("INVALID_MEDIA_RECORD")
  return "PROVENANCE-MEDIA|1|" || .ProvenanceSegmentCodec~hx(k) || "|" || .ProvenanceSegmentCodec~hx(n) || "|" || p~length || "|" || self~payloadDigest(p) || "0A"x || p
::method decode class
  use strict arg bytes
  b=bytes~string; nl=b~pos("0A"x)
  if nl=0 then raise syntax 88.900 array("BAD_MEDIA_ENVELOPE")
  header=b~substr(1,nl-1); payload=b~substr(nl+1)
  parse var header magic "|" version "|" kindHex "|" nameHex "|" payloadLength "|" digest
  if magic<>"PROVENANCE-MEDIA" | version<>"1" then raise syntax 88.900 array("BAD_MEDIA_HEADER")
  if payload~length<>payloadLength then raise syntax 88.900 array("MEDIA_LENGTH_MISMATCH")
  if self~payloadDigest(payload) \== digest then raise syntax 88.900 array("MEDIA_DIGEST_MISMATCH")
  d=.directory~new; d["kind"]=.ProvenanceSegmentCodec~unhx(kindHex); d["name"]=.ProvenanceSegmentCodec~unhx(nameHex); d["payload"]=payload; d["digest"]=digest
  return d
::method addToSequentialImage class
  use strict arg image, kind, name, payload, filemark=.true
  if image==.nil | \image~hasMethod("ADDDATA") then raise syntax 88.900 array("StorageSequentialMediaImage-compatible object required")
  image~addData(self~envelope(kind,name,payload))
  if filemark==.true & image~hasMethod("ADDFILEMARK") then image~addFilemark
  return image
::method readSequentialImage class
  use strict arg image
  if image==.nil | \image~hasMethod("RECORDS") then raise syntax 88.900 array("StorageSequentialMediaImage-compatible object required")
  out=.array~new
  do r over image~records
    if r~kind=="DATA" then out~append(self~decode(r~data))
  end
  return out
::method fileBytes class
  use strict arg path
  f=.stream~new(path); rc=f~open("read")
  if rc<>"READY:" then raise syntax 88.900 array("MEDIA_SOURCE_OPEN_FAILED",rc)
  n=chars(path); if n>0 then data=charin(path,1,n); else data=""
  f~close; return data
::method writeBytes class
  use strict arg path, bytes
  f=.stream~new(path); rc=f~open("write replace")
  if rc<>"READY:" then raise syntax 88.900 array("MEDIA_TARGET_OPEN_FAILED",rc)
  call charout path,bytes; call stream path,"c","close"; return path
::method archiveToSequentialImage class
  use strict arg image, manifestPath, anchorPath="", segmentPaths=.nil
  if segmentPaths==.nil then segmentPaths=.array~new
  self~addToSequentialImage(image,.ProvenanceMediaRecordKind~MANIFEST,"manifest",self~fileBytes(manifestPath))
  if anchorPath<>"" then self~addToSequentialImage(image,.ProvenanceMediaRecordKind~ANCHOR,"anchor",self~fileBytes(anchorPath))
  do path over segmentPaths
    self~addToSequentialImage(image,.ProvenanceMediaRecordKind~SEGMENT,path~string,self~fileBytes(path))
  end
  return image
::method extractSequentialImage class
  use strict arg image, targetPrefix
  records=self~readSequentialImage(image); extracted=.directory~new; segs=.array~new
  do d over records
    kind=d["kind"]
    if kind=.ProvenanceMediaRecordKind~MANIFEST then do; path=targetPrefix||".manifest"; self~writeBytes(path,d["payload"]); extracted["manifest"]=path; end
    else if kind=.ProvenanceMediaRecordKind~ANCHOR then do; path=targetPrefix||".anchor"; self~writeBytes(path,d["payload"]); extracted["anchor"]=path; end
    else if kind=.ProvenanceMediaRecordKind~SEGMENT then do; path=targetPrefix||".segment."||(segs~items+1); self~writeBytes(path,d["payload"]); segs~append(path); end
    else raise syntax 88.900 array("UNKNOWN_PROVENANCE_MEDIA_RECORD",kind)
  end
  extracted["segments"]=segs; return extracted
