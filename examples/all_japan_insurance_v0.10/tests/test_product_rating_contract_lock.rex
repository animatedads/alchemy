registry=.AllJapanInsuranceStandardProductDefinitions~registry
rateBook=.AllJapanInsuranceRateBook~new
b=.AJIProductTestSupport~simplePlan("AJI-HOME-B/2026A","HOME","BUILDINGS","REBUILD_VALUE","REBUILD_VALUE")
c=.AJIProductTestSupport~simplePlan("AJI-HOME-C/2026A","HOME","CONTENTS","CONTENTS_VALUE","CONTENTS_VALUE")
.AJITestSupport~must(rateBook~addPlan(b),"add b")
.AJITestSupport~must(rateBook~addPlan(c),"add c")
refs=.table~new; refs["BUILDINGS"]=b~planRef; refs["CONTENTS"]=c~planRef
book=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
program=.AJIProductTestSupport~program("AJI.PROGRAM.HOME/2026A","AJI.PRODUCT.HOME/0.5","HOME",refs)
.AJITestSupport~must(book~addProgram(program),"program")
facts=.table~new; facts["CONSTRUCTION_CLASS"]="STANDARD"; facts["POSTCODE_ZONE"]="Z1"; facts["OCCUPANCY_CLASS"]="OWNER"; facts["SECURITY_CLASS"]="A"; facts["REBUILD_VALUE"]=10000000; facts["CONTENTS_VALUE"]=2000000
risk=.AllJapanInsuranceRiskObject~new("PROPERTY-1","HOME","PROPERTY",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("BUILDINGS")))
rr=book~rate("PORT-HOME-LOCK","SUB-HOME-LOCK","HOME","GB","GBP","2026-05-01",.array~of(risk),"2026-05-01T12:00:00")
.AJITestSupport~must(rr,"aggregate rating")
contract=.AJITestSupport~contractVersion("AJI-CONTRACT-HOME-GB/2026A","HOME","GB","2026-01-01","",.nil,program~programRef,.AllJapanInsuranceProductRatingBuild~FUNCTION_COMPOSITE)
contractBook=.AJITestSupport~contractBook(.array~of(contract))
authority=.AllJapanInsuranceAuthority~new(.nil,contractBook)
dist=.AJITestSupport~actor("DIST",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY",.AllJapanInsuranceBuild~ROLE_POLICY)
submission=.AllJapanInsuranceRiskSubmission~new("SUB-HOME-LOCK","HOME","PARTY-1","HOME-PORTFOLIO","GB","2026-05-01T10:00:00")
.AJITestSupport~must(authority~submitRisk(dist,submission),"submit")
decision=.AllJapanInsuranceUnderwritingDecision~new("DEC-HOME-LOCK","SUB-HOME-LOCK","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW","2026-05-01T11:00:00")
.AJITestSupport~must(authority~recordDecision(uw,decision),"decision")
.AJITestSupport~must(authority~recordRating(rater,rr~value),"record product rating")
qr=authority~issueRatedQuote(uw,"Q-HOME-LOCK","DEC-HOME-LOCK","PORT-HOME-LOCK","2026-05-10T00:00:00","2026-05-01T12:30:00")
.AJITestSupport~must(qr,"issue aggregate quote")
policy=.AllJapanInsurancePolicy~new("P-HOME-LOCK","Q-HOME-LOCK","PARTY-1","HOME","HOME-PORTFOLIO","2026-05-02","2027-05-02","2026-05-01T13:00:00")
.AJITestSupport~must(authority~bindPolicy(policyActor,policy),"bind product-rated policy")
lock=authority~policyContractLock("P-HOME-LOCK")
.AJITestSupport~assert(lock~ratingPlanRef=program~programRef,"contract locks product program")
.AJITestSupport~assert(lock~ratingFunctionRef=.AllJapanInsuranceProductRatingBuild~FUNCTION_COMPOSITE,"contract locks composite function")
say "PASS aggregate product rating flows through quote and immutable policy contract lock"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
