::class AJIAccountingTestSupport public
::method jpyPlan class
  tier=.AllJapanInsuranceTieredRiskPrice~new("REBUILD_VALUE",100000,1000000000,.AllJapanInsuranceRationalRate~new(0,1,"0"),.AllJapanInsuranceRationalRate~new(0,1,"0"))
  uw=.AllJapanInsuranceUnderwritingPrice~new("REBUILD_VALUE",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1,"0"))
  sales=.AllJapanInsuranceSalesCostRule~new("ADDITIVE",0,.AllJapanInsuranceRationalRate~new(1,10,"10%"))
  taxes=.array~of(.AllJapanInsuranceTaxRule~new("JP_TEST_TAX","PRE_TAX_PREMIUM",.AllJapanInsuranceRationalRate~new(1,20,"5%")))
  return .AllJapanInsuranceRatingPlan~new("AJI-RATE-HOME-JP-2026A","HOME","JP","JPY","2026-01-01","",tier,uw,sales,taxes)
::method ratedHomeContext class
  book=.AJITestSupport~contractBook(.array~of(.AJITestSupport~contractVersion("AJI-CONTRACT-HOME-JP/ACC1","HOME","JP","2026-01-01","",.nil,"AJI-RATE-HOME-JP-2026A",.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE)))
  a=.AllJapanInsuranceAuthority~new(.nil,book)
  channel=.AJITestSupport~actor("DIRECT-JP",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
  uw=.AJITestSupport~actor("UW-JP",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
  ratingActor=.AJITestSupport~actor("RATING-JP",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  pa=.AJITestSupport~actor("POLICY-JP",.AllJapanInsuranceBuild~ROLE_POLICY)
  s=.AllJapanInsuranceRiskSubmission~new("S-HOME-JPY-1","HOME","CUSTOMER-JP-1","HOME-JP-1","JP","2026-08-28")
  ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit JPY risk")
  d=.AllJapanInsuranceUnderwritingDecision~new("D-HOME-JPY-1",s~submissionId,"HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW-JP","2026-08-28T12:00:00","EVID-UW-JPY")
  ignored=.AJITestSupport~must(a~recordDecision(uw,d),"accept JPY risk")
  plan=self~jpyPlan
  req=.AllJapanInsuranceRatingRequest~new(s~submissionId,"HOME","JP","JPY","2026-08-28","REBUILD_VALUE",25000000,"REBUILD_VALUE",25000000)
  rr=.AllJapanInsuranceRatingEngine~new~rate("R-HOME-JPY-1",req,plan,"2026-08-28T12:01:00")
  ignored=.AJITestSupport~must(rr,"rate JPY risk")
  rating=rr~value
  ignored=.AJITestSupport~must(a~recordRating(ratingActor,rating),"record JPY rating")
  qr=a~issueRatedQuote(uw,"Q-HOME-JPY-1",d~decisionId,rating~ratingId,"2026-09-15T23:59:59","2026-08-28T12:02:00")
  ignored=.AJITestSupport~must(qr,"issue JPY quote")
  p=.AllJapanInsurancePolicy~new("P-HOME-JPY-1","Q-HOME-JPY-1","CUSTOMER-JP-1","HOME","HOME-JP-1","2026-09-01","2027-09-01","2026-08-28T12:03:00","AJI-HOME-0001",1,"NEW_BUSINESS")
  ignored=.AJITestSupport~must(a~bindPolicy(pa,p),"bind JPY policy")
  out=.directory~new
  out["authority"]=a
  out["rating"]=rating
  out["policy"]=p
  out["quote"]=qr~value
  out["plan"]=plan
  return out
::method accountingEngine class
  return .AllJapanInsuranceAccountingFactory~engine("2026-2027","2026-01-01","2027-12-31")

::requires "AllJapanInsuranceAccounting.cls"
::requires "TestSupport.cls"
