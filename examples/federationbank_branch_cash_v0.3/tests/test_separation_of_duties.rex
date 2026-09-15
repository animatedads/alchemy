call load
signal on syntax name expected
c=.FederationBankBranchCashControl~new("IOM-DOUGLAS","VAULT-1","STAFF-A","STAFF-A","BAD")
say "FAIL: same staff accepted for dual control"; exit 1
expected:
say "PASS: vault control enforces separation of duties"; exit 0
load: return
::requires "TestSupport.cls"
