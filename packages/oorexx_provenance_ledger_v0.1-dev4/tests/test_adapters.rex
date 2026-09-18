ledger=.ProvenanceLedger~new("adapter-chain")
seed="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
kp=.Ed25519~keypair(seed)
before=.FakeStorageRef~new("storage://object/17","sha256:aaaa")
after=.FakeStorageRef~new("storage://object/17","sha256:bbbb")
tx=.ProvenanceStorageAdapter~transition(ledger,"storage-1","2026-09-18T00:05:00+01:00","SNAPSHOT_COMMITTED",before,after,"authority:storage","evidence:snapshot","policy:storage")
if tx~beforeHash \== "sha256:aaaa" | tx~afterHash \== "sha256:bbbb" then exit 20
if \.ProvenanceStorageAdapter~verifyCurrent(tx,after) then exit 21
a=.array~of(tx)
b=ledger~candidate("2026-09-18T00:05:01+01:00",a,"authority:storage","policy:storage")
b~sign(seed,kp["public"]); ledger~commit(b)
h=.array~of(tx~hash); receipt=.ProvenanceCommitReceipt~new(ledger~chainId,b~height,b~hash,b~merkleRoot,h)
if \receipt~verifies(b) then exit 22
acct=.ProvenanceAccountingAdapter~event(ledger,"acct-1","2026-09-18T00:05:02+01:00","accounting://book/ACME/filing/2026","sha256:old","sha256:new","authority:accounts","evidence:filing","policy:accounts")
if acct~operation \== "ACCOUNTING_EVIDENCE_COMMITTED" then exit 23
say "PASS provenance adapters and receipt"
exit 0
::class FakeStorageRef
::attribute objectId get
::attribute digest get
::method init
 expose objectId digest
 use strict arg objectId,digest
::requires 'ProvenanceLedger.cls'