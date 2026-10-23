# Negative test vector: fabricate a receipt with NO MI, NO XTP, NO key, and see if the central gate accepts it.
import sys, json, hashlib
sys.path.insert(0, sys.argv[1])
import run_20mi
run, mi, mu, n, ep = "ED209-FORGE", "MN1-ED209F", "MU-ED209F", 1000, 1
v = n*(n+1)//2
r = {"schema":"ed209.rto2.controller-receipt/1","run_id":run,"mi_id":mi,"mu_id":mu,
     "controller_id":"GRID.MU."+mu,"delivery":"authenticated-xtp-qf-wire-response",
     "response_correlation":"RTO2-made-up",
     "rto2":{"schema":"rexxos.rto2.smoke.result/1","run_id":run,"node_id":mi,"n":n,"value":v,
             "committed_value":v,"committed_sequence":1,"epoch":ep,"role":"ACTIVE",
             "rto2_api":"alchemy.rto/0.1","rto2_lifecycle":"CAPTURED",
             "rto2_identity":f"ED209.SMOKE.{run}:{mi}","rto2_state":{"value":v,"committedValue":v}}}
canon = json.dumps(r, sort_keys=True, separators=(',',':')).encode()
r.update(controller_commit="DURABLE_LOCAL_RECEIPT", receipt_sha256=hashlib.sha256(canon).hexdigest(), committed_at_utc="2026-10-23T00:00:00+00:00")
row = run_20mi.check_receipt(r, 17, "ed209f", mu, mi, run, n, ep)
print("FORGED RECEIPT ACCEPTED BY CENTRAL GATE:", row["status"], row["value"])
