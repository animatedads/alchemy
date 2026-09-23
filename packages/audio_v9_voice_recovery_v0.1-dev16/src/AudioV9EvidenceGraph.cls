/* AudioV9EvidenceGraph.cls
 * dev5: semantic graph evidence for box movement, inter-box relations,
 * spatial path hypotheses and source-conditioned reconstruction.
 *
 * Authority boundary:
 *   Audio/ML objects create semantic evidence.
 *   MLGraph carries coordinates/series/annotations.
 *   Renderers own pixels only and may not create/remove/reclassify evidence.
 */
::options numeric inherit

::class AudioV9SpectralRelationEdge public
::method init
  expose id kind source target delayMs difference provenance
  use strict arg idValue,kindValue,sourceValue,targetValue,delayValue,differenceValue=.nil,provenanceValue=''
  id=idValue~string; kind=kindValue~string~upper; source=sourceValue; target=targetValue; delayMs=delayValue+0; difference=differenceValue; provenance=provenanceValue~string
  if \source~isA(.AudioV9BoxCharacter) | \target~isA(.AudioV9BoxCharacter) then raise syntax 88.900 array('spectral relation requires box characters')
  if difference\==.nil then do
    if \difference~isA(.MLPatternHashDifference) then raise syntax 88.900 array('spectral relation difference must be MLPatternHashDifference')
  end
  select
    when kind='CONTINUATION' then nop
    when kind='ADJACENT_BAND' then nop
    when kind='DIAGONAL_MIGRATION' then nop
    when kind='DELAYED_RECURRENCE' then nop
    otherwise raise syntax 88.900 array('unsupported spectral relation kind',kind)
  end
::method id; expose id; return id
::method kind; expose kind; return kind
::method source; expose source; return source
::method target; expose target; return target
::method delayMs; expose delayMs; return delayMs
::method difference; expose difference; return difference
::method provenance; expose provenance; return provenance
::method ownerStartMs; expose source; return source~absoluteStartMs
::method patternDominant
  expose difference
  if difference==.nil then return -1
  return difference~dominantDelta
::method patternTotal
  expose difference
  if difference==.nil then return -1
  return difference~totalDelta
::method role
  expose kind
  select
    when kind='CONTINUATION' then return 'PRIMARY'
    when kind='ADJACENT_BAND' then return 'NEAR'
    when kind='DIAGONAL_MIGRATION' then return 'DIFFERENCE'
    when kind='DELAYED_RECURRENCE' then return 'SECONDARY'
    otherwise return 'PRIMARY'
  end
::method wobbleObservation
  expose id delayMs
  d=.directory~new; d['id']=id; d['lag_ms']=delayMs; return d
::method canonicalText
  expose id kind source target delayMs difference provenance
  text='AUDIO_V9_SPECTRAL_RELATION/1|id='||id||'|kind='||kind||'|source='||source~id||'|target='||target~id||'|delayMs='||delayMs||'|ownerStartMs='||source~absoluteStartMs
  if difference\==.nil then text=text||'|dominant='||difference~dominantDelta||'|total='||difference~totalDelta||'|radialMax='||difference~radialMax||'|slopeMax='||difference~slopeMax||'|curvatureMax='||difference~curvatureMax
  if provenance<>'' then text=text||'|provenance='||provenance
  return text

::class AudioV9SpectralRelationEvidence public
::method init
  expose characters edges
  use strict arg characterValues,edgeValues
  if \characterValues~isA(.Array) | \edgeValues~isA(.Array) then raise syntax 88.900 array('spectral relation evidence requires arrays')
  characters=characterValues~copy; edges=edgeValues~copy
::method characters; expose characters; return characters~copy
::method edges; expose edges; return edges~copy
::method edgeCount; expose edges; return edges~items
::method edgesOf
  expose edges
  use strict arg kind
  wanted=kind~string~upper; out=.array~new
  do e over edges; if e~kind=wanted then out~append(e); end
  return out
::method count; use strict arg kind; return self~edgesOf(kind)~items
::method write
  expose edges
  use strict arg path
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'edge_id'||'09'x||'kind'||'09'x||'source_id'||'09'x||'target_id'||'09'x||'owner_start_ms'||'09'x||'delay_ms'||'09'x||'pattern_dominant'||'09'x||'pattern_total'||'09'x||'radial_max'||'09'x||'slope_max'||'09'x||'curvature_max'||'09'x||'provenance'
  do e over edges
    d=e~difference
    if d==.nil then row=e~id||'09'x||e~kind||'09'x||e~source~id||'09'x||e~target~id||'09'x||e~ownerStartMs||'09'x||e~delayMs||'09'x||-1||'09'x||-1||'09'x||-1||'09'x||-1||'09'x||-1||'09'x||e~provenance
    else row=e~id||'09'x||e~kind||'09'x||e~source~id||'09'x||e~target~id||'09'x||e~ownerStartMs||'09'x||e~delayMs||'09'x||d~dominantDelta||'09'x||d~totalDelta||'09'x||d~radialMax||'09'x||d~slopeMax||'09'x||d~curvatureMax||'09'x||e~provenance
    call lineout path,row
  end
  call stream path,'C','CLOSE'; return path

::class AudioV9SpectralRelationBuilder public
::method init
  expose schema
  use strict arg schemaValue=.nil
  if schemaValue==.nil then schema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(24,48,1,4,10,.false,.false),'AUDIO-V9-SPECTRAL-BOX/1')
  else schema=schemaValue
::method build
  expose schema
  use strict arg characters,provenance='',differenceMode='FULL'
  if \characters~isA(.Array) then raise syntax 88.900 array('spectral relation builder requires character array')
  differenceMode=differenceMode~string~upper
  if differenceMode<>'FULL' & differenceMode<>'TOPOLOGY' then raise syntax 88.900 array('relation difference mode must be FULL or TOPOLOGY',differenceMode)
  ordered=characters~copy; ordered~sortWith(.AudioV9GraphCharacterComparator~new)
  index=.directory~new; timeByFeed=.directory~new
  do c over ordered
    key=self~key(c~feed,c~absoluteStartMs,c~bandIndex); index[key]=c
    if \timeByFeed~hasIndex(c~feed) then timeByFeed[c~feed]=.array~new
    times=timeByFeed[c~feed]
    if times~items=0 then times~append(c~absoluteStartMs)
    else if times[times~items]<>c~absoluteStartMs then times~append(c~absoluteStartMs)
  end
  nextTime=.directory~new
  do feed over timeByFeed~allIndexes
    times=timeByFeed[feed]
    do i=1 to times~items-1; nextTime[feed||'|'||times[i]]=times[i+1]; end
  end
  edges=.array~new; serial=1; diffCache=.directory~new
  do c over ordered
    feed=c~feed; t=c~absoluteStartMs; b=c~bandIndex
    /* Adjacent-band, same-time relation: own only the upward pair. */
    k=self~key(feed,t,b+1)
    if index~hasIndex(k) then do
      target=index[k]; edges~append(self~edge(serial,'ADJACENT_BAND',c,target,target~absoluteStartMs-c~absoluteStartMs,provenance,diffCache,differenceMode)); serial=serial+1
    end
    nk=feed||'|'||t
    if nextTime~hasIndex(nk) then do
      nt=nextTime[nk]
      k=self~key(feed,nt,b)
      if index~hasIndex(k) then do
        target=index[k]
        edges~append(self~edge(serial,'CONTINUATION',c,target,nt-t,provenance,diffCache,differenceMode)); serial=serial+1
        /* Same topology, separate semantic candidate.  Recurrence remains a
         * hypothesis carrying ML difference evidence, not an echo declaration. */
        edges~append(self~edge(serial,'DELAYED_RECURRENCE',c,target,nt-t,provenance,diffCache,differenceMode)); serial=serial+1
      end
      do db=-1 to 1 by 2
        k=self~key(feed,nt,b+db)
        if index~hasIndex(k) then do
          target=index[k]; edges~append(self~edge(serial,'DIAGONAL_MIGRATION',c,target,nt-t,provenance,diffCache,differenceMode)); serial=serial+1
        end
      end
    end
  end
  return .AudioV9SpectralRelationEvidence~new(ordered,edges)
::method edge private
  expose schema
  use strict arg serial,kind,source,target,delay,provenance,diffCache,differenceMode
  diff=.nil
  if differenceMode='FULL' then do
    pair=source~id||'>'||target~id
    if diffCache~hasIndex(pair) then diff=diffCache[pair]
    else do; diff=schema~difference(source~residualHash,target~residualHash); diffCache[pair]=diff; end
  end
  id='EDGE_'||right(serial,6,'0')||'|'||kind||'|'||source~id||'|'||target~id
  return .AudioV9SpectralRelationEdge~new(id,kind,source,target,delay,diff,provenance)
::method key private
  use strict arg feed,time,band
  return feed||'|'||time||'|'||band

::class AudioV9GraphCharacterComparator private
::method compare
  use strict arg a,b
  if a~feed<b~feed then return -1
  if a~feed>b~feed then return 1
  if a~absoluteStartMs<b~absoluteStartMs then return -1
  if a~absoluteStartMs>b~absoluteStartMs then return 1
  if a~bandIndex<b~bandIndex then return -1
  if a~bandIndex>b~bandIndex then return 1
  if a~id<b~id then return -1
  if a~id>b~id then return 1
  return 0

::class AudioV9QualityGraphBundle public
::method init
  expose ids graphs
  ids=.array~new; graphs=.directory~new
::method add
  expose ids graphs
  use strict arg id,graph
  key=id~string~upper
  if \graph~isA(.MLGraph) then raise syntax 88.900 array('quality graph bundle requires MLGraph')
  if graphs~hasIndex(key) then raise syntax 88.900 array('duplicate quality graph id',key)
  ids~append(key); graphs[key]=graph; return self
::method ids; expose ids; return ids~copy
::method graph
  expose graphs
  use strict arg id
  key=id~string~upper; if \graphs~hasIndex(key) then raise syntax 88.900 array('unknown quality graph id',key)
  return graphs[key]
::method items; expose ids; return ids~items
::method writeArchive
  use strict arg path
  return .AudioV9MLGraphArchive~new~write(self,path)
::method renderAll
  expose ids graphs
  use strict arg renderer,prefix
  out=.array~new
  do id over ids
    path=prefix||'.'||id~lower||'.svg'; graphs[id]~render(renderer,path); out~append(path)
  end
  return out

::class AudioV9QualityGraphBuilder public
::method init
  expose relationBuilder delayAnalyzer
  relationBuilder=.AudioV9SpectralRelationBuilder~new
  delayAnalyzer=.AudioV9DelayTrackAnalyzer~new(3.0,4,100000)
::method build
  expose relationBuilder
  use strict arg analysis,scan,maskPlan,absoluteChunkStartMs,sampleRate=8000,provenance='',relationMode='TOPOLOGY'
  if \analysis~isA(.AudioV9AcousticAnalysis) then raise syntax 88.900 array('quality graph builder requires acoustic analysis')
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('quality graph builder requires spatial scan')
  if \maskPlan~isA(.AudioV9TfMaskPlan) then raise syntax 88.900 array('quality graph builder requires TF mask plan')
  rel=relationBuilder~build(analysis~characters,provenance,relationMode)
  b=.AudioV9QualityGraphBundle~new
  b~add('FIELD',self~fieldGraph(analysis,absoluteChunkStartMs))
  b~add('RELATIONS',self~relationGraph(rel,absoluteChunkStartMs,relationMode))
  b~add('DELAY',self~delayGraph(scan))
  b~add('RECONSTRUCTION',self~reconstructionGraph(maskPlan,sampleRate,absoluteChunkStartMs))
  return .array~of(b,rel)
::method fieldGraph private
  use strict arg analysis,baseMs
  g=.MLGraph~cartesian3('Audio V9 spectral movement field','time_ms','frequency_hz','motion_db','TIME','FREQUENCY','VALUE')
  g~putMetadata('audioView','FIELD'); g~putMetadata('baseEpochMs',baseMs); g~putMetadata('semanticSource','AudioV9BoxCharacter')
  buckets=.directory~new; keys=.array~new
  do c over analysis~characters
    key=c~feed||'|B'||c~bandIndex
    if \buckets~hasIndex(key) then do; buckets[key]=.array~new; keys~append(key); end
    v=.directory~new; v['time_ms']=c~absoluteStartMs-baseMs; v['frequency_hz']=c~centerHz; v['motion_db']=c~residualMotionDb
    buckets[key]~append(.MLGraphPoint~new(v,c~canonicalText))
  end
  keys~sort
  do key over keys
    role='PRIMARY'; if key~left(2)='FD' then role='SECONDARY'
    feed=key~substr(1,2); g~addSeries(.MLGraphSeries~new(key,buckets[key],role,.false,feed,key))
  end
  return g
::method relationGraph private
  use strict arg relationEvidence,baseMs,relationMode
  g=.MLGraph~cartesian3('Audio V9 continuation / migration graph','time_ms','frequency_hz','pattern_total','TIME','FREQUENCY','DIFFERENCE')
  g~putMetadata('audioView','RELATIONS'); g~putMetadata('baseEpochMs',baseMs); g~putMetadata('semanticSource','AudioV9SpectralRelationEdge'); g~putMetadata('relationMode',relationMode)
  do e over relationEvidence~edges
    pts=.array~new
    v=.directory~new; v['time_ms']=e~source~absoluteStartMs-baseMs; v['frequency_hz']=e~source~centerHz; v['pattern_total']=e~patternTotal; pts~append(.MLGraphPoint~new(v,e~source~canonicalText))
    v=.directory~new; v['time_ms']=e~target~absoluteStartMs-baseMs; v['frequency_hz']=e~target~centerHz; v['pattern_total']=e~patternTotal; pts~append(.MLGraphPoint~new(v,e~target~canonicalText))
    g~addSeries(.MLGraphSeries~new(e~id,pts,e~role,.false,e~canonicalText,e~kind))
  end
  return g
::method delayGraph private
  expose delayAnalyzer
  use strict arg scan
  g=.MLGraph~cartesian3('Audio V9 competing spatial path hypotheses','time_ms','lag_ms','score','TIME','DELAY','CONFIDENCE')
  g~putMetadata('audioView','DELAY'); g~putMetadata('semanticSource','AudioV9SpatialHypothesis')
  env=.array~new; direct=.array~new; refined=.array~new; obs=.array~new
  builder=.AudioV9SpatialHypothesisBuilder~new
  do r over scan~rows
    hs=builder~fromMeasurement(r~measurement)
    do h over hs
      v=.directory~new; v['time_ms']=r~startMs; v['lag_ms']=h~lagMs; v['score']=h~score
      p=.MLGraphPoint~new(v,h~canonicalText)
      select
        when h~id='ENVELOPE' then env~append(p)
        when h~id='DIRECT' then direct~append(p)
        when h~id='REFINED' then refined~append(p)
        otherwise nop
      end
    end
    d=.directory~new; d['id']='REFINED|'||r~index; d['lag_ms']=r~measurement~refinedLagMs; obs~append(d)
  end
  if env~items>0 then g~addSeries(.MLGraphSeries~new('Envelope lag',env,'SECONDARY',.false,'ENVELOPE','ENVELOPE'))
  if direct~items>0 then g~addSeries(.MLGraphSeries~new('Direct residual lag',direct,'REFERENCE',.false,'DIRECT','DIRECT'))
  if refined~items>0 then g~addSeries(.MLGraphSeries~new('Refined lag',refined,'PRIMARY',.false,'REFINED','REFINED'))
  if obs~items>=3 then do
    wobble=delayAnalyzer~analyze(obs)
    text='active-model=ONE_COHERENT_REFINED_DELAY; baselineRmsMs='||wobble~baseline~value||'; distanceToFit='||wobble~distanceToFit||'; normalized='||wobble~normalizedDistance||'; minimalSets='||wobble~restoringSets~items
    g~addAnnotation(.MLGraphAnnotation~summary(text,wobble))
    g~putMetadata('wobbleModel','ONE_COHERENT_REFINED_DELAY')
  end
  return g
::method reconstructionGraph private
  use strict arg maskPlan,sampleRate,baseMs
  g=.MLGraph~cartesian3('Audio V9 source-conditioned reconstruction','time_ms','frequency_hz','gain','TIME','FREQUENCY','GAIN')
  g~putMetadata('audioView','RECONSTRUCTION'); g~putMetadata('baseEpochMs',baseMs); g~putMetadata('sampleRate',sampleRate); g~putMetadata('semanticSource','AudioV9TfMaskRow')
  i=0
  do r over maskPlan~rows
    i=i+1; pts=.array~new
    s=1000*r~startSample/sampleRate; e=1000*r~endSample/sampleRate
    v=.directory~new; v['time_ms']=s; v['frequency_hz']=r~lowHz; v['gain']=r~gain; pts~append(.MLGraphPoint~new(v,r~tsv))
    v=.directory~new; v['time_ms']=e; v['frequency_hz']=r~highHz; v['gain']=r~gain; pts~append(.MLGraphPoint~new(v,r~tsv))
    role='PRIMARY'; if r~protect then role='REFERENCE'; else if r~gain<1 then role='CONTRAST'
    key=r~reason; if r~speakerId<>'' then key='SPEAKER_VOICE'
    g~addSeries(.MLGraphSeries~new('MASK_'||right(i,6,'0')||' '||r~familyId,pts,role,.false,r~tsv,key))
  end
  return g

/* Deterministic MLGraph archive.  This preserves already-computed graph state so
 * presentation can be regenerated without decoding audio or rerunning ML. */
::class AudioV9MLGraphArchive public
::method write
  use strict arg bundle,path
  if \bundle~isA(.AudioV9QualityGraphBundle) then raise syntax 88.900 array('graph archive requires quality graph bundle')
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'AUDIO_V9_MLGRAPH_ARCHIVE/1'
  do id over bundle~ids
    g=bundle~graph(id)
    call lineout path,'GRAPH'||'09'x||self~esc(id)||'09'x||self~esc(g~title)||'09'x||self~esc(g~coordinateSystem)
    do ai=1 to g~dimensionCount
      a=g~axis(ai); call lineout path,'AXIS'||'09'x||self~esc(id)||'09'x||ai||'09'x||self~esc(a~name)||'09'x||self~esc(a~role)||'09'x||self~esc(a~label)||'09'x||self~esc(a~unit)
    end
    /* Only metadata needed for presentation/replay is serialized explicitly. */
    do name over .array~of('audioView','baseEpochMs','sampleRate','semanticSource','wobbleModel','relationMode')
      value=g~metadata(name,.nil); if value\==.nil then call lineout path,'META'||'09'x||self~esc(id)||'09'x||self~esc(name)||'09'x||self~esc(value)
    end
    do si=1 to g~seriesCount
      s=g~seriesAt(si); ev=self~evidenceText(s~evidence)
      call lineout path,'SERIES'||'09'x||self~esc(id)||'09'x||si||'09'x||self~esc(s~label)||'09'x||self~esc(s~role)||'09'x||self~esc(s~semanticKey)||'09'x||self~esc(ev)
      do pi=1 to s~pointCount
        p=s~point(pi); vals=p~values; names=.array~new; do k over vals~allIndexes; names~append(k); end; names~sort
        coords=''; first=.true
        do k over names
          if \first then coords=coords||';'
          coords=coords||self~esc(k)||'='||self~esc(vals[k]); first=.false
        end
        call lineout path,'POINT'||'09'x||self~esc(id)||'09'x||si||'09'x||pi||'09'x||coords||'09'x||self~esc(self~evidenceText(p~evidence))
      end
    end
    do ai=1 to g~annotationCount
      a=g~annotationAt(ai); call lineout path,'ANNOTATION'||'09'x||self~esc(id)||'09'x||ai||'09'x||self~esc(a~kind)||'09'x||self~esc(a~text)||'09'x||self~esc(self~evidenceText(a~evidence))
    end
  end
  call stream path,'C','CLOSE'; return path
::method read
  use strict arg path
  call stream path,'C','OPEN READ'
  header=linein(path); if header<>'AUDIO_V9_MLGRAPH_ARCHIVE/1' then raise syntax 88.900 array('graph archive header mismatch',header)
  defs=.directory~new; order=.array~new
  do while lines(path)>0
    line=linein(path); if line='' then iterate
    f=self~splitTabs(line); kind=f[1]
    select
      when kind='GRAPH' then do
        id=self~unesc(f[2]); d=.directory~new; d['title']=self~unesc(f[3]); d['coords']=self~unesc(f[4]); d['axes']=.array~new; d['meta']=.directory~new; d['series']=.array~new; d['annotations']=.array~new; defs[id]=d; order~append(id)
      end
      when kind='AXIS' then do
        id=self~unesc(f[2]); a=.MLGraphAxis~new(self~unesc(f[4]),self~unesc(f[5]),self~unesc(f[6]),self~unesc(f[7])); defs[id]['axes']~append(a)
      end
      when kind='META' then do; id=self~unesc(f[2]); defs[id]['meta'][self~unesc(f[3])]=self~unesc(f[4]); end
      when kind='SERIES' then do
        id=self~unesc(f[2]); s=.directory~new; s['label']=self~unesc(f[4]); s['role']=self~unesc(f[5]); s['key']=self~unesc(f[6]); s['evidence']=self~unesc(f[7]); s['points']=.array~new; defs[id]['series']~append(s)
      end
      when kind='POINT' then do
        id=self~unesc(f[2]); si=f[3]+0; vals=self~parseCoords(f[5]); p=.MLGraphPoint~new(vals,self~unesc(f[6])); defs[id]['series'][si]['points']~append(p)
      end
      when kind='ANNOTATION' then do
        id=self~unesc(f[2]); defs[id]['annotations']~append(.MLGraphAnnotation~summary(self~unesc(f[5]),self~unesc(f[6])))
      end
      otherwise raise syntax 88.900 array('unknown graph archive record',kind)
    end
  end
  call stream path,'C','CLOSE'
  bundle=.AudioV9QualityGraphBundle~new
  do id over order
    d=defs[id]; g=.MLGraph~new(d['title'],d['coords'],d['axes'],.MLGraphGrid~none)
    do k over d['meta']~allIndexes; g~putMetadata(k,d['meta'][k]); end
    do sd over d['series']; g~addSeries(.MLGraphSeries~new(sd['label'],sd['points'],sd['role'],.false,sd['evidence'],sd['key'])); end
    do a over d['annotations']; g~addAnnotation(a); end
    bundle~add(id,g)
  end
  return bundle
::method evidenceText private
  use strict arg evidence
  if evidence==.nil then return ''
  return evidence~string
::method esc private
  use strict arg value
  x=value~string; x=x~changeStr('%','%25'); x=x~changeStr('09'x,'%09'); x=x~changeStr('0D'x,'%0D'); x=x~changeStr('0A'x,'%0A'); return x
::method unesc private
  use strict arg value
  x=value~string; x=x~changeStr('%0A','0A'x); x=x~changeStr('%0D','0D'x); x=x~changeStr('%09','09'x); x=x~changeStr('%25','%'); return x
::method splitTabs private
  use strict arg line
  out=.array~new; rest=line
  do forever
    p=rest~pos('09'x)
    if p=0 then do; out~append(rest); leave; end
    out~append(rest~substr(1,p-1)); rest=rest~substr(p+1)
  end
  return out
::method parseCoords private
  use strict arg text
  out=.directory~new; rest=text
  do forever
    p=rest~pos(';')
    if p=0 then do; part=rest; rest=''; end
    else do; part=rest~substr(1,p-1); rest=rest~substr(p+1); end
    eq=part~pos('='); if eq<2 then raise syntax 88.900 array('graph coordinate malformed',part)
    out[self~unesc(part~substr(1,eq-1))]=self~unesc(part~substr(eq+1))+0
    if rest='' then leave
  end
  return out



::class AudioV9GraphEvidenceWriter public
::method writeSpatialPaths class
  use strict arg scan,path
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('spatial path evidence requires AudioV9SpatialScan')
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'row_index'||'09'x||'start_sample'||'09'x||'start_ms'||'09'x||'hypothesis'||'09'x||'lag_ms'||'09'x||'score'||'09'x||'coherence'||'09'x||'ratio_db'
  builder=.AudioV9SpatialHypothesisBuilder~new
  do r over scan~rows
    hs=builder~fromMeasurement(r~measurement)
    do h over hs
      ev=h~evidence
      call lineout path,r~index||'09'x||r~startSample||'09'x||r~startMs||'09'x||h~id||'09'x||h~lagMs||'09'x||h~score||'09'x||ev['coherence']||'09'x||ev['ratio_db']
    end
  end
  call stream path,'C','CLOSE'; return path
::method writeDelayWobble class
  use strict arg scan,path
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('delay wobble evidence requires AudioV9SpatialScan')
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'status'||'09'x||'model'||'09'x||'observations'||'09'x||'baseline_rms_ms'||'09'x||'threshold_ms'||'09'x||'distance_to_fit'||'09'x||'normalized_distance'||'09'x||'minimal_sets'||'09'x||'evaluations'
  rows=scan~rows
  if rows~items<3 then do
    call lineout path,'INSUFFICIENT'||'09'x||'ONE_COHERENT_REFINED_DELAY'||'09'x||rows~items||'09'x||''||'09'x||3||'09'x||''||'09'x||''||'09'x||''||'09'x||''
    call stream path,'C','CLOSE'; return path
  end
  obs=.array~new
  do r over rows; d=.directory~new; d['id']='REFINED|'||r~index; d['lag_ms']=r~measurement~refinedLagMs; obs~append(d); end
  a=.AudioV9DelayTrackAnalyzer~new(3.0,4,100000)~analyze(obs)
  call lineout path,'ACTIVE'||'09'x||'ONE_COHERENT_REFINED_DELAY'||'09'x||obs~items||'09'x||a~baseline~value||'09'x||a~criterion~threshold||'09'x||a~distanceToFit||'09'x||a~normalizedDistance||'09'x||a~restoringSets~items||'09'x||a~evaluations
  call stream path,'C','CLOSE'; return path

/* Adapter from immutable per-chunk evidence TSVs to MLGraph scenes.  This is a
 * presentation adapter only: it does not decode audio, rerun source clustering,
 * invent graph edges, or alter TF reconstruction decisions. */
::class AudioV9QualityGraphTsvAdapter public
::method fromPrefix
  use strict arg prefix,sampleRate=8000,windowStartMs=.nil,windowEndMs=.nil
  chars=self~readCharacters(prefix||'.characters.tsv')
  base=self~baseOf(chars)
  if windowStartMs\==.nil then windowStartMs=windowStartMs+0
  if windowEndMs\==.nil then windowEndMs=windowEndMs+0
  if windowStartMs\==.nil then do
    if windowEndMs\==.nil then do
      if windowEndMs<=windowStartMs then raise syntax 88.900 array('graph diagnostic window must have positive duration')
    end
  end
  b=.AudioV9QualityGraphBundle~new
  b~add('FIELD',self~field(chars,base,windowStartMs,windowEndMs))
  b~add('RELATIONS',self~relations(chars,prefix||'.graph_edges.tsv',base,windowStartMs,windowEndMs))
  b~add('DELAY',self~delay(prefix||'.graph_paths.tsv',prefix||'.graph_wobble.tsv',base,windowStartMs,windowEndMs))
  b~add('RECONSTRUCTION',self~reconstruction(prefix||'.tf_mask.tsv',sampleRate,base,windowStartMs,windowEndMs))
  return b
::method readCharacters private
  use strict arg path
  call stream path,'C','OPEN READ'
  header=linein(path)
  expected='id'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'feed'||'09'x||'band'||'09'x||'center_hz'||'09'x||'motion'||'09'x||'turn'||'09'x||'active'||'09'x||'coherence'||'09'x||'ratio_db'||'09'x||'crest'||'09'x||'lag_abs_ms'
  if header\==expected then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('unexpected graph character TSV schema',path); end
  out=.array~new
  do while lines(path)>0
    line=linein(path); if line='' then iterate; f=line~makeArray('09'x); if f~items<>13 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad graph character row width',f~items); end
    d=.directory~new; d['id']=f[1]; d['start_ms']=f[2]+0; d['end_ms']=f[3]+0; d['feed']=f[4]; d['band']=f[5]+0; d['center_hz']=f[6]+0; d['motion']=f[7]+0; d['line']=line; out~append(d)
  end
  call stream path,'C','CLOSE'; return out
::method baseOf private
  use strict arg chars
  if chars~items=0 then return 0
  base=chars[1]['start_ms']
  do c over chars; if c['start_ms']<base then base=c['start_ms']; end
  return base
::method selected private
  use strict arg itemStart,itemEnd,windowStart,windowEnd
  if windowStart\==.nil then do; if itemEnd<=windowStart then return .false; end
  if windowEnd\==.nil then do; if itemStart>=windowEnd then return .false; end
  return .true
::method putWindowMetadata private
  use strict arg g,windowStart,windowEnd
  if windowStart\==.nil then g~putMetadata('windowStartMs',windowStart)
  if windowEnd\==.nil then g~putMetadata('windowEndMs',windowEnd)
  return g
::method field private
  use strict arg chars,base,windowStart,windowEnd
  g=.MLGraph~cartesian3('Audio V9 spectral movement field','time_ms','frequency_hz','motion_db','TIME','FREQUENCY','VALUE'); g~putMetadata('audioView','FIELD'); g~putMetadata('semanticSource','characters.tsv'); g~putMetadata('baseEpochMs',base); self~putWindowMetadata(g,windowStart,windowEnd)
  buckets=.directory~new; keys=.array~new
  do c over chars
    if \self~selected(c['start_ms'],c['end_ms'],windowStart,windowEnd) then iterate
    key=c['feed']||'|B'||c['band']; if \buckets~hasIndex(key) then do; buckets[key]=.array~new; keys~append(key); end
    v=.directory~new; v['time_ms']=c['start_ms']-base; v['frequency_hz']=c['center_hz']; v['motion_db']=c['motion']; buckets[key]~append(.MLGraphPoint~new(v,c['line']))
  end
  keys~sort
  do key over keys; role='PRIMARY'; if key~left(2)='FD' then role='SECONDARY'; g~addSeries(.MLGraphSeries~new(key,buckets[key],role,.false,key~left(2),key)); end
  return g
::method relations private
  use strict arg chars,path,base,windowStart,windowEnd
  nodes=.directory~new; do c over chars; nodes[c['id']]=c; end
  g=.MLGraph~cartesian3('Audio V9 continuation / migration graph','time_ms','frequency_hz','pattern_total','TIME','FREQUENCY','DIFFERENCE'); g~putMetadata('audioView','RELATIONS'); g~putMetadata('baseEpochMs',base); g~putMetadata('semanticSource','graph_edges.tsv'); self~putWindowMetadata(g,windowStart,windowEnd)
  call stream path,'C','OPEN READ'; header=linein(path); full=.false
  do while lines(path)>0
    line=linein(path); if line='' then iterate; f=line~makeArray('09'x); if f~items<>12 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad graph edge row width',f~items); end
    /* owner_start_ms is the source-box start and therefore a safe cheap
     * upper-window rejection before any node hash lookup.  This preserves
     * exact selection semantics while keeping bounded diagnostic replay
     * proportional to the requested view rather than the whole chunk. */
    ownerStart=f[5]+0
    if windowEnd\==.nil then do; if ownerStart>=windowEnd then iterate; end
    a=nodes[f[3]]
    if a==.nil then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('graph edge references missing source node',f[1]); end
    z=nodes[f[4]]
    if z==.nil then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('graph edge references missing target node',f[1]); end
    if \self~selected(a['start_ms'],z['end_ms'],windowStart,windowEnd) then iterate
    total=f[8]+0; if total>=0 then full=.true
    pts=.array~new; v=.directory~new; v['time_ms']=a['start_ms']-base; v['frequency_hz']=a['center_hz']; v['pattern_total']=total; pts~append(.MLGraphPoint~new(v,a['line']))
    v=.directory~new; v['time_ms']=z['start_ms']-base; v['frequency_hz']=z['center_hz']; v['pattern_total']=total; pts~append(.MLGraphPoint~new(v,z['line']))
    g~addSeries(.MLGraphSeries~new(f[1],pts,self~roleFor(f[2]),.false,line,f[2]))
  end
  call stream path,'C','CLOSE'; if full then g~putMetadata('relationMode','FULL'); else g~putMetadata('relationMode','TOPOLOGY'); return g
::method delay private
  use strict arg path,wobblePath,base,windowStart,windowEnd
  g=.MLGraph~cartesian3('Audio V9 competing spatial path hypotheses','time_ms','lag_ms','score','TIME','DELAY','CONFIDENCE'); g~putMetadata('audioView','DELAY'); g~putMetadata('semanticSource','graph_paths.tsv'); g~putMetadata('baseEpochMs',base); self~putWindowMetadata(g,windowStart,windowEnd)
  groups=.directory~new; do k over .array~of('ENVELOPE','DIRECT','REFINED'); groups[k]=.array~new; end
  call stream path,'C','OPEN READ'; header=linein(path)
  do while lines(path)>0
    line=linein(path); if line='' then iterate; f=line~makeArray('09'x); if f~items<>8 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad graph path row width',f~items); end
    if \groups~hasIndex(f[4]) then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('unknown spatial path hypothesis',f[4]); end
    absolute=base+(f[3]+0); if \self~selected(absolute,absolute+1,windowStart,windowEnd) then iterate
    v=.directory~new; v['time_ms']=f[3]+0; v['lag_ms']=f[5]+0; v['score']=f[6]+0; groups[f[4]]~append(.MLGraphPoint~new(v,line))
  end
  call stream path,'C','CLOSE'
  if groups['ENVELOPE']~items>0 then g~addSeries(.MLGraphSeries~new('Envelope lag',groups['ENVELOPE'],'SECONDARY',.false,'graph_paths.tsv','ENVELOPE'))
  if groups['DIRECT']~items>0 then g~addSeries(.MLGraphSeries~new('Direct residual lag',groups['DIRECT'],'REFERENCE',.false,'graph_paths.tsv','DIRECT'))
  if groups['REFINED']~items>0 then g~addSeries(.MLGraphSeries~new('Refined lag',groups['REFINED'],'PRIMARY',.false,'graph_paths.tsv','REFINED'))
  if stream(wobblePath,'C','QUERY EXISTS')<>'' then do
    call stream wobblePath,'C','OPEN READ'; wh=linein(wobblePath); row=''; if lines(wobblePath)>0 then row=linein(wobblePath); call stream wobblePath,'C','CLOSE'
    if row<>'' then do; f=row~makeArray('09'x); if f[1]='ACTIVE' then g~addAnnotation(.MLGraphAnnotation~summary('scope=CHUNK; active-model='||f[2]||'; baselineRmsMs='||f[4]||'; distanceToFit='||f[6]||'; normalized='||f[7]||'; minimalSets='||f[8],row)); else g~addAnnotation(.MLGraphAnnotation~summary('scope=CHUNK; delay-wobble='||f[1]||'; observations='||f[3],row)); end
  end
  return g
::method reconstruction private
  use strict arg path,sampleRate,base,windowStart,windowEnd
  g=.MLGraph~cartesian3('Audio V9 source-conditioned reconstruction','time_ms','frequency_hz','gain','TIME','FREQUENCY','GAIN'); g~putMetadata('audioView','RECONSTRUCTION'); g~putMetadata('sampleRate',sampleRate); g~putMetadata('semanticSource','tf_mask.tsv'); g~putMetadata('baseEpochMs',base); self~putWindowMetadata(g,windowStart,windowEnd)
  call stream path,'C','OPEN READ'; header=linein(path); i=0
  do while lines(path)>0
    line=linein(path); if line='' then iterate; f=line~makeArray('09'x); if f~items<10 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad TF mask graph row width',f~items); end
    localS=1000*(f[1]+0)/sampleRate; localE=1000*(f[2]+0)/sampleRate; absoluteS=base+localS; absoluteE=base+localE
    if \self~selected(absoluteS,absoluteE,windowStart,windowEnd) then iterate
    i=i+1; pts=.array~new
    v=.directory~new; v['time_ms']=localS; v['frequency_hz']=f[3]+0; v['gain']=f[5]+0; pts~append(.MLGraphPoint~new(v,line)); v=.directory~new; v['time_ms']=localE; v['frequency_hz']=f[4]+0; v['gain']=f[5]+0; pts~append(.MLGraphPoint~new(v,line))
    protect=f[6]+0; gain=f[5]+0; role='PRIMARY'; if protect<>0 then role='REFERENCE'; else if gain<1 then role='CONTRAST'; key=f[10]; if f~items>=9 then do; if f[9]<>'' then key='SPEAKER_VOICE'; end
    g~addSeries(.MLGraphSeries~new('MASK_'||right(i,6,'0')||' '||f[8],pts,role,.false,line,key))
  end
  call stream path,'C','CLOSE'; return g
::method roleFor private
  use strict arg kind
  select
    when kind='CONTINUATION' then return 'PRIMARY'
    when kind='ADJACENT_BAND' then return 'NEAR'
    when kind='DIAGONAL_MIGRATION' then return 'DIFFERENCE'
    when kind='DELAYED_RECURRENCE' then return 'SECONDARY'
    otherwise return 'PRIMARY'
  end

::requires 'AudioV9TimeFrequencyReconstruction.cls'
::requires 'AudioV9SpatialEvidence.cls'
::requires 'MLGraph.cls'
