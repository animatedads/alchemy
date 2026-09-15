seed = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
pub  = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
priv=.directory~new; priv["BUILD|K1"]=seed
pubs=.directory~new; pubs["BUILD|K1"]=pub
proof=.WorkBundleEd25519ProofAuthority~new(priv,pubs)
canonical="work-bundle-production-proof"
sig=proof~sign("BUILD","K1",canonical)
call assertTrue sig~length=128,"Ed25519 signature length"
call assertTrue proof~verify("BUILD","K1",canonical,sig),"Ed25519 verify"
call assertTrue \proof~verify("BUILD","K1",canonical||"-tampered",sig),"canonical tamper rejected"
call assertTrue proof~sign("BUILD","MISSING",canonical)="","missing private key fails closed"
call assertTrue \proof~verify("BUILD","MISSING",canonical,sig),"missing public key fails closed"
say "PASS Work Bundle Ed25519 producer proof adapter"
exit 0
assertTrue: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "../src/WorkBundle.cls"
