numeric digits 30
assertions=0
base=63832500000000
schema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(24,48,1,4,10,.false,.false),'AUDIO-V9-SPECTRAL-BOX/1')
chars=.array~new; serial=1
do ti=0 to 3
  t=ti*250
  do b=1 to 3
    vals=.array~of(1+b+t/1000,2+b,4+t/500,3+b/2,5+t/1000,4,6+b,3)
    h=schema~encode(vals)
    box=.AudioV9SpectralBoxEvidence~new(t,t+1000,b,b*400,b*400+300,b*400+150,8,-50+b,8,1.0+b/10,.8+b/20,.9+b/30,.6,3,h,h,'MOVING_STRUCTURED_BOX')
    id='FC|'||(base+t)||'|B'||b
    chars~append(.AudioV9BoxCharacter~new(id,base+t,'FC',box,.nil)); serial=serial+1
  end
end
rel=.AudioV9SpectralRelationBuilder~new(schema)~build(chars,'TEST_SHARD')
call ok rel~characters~items=12,'twelve boxes retained'
call ok rel~count('CONTINUATION')=9,'continuation topology 9'
call ok rel~count('ADJACENT_BAND')=8,'adjacent topology 8'
call ok rel~count('DIAGONAL_MIGRATION')=12,'diagonal topology 12'
call ok rel~count('DELAYED_RECURRENCE')=9,'delayed topology 9'
call ok rel~edgeCount=38,'total topology 38'
do e over rel~edges
  call ok e~ownerStartMs=e~source~absoluteStartMs,'source start owns edge'
  call ok e~difference~isA(.MLPatternHashDifference),'edge retains ML pattern difference'
end
out=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')||'/run/test/evidence_graph_edges.tsv'
rel~write(out); call ok stream(out,'C','QUERY SIZE')>100,'edge evidence written'
say 'PASS test_evidence_graph assertions='||assertions||' edges='||rel~edgeCount
exit 0
ok: procedure expose assertions
  parse arg cond,msg; assertions=assertions+1; if \cond then do; say 'FAIL '||msg; exit 1; end; return
::requires 'AudioV9EvidenceGraph.cls'
