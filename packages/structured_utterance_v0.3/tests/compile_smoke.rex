ctx = .BrandExperienceContext~serviceAsSales
u = .StructuredUtterance~new('smoke','AGENT','CHAT','',ctx)
s = .StructuredUtteranceSegment~new('s1','Hello.','GENERAL')
call assertTrue s~seal~ok, 'segment seals'
call assertTrue u~addSegment(s), 'segment added'
call assertTrue u~seal~ok, 'utterance seals'
call assertEqual 'structured.utterance/0.3', .StructuredUtteranceBuild~API_VERSION, 'api version'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
