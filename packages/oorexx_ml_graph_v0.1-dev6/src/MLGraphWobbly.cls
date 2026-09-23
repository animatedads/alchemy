/* ooRexx ML Graph v0.1-dev5
 * Wobbly-fit visualisation adapter for ooRexx ML v0.1-dev11.
 *
 * Upstream ML owns fit, exclusion search, restoration, participation and
 * reassignment semantics.  This adapter only maps published evidence into
 * semantic graph objects.
 */

::class MLWobbleGraphAdapter public
::method graphForAnalysis class
  use strict arg title,observations,analysis,setIndex=1,xName='x',yName='y'
  if \observations~isA(.Array) then raise syntax 88.900 array('wobble graph observations must be an Array')
  if observations~items<1 then raise syntax 88.900 array('wobble graph requires at least one observation')
  do i=1 to observations~items
    o=observations[i]
    if \o~isA(.Directory) then raise syntax 88.900 array('wobble graph observations must be Directory values',i)
    if \o~hasIndex(xName) | \o~hasIndex(yName) then raise syntax 88.900 array('wobble graph observation lacks requested coordinate',i,xName,yName)
  end

  g=.MLGraph~cartesian2(title,xName,yName)
  g~putMetadata('semanticSource','MLWobbleAnalysis')
  g~putMetadata('wobble.exclusionAuthority','DIAGNOSTIC_ONLY')
  g~putMetadata('wobble.distanceToFit',analysis~distanceToFit)
  g~putMetadata('wobble.normalizedDistance',analysis~normalizedDistance)
  g~putMetadata('wobble.restoringSetCount',analysis~restoringSets~items)
  g~putMetadata('wobble.evaluations',analysis~evaluations)

  selected=.nil; selectedIndexes=.directory~new
  if analysis~restoringSets~items>0 then do
    if setIndex<1 | setIndex>analysis~restoringSets~items then raise syntax 88.900 array('wobble graph restoring-set index is out of range',setIndex,analysis~restoringSets~items)
    selected=analysis~restoringSets[setIndex]
    do ix over selected~indexes~toArray; selectedIndexes[ix]=1; end
    g~putMetadata('wobble.selectedRestoringSet',setIndex)
  end
  else g~putMetadata('wobble.selectedRestoringSet',0)

  retained=.array~new; removed=.array~new
  do i=1 to observations~items
    o=observations[i]; v=.directory~new; v[xName]=o[xName]; v[yName]=o[yName]
    p=.MLGraphPoint~new(v,o)
    if selectedIndexes~hasIndex(i) then removed~append(p); else retained~append(p)
  end
  g~addSeries(.MLGraphSeries~new('retained observations',retained,'OBSERVED',.false,analysis,'OBSERVED','POINTS'))
  if selected \== .nil then g~addSeries(.MLGraphSeries~new('minimal restoring set #'||setIndex,removed,'RESTORING_SET',.false,selected,'RESTORING_SET','POINTS'))

  self~addPublishedFit(g,analysis~baseline,observations,xName,yName,'full-set fit','BASELINE_FIT')
  if selected \== .nil then self~addPublishedFit(g,selected~assessment,observations,xName,yName,'restored fit','RESTORED_FIT')

  self~addAnalysisSummary(g,analysis)
  if selected \== .nil then self~addSetSummary(g,selected,setIndex)
  return g

::method participationGraph class
  use strict arg title,analysis
  g=.MLGraph~cartesian2(title,'observationIndex','participation','INDEX','FRACTION')
  g~putMetadata('semanticSource','MLWobbleAnalysis.participation')
  g~putMetadata('wobble.exclusionAuthority','DIAGNOSTIC_ONLY')
  pts=.array~new
  do p over analysis~participation~toArray
    v=.directory~new; v['observationIndex']=p~index; v['participation']=p~fraction
    pts~append(.MLGraphPoint~new(v,p))
  end
  g~addSeries(.MLGraphSeries~new('minimal-set participation',pts,'PARTICIPATION',.false,analysis,'PARTICIPATION','POINTS'))
  text='minimal restoring sets='||analysis~restoringSets~items||', distanceToFit='||analysis~distanceToFit||', normalized='||analysis~normalizedDistance
  g~addAnnotation(.MLGraphAnnotation~summary(text,analysis))
  if analysis~participation~items>0 & analysis~participation~items<=12 then do
    detail='participation: '; first=.true
    do p over analysis~participation~toArray
      if \first then detail=detail||', '
      detail=detail||p~id||'='||p~fraction
      first=.false
    end
    g~addAnnotation(.MLGraphAnnotation~summary(detail,analysis))
  end
  return g

::method addFitAssessment class
  use strict arg graph,assessment,observations,label='published fit',role='REFERENCE',xName='x',yName='y'
  if \graph~isA(.MLGraph) then raise syntax 88.900 array('fit-assessment adapter requires MLGraph')
  if \observations~isA(.Array) then raise syntax 88.900 array('fit-assessment observations must be an Array')
  return self~addPublishedFit(graph,assessment,observations,xName,yName,label,role)

::method addReassignments class
  use strict arg graph,reassignments
  if \graph~isA(.MLGraph) then raise syntax 88.900 array('wobble reassignment adapter requires MLGraph')
  if \reassignments~isA(.Array) then raise syntax 88.900 array('wobble reassignments must be an Array')
  do r over reassignments
    text='reassignment '||r~id||': '||r~disposition
    if r~target<>'' then text=text||' -> '||r~target
    graph~addAnnotation(.MLGraphAnnotation~summary(text,r))
  end
  return graph

::method addPublishedFit class private
  use strict arg graph,assessment,observations,xName,yName,label,role
  ev=assessment~evidence
  if \ev~hasIndex('slope') | \ev~hasIndex('intercept') then return graph
  minx=.nil; maxx=.nil
  do o over observations
    x=o[xName]+0
    if minx==.nil | x<minx then minx=x
    if maxx==.nil | x>maxx then maxx=x
  end
  if minx==.nil then return graph
  slope=ev['slope']+0; intercept=ev['intercept']+0
  pts=.array~new
  v=.directory~new; v[xName]=minx; v[yName]=intercept+slope*minx; pts~append(.MLGraphPoint~new(v,assessment))
  if maxx<>minx then do
    v=.directory~new; v[xName]=maxx; v[yName]=intercept+slope*maxx; pts~append(.MLGraphPoint~new(v,assessment))
  end
  graph~addSeries(.MLGraphSeries~new(label,pts,role,.false,assessment,role,'PATH'))
  return graph

::method addAnalysisSummary class private
  use strict arg graph,analysis
  text='fit: baseline='||analysis~baseline~value||', criterion='||analysis~criterion~direction||' '||analysis~criterion~threshold
  graph~addAnnotation(.MLGraphAnnotation~summary(text,analysis))
  text='restoration: distanceToFit='||analysis~distanceToFit||', normalized='||analysis~normalizedDistance||', minimalSets='||analysis~restoringSets~items||', evaluations='||analysis~evaluations
  graph~addAnnotation(.MLGraphAnnotation~summary(text,analysis))
  if analysis~normative \== .nil then do
    text='normative: '||analysis~normativeClass||', percentile='||analysis~percentile
    graph~addAnnotation(.MLGraphAnnotation~summary(text,analysis))
  end
  return graph

::method addSetSummary class private
  use strict arg graph,restoringSet,setIndex
  ids=''; a=restoringSet~ids~toArray
  do i=1 to a~items; if i>1 then ids=ids||','; ids=ids||a[i]; end
  text='set #'||setIndex||' temporarily excludes ['||ids||']; restoredFit='||restoringSet~assessment~value||', restoration='||restoringSet~restoration
  graph~addAnnotation(.MLGraphAnnotation~summary(text,restoringSet))
  return graph

::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
