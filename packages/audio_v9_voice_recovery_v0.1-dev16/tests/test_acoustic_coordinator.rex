numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
tmp=root||'/run/test/acoustic_coord'; call directory root||'/run/test'
f1=tmp||'_a.tracks.tsv'; f2=tmp||'_b.tracks.tsv'
header='track_id'||'09'x||'feed'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'members'||'09'x||'motion'||'09'x||'turn'||'09'x||'active'||'09'x||'width'||'09'x||'coherence'||'09'x||'crest'||'09'x||'lag_abs_ms'||'09'x||'ratio_db'||'09'x||'center_hz'
call stream f1,'C','OPEN WRITE REPLACE'; call lineout f1,header
call lineout f1,row('TRACK_1','FC',1000,2000,4,2.0,2.4,.62,5.1,.72,4.5,120,1.0,420)
call lineout f1,row('TRACK_2','FD',3000,4000,3,11,15,.95,18,.05,12,8,18,2750)
call stream f1,'C','CLOSE'
call stream f2,'C','OPEN WRITE REPLACE'; call lineout f2,header
call lineout f2,row('TRACK_1','FD',11000,12000,4,2.04,2.38,.62,5.2,.70,4.6,121,1.1,425)
call stream f2,'C','CLOSE'

r=.AudioV9AcousticTrackTsvReader~new~read(f1,'chunkA')
call assert r~items=2,'reader retains both track summaries'
call assert r[1]~id='chunkA:TRACK_1','reader namespaces repeated local track ids by origin'
call assert r[1]~feed='FC' & r[1]~meanLagAbs=120,'reader retains feed and spatial lag statistics'

s1=spec('chunkA',f1); s2=spec('chunkB',f2)
c=.AudioV9CampaignAcousticCoordinator~new
a=c~fromTrackFiles(.array~of(s1,s2)); b=c~fromTrackFiles(.array~of(s2,s1))
call assert a~tracks~items=3,'campaign coordinator retains every immutable appearance'
call assert a~families~items=2,'compatible repeated source merges while distant source remains separate'
call assert a~families[1]~tracks~items=2,'first recurring family spans chunk origins'
call assert a~families~items=b~families~items,'campaign family count independent of input file order'
call assert familyMap(a)=familyMap(b),'campaign family membership independent of input file order'
call assert speakerMap(a)=speakerMap(b),'campaign anonymous speaker membership independent of input file order'

prefix=tmp||'_out'; files=a~write(prefix)
call assert files~items=3 & stream(prefix||'.source_appearances.tsv','C','QUERY EXISTS')<>'' & stream(prefix||'.speakers.tsv','C','QUERY EXISTS')<>'','campaign coordinator writes family, appearance and speaker evidence'

say 'PASS test_acoustic_coordinator assertions=10'
exit 0

row: procedure
  use strict arg id,feed,s,e,n,motion,turn,active,width,coh,crest,lag,ratio,center
  return id||'09'x||feed||'09'x||s||'09'x||e||'09'x||n||'09'x||motion||'09'x||turn||'09'x||active||'09'x||width||'09'x||coh||'09'x||crest||'09'x||lag||'09'x||ratio||'09'x||center
spec: procedure
  use strict arg origin,path
  d=.directory~new; d~put(origin,'origin'); d~put(path,'path'); return d
familyMap: procedure
  use strict arg analysis
  text=''
  do f over analysis~families
    ids=.array~new; do t over f~tracks; ids~append(t~id); end; ids~sort
    text=text||f~id||'='; do id over ids; text=text||id||','; end; text=text||';'
  end
  return text
speakerMap: procedure
  use strict arg analysis
  text=''
  do sp over analysis~speakers
    ids=.array~new; do f over sp~families; ids~append(f~id); end; ids~sort
    text=text||sp~id||'='; do id over ids; text=text||id||','; end; text=text||';'
  end
  return text
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return

::requires 'AudioV9AcousticCoordinator.cls'
