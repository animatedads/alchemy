ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('sealed-context-1','AGENT','CHAT','',ctx)
s=.StructuredUtteranceSegment~new('s1','hello','INFORMATION')
call assertTrue s~seal~ok,'segment seals';u~addSegment(s)
call assertTrue u~seal~ok,'utterance seals'
call assertTrue ctx~sealed,'owned brand context seals with utterance'
before=u~canonicalText
call assertTrue \ctx~addDomain('SECURITY'),'sealed context rejects domain mutation'
call assertTrue \ctx~addFunction('REPUTATIONAL_WORK'),'sealed context rejects function mutation'
call assertTrue \ctx~addOpportunity('RECOVERY'),'sealed context rejects opportunity mutation'
after=u~canonicalText
call assertEqual before,after,'sealed utterance canonical evidence is stable'
say 'PASS test_sealed_context_immutability'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtterance.cls'
