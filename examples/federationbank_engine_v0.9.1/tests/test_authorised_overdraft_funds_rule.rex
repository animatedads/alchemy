/* Ordinary customer debits may consume an authorised overdraft, but may not
 * cross its floor.  This remains distinct from SETTLEMENT_MUST_POST. */
profiles=.FederationBankRegulatoryProfileRegistry~standard; p=profiles~byCurrency("GBP")
ledger=.FederationBankLedger~new
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",p~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("OD-SRC","CUST-OD","GBP","OFFSHORE_CURRENT","IOM",p~profileId,.false,.false,10000)),"overdraft source"
call must ledger~addAccount(.FederationBankAccount~new("OD-DST","CUST-OD","GBP","OFFSHORE_CURRENT","IOM",p~profileId)),"destination"
call must ledger~postTransfer("OD-SEED","FB-SETTLEMENT-GBP","OD-SRC",4000,"GBP"),"seed"
call assert ledger~availableBalanceMinor("OD-SRC")=14000,"available includes authorised overdraft"
call must ledger~postTransfer("OD-USE","OD-SRC","OD-DST",14000,"GBP"),"ordinary debit may use full authorised overdraft"
call assert ledger~balanceMinor("OD-SRC")=-10000,"book reaches exact authorised floor"
call assert ledger~fundsState("OD-SRC")["fundsState"]="AUTHORISED_OVERDRAFT","floor is authorised overdraft, not excess"
blocked=ledger~postTransfer("OD-BEYOND","OD-SRC","OD-DST",1,"GBP")
call assert blocked~ok=.false,"ordinary debit cannot cross authorised floor"
call assert blocked~code="INSUFFICIENT_AVAILABLE_FUNDS","funds gate distinguishes ordinary debit from mandatory settlement"
call assert ledger~balanceMinor("OD-SRC")=-10000,"rejected beyond-floor debit leaves truth unchanged"
say "PASS ordinary funds rule uses authorised overdraft but cannot cross its floor"
exit 0
must: procedure
 use arg r,label
 if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
 return
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "FederationBankEngine.cls"
