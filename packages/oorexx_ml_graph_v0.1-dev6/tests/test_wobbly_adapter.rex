f=0
obs=.array~new
call addObs obs,'A0',0,1,'A'
call addObs obs,'A1',1,3,'A'
call addObs obs,'A2',2,5,'A'
call addObs obs,'B3',3,17,'B'
call addObs obs,'A4',4,9,'A'
call addObs obs,'A5',5,11,'A'
call addObs obs,'B6',6,14,'B'
call addObs obs,'A7',7,15,'A'
call addObs obs,'A8',8,17,'A'
call addObs obs,'B9',9,11,'B'
call addObs obs,'A10',10,21,'A'
call addObs obs,'A11',11,23,'A'
criterion=.MLFitCriterion~new(0.00001,'LOWER_IS_BETTER')
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,criterion,4,10000)
norm=.MLWobbleNorm~new(.array~of(.00,.04,.05,.06,.08,.08,.10,.10,.12,.15))
a=search~analyze(obs,norm)
call check a~distanceToFit=3 & a~restoringSets~items=1,'upstream radar analysis has one three-observation restoring set'
ws=a~restoringSets[1]
g=.MLWobbleGraphAdapter~graphForAnalysis('contextual wobble',obs,a)
call check g~coordinateSystem='CARTESIAN' & g~dimensionCount=2,'wobble adapter creates ordinary 2D semantic graph'
call check g~metadata('semanticSource')='MLWobbleAnalysis','graph records upstream semantic source'
call check g~metadata('wobble.exclusionAuthority')='DIAGNOSTIC_ONLY','graph states exclusion has no deletion authority'
call check g~metadata('wobble.distanceToFit')=3 & g~metadata('wobble.selectedRestoringSet')=1,'distance and selected published set are retained'
call check g~seriesCount=4,'radar graph has retained points, restoring points, baseline fit and restored fit'
call check g~seriesAt(1)~connection='POINTS' & g~seriesAt(1)~role='OBSERVED','retained observations are points, not an invented path'
call check g~seriesAt(1)~pointCount=9,'retained series excludes exactly the published restoring set'
call check g~seriesAt(2)~connection='POINTS' & g~seriesAt(2)~role='RESTORING_SET','restoring set is a point-only diagnostic series'
call check g~seriesAt(2)~pointCount=3 & g~seriesAt(2)~evidence==ws,'restoring-set series retains exact MLWobbleSet evidence'
call check g~seriesAt(2)~point(1)~evidence==obs[4] & g~seriesAt(2)~point(2)~evidence==obs[7] & g~seriesAt(2)~point(3)~evidence==obs[10],'restoring points retain exact source observations'
call check g~seriesAt(3)~role='BASELINE_FIT' & g~seriesAt(3)~evidence==a~baseline,'baseline line comes from published baseline fit assessment'
call check g~seriesAt(4)~role='RESTORED_FIT' & g~seriesAt(4)~evidence==ws~assessment,'restored line comes from published restoring-set assessment'
call check g~seriesAt(4)~point(1)~evidence==ws~assessment,'fit geometry points retain the assessment that published slope/intercept'
call check g~annotationCount=4,'fit, restoration, normative and selected-set evidence are summarized separately'
call check g~annotationAt(1)~evidence==a & g~annotationAt(2)~evidence==a & g~annotationAt(3)~evidence==a & g~annotationAt(4)~evidence==ws,'summaries retain exact upstream evidence objects'
call check g~annotationAt(3)~text~pos('ABOVE_NORMATIVE_P95')>0,'normative classification is displayed only from upstream analysis'
call check g~annotationAt(4)~text~pos('B3,B6,B9')>0,'selected restoring-set IDs are explicitly named'

pg=.MLWobbleGraphAdapter~participationGraph('ambiguity participation',a)
call check pg~seriesCount=1 & pg~seriesAt(1)~connection='POINTS','participation is rendered as evidence points'
call check pg~seriesAt(1)~pointCount=3,'unique restoring set produces three participation evidence points'
call check pg~seriesAt(1)~point(1)~evidence~isA(.MLWobbleParticipation),'participation points retain MLWobbleParticipation evidence'
call check pg~annotationCount=2 & pg~annotationAt(2)~text~pos('B3=1')>0,'small participation views name upstream observation IDs and fractions'

re=.array~new
do o over .array~of(obs[4],obs[7],obs[10])
  ev=.directory~new; ev['reason']='coherent alternate track'
  re~append(.MLWobbleReassignment~new(o['id'],'ALTERNATE_TRACK','TRACK-B',ev))
end
.MLWobbleGraphAdapter~addReassignments(g,re)
call check g~annotationCount=7,'explicit reassignments add explanatory evidence without modifying observations'
call check g~annotationAt(5)~evidence==re[1] & g~annotationAt(5)~text~pos('ALTERNATE_TRACK -> TRACK-B')>0,'reassignment annotation retains exact semantic decision'

amb=.array~new
call addObs amb,'A',0,-2,'?'; call addObs amb,'B',1,1,'?'; call addObs amb,'C',2,2,'?'
call addObs amb,'D',3,3,'?'; call addObs amb,'E',4,7,'?'; call addObs amb,'F',5,5,'?'
aa=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.5),2,1000)~analyze(amb)
call check aa~restoringSets~items>=2,'upstream ambiguous analysis exposes multiple minimal restoring sets'
ag=.MLWobbleGraphAdapter~graphForAnalysis('alternative minimal explanation',amb,aa,2)
call check ag~seriesAt(2)~evidence==aa~restoringSets[2] & ag~metadata('wobble.selectedRestoringSet')=2,'caller can select a published alternative without Graph ranking it'
ap=.MLWobbleGraphAdapter~participationGraph('ambiguous participation',aa)
call check ap~seriesAt(1)~pointCount=aa~participation~items,'participation graph contains exactly upstream participation objects'

bad=.array~new
call addObs bad,'R1',0,0,'?'; call addObs bad,'W1',1,4,'?'; call addObs bad,'R3',2,2,'?'; call addObs bad,'W2',3,-1,'?'
na=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.01),0,100)~analyze(bad)
call check na~restoringSets~items=0 & na~distanceToFit=-1,'upstream can report not-restored within declared search bound'
ng=.MLWobbleGraphAdapter~graphForAnalysis('not restored',bad,na)
call check ng~metadata('wobble.selectedRestoringSet')=0 & ng~seriesCount=2,'graph explains not-restored analysis without inventing a restoring set'
call check ng~annotationAt(2)~text~pos('distanceToFit=-1')>0,'not-restored state is explicit in summary'

if f=0 then do; say 'PASS MLGraph wobbly adapter 30 assertions'; exit 0; end
say 'FAIL MLGraph wobbly adapter failures='f; exit 1
addObs: procedure
  use strict arg a,id,x,y,truth
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; d['truth']=truth; a~append(d); return
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphWobbly.cls'
