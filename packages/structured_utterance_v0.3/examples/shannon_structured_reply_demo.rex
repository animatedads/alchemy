ctx = .BrandExperienceContext~serviceAsSales
ctx~addDomain('SECURITY')
ctx~addOpportunity('REPUTATIONAL_RISK')
ctx~addOpportunity('COMMERCIAL_OPPORTUNITY')
u = .StructuredUtterance~new('demo-shannon','AGENT','CHAT','customer-prompt-1',ctx)
u~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION')

s1 = .StructuredUtteranceSegment~new('warn','I cannot advise you on how to do anything illegal.','WARNLAW')
s1~seal; u~addSegment(s1)
s2 = .StructuredUtteranceSegment~new('sale-a','Would ','SALESPROP','NONE','DERIVED_NONCUSTOMER','','RETAIN',d2c(10))
s2~seal; u~addSegment(s2)
s3 = .StructuredUtteranceSegment~new('sale-name','Barbie','SALESPROP','CUSTNAME','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY')
s3~addLineage(.UtteranceLineageEdge~new('name-source','COPIED_FROM_CUSTOMER','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC'))
s3~seal; u~addSegment(s3)
s4 = .StructuredUtteranceSegment~new('sale-b',' like an extra bag?','SALESPROP')
s4~seal; u~addSegment(s4)
u~seal

say 'DELIVERY:'
say .StructuredUtteranceRenderer~renderDelivery(u)~value
say
say 'TAGGED FULL:'
say .StructuredUtteranceRenderer~renderTagged(u,.UtteranceProjectionPolicy~full)~value
say
say 'TAGGED DEIDENTIFIED:'
say .StructuredUtteranceRenderer~renderTagged(u)~value
say
say 'EXPLICIT SALESPROP:' u~hasExplicitSalesProposition
say 'PROMOTIONAL WORK:' ctx~isPromotionalWork
::requires 'StructuredUtterance.cls'
