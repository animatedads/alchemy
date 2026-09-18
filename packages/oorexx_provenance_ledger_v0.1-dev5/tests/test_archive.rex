seed="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"; kp=.Ed25519~keypair(seed)
ledger=.ProvenanceLedger~new("archive-chain")
t1=ledger~newTransaction("e1","2026-09-18T01:00:00+01:00","OBJECT_CREATED","storage://one","","sha256:111","authority:test")
b1=ledger~candidate("2026-09-18T01:00:01+01:00",.array~of(t1),"authority:test"); b1~sign(seed,kp["public"]); ledger~commit(b1)
anchor=.ProvenanceTrustedAnchor~new(ledger~chainId,ledger~height,ledger~headHash,"state-root-1","storage://snapshot/one","authority:test")
anchor~sign(seed,kp["public"])
if \anchor~verify then exit 40
anchor~write("test.anchor"); loadedAnchor=.ProvenanceTrustedAnchor~read("test.anchor")
if \loadedAnchor~verify | loadedAnchor~hash \== anchor~hash then exit 41
t2=ledger~newTransaction("e2","2026-09-18T01:00:02+01:00","OBJECT_MUTATED","storage://one","sha256:111","sha256:222","authority:test")
b2=ledger~candidate("2026-09-18T01:00:03+01:00",.array~of(t2),"authority:test"); b2~sign(seed,kp["public"]); ledger~commit(b2)
.ProvenanceSegmentCodec~write("test.segment",ledger,2,2)
partial=.ProvenanceSegmentCodec~read("test.segment",.true,loadedAnchor)
if partial~height<>2 | partial~headHash \== ledger~headHash | \\partial~verify then exit 42
content=charin("test.segment",1,chars("test.segment")); call stream "test.segment","c","close"
segDigest=.CryptoHash~hashString(content,"SHA256")
manifest=.ProvenanceArchiveManifest~new(ledger~chainId,anchor~hash); manifest~addSegment("test.segment",2,2,segDigest); manifest~write("test.manifest")
loaded=.ProvenanceArchiveManifest~read("test.manifest")
if loaded~digest \== manifest~digest | loaded~entries~items<>1 then exit 43
call sysfiledelete "test.anchor"; call sysfiledelete "test.segment"; call sysfiledelete "test.manifest"
say "PASS trusted anchor, anchored partial segment, archive manifest"
exit 0
::requires 'ProvenanceLedger.cls'
