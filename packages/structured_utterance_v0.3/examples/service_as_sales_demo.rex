ctx = .BrandExperienceContext~serviceAsSales
ctx~addOpportunity('RECOVERY')
u = .StructuredUtterance~new('demo-service','AGENT','CHAT','lost-bag-1',ctx)
s1 = .StructuredUtteranceSegment~new('a',"I'm sorry your bag has not arrived.",'APOLOGY')
s1~seal; u~addSegment(s1)
s2 = .StructuredUtteranceSegment~new('b','I have located it and the delivery team expects it by 18:00.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER','','RETAIN',' ')
s2~seal; u~addSegment(s2)
u~seal
say .StructuredUtteranceRenderer~renderDelivery(u)~value
say 'PROMOTIONAL_WORK='ctx~isPromotionalWork
say 'REPUTATIONAL_WORK='ctx~isReputationalWork
say 'COMMERCIAL_RELATIONSHIP_WORK='ctx~isCommercialRelationshipWork
say 'EXPLICIT_SALESPROP='u~hasExplicitSalesProposition
::requires 'StructuredUtterance.cls'
