ctx = .BrandExperienceContext~serviceAsSales
ctx~addDomain(.StructuredUtteranceConstant~DOMAIN_SECURITY)
ctx~addOpportunity(.StructuredUtteranceConstant~OPP_REPUTATIONAL_RISK)
ctx~addOpportunity(.StructuredUtteranceConstant~OPP_COMMERCIAL_OPPORTUNITY)
u = .StructuredUtterance~new('shannon-bag-1','AGENT','CHAT','customer-risk-1',ctx)
u~addSpeechAct('REFUSE_ILLEGAL_ASSISTANCE')
u~addSpeechAct('OFFER_BAGGAGE_PRODUCT')
u~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION')
u~addCorrelation('journey-42')

s1 = .StructuredUtteranceSegment~new('s1','I cannot advise you on how to do anything illegal.', 'WARNLAW', 'NONE', 'DERIVED_NONCUSTOMER')
s1~addRole('REFUSE_ILLEGAL_ASSISTANCE')
call assertTrue s1~seal~ok, 'law warning seals'
call assertTrue u~addSegment(s1), 'warning added'

s2 = .StructuredUtteranceSegment~new('s2','Would ', 'SALESPROP', 'NONE', 'DERIVED_NONCUSTOMER', '', 'RETAIN', d2c(10))
call assertTrue s2~seal~ok, 'sales prefix seals'
call assertTrue u~addSegment(s2), 'sales prefix added'

s3 = .StructuredUtteranceSegment~new('s3','Barbie', 'SALESPROP', 'CUSTNAME', 'CUSTOMER_SPECIFIC', '[CUSTOMER_RELATED_PERSON]', 'ABSTRACT_ONLY')
e3 = .UtteranceLineageEdge~new('e3','COPIED_FROM_CUSTOMER','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC')
call assertTrue s3~addLineage(e3), 'name lineage added'
call assertTrue s3~seal~ok, 'name segment seals'
call assertTrue u~addSegment(s3), 'name segment added'

s4 = .StructuredUtteranceSegment~new('s4',' like an extra bag?', 'SALESPROP', 'NONE', 'DERIVED_NONCUSTOMER')
call assertTrue s4~seal~ok, 'sales suffix seals'
call assertTrue u~addSegment(s4), 'sales suffix added'
call assertTrue u~seal~ok, 'utterance seals'

full = .StructuredUtteranceRenderer~renderDelivery(u)
call assertTrue full~ok, 'delivery renders'
call assertTrue full~value~pos('Barbie') > 0, 'customer delivery contains operational name'

taggedFull = .StructuredUtteranceRenderer~renderTagged(u, .UtteranceProjectionPolicy~full)
call assertTrue taggedFull~ok, 'full tagged renders'
call assertTrue taggedFull~value~pos('<<WARNLAW>>I cannot advise you on how to do anything illegal.<</WARNLAW>>') > 0, 'warnlaw preserved'
call assertTrue taggedFull~value~pos('<<SALESPROP>>Would <<CUSTNAME>>Barbie<</CUSTNAME>> like an extra bag?<</SALESPROP>>') > 0, 'sales prop and name are orthogonal tags'

taggedSafe = .StructuredUtteranceRenderer~renderTagged(u)
call assertTrue taggedSafe~ok, 'safe tagged renders'
call assertTrue taggedSafe~value~pos('Barbie') = 0, 'name removed from safe projection'
call assertTrue taggedSafe~value~pos('<<CUSTNAME>>[CUSTOMER_RELATED_PERSON]<</CUSTNAME>>') > 0, 'name semantic position retained'
call assertTrue u~hasExplicitSalesProposition, 'explicit sales proposition recognised'

say 'PASS test_shannon_baggage_markup'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtterance.cls'
