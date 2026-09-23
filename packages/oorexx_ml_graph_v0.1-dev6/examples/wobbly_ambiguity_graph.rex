/* Two equally minimal restoring sets: Graph displays one selected explanation
 * and a separate participation view showing how often each observation occurs
 * across all minimal sets.  Graph does not rank the alternatives.
 */
parse arg fitOut participationOut
if fitOut='' then fitOut='wobbly_ambiguity_fit.svg'
if participationOut='' then participationOut='wobbly_ambiguity_participation.svg'
obs=.array~new
call addObs obs,'A',0,-2; call addObs obs,'B',1,1; call addObs obs,'C',2,2
call addObs obs,'D',3,3; call addObs obs,'E',4,7; call addObs obs,'F',5,5
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.5),2,1000)
a=search~analyze(obs)
say 'minimalSets='a~restoringSets~items 'distanceToFit='a~distanceToFit
r=.MLGraphRenderers~byName('SVG')
fit=.MLWobbleGraphAdapter~graphForAnalysis('Wobbly fit: one published minimal explanation',obs,a,1)
fit~render(r,fitOut)
part=.MLWobbleGraphAdapter~participationGraph('Wobbly fit: participation across all minimal explanations',a)
part~render(r,participationOut)
say 'FIT_SVG='fitOut
say 'PARTICIPATION_SVG='participationOut
say 'PASS wobbly_ambiguity_graph'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
::requires 'MLGraphWobbly.cls'
