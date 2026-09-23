/* Replace the dev11 hand-authored radar SVG with semantic MLGraph objects.
 * Fit/search/reassignment authority remains in ooRexx ML; Graph only renders
 * published evidence.
 */
parse arg out
if out='' then out='wobbly_fit_graph.svg'
obs=.array~new
call addObs obs,'A0',0,1,'A'; call addObs obs,'A1',1,3,'A'; call addObs obs,'A2',2,5,'A'
call addObs obs,'B3',3,17,'B'; call addObs obs,'A4',4,9,'A'; call addObs obs,'A5',5,11,'A'
call addObs obs,'B6',6,14,'B'; call addObs obs,'A7',7,15,'A'; call addObs obs,'A8',8,17,'A'
call addObs obs,'B9',9,11,'B'; call addObs obs,'A10',10,21,'A'; call addObs obs,'A11',11,23,'A'

criterion=.MLFitCriterion~new(0.00001,'LOWER_IS_BETTER')
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,criterion,4,10000)
norm=.MLWobbleNorm~new(.array~of(.00,.04,.05,.06,.08,.08,.10,.10,.12,.15))
a=search~analyze(obs,norm); ws=a~restoringSets[1]

g=.MLWobbleGraphAdapter~graphForAnalysis('Wobbly value: model-relative fit restoration',obs,a)
removed=.array~new
do ix over ws~indexes~toArray; removed~append(obs[ix]); end
secondary=.MLLinearTrackFitScorer~new~assess(removed)
.MLWobbleGraphAdapter~addFitAssessment(g,secondary,removed,'reassigned Track B fit','SECONDARY')

re=.array~new
do o over removed
  ev=.directory~new; ev['secondary_fit_rms']=secondary~value; ev['reason']='coherent alternate linear track'
  re~append(.MLWobbleReassignment~new(o['id'],'ALTERNATE_TRACK','TRACK-B',ev))
end
.MLWobbleGraphAdapter~addReassignments(g,re)
g~render(.MLGraphRenderers~byName('SVG'),out)
say 'distanceToFit='a~distanceToFit 'normalized='a~normalizedDistance 'sets='a~restoringSets~items
say 'restoringSet='ws~ids~canonicalText
say 'SVG='out
say 'PASS wobbly_fit_graph'
exit 0

addObs: procedure
  use strict arg a,id,x,y,truth
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; d['truth']=truth; a~append(d); return

::requires 'MLGraphWobbly.cls'
