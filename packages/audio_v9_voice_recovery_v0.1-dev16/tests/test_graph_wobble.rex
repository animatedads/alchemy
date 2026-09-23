numeric digits 30
assertions=0
obs=.array~new
do i=1 to 3; d=.directory~new; d['id']='A'||i; d['lag_ms']=80; obs~append(d); end
do i=1 to 3; d=.directory~new; d['id']='B'||i; d['lag_ms']=140; obs~append(d); end
a=.AudioV9DelayTrackAnalyzer~new(.01,3,1000)~analyze(obs)
call ok a~distanceToFit=3,'distance-to-fit three'
call ok a~normalizedDistance=.5,'normalized distance half'
call ok a~restoringSets~items=2,'two minimal restoring explanations'
call ok a~participation~items=6,'all observations represented in participation'
do p over a~participation~toArray; call ok p~fraction=.5,'each observation participates in half the explanations'; end
say 'PASS test_graph_wobble assertions='||assertions||' distance='||a~distanceToFit||' sets='||a~restoringSets~items
exit 0
ok: procedure expose assertions
  parse arg cond,msg; assertions=assertions+1; if \cond then do; say 'FAIL '||msg; exit 1; end; return
::requires 'AudioV9EvidenceGraph.cls'
