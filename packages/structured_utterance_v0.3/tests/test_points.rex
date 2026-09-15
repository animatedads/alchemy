ctx = .BrandExperienceContext~deliveryAsSales
u = .StructuredUtterance~new('points-1','AGENT','CHAT','',ctx)
s1 = .StructuredUtteranceSegment~new('s1','We can deliver it tomorrow.','SERVICE_RESOLUTION')
s1~addRole('DELIVERY_COMMITMENT')
call assertTrue s1~seal~ok, 'segment seals'
u~addSegment(s1)
call assertTrue u~seal~ok, 'utterance seals'
lib = .StructuredUtteranceLibrary~new
call assertTrue lib~capture(u)~ok, 'captured'
pts = lib~pointsFor('points-1')
call assertTrue pts~items >= 7, 'rich points exposed'
call assertEqual 1, lib~pointsMatching('points-1','PURPOSE','SERVICE_RESOLUTION')~items, 'purpose point'
call assertEqual 1, lib~pointsMatching('points-1','ROLE','DELIVERY_COMMITMENT')~items, 'role point'
call assertEqual 1, lib~pointsMatching('points-1','BRAND_DOMAIN','DELIVERY')~items, 'delivery domain point'
call assertEqual 1, lib~pointsMatching('points-1','BRAND_FUNCTION','REPUTATIONAL_WORK')~items, 'reputation point'
say 'PASS test_points'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
