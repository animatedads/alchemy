/* Requires crypto.cls and ProvenanceLedger.cls on RXREXX_PATH / current search path. */
ledger=.ProvenanceLedger~new("test-chain")
seed="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
kp=.Ed25519~keypair(seed)
tx=ledger~newTransaction("evt-1","2026-09-17T23:50:00+01:00","SNAPSHOT_COMMITTED","storage://demo/object","aaa","bbb","authority:test","storage://evidence/1","policy:test","meta")
a=.Array~new; a~append(tx)
b=ledger~candidate("2026-09-17T23:50:01+01:00",a,"authority:test","policy:test")
b~sign(seed,kp["public"])
ledger~commit(b)
if ledger~height \== 1 then exit 10
if \ledger~verify then exit 11
say "PASS provenance ledger signed chain"
exit 0
::requires 'ProvenanceLedger.cls'