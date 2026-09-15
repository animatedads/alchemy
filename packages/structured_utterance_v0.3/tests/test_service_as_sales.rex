/* Service is promotional/reputational/commercial relationship work without
   requiring an upsell or an explicit sales proposition. */
ctx = .BrandExperienceContext~serviceAsSales
ctx~addOpportunity(.StructuredUtteranceConstant~OPP_RECOVERY)
u = .StructuredUtterance~new('service-1','AGENT','CHAT','lost-bag-1',ctx)
u~addContextTag('SERVICE_FAILURE_RECOVERY')

s1 = .StructuredUtteranceSegment~new('s1',"I'm sorry your bag has not arrived.",'APOLOGY')
s1~addRole('ACKNOWLEDGE_SERVICE_FAILURE')
call assertTrue s1~seal~ok, 'apology seals'
u~addSegment(s1)

s2 = .StructuredUtteranceSegment~new('s2','I have located it and the delivery team expects it by 18:00.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER','','RETAIN',' ')
s2~addRole('PROVIDE_DELIVERY_STATUS')
call assertTrue s2~seal~ok, 'resolution seals'
u~addSegment(s2)
call assertTrue u~seal~ok, 'service utterance seals'

call assertTrue ctx~isPromotionalWork, 'support is promotional work in brand context'
call assertTrue ctx~isReputationalWork, 'support is reputational work'
call assertTrue ctx~isCommercialRelationshipWork, 'support works on commercial relationship'
call assertFalse u~hasExplicitSalesProposition, 'service-as-sales does not imply upsell'

lib = .StructuredUtteranceLibrary~new
call assertTrue lib~capture(u)~ok, 'captured'
call assertTrue lib~pointsMatching('service-1','BRAND_FUNCTION','PROMOTIONAL_WORK')~items > 0, 'promotional action point exposed'
call assertTrue lib~pointsMatching('service-1','BRAND_OPPORTUNITY','RETENTION')~items > 0, 'retention opportunity point exposed'
call assertEqual 0, lib~pointsMatching('service-1','PURPOSE','SALESPROP')~items, 'no SALESPROP point invented'

say 'PASS test_service_as_sales'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
