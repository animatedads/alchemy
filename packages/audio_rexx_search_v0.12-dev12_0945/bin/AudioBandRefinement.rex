/* AudioBandRefinement.rex - second-stage native band-reject refinement of a voice-positive WAV. */
parse arg sourcePath corpusPath outDir bridgePath parentId shortlist
if words(arg(1))<4 then do
  say 'usage: AudioBandRefinement.rex SOURCE_WAV CORPUS OUT BRIDGE [PARENT_ID] [SHORTLIST]'; exit 2
end
if parentId='' then parentId=sourcePath
if shortlist='' then shortlist=12; else shortlist=shortlist+0
if shortlist<1 then shortlist=1
call ensureDir outDir
ctx=.AudioSearchNativeContext~new(bridgePath,sourcePath,sourcePath,corpusPath)
planFile=value('AUDIO_BAND_PLAN_FILE',,'ENVIRONMENT')
if planFile='' then plans=defaultPlans(); else plans=loadPlans(planFile)
records=.array~new; baseline=.nil
say 'REXX BAND REFINEMENT source='sourcePath 'plans='plans~items 'sr='ctx~sampleRate 'duration='ctx~duration

do plan over plans
  canonical=canonicalPlan(plan)
  c=neutralConfig(canonical)
  st=ctx~evaluate(c)
  r=.directory~new; r['plan']=canonical; r['config']=c; r['score']=st['score']; r['pcm_hash64']=st['pcm_hash64']
  do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak'); r[k]=st[k]; end
  records~append(r)
  if canonical='' then baseline=r
end
if baseline==.nil then do
  c=neutralConfig(''); st=ctx~evaluate(c); baseline=.directory~new; baseline['plan']=''; baseline['config']=c; baseline['score']=st['score']; baseline['pcm_hash64']=st['pcm_hash64']
  do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak'); baseline[k]=st[k]; end
  records~append(baseline)
end
records~sortWith(.BandRefineComparator~new)
results=.array~new; seen=.directory~new; rank=0
do r over records
  h=r['pcm_hash64']~string
  if seen~hasIndex(h) then iterate
  seen[h]=1; rank=rank+1
  name='band_rank_'||right(rank,2,'0')||'.wav'
  ctx~render(r['config'],outDir'/'name); r['output']=name; results~append(r)
  if rank>=shortlist then leave
end
call writeResults outDir'/band_results.json',sourcePath,parentId,baseline,records~items,results
call writeReview outDir'/review_candidates.tsv',parentId,results
ctx~close
say 'PASS REXX BAND REFINEMENT evaluated='records~items 'shortlist='results~items 'baseline='baseline['score'] 'best='results[1]['score']
exit 0

neutralConfig: procedure
  use strict arg plan
  c=.directory~new
  c['gain_db']=0; c['highpass']=0; c['lowpass']=0; c['denoise_nf']=.nil
  c['echo_delay_ms']=0; c['echo_gain']=0; c['cancel_strength']=0; c['cancel_tweak_ms']=0
  c['compress']=0; c['compress_ratio']=2; c['compress_threshold_db']=-18; c['reject_bands']=plan
  return c

defaultPlans: procedure
  p=.array~new
  do x over .array~of('', '0-70','0-90','0-120','120-180','180-260','260-360','360-500','500-700','700-950','950-1250','1250-1650','1650-2150','2150-2800','2800-3600','3600-4600','4600-6000','5500-7900','6500-7900','0-80;5000-7900','0-100;4500-7900','180-260;950-1250','950-1250;2800-3600','500-700;2150-2800','180-260;1650-2150;4600-6000')
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
  use strict arg path,source,parentId,baseline,evaluated,results
  s=.stream~new(path); s~open('write replace')
  s~lineout('{')
  s~lineout('  "schema": "audio.band.refinement/1",')
  s~lineout('  "engine": "ooRexx native multi-band reject refinement",')
  s~lineout('  "python_execution": false,')
  s~lineout('  "source": 'jstr(source)',')
  s~lineout('  "parent_candidate_id": 'jstr(parentId)',')
  s~lineout('  "filter_semantics": "up to six sequential rejected bands; each interior band is reconstructed as low-pass below LOW plus high-pass above HIGH; outer bands reduce to high-pass/low-pass",')
  s~lineout('  "objective_status": "UNQUALIFIED_PENDING_HUMAN_REVIEW",')
  s~lineout('  "baseline_score": 'baseline['score']',')
  s~lineout('  "evaluated_plan_count": 'evaluated',')
  s~lineout('  "results": [')
  do i=1 to results~items
    r=results[i]; comma=','; if i=results~items then comma=''
    improvement=baseline['score']-r['score']
    s~lineout('    {"rank": 'i', "score": 'r['score']', "score_improvement_vs_baseline": 'improvement', "reject_bands": 'jstr(r['plan'])', "pcm_hash64": 'jstr(r['pcm_hash64']~string)', "output": 'jstr(r['output'])', "evidence": {"global_distance": 'r['global_distance']', "window_median_distance": 'r['window_median_distance']', "window_p25_distance": 'r['window_p25_distance']', "temporal_distance": 'r['temporal_distance']', "silence_fraction": 'r['silence_fraction']', "pre_limiter_over_fraction": 'r['pre_limiter_over_fraction']', "post_limiter_clip_fraction": 'r['post_limiter_clip_fraction']'}}'comma)
  end
  s~lineout('  ]'); s~lineout('}'); s~close
  return

writeReview: procedure
  use strict arg path,parentId,results
  tab='09'x; s=.stream~new(path); s~open('write replace')
  s~lineout('candidate_id'||tab||'lane_id'||tab||'rank'||tab||'score'||tab||'material_ref'||tab||'pcm_hash64'||tab||'objective_id'||tab||'chain')
  do i=1 to results~items
    r=results[i]; cid='bandrefine:'||r['pcm_hash64']~string
    chain='parent='||parentId||' -> reject=['||r['plan']||']Hz'
    s~lineout(cid||tab||'band-refinement'||tab||i||tab||canonicalNumber(r['score'])||tab||r['output']||tab||r['pcm_hash64']~string||tab||'quality-target-distance'||tab||chain)
  end
  s~close
  return

jstr: procedure
  use strict arg x
  if x==.nil then return 'null'
  t=x~string; t=t~changeStr('\\','\\\\')~changeStr('"','\\"')~changeStr('0a'x,'\\n')~changeStr('0d'x,'\\r')
  return '"'||t||'"'

::class BandRefineComparator public
::method compare
  use strict arg a,b
  if a['score']<b['score'] then return -1
  if a['score']>b['score'] then return 1
  return 0

::requires 'AudioSearchNative.cls'
