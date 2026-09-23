/* AudioTemporalBandRefinement.rex - replay a promoted parent chain on one neighbouring raw window, then refine rejected bands. */
parse arg sourcePath companionPath corpusPath outDir bridgePath parentConfigPath windowConfigPath shortlist
if words(arg(1))<7 then do
  say 'usage: AudioTemporalBandRefinement.rex SOURCE_WAV COMPANION_WAV CORPUS OUT BRIDGE PARENT_CONFIG WINDOW_CONFIG [SHORTLIST]'; exit 2
end
if shortlist='' then shortlist=16; else shortlist=shortlist+0
if shortlist<1 then shortlist=1
call ensureDir outDir
parentMeta=loadKv(parentConfigPath)
window=loadKv(windowConfigPath)
parent=parentConfig(parentMeta)
parentId=kv(parentMeta,'parent_candidate_id',parentConfigPath)
parentChain=kv(parentMeta,'parent_chain','')
windowId=kv(window,'window_id','WINDOW')
relativeOffset=kv(window,'relative_offset_sec',0)+0
ctx=.AudioSearchNativeContext~new(bridgePath,sourcePath,companionPath,corpusPath)
planFile=value('AUDIO_BAND_PLAN_FILE',,'ENVIRONMENT')
if planFile='' then plans=defaultPlans(); else plans=loadPlans(planFile)
mixEnabled=envNumber('AUDIO_H_VOICE_MIX_ENABLED',1)+0
mixDepth=envNumber('AUDIO_H_VOICE_MIX_POOL_DEPTH',24)+0
mixMinAttenuation=envNumber('AUDIO_H_VOICE_MIX_MIN_ATTENUATION_DB',0)+0
mixPrimaryGain=envNumber('AUDIO_H_VOICE_MIX_PRIMARY_GAIN',1)+0
mixResidualGain=envNumber('AUDIO_H_VOICE_MIX_RESIDUAL_GAIN',1)+0
if mixDepth<2 then mixDepth=2
if mixDepth>64 then mixDepth=64
records=.array~new
baselineConfig=copyConfig(parent)
baselineStats=ctx~evaluate(baselineConfig)
baseline=recordFor('',baselineConfig,baselineStats)
records~append(baseline)

say 'REXX H TEMPORAL REFINE parent='parentId 'window='windowId 'offset='relativeOffset 'plans='plans~items 'sr='ctx~sampleRate 'duration='ctx~duration

do plan over plans
  added=canonicalPlan(plan)
  if added='' then iterate
  c=copyConfig(parent)
  c['reject_bands']=combinePlans(configValue(parent,'reject_bands',''),added)
  st=ctx~evaluate(c)
  records~append(recordFor(added,c,st))
end
records~sortWith(.TemporalBandComparator~new)

/* Build a distinct top-N pool independently of the ordinary materialized
 * shortlist.  H uses this pool only for the derived additive voice mix, so the
 * established ranked outputs and their ordering remain unchanged. */
mixPool=.array~new; mixSeen=.directory~new; poolRank=0
do r over records
  h=r['pcm_hash64']~string
  if mixSeen~hasIndex(h) then iterate
  mixSeen[h]=1; poolRank=poolRank+1; r['pool_rank']=poolRank; mixPool~append(r)
  if poolRank>=mixDepth then leave
end

mixInfo=.nil
if mixEnabled<>0 & mixPool~items>=2 then do
  primary=mixPool[1]
  primaryRms=ctx~rmsDb(primary['config'])
  selected=.nil; selectedRms=1.0E100; selectedAtt=0
  quietest=.nil; quietestRms=1.0E100; quietestAtt=0
  do i=2 to mixPool~items
    candidate=mixPool[i]
    candidateRms=ctx~rmsDb(candidate['config'])
    attenuation=primaryRms-candidateRms
    if candidateRms<quietestRms then do
      quietest=candidate; quietestRms=candidateRms; quietestAtt=attenuation
    end
    if attenuation>=mixMinAttenuation & candidateRms<selectedRms then do
      selected=candidate; selectedRms=candidateRms; selectedAtt=attenuation
    end
  end
  fallback=0
  if selected==.nil then do
    selected=quietest; selectedRms=quietestRms; selectedAtt=quietestAtt; fallback=1
  end
  if selected<>.nil then do
    mixStats=ctx~evaluateAdditiveMix(primary['config'],selected['config'],mixPrimaryGain,mixResidualGain)
    ctx~renderAdditiveMix(primary['config'],selected['config'],outDir'/h_voice_mix.wav',mixPrimaryGain,mixResidualGain)
    ctx~render(selected['config'],outDir'/h_voice_residual.wav')
    mixInfo=.directory~new
    mixInfo['output']='h_voice_mix.wav'; mixInfo['residual_output']='h_voice_residual.wav'
    mixInfo['primary_rank']=primary['pool_rank']; mixInfo['residual_rank']=selected['pool_rank']
    mixInfo['primary_plan']=primary['plan']; mixInfo['residual_plan']=selected['plan']
    mixInfo['primary_rms_db']=primaryRms; mixInfo['residual_rms_db']=selectedRms
    mixInfo['attenuation_db']=selectedAtt; mixInfo['minimum_attenuation_db']=mixMinAttenuation
    mixInfo['fallback_quietest']=fallback; mixInfo['pool_depth']=mixPool~items
    mixInfo['primary_gain']=mixPrimaryGain; mixInfo['residual_gain']=mixResidualGain
    mixInfo['parent_cancel_strength']=configValue(primary['config'],'cancel_strength',0)
    mixInfo['score']=mixStats['score']; mixInfo['pcm_hash64']=mixStats['pcm_hash64']
    do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak'); mixInfo[k]=mixStats[k]; end
  end
end

results=.array~new; seen=.directory~new; rank=0
/* Baseline is always materialized separately even if the numerical shortlist excludes it. */
ctx~render(baselineConfig,outDir'/parent_baseline.wav')
baseline['output']='parent_baseline.wav'
do r over records
  h=r['pcm_hash64']~string
  if seen~hasIndex(h) then iterate
  seen[h]=1; rank=rank+1
  name='h_rank_'||right(rank,2,'0')||'.wav'
  ctx~render(r['config'],outDir'/'name); r['output']=name; results~append(r)
  if rank>=shortlist then leave
end
call writeResults outDir'/temporal_band_results.json',sourcePath,companionPath,parentId,parentChain,parent,window,baseline,records~items,results,mixInfo
call writeReview outDir'/review_candidates.tsv',parentId,parentChain,window,baseline,results
call writeVoiceMix outDir'/voice_mix.tsv',parentId,window,mixInfo
ctx~close
mixText='disabled'; if mixInfo<>.nil then mixText='primary='mixInfo['primary_rank'] 'residual='mixInfo['residual_rank'] 'attenuation_db='mixInfo['attenuation_db']
say 'PASS REXX H TEMPORAL REFINE parent='parentId 'window='windowId 'evaluated='records~items 'shortlist='results~items 'baseline='baseline['score'] 'best='results[1]['score'] 'voice_mix='mixText
exit 0

envNumber: procedure
  use strict arg name,default
  v=value(name,,'ENVIRONMENT')
  if v='' then return default
  if \datatype(v,'N') then raise syntax 88.900 array('invalid numeric H voice-mix environment value',name,v)
  return v+0

loadKv: procedure
  use strict arg path
  d=.directory~new; s=.stream~new(path); s~open('read')
  if s~state<>'READY' then raise syntax 88.900 array('cannot open config',path)
  do while s~lines>0
    line=s~linein
    if line~strip='' | line~strip~left(1)='#' then iterate
    parse var line key '=' value
    key=key~strip
    if key='' then iterate
    d[key]=value~strip
  end
  s~close
  return d

kv: procedure
  use strict arg d,k,default
  if d~hasIndex(k) then return d[k]
  return default

parentConfig: procedure
  use strict arg m
  c=.directory~new
  c['gain_db']=kv(m,'gain_db',24)+0
  c['highpass']=kv(m,'highpass_hz',50)+0
  c['lowpass']=kv(m,'lowpass_hz',3000)+0
  nf=kv(m,'denoise_floor_db','NONE')
  if nf~upper='NONE' | nf='' then c['denoise_nf']=.nil; else c['denoise_nf']=nf+0
  c['echo_delay_ms']=kv(m,'echo_delay_ms',0)+0
  c['echo_gain']=kv(m,'echo_gain',0)+0
  c['cancel_strength']=kv(m,'cancel_strength',0)+0
  c['cancel_tweak_ms']=kv(m,'cancel_tweak_ms',0)+0
  c['compress']=kv(m,'compress',0)+0
  c['compress_ratio']=kv(m,'compress_ratio',2)+0
  c['compress_threshold_db']=kv(m,'compress_threshold_db',-18)+0
  c['reject_bands']=canonicalPlan(kv(m,'reject_bands',''))
  return c

copyConfig: procedure
  use strict arg src
  d=.directory~new
  do k over src; d[k]=src[k]; end
  return d

configValue: procedure
  use strict arg c,k,default
  if c~hasIndex(k) then return c[k]
  return default

recordFor: procedure
  use strict arg plan,c,st
  r=.directory~new; r['plan']=plan; r['config']=c; r['score']=st['score']; r['pcm_hash64']=st['pcm_hash64']
  do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak'); r[k]=st[k]; end
  return r

defaultPlans: procedure
  p=.array~new
  do x over .array~of('', '0-60','0-70','0-80','0-90','0-110','0-130','120-180','180-260','260-360','360-500','500-700','700-950','950-1250','1250-1650','1650-2150','2150-2800','2800-3600','3600-4600','4600-6000','5200-7900','6000-7900','6500-7900','0-70;5200-7900','0-80;5200-7900','0-90;5200-7900','0-110;5200-7900','0-80;4600-6000','0-80;950-1250','0-80;1650-2150','0-80;2800-3600','180-260;950-1250','180-260;1650-2150','500-700;2150-2800','700-950;2800-3600','950-1250;2800-3600','0-80;180-260;4600-6000','0-80;950-1250;4600-6000','0-80;1650-2150;4600-6000','180-260;950-1250;2800-3600')
    p~append(x)
  end
  return p

loadPlans: procedure
  use strict arg path
  p=.array~new; s=.stream~new(path); s~open('read')
  do while s~lines>0
    line=s~linein~strip
    if line='' | line~left(1)='#' then iterate
    if line~upper='NONE' then line=''
    p~append(canonicalPlan(line))
  end
  s~close
  if p~items=0 then p~append('')
  return p

combinePlans: procedure
  use strict arg a,b
  a=canonicalPlan(a); b=canonicalPlan(b)
  if a='' then return b
  if b='' then return a
  return canonicalPlan(a||';'||b)

canonicalPlan: procedure
  use strict arg plan
  plan=plan~strip
  if plan='' | plan~upper='NONE' then return ''
  out=''; count=0
  do token over plan~makeArray(';')
    token=token~strip
    if token='' then iterate
    parse var token lo '-' hi
    lo=lo~strip; hi=hi~strip
    if lo='' | hi='' then raise syntax 88.900 array('invalid band plan token; expected LOW-HIGH',token)
    lo=lo+0; hi=hi+0
    if lo<0 | hi<=lo then raise syntax 88.900 array('invalid band plan bounds',token)
    count=count+1
    if count>6 then raise syntax 88.900 array('at most six rejected bands are supported',plan)
    if out<>'' then out=out||';'
    out=out||canonicalNumber(lo)||'-'||canonicalNumber(hi)
  end
  return out

canonicalNumber: procedure
  use strict arg v
  s=v~string
  if s~left(1)='.' then return '0'||s
  if s~left(2)='-.' then return '-0'||s~substr(2)
  return s

ensureDir: procedure
  use strict arg path
  address system 'mkdir -p -- 'shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot create output directory',path)
  return
shellQuote: procedure
  use strict arg v
  return "'"||v~changeStr("'","'\\''")||"'"

writeResults: procedure
  use strict arg path,source,companion,parentId,parentChain,parent,window,baseline,evaluated,results,mixInfo
  s=.stream~new(path); s~open('write replace')
  s~lineout('{')
  s~lineout('  "schema": "audio.temporal.band.refinement/1",')
  s~lineout('  "engine": "ooRexx native Strategy H temporal parent-chain replay + multi-band reject refinement",')
  s~lineout('  "python_execution": false,')
  s~lineout('  "parent_candidate_id": 'jstr(parentId)',')
  s~lineout('  "parent_chain": 'jstr(parentChain)',')
  s~lineout('  "parent_config": 'configJson(parent)',')
  s~lineout('  "source": 'jstr(source)',')
  s~lineout('  "companion": 'jstr(companion)',')
  s~lineout('  "window": {"id": 'jstr(kv(window,'window_id',''))', "relative_offset_sec": 'jnum(kv(window,'relative_offset_sec',0))', "source_start_sec": 'jnum(kv(window,'source_start_sec',0))', "source_duration_sec": 'jnum(kv(window,'source_duration_sec',180))', "companion_start_sec": 'jnum(kv(window,'companion_start_sec',0))', "companion_duration_sec": 'jnum(kv(window,'companion_duration_sec',210))'},')
  s~lineout('  "quality_targets": {"set": "AUDIO-QUALITY-TARGETS-V2", "corpus": "QUALITY_CORPUS.tsv", "target_count": 4, "score_compatibility": "NOT_COMPARABLE_WITH_PRE_V2_REFERENCE_PROFILE"},')
  s~lineout('  "objective_status": "UNQUALIFIED_PENDING_HUMAN_REVIEW",')
  s~lineout('  "baseline_score": 'baseline['score']',')
  s~lineout('  "evaluated_plan_count": 'evaluated',')
  if mixInfo==.nil then s~lineout('  "additive_voice_mix": null,')
  else s~lineout('  "additive_voice_mix": 'mixJson(mixInfo)',')
  s~lineout('  "results": [')
  do i=1 to results~items
    r=results[i]; comma=','; if i=results~items then comma=''
    improvement=baseline['score']-r['score']
    s~lineout('    {"rank": 'i', "score": 'r['score']', "score_improvement_vs_parent_chain_baseline": 'improvement', "added_reject_bands": 'jstr(r['plan'])', "effective_reject_bands": 'jstr(configValue(r['config'],'reject_bands',''))', "pcm_hash64": 'jstr(r['pcm_hash64']~string)', "output": 'jstr(r['output'])', "evidence": {"global_distance": 'r['global_distance']', "window_median_distance": 'r['window_median_distance']', "window_p25_distance": 'r['window_p25_distance']', "temporal_distance": 'r['temporal_distance']', "silence_fraction": 'r['silence_fraction']', "pre_limiter_over_fraction": 'r['pre_limiter_over_fraction']', "post_limiter_clip_fraction": 'r['post_limiter_clip_fraction']'}}'comma)
  end
  s~lineout('  ]'); s~lineout('}'); s~close
  return

writeReview: procedure
  use strict arg path,parentId,parentChain,window,baseline,results
  tab='09'x; s=.stream~new(path); s~open('write replace')
  s~lineout('candidate_id'||tab||'lane_id'||tab||'rank'||tab||'score'||tab||'material_ref'||tab||'pcm_hash64'||tab||'objective_id'||tab||'chain')
  wid=kv(window,'window_id','WINDOW'); off=canonicalNumber(kv(window,'relative_offset_sec',0)+0)
  baseId='h:'||wid||':baseline:'||baseline['pcm_hash64']~string
  baseChain='parent='||parentId||' -> temporal_offset='||off||'s -> parent-chain-baseline ['||parentChain||']'
  s~lineout(baseId||tab||'ed209h:H'||tab||0||tab||canonicalNumber(baseline['score'])||tab||'parent_baseline.wav'||tab||baseline['pcm_hash64']~string||tab||'quality-target-distance'||tab||baseChain)
  do i=1 to results~items
    r=results[i]; cid='h:'||wid||':'||r['pcm_hash64']~string
    chain='parent='||parentId||' -> temporal_offset='||off||'s -> parent-chain ['||parentChain||'] -> added_reject=['||r['plan']||']Hz'
    s~lineout(cid||tab||'ed209h:H'||tab||i||tab||canonicalNumber(r['score'])||tab||r['output']||tab||r['pcm_hash64']~string||tab||'quality-target-distance'||tab||chain)
  end
  s~close
  return

writeVoiceMix: procedure
  use strict arg path,parentId,window,m
  tab='09'x; s=.stream~new(path); s~open('write replace')
  s~lineout('parent_candidate_id'||tab||'window_id'||tab||'relative_offset_sec'||tab||'output'||tab||'primary_rank'||tab||'residual_rank'||tab||'primary_rms_db'||tab||'residual_rms_db'||tab||'attenuation_db'||tab||'minimum_attenuation_db'||tab||'parent_cancel_strength'||tab||'residual_added_reject_bands'||tab||'mix_score'||tab||'pcm_hash64'||tab||'fallback_quietest')
  if m<>.nil then s~lineout(parentId||tab||kv(window,'window_id','WINDOW')||tab||canonicalNumber(kv(window,'relative_offset_sec',0)+0)||tab||m['output']||tab||m['primary_rank']||tab||m['residual_rank']||tab||canonicalNumber(m['primary_rms_db'])||tab||canonicalNumber(m['residual_rms_db'])||tab||canonicalNumber(m['attenuation_db'])||tab||canonicalNumber(m['minimum_attenuation_db'])||tab||canonicalNumber(m['parent_cancel_strength'])||tab||m['residual_plan']||tab||canonicalNumber(m['score'])||tab||m['pcm_hash64']~string||tab||m['fallback_quietest'])
  s~close
  return

mixJson: procedure
  use strict arg m
  if m==.nil then return 'null'
  if m['fallback_quietest'] then fallback='true'; else fallback='false'
  return '{"schema": "audio.h.additive.voice-mix/1", "selection": "rank-1-plus-quietest-top24-residual", "pool_depth": 'm['pool_depth']', "primary_rank": 'm['primary_rank']', "residual_rank": 'm['residual_rank']', "primary_added_reject_bands": 'jstr(m['primary_plan'])', "residual_added_reject_bands": 'jstr(m['residual_plan'])', "primary_rms_db": 'canonicalNumber(m['primary_rms_db'])', "residual_rms_db": 'canonicalNumber(m['residual_rms_db'])', "attenuation_db": 'canonicalNumber(m['attenuation_db'])', "minimum_attenuation_db": 'canonicalNumber(m['minimum_attenuation_db'])', "parent_cancel_strength": 'canonicalNumber(m['parent_cancel_strength'])', "fallback_quietest": 'fallback', "primary_gain": 'canonicalNumber(m['primary_gain'])', "residual_gain": 'canonicalNumber(m['residual_gain'])', "final_limiter": "sample-local-.88-.98-no-normalization", "output": 'jstr(m['output'])', "residual_output": 'jstr(m['residual_output'])', "score": 'canonicalNumber(m['score'])', "pcm_hash64": 'jstr(m['pcm_hash64']~string)', "evidence": {"global_distance": 'canonicalNumber(m['global_distance'])', "window_median_distance": 'canonicalNumber(m['window_median_distance'])', "window_p25_distance": 'canonicalNumber(m['window_p25_distance'])', "temporal_distance": 'canonicalNumber(m['temporal_distance'])', "silence_fraction": 'canonicalNumber(m['silence_fraction'])', "pre_limiter_over_fraction": 'canonicalNumber(m['pre_limiter_over_fraction'])', "post_limiter_clip_fraction": 'canonicalNumber(m['post_limiter_clip_fraction'])'}}'

configJson: procedure
  use strict arg c
  nf=configValue(c,'denoise_nf',.nil); if nf==.nil then nfj='null'; else nfj=canonicalNumber(nf)
  if configValue(c,'compress',0) then coj='true'; else coj='false'
  return '{"gain_db": 'canonicalNumber(configValue(c,'gain_db',24))', "highpass_hz": 'canonicalNumber(configValue(c,'highpass',50))', "lowpass_hz": 'canonicalNumber(configValue(c,'lowpass',3000))', "denoise_floor_db": 'nfj', "echo_delay_ms": 'canonicalNumber(configValue(c,'echo_delay_ms',0))', "echo_gain": 'canonicalNumber(configValue(c,'echo_gain',0))', "cancel_strength": 'canonicalNumber(configValue(c,'cancel_strength',0))', "cancel_tweak_ms": 'canonicalNumber(configValue(c,'cancel_tweak_ms',0))', "compress": 'coj', "compress_ratio": 'canonicalNumber(configValue(c,'compress_ratio',2))', "compress_threshold_db": 'canonicalNumber(configValue(c,'compress_threshold_db',-18))', "reject_bands": 'jstr(configValue(c,'reject_bands',''))'}'

jnum: procedure
  use strict arg x
  if x==.nil then return 'null'
  return canonicalNumber(x+0)
jstr: procedure
  use strict arg x
  if x==.nil then return 'null'
  t=x~string; t=t~changeStr('\\','\\\\')~changeStr('"','\\"')~changeStr('0a'x,'\\n')~changeStr('0d'x,'\\r')
  return '"'||t||'"'

::class TemporalBandComparator public
::method compare
  use strict arg a,b
  if a['score']<b['score'] then return -1
  if a['score']>b['score'] then return 1
  return 0

::requires 'AudioSearchNative.cls'
