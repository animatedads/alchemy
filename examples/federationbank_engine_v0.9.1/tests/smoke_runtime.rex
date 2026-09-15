e=.FederationBankFixtures~engine
say "engine ok"
p=e~profiles~byCurrency("USD")
say p~profileId p~legalProfileId
c=.FederationBankCommand~new("CMD-OPEN-1","OPEN_ACCOUNT","OPEN-1","CUST-001","","","USD",0,"WEB","cust","", "OFFSHORE_CURRENT", "USD-001")
r=e~handle(c)
say "open" r~ok r~code
if r~ok then say r~value["regulatoryProfileId"]
/* target */
c2=.FederationBankCommand~new("CMD-OPEN-2","OPEN_ACCOUNT","OPEN-2","CUST-001","","","USD",0,"WEB","cust","", "OFFSHORE_CURRENT", "USD-002")
r2=e~handle(c2)
say "open2" r2~ok r2~code
seed=e~ledger~postTransfer("SEED-1","FB-SETTLEMENT-USD","USD-001",1000000,"USD")
say "seed" seed~ok seed~code e~ledger~balanceMinor("USD-001")
t=.FederationBankCommand~new("CMD-TX-1","TRANSFER","TX-1","CUST-001","USD-001","USD-002","USD",250000,"WEB","cust")
z=e~handle(t)
say "tx" z~ok z~code z~detail
if z~ok then do
 say z~value["regulatoryProfileId"] z~value["corporatePolicyRuleId"] z~value["legalGenerationId"] z~value["securityDisposition"]
 say z~value["sourceBalanceMinor"] z~value["targetBalanceMinor"]
end
::requires "FederationBankFixtures.cls"
