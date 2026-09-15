/* v1: 10,000 deductible, then 100%.  v2: 20,000 deductible, 80%, capped at 50,000. */
rule1=.AJITestSupport~payoutRule("AJI-HOME-PAYOUT/1",10000,1,1,.false,0)
rule2=.AJITestSupport~payoutRule("AJI-HOME-PAYOUT/2",20000,4,5,.true,50000)
v1=.AJITestSupport~contractVersion("AJI-HOME-JP/1","HOME","JP","2026-01-01","2026-07-01",rule1)
v2=.AJITestSupport~contractVersion("AJI-HOME-JP/2","HOME","JP","2026-07-01","",rule2)
book=.AJITestSupport~contractBook(.array~of(v1,v2))
a=.AllJapanInsuranceAuthority~new(.nil,book)
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actorRoles("UW",.array~of(.AllJapanInsuranceBuild~ROLE_UNDERWRITER,.AllJapanInsuranceBuild~ROLE_RATE_OVERRIDE))
pa=.AJITestSupport~actor("PA",.AllJapanInsuranceBuild~ROLE_POLICY)
ci=.AJITestSupport~actor("CI",.AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)
ca=.AJITestSupport~actor("CA",.AllJapanInsuranceBuild~ROLE_CLAIMS_ASSESSOR)

/* Old term binds while v1 is the applicable contract. */
s1=.AllJapanInsuranceRiskSubmission~new("S-OLD","HOME","REL-1","HOUSE-1","JP","2026-02-01")
ignored=.AJITestSupport~must(a~submitRisk(channel,s1),"submit old")
d1=.AllJapanInsuranceUnderwritingDecision~new("D-OLD","S-OLD","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW","2026-02-01T10:00:00","E1")
ignored=.AJITestSupport~must(a~recordDecision(uw,d1),"decision old")
q1=.AllJapanInsuranceQuote~new("Q-OLD","D-OLD","S-OLD","HOME",100000,"JPY","2026-02-20T23:59:59","2026-02-01T10:01:00","","","MANUAL_OVERRIDE","fixture old")
ignored=.AJITestSupport~must(a~issueQuote(uw,q1),"quote old")
p1=.AllJapanInsurancePolicy~new("P-OLD-T1","Q-OLD","REL-1","HOME","HOUSE-1","2026-02-10","2027-02-10","2026-02-02T10:00:00","AJI-HOME-0001",1,"NEW_BUSINESS","")
ignored=.AJITestSupport~must(a~bindPolicy(pa,p1),"bind old")
lock1=a~policyContractLock("P-OLD-T1")
ignored=.AJITestSupport~assert(lock1~contractVersionRef="AJI-HOME-JP/1","old term locks v1")

/* Loss happens after v2 has become the new-business ruleset.  Old term still executes v1. */
c1=.AllJapanInsuranceClaim~new("C-OLD","P-OLD-T1","REL-1","2026-08-01","2026-08-02T09:00:00","LOSS-OLD")
ignored=.AJITestSupport~must(a~openClaim(ci,c1),"open old claim")
a1=.AJITestSupport~must(a~assessClaim(ca,"A-OLD","C-OLD",100000,"2026-08-03T10:00:00","ADJ-1"),"assess old")~value
ignored=.AJITestSupport~assert(a1~contractVersionRef="AJI-HOME-JP/1","claim uses policy lock, not current date")
ignored=.AJITestSupport~assert(a1~payoutRuleRef="AJI-HOME-PAYOUT/1","old payout rule retained")
ignored=.AJITestSupport~assert(a1~payableMinor=90000,"old payout arithmetic retained")

/* A contract signed after the change binds v2 and therefore gets the new payout rule. */
s2=.AllJapanInsuranceRiskSubmission~new("S-NEW","HOME","REL-2","HOUSE-2","JP","2026-08-05")
ignored=.AJITestSupport~must(a~submitRisk(channel,s2),"submit new")
d2=.AllJapanInsuranceUnderwritingDecision~new("D-NEW","S-NEW","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW","2026-08-05T10:00:00","E2")
ignored=.AJITestSupport~must(a~recordDecision(uw,d2),"decision new")
q2=.AllJapanInsuranceQuote~new("Q-NEW","D-NEW","S-NEW","HOME",100000,"JPY","2026-08-20T23:59:59","2026-08-05T10:01:00","","","MANUAL_OVERRIDE","fixture new")
ignored=.AJITestSupport~must(a~issueQuote(uw,q2),"quote new")
p2=.AllJapanInsurancePolicy~new("P-NEW-T1","Q-NEW","REL-2","HOME","HOUSE-2","2026-08-10","2027-08-10","2026-08-06T10:00:00","AJI-HOME-0002",1,"NEW_BUSINESS","")
ignored=.AJITestSupport~must(a~bindPolicy(pa,p2),"bind new")
lock2=a~policyContractLock("P-NEW-T1")
ignored=.AJITestSupport~assert(lock2~contractVersionRef="AJI-HOME-JP/2","new term locks v2")
c2=.AllJapanInsuranceClaim~new("C-NEW","P-NEW-T1","REL-2","2026-09-01","2026-09-02T09:00:00","LOSS-NEW")
ignored=.AJITestSupport~must(a~openClaim(ci,c2),"open new claim")
a2=.AJITestSupport~must(a~assessClaim(ca,"A-NEW","C-NEW",100000,"2026-09-03T10:00:00","ADJ-2"),"assess new")~value
ignored=.AJITestSupport~assert(a2~payoutRuleRef="AJI-HOME-PAYOUT/2","new payout rule used")
ignored=.AJITestSupport~assert(a2~payableMinor=50000,"new deductible/percentage/cap applied")

/* Renewal is a new term and may adopt the then-effective release. */
s3=.AllJapanInsuranceRiskSubmission~new("S-RENEW","HOME","REL-1","HOUSE-1","JP","2027-01-20")
ignored=.AJITestSupport~must(a~submitRisk(channel,s3),"submit renewal")
d3=.AllJapanInsuranceUnderwritingDecision~new("D-RENEW","S-RENEW","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW","2027-01-20T10:00:00","E3")
ignored=.AJITestSupport~must(a~recordDecision(uw,d3),"decision renewal")
q3=.AllJapanInsuranceQuote~new("Q-RENEW","D-RENEW","S-RENEW","HOME",110000,"JPY","2027-02-15T23:59:59","2027-01-20T10:01:00","","","MANUAL_OVERRIDE","fixture renewal")
ignored=.AJITestSupport~must(a~issueQuote(uw,q3),"quote renewal")
p3=.AllJapanInsurancePolicy~new("P-OLD-T2","Q-RENEW","REL-1","HOME","HOUSE-1","2027-02-10","2028-02-10","2027-01-21T10:00:00","AJI-HOME-0001",2,"RENEWAL","P-OLD-T1")
ignored=.AJITestSupport~must(a~renewPolicy(pa,p3),"renew")
lock3=a~policyContractLock("P-OLD-T2")
ignored=.AJITestSupport~assert(lock3~contractVersionRef="AJI-HOME-JP/2","renewal term selects current release")
ignored=.AJITestSupport~assert(lock1~contractVersionRef="AJI-HOME-JP/1","renewal does not rewrite prior term lock")
say "PASS bound term keeps old rules; new business and renewal adopt new rules"
::requires "TestSupport.cls"
