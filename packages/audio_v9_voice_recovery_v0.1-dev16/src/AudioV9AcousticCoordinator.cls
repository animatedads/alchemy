/* AudioV9AcousticCoordinator.cls
 * dev2: deterministic campaign-level merge of immutable per-chunk acoustic
 * track summaries into recurring source families.  Labels remain external
 * evidence; this coordinator never infers a real-world person identity.
 */
::options numeric inherit

::class AudioV9TrackSummary public
::method init
  expose id localId origin feed startMs endMs members motion turn active width coherence crest lag ratio center closeCache
  use strict arg idValue,localIdValue,originValue,feedValue,startValue,endValue,membersValue,motionValue,turnValue,activeValue,widthValue,coherenceValue,crestValue,lagValue,ratioValue,centerValue
  id=idValue~string; localId=localIdValue~string; origin=originValue~string; feed=feedValue~string~upper
  startMs=startValue+0; endMs=endValue+0; members=membersValue+0
  motion=motionValue+0; turn=turnValue+0; active=activeValue+0; width=widthValue+0; coherence=coherenceValue+0
  crest=crestValue+0; lag=lagValue+0; ratio=ratioValue+0; center=centerValue+0; closeCache=.directory~new
::method id; expose id; return id
::method localId; expose localId; return localId
::method origin; expose origin; return origin
::method feed; expose feed; return feed
::method startMs; expose startMs; return startMs
::method endMs; expose endMs; return endMs
::method items; expose members; return members
::method durationMs; expose startMs endMs; return endMs-startMs
::method meanResidualMotion; expose motion; return motion
::method meanTurn; expose turn; return turn
::method meanActive; expose active; return active
::method meanWidth; expose width; return width
::method meanCoherence; expose coherence; return coherence
::method meanCrest; expose crest; return crest
::method meanLagAbs; expose lag; return lag
::method meanRatioDb; expose ratio; return ratio
::method meanCenterHz; expose center; return center
::method featureVector
  expose motion turn active width coherence crest lag ratio center
  return .array~of(motion,turn,active,width,coherence,crest,lag,ratio,center)
::method closeHash
  expose closeCache
  use strict arg schema
  key=schema~id
  if closeCache~hasIndex(key) then return closeCache[key]
  h=schema~encode(self~featureVector); closeCache[key]=h
  return h
::method temporalHash
  use strict arg schema=.nil
  /* The compact campaign summary intentionally carries no invented temporal
   * series.  Temporal refinement must reopen track_members/characters evidence. */
  return .nil
::method canonicalText
  return 'AUDIO_V9_TRACK_SUMMARY/1|id='||self~id||'|origin='||self~origin||'|local='||self~localId||'|feed='||self~feed||'|time='||self~startMs||'..'||self~endMs||'|members='||self~items

::class AudioV9TrackSummaryComparator private
::method compare
  use strict arg a,b
  if a~startMs<b~startMs then return -1
  if a~startMs>b~startMs then return 1
  if a~id<b~id then return -1
  if a~id>b~id then return 1
  return 0

::class AudioV9AcousticTrackTsvReader public
::method read
  use strict arg path,originValue
  call stream path,'C','OPEN READ'
  header=linein(path)
  expected='track_id'||'09'x||'feed'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'members'||'09'x||'motion'||'09'x||'turn'||'09'x||'active'||'09'x||'width'||'09'x||'coherence'||'09'x||'crest'||'09'x||'lag_abs_ms'||'09'x||'ratio_db'||'09'x||'center_hz'
  if header\==expected then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('unexpected acoustic track TSV schema',path,header); end
  out=.array~new
  do while lines(path)>0
    line=linein(path); if line='' then iterate
    p=line~makeArray('09'x)
    if p~items<>14 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad acoustic track TSV row width',path,p~items); end
    local=p[1]; gid=originValue||':'||local
    out~append(.AudioV9TrackSummary~new(gid,local,originValue,p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11],p[12],p[13],p[14]))
  end
  call stream path,'C','CLOSE'
  return out

::class AudioV9CampaignAcousticAnalysis public
::method init
  expose tracks families speakers
  use strict arg trackValues,familyValues,speakerValues=.nil
  tracks=trackValues~copy; families=familyValues~copy
  if speakerValues==.nil then speakers=.array~new; else speakers=speakerValues~copy
::method tracks; expose tracks; return tracks~copy
::method families; expose families; return families~copy
::method speakers; expose speakers; return speakers~copy
::method write
  expose tracks families speakers
  use strict arg prefix
  ff=prefix||'.source_families.tsv'; af=prefix||'.source_appearances.tsv'; sf=prefix||'.speakers.tsv'
  call stream ff,'C','OPEN WRITE REPLACE'
  call lineout ff,'family_id'||'09'x||'label'||'09'x||'tracks'||'09'x||'voice'||'09'x||'alarm'||'09'x||'impact'||'09'x||'background'||'09'x||'vocalisation'||'09'x||'strongest'
  do f over families
    e=f~evidence
    call lineout ff,f~id||'09'x||f~label||'09'x||f~tracks~items||'09'x||e~voice||'09'x||e~alarm||'09'x||e~impulse||'09'x||e~background||'09'x||e~vocalisation||'09'x||e~strongest
  end
  call stream ff,'C','CLOSE'
  call stream af,'C','OPEN WRITE REPLACE'
  call lineout af,'family_id'||'09'x||'track_id'||'09'x||'origin'||'09'x||'local_track_id'||'09'x||'feed'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'members'
  do f over families
    ft=f~tracks
    do t over ft
      call lineout af,f~id||'09'x||t~id||'09'x||t~origin||'09'x||t~localId||'09'x||t~feed||'09'x||t~startMs||'09'x||t~endMs||'09'x||t~items
    end
  end
  call stream af,'C','CLOSE'
  call stream sf,'C','OPEN WRITE REPLACE'
  call lineout sf,'speaker_id'||'09'x||'family_id'||'09'x||'appearances'
  do sp over speakers
    do f over sp~families
      call lineout sf,sp~id||'09'x||f~id||'09'x||f~tracks~items
    end
  end
  call stream sf,'C','CLOSE'
  return .array~of(ff,af,sf)

::class AudioV9CampaignAcousticCoordinator public
::method init
  expose clusterer reader diarizer
  use strict arg clustererValue=.nil,diarizerValue=.nil
  if clustererValue==.nil then clusterer=.AudioV9SourceFamilyClusterer~new(28,120); else clusterer=clustererValue
  if diarizerValue==.nil then diarizer=.AudioV9AnonymousDiarizer~new(.AudioV9SourceFamilyClusterer~new(22,90,1400)); else diarizer=diarizerValue
  reader=.AudioV9AcousticTrackTsvReader~new
::method fromTrackFiles
  expose clusterer reader diarizer
  use strict arg fileSpecs
  if \fileSpecs~isA(.Array) then raise syntax 88.900 array('campaign acoustic coordinator requires Array of file specs')
  tracks=.array~new
  do spec over fileSpecs
    if \spec~isA(.Directory) then raise syntax 88.900 array('track file spec must be Directory')
    path=spec~at('path'); origin=spec~at('origin')
    if path==.nil | origin==.nil then raise syntax 88.900 array('track file spec requires path and origin')
    rows=reader~read(path,origin)
    do t over rows; tracks~append(t); end
  end
  tracks~sortWith(.AudioV9TrackSummaryComparator~new)
  families=clusterer~cluster(tracks)
  /* Campaign speaker IDs are reconstructed here; local per-chunk speaker IDs
   * are deliberately not semantic authority.  Compact summaries provide the
   * coarse pass; member evidence may refine a candidate later. */
  speakers=diarizer~cluster(families,.45)
  return .AudioV9CampaignAcousticAnalysis~new(tracks,families,speakers)

::requires 'AudioV9AcousticCharacter.cls'
