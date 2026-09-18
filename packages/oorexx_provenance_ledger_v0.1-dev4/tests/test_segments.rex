ledger=.ProvenanceLedger~new("durable-chain")
seed="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"; kp=.Ed25519~keypair(seed)
t1=ledger~newTransaction("e1","2026-09-18T00:30:00+01:00","OBJECT_CREATED","storage://one","","sha256:111","authority:test")
b1=ledger~candidate("2026-09-18T00:30:01+01:00",.array~of(t1),"authority:test"); b1~sign(seed,kp["public"]); ledger~commit(b1)
states=.array~of(.ProvenanceStateRef~new("storage://one","sha256:111"),.ProvenanceStateRef~new("storage://two","sha256:222"))
cp=.ProvenanceCheckpoint~new(ledger,states,"storage://snapshot/checkpoint-1")
if cp~height<>1 | cp~stateCount<>2 | cp~stateRoot=="" then exit 30
ctx=cp~event(ledger,"checkpoint-1","2026-09-18T00:30:02+01:00","authority:test")
b2=ledger~candidate("2026-09-18T00:30:03+01:00",.array~of(ctx),"authority:test"); b2~sign(seed,kp["public"]); ledger~commit(b2)
path="provenance-test.segment"; .ProvenanceSegmentCodec~write(path,ledger)
restored=.ProvenanceSegmentCodec~read(path)
if restored~height<>ledger~height | restored~headHash \== ledger~headHash then exit 31
call sysfiledelete path
say "PASS durable segment roundtrip and checkpoint state root"
exit 0
::requires 'ProvenanceLedger.cls'