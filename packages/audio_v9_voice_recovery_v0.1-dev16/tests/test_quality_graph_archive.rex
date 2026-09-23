numeric digits 30
assertions=0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
base=63832500000000
schema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(24,48,1,4,10,.false,.false),'AUDIO-V9-SPECTRAL-BOX/1')
chars=.array~new
do ti=0 to 3
  t=ti*250
  do b=1 to 3
    vals=.array~of(1+b+t/1000,2+b,4+t/500,3+b/2,5+t/1000,4,6+b,3)
    h=schema~encode(vals)
    box=.AudioV9SpectralBoxEvidence~new(t,t+1000,b,b*400,b*400+300,b*400+150,8,-50+b,8,1,.8,.9,.6,3,h,h,'MOVING_STRUCTURED_BOX')
    chars~append(.AudioV9BoxCharacter~new('FC|'||(base+t)||'|B'||b,base+t,'FC',box,.nil))
  end
end
analysis=.AudioV9AcousticAnalysis~new(chars,.array~new,.array~new,.array~new)
scan=.AudioV9SpatialScan~new(makeScan())
mask=.AudioV9TfMaskPlan~new
mask~append(.AudioV9TfMaskRow~new(0,8000,300,600,1.18,.true,.8,'VOICE','SPEAKER_0001','SPEAKER_VOICE',chars[1]~id))
mask~append(.AudioV9TfMaskRow~new(8000,16000,1800,2400,.45,.false,1,'ALARM','','CONFIRMED_ALARM',chars[2]~id))
built=.AudioV9QualityGraphBuilder~new~build(analysis,scan,mask,base,8000,'TEST')
bundle=built[1]; rel=built[2]
call ok bundle~items=4,'four diagnostic views'
call ok bundle~graph('FIELD')~seriesCount=3,'field grouped by band'
call ok bundle~graph('RELATIONS')~seriesCount=38,'all semantic relations exposed'
call ok bundle~graph('DELAY')~seriesCount=3,'three competing delay series'
call ok bundle~graph('DELAY')~annotationCount=1,'wobble active-model annotation'
call ok bundle~graph('RECONSTRUCTION')~seriesCount=2,'mask decisions exposed'
call ok bundle~graph('RECONSTRUCTION')~seriesAt(1)~point(1)~evidence~pos(chars[1]~id)>0,'reconstruction point retains character provenance'
archive=root||'/run/test/quality_graphs.tsv'; bundle~writeArchive(archive)
call ok stream(archive,'C','QUERY SIZE')>1000,'graph archive written'
copy=.AudioV9MLGraphArchive~new~read(archive)
call ok copy~items=4,'archive restores four views'
do id over bundle~ids
  g1=bundle~graph(id); g2=copy~graph(id)
  call ok g1~seriesCount=g2~seriesCount,'series count roundtrip '||id
  call ok g1~annotationCount=g2~annotationCount,'annotation count roundtrip '||id
  call ok g1~metadata('audioView','')=g2~metadata('audioView',''),'view metadata roundtrip '||id
end
say 'PASS test_quality_graph_archive assertions='||assertions||' archive='||archive||' edges='||rel~edgeCount
exit 0
makeScan:
  tab='09'x; nl='0A'x
  text='AUDIO_V9_SPATIAL_SCAN/1'||nl
  do i=1 to 3
    start=(i-1)*4000; lag=80+(i-2)*.5
    fields='SAMPLES=64000'||tab||'SR=8000'||tab||'RMS_A=.02'||tab||'RMS_B=.018'||tab||'PEAK_A=.08'||tab||'PEAK_B=.07'||tab||'CREST_A=4'||tab||'CREST_B=4'||tab||'RATIO_DB=1'||tab||'ENV_LAG_SAMPLES='||(lag*8)||tab||'ENV_LAG_MS='||lag||tab||'ENV_SCORE=2'||tab||'DIRECT_LAG_SAMPLES=4'||tab||'DIRECT_LAG_MS=.5'||tab||'DIRECT_SCORE=1.5'||tab||'DIRECT_COHERENCE=.3'||tab||'REFINED_LAG_SAMPLES='||(lag*8)||tab||'REFINED_LAG_MS='||lag||tab||'REFINED_SCORE=2.5'||tab||'REFINED_COHERENCE=.4'
    text=text||'W'||tab||i||tab||(start*8)||tab||start||tab||fields||nl
  end
  return text
ok: procedure expose assertions
  parse arg cond,msg; assertions=assertions+1; if \cond then do; say 'FAIL '||msg; exit 1; end; return
::requires 'AudioV9EvidenceGraph.cls'
