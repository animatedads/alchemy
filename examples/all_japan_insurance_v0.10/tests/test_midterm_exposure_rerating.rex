registry=.AllJapanInsuranceStandardProductDefinitions~registry
rateBook=.AllJapanInsuranceRateBook~new
b=.AJIProductTestSupport~simplePlan("AJI-HOME-B-MID/2026A","HOME","BUILDINGS","REBUILD_VALUE","REBUILD_VALUE")
c=.AJIProductTestSupport~simplePlan("AJI-HOME-C-MID/2026A","HOME","CONTENTS","CONTENTS_VALUE","CONTENTS_VALUE")
.AJITestSupport~must(rateBook~addPlan(b),"add buildings")
.AJITestSupport~must(rateBook~addPlan(c),"add contents")
refs=.table~new; refs["BUILDINGS"]=b~planRef; refs["CONTENTS"]=c~planRef
productBook=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
program=.AJIProductTestSupport~program("AJI.PROGRAM.HOME.MID/2026A","AJI.PRODUCT.HOME/0.5","HOME",refs)
.AJITestSupport~must(productBook~addProgram(program),"program")

facts=.table~new; facts["CONSTRUCTION_CLASS"]="STANDARD"; facts["POSTCODE_ZONE"]="Z1"; facts["OCCUPANCY_CLASS"]="OWNER"; facts["SECURITY_CLASS"]="A"; facts["REBUILD_VALUE"]=10000000; facts["CONTENTS_VALUE"]=2000000
risk=.AllJapanInsuranceRiskObject~new("PROPERTY-MID","HOME","PROPERTY",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("BUILDINGS")))
initial=productBook~rate("R-MID-BOUND","S-MID","HOME","GB","GBP","2026-05-01",.array~of(risk),"2026-05-01T12:00:00")
.AJITestSupport~must(initial,"initial product rating")
.AJITestSupport~assert(initial~value~totalPremiumMinor=11000,"initial annual premium")

contract=.AJITestSupport~contractVersion("AJI-CONTRACT-HOME-MID/2026A","HOME","GB","2026-01-01","",.nil,program~programRef,.AllJapanInsuranceProductRatingBuild~FUNCTION_COMPOSITE)
a=.AllJapanInsuranceAuthority~new(.nil,.AJITestSupport~contractBook(.array~of(contract)))
dist=.AJITestSupport~actor("DIST-MID",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW-MID",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER-MID",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
pa=.AJITestSupport~actor("POLICY-MID",.AllJapanInsuranceBuild~ROLE_POLICY)
txnActor=.AJITestSupport~actor("POLICY-TXN-MID",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
submission=.AllJapanInsuranceRiskSubmission~new("S-MID","HOME","PARTY-MID","HOME-MID","GB","2026-05-01T10:00:00")
.AJITestSupport~must(a~submitRisk(dist,submission),"submit")
decision=.AllJapanInsuranceUnderwritingDecision~new("D-MID","S-MID","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW-MID","2026-05-01T11:00:00","UW-EVID")
.AJITestSupport~must(a~recordDecision(uw,decision),"decision")
.AJITestSupport~must(a~recordRating(rater,initial~value),"record initial rating")
quote=.AJITestSupport~must(a~issueRatedQuote(uw,"Q-MID","D-MID","R-MID-BOUND","2026-05-10","2026-05-01T12:30:00"),"quote")~value
policy=.AllJapanInsurancePolicy~new("P-MID","Q-MID","PARTY-MID","HOME","HOME-MID","2026-05-02","2027-05-02","2026-05-01T13:00:00")
.AJITestSupport~must(a~bindPolicy(pa,policy),"bind")

tx=.AllJapanInsuranceTransactionAuthority~new(a,productBook)
snapshot=.AllJapanInsuranceExposureSnapshot~new("EXP-MID-BOUND",policy~policyId,policy~inceptionDate,program~programRef,quote~ratingFunctionRef,.array~of(risk),quote~premiumMinor,quote~currency,"2026-05-01T13:01:00","BOUND-RISK-SNAPSHOT")
.AJITestSupport~must(tx~registerBoundExposureSnapshot(rater,snapshot),"verify bound exposure snapshot")

newFacts=.table~new; do key over facts~allIndexes; newFacts[key]=facts[key]; end
newFacts["REBUILD_VALUE"]=20000000
newRisk=.AllJapanInsuranceRiskObject~new("PROPERTY-MID","HOME","PROPERTY",newFacts,.array~of(.AllJapanInsuranceCoverageSelection~new("BUILDINGS")))
change=.AllJapanInsuranceExposureChange~new("CHG-MID-1",policy~policyId,snapshot~snapshotId,"2026-11-02",.array~of(newRisk),1,2,"2026-10-25T10:00:00","CUSTOMER-INCREASED-REBUILD")
.AJITestSupport~must(tx~recordExposureChange(txnActor,change),"record exposure change")
calc=.AJITestSupport~must(tx~calculateExposureChange(rater,"CALC-MID-1",change~changeId,"2026-10-25T10:05:00"),"rerate change")~value
.AJITestSupport~assert(calc~riskDeltaMinor=5000 & calc~salesDeltaMinor=0 & calc~taxDeltaMinor=0 & calc~totalDeltaMinor=5000,"half-term delta is difference of pinned before/after ratings")
.AJITestSupport~assert(calc~ratingFunctionRef=quote~ratingFunctionRef,"mid-term re-rating retains bound composite function")
ev=tx~reratingEvidence(calc~calculationId)
.AJITestSupport~assert(ev\==.nil & ev["beforeRating"]~planRef=program~programRef & ev["afterRating"]~planRef=program~programRef,"before and after use exact bound product program")

adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-MID-1",policy~policyId,"ENDORSEMENT",change~effectiveDate,calc~calculationId,calc~riskDeltaMinor,calc~salesDeltaMinor,calc~taxDeltaMinor,calc~totalDeltaMinor,calc~currency,"PREMIUM_CONTROL","SUM_INSURED_CHANGE",txnActor~principalId,"2026-10-25T10:10:00","ENDORSEMENT-EVID")
.AJITestSupport~must(tx~recordPremiumAdjustment(txnActor,adj),"authorise rerated endorsement")
current=tx~currentExposureSnapshot(policy~policyId)
.AJITestSupport~assert(current~snapshotId="EXPOSURE:ADJ-MID-1" & current~totalPremiumMinor=16000,"accepted endorsement advances exposure state and cumulative written premium")

stale=.AllJapanInsuranceExposureChange~new("CHG-MID-STALE",policy~policyId,snapshot~snapshotId,"2026-12-01",.array~of(newRisk),1,3,"2026-11-20T10:00:00","STALE")
staleResult=tx~recordExposureChange(txnActor,stale)
.AJITestSupport~assert(\staleResult~ok & staleResult~code="EXPOSURE_CHANGE_STALE_SNAPSHOT","later change cannot branch from stale exposure state")

say "PASS mid-term exposure changes are re-rated as pinned before/after product states with transaction proration"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
::requires "AllJapanInsuranceTransactions.cls"
