/* Same dev11 wobble evidence through Foreign Runtime -> matplotlib. */
parse arg out
if out='' then out='wobbly_fit_graph.png'
obs=.array~new
call addObs obs,'A0',0,1; call addObs obs,'A1',1,3; call addObs obs,'A2',2,5
call addObs obs,'B3',3,17; call addObs obs,'A4',4,9; call addObs obs,'A5',5,11
call addObs obs,'B6',6,14; call addObs obs,'A7',7,15; call addObs obs,'A8',8,17
call addObs obs,'B9',9,11; call addObs obs,'A10',10,21; call addObs obs,'A11',11,23
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.00001),4,10000)
a=search~analyze(obs); ws=a~restoringSets[1]
g=.MLWobbleGraphAdapter~graphForAnalysis('Wobbly value: published restoring-set evidence',obs,a)
removed=.array~new; do ix over ws~indexes~toArray; removed~append(obs[ix]); end
secondary=.MLLinearTrackFitScorer~new~assess(removed)
.MLWobbleGraphAdapter~addFitAssessment(g,secondary,removed,'reassigned Track B fit','SECONDARY')
r=.MLGraphMatplotlibRenderer~new
g~render(r,out)
say 'renderer='r~name 'version='r~version
say 'PNG='out
say 'PASS wobbly_fit_graph_matplotlib'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
::requires 'MLGraphWobbly.cls'
::requires 'MLGraphMatplotlib.cls'
