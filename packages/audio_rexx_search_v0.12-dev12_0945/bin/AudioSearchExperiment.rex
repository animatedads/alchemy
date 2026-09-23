/* AudioSearchExperiment.rex - Rexx-authoritative recovered-audio search. */
parse arg jobPath sourcePath companionPath corpusPath outDir bridgePath
if words(arg(1))<6 then do
  say 'usage: AudioSearchExperiment.rex JOB SOURCE COMPANION CORPUS OUT BRIDGE'; exit 2
end
job=loadJob(jobPath); call ensureDir outDir
strategy=job['strategy']~upper; limit=job['candidate_limit']+0
if value('SEARCH_LIMIT',,'ENVIRONMENT')<>'' then limit=value('SEARCH_LIMIT',,'ENVIRONMENT')+0
ctx=.AudioSearchNativeContext~new(bridgePath,sourcePath,companionPath,corpusPath)
say 'REXX AUDIO SEARCH node='job['node'] 'strategy='strategy 'limit='limit 'sr='ctx~sampleRate 'duration='ctx~duration
align=ctx~alignment
say 'ALIGN offset='align['offset_sec'] 'drift_ppm='align['drift_ppm'] 'correlation='align['correlation']
records=.array~new; cache=.directory~new; runMeta=.directory~new
workspaceGiB=job['workspace_budget_gib']+0; retainCount=job['shortlist_count']+0
workspace=.MLWorkspaceBudget~gib(workspaceGiB,1,workspaceGiB+1,retainCount,'NONE','FAIL_CLOSED')
retention=.MLRetentionPolicy~new(retainCount,'PCM_HASH','PROMOTED_ONLY')
runMeta['workspace_contract']=workspace~canonicalText
runMeta['retention_contract']=retention~canonicalText
if strategy='A' then call runGrid ctx,gridA(),limit,records,cache
else if strategy='B' then call runGrid ctx,gridB(),limit,records,cache
else if strategy='D' then call runGrid ctx,gridD(),limit,records,cache
else if strategy='I' then call runGrid ctx,gridI(),limit,records,cache
else if strategy='C' then call runGA ctx,limit,records,cache,runMeta
else if strategy='E' then call runCheckpointedExploration ctx,limit,records,cache,runMeta,value('AUDIO_SEARCH_STATE_DIR',,'ENVIRONMENT')
else do; say 'unsupported strategy' strategy; ctx~close; exit 3; end
records~sortWith(.AudioRecordComparator~new)
shortlist=retention~retainCount; if shortlist<1 then shortlist=12; if shortlist>records~items then shortlist=records~items
results=.array~new
seen=.directory~new
rank=0
do r over records
  h=r['pcm_hash64']~string
  if seen~hasIndex(h) then iterate
  seen[h]=1; rank=rank+1
  name='rank_'||right(rank,2,'0')||'.wav'; path=outDir'/'name
  ctx~render(r['config'],path); r['output']=name; results~append(r)
  if rank>=shortlist then leave
end
pareto=buildParetoAnalysis(job,results)
call writeResults outDir'/results.json',job,sourcePath,companionPath,align,ctx~sharedDiagnostics,runMeta,records~items,results,pareto
call writeReviewCatalog outDir'/review_candidates.tsv',job,results
call writeCandidateConfigs outDir'/candidate_configs.tsv',job,results
call writeParetoCatalog outDir'/pareto_candidates.tsv',job,results,pareto
ctx~close
say 'PASS REXX AUDIO SEARCH node='job['node'] 'evaluated='records~items 'shortlist='results~items 'best='results[1]['score']
exit 0

loadJob: procedure
  use strict arg path
  d=.directory~new; s=.stream~new(path); s~open('read')
  do while s~lines>0
    line=s~linein~strip; if line='' | line~left(1)='#' then iterate; p=line~pos('='); if p=0 then iterate; d[line~left(p-1)~strip]=line~substr(p+1)~strip
  end
  s~close
  return d
ensureDir: procedure
  use strict arg path
  address system 'mkdir -p -- 'shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot create output directory',path)
  return
shellQuote: procedure
  use strict arg v
  return "'"||v~changeStr("'","'\\''")||"'"

runGrid: procedure
  use strict arg ctx,configs,limit,records,cache
  n=configs~items; if limit<=0 | limit>n then limit=n
  do i=1 to limit
    if limit=1 then idx=1; else idx=1+((i-1)*(n-1)%(limit-1))
    c=configs[idx]; ignored=evaluateOne(ctx,c,records,cache)
    if i//10=0 then say 'GRID evaluated='i'/'limit
  end
  return

evaluateOne: procedure
  use strict arg ctx,c,records,cache
  key=configKey(c)
  if cache~hasIndex(key) then return cache[key]['score']
  st=ctx~evaluate(c); r=.directory~new; r['config']=copyConfig(c); r['score']=st['score']; r['pcm_hash64']=st['pcm_hash64']; r['global_distance']=st['global_distance']; r['window_median_distance']=st['window_median_distance']; r['window_p25_distance']=st['window_p25_distance']; r['temporal_distance']=st['temporal_distance']; r['silence_fraction']=st['silence_fraction']; r['post_limiter_clip_fraction']=st['post_limiter_clip_fraction']; r['pre_limiter_over_fraction']=st['pre_limiter_over_fraction']; r['pre_filter_peak']=st['pre_filter_peak']; r['chain']=chainText(c)
  records~append(r); cache[key]=r; return r['score']

runGA: procedure
  use strict arg ctx,limit,records,cache,runMeta
  requestedLimit=limit
  plan=.MLGABudgetPlan~forCandidateLimit(limit,30,3,4)
  popSize=plan~populationSize
  objective=.MLObjective~new('quality-target-distance','MINIMIZE','0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal + 18*pre_limiter_over + 40*post_limiter_clip + low-silence penalty','quality-target resemblance; lower score is better; artefact weights require perceptual calibration')
  policy=.MLGeneticPolicy~new(.25,.12,.80,2)

  runMeta['requested_limit']=requestedLimit
  runMeta['effective_limit']=limit
  runMeta['population_size']=plan~populationSize
  runMeta['evaluated_population_rounds']=plan~evaluatedGenerations
  runMeta['breeding_steps']=plan~breedingSteps
  runMeta['evaluation_slots']=plan~plannedEvaluationRequests
  runMeta['unused_slots']=plan~unusedBudget
  runMeta['final_population_evaluated']=1
  runMeta['mutation_rate']=policy~mutationRate
  runMeta['mutation_scale']=policy~mutationScale
  runMeta['crossover_rate']=policy~crossoverRate
  runMeta['elite_count']=policy~eliteCount
  runMeta['objective_id']=objective~id
  runMeta['objective_direction']=objective~direction
  runMeta['ga_budget_plan']=plan~canonicalText
  runMeta['ga_policy']=policy~canonicalText
  runMeta['space_a_to_c']=.MLSearchSpaceComparison~compare(sharedSpaceA(),sharedSpaceC())~relation
  runMeta['space_b_to_c']=.MLSearchSpaceComparison~compare(sharedSpaceB(),sharedSpaceC())~relation
  runMeta['space_d_to_c']=.MLSearchSpaceComparison~compare(sharedSpaceD(),sharedSpaceC())~relation

  rng=.MLDeterministicRNG~new(20903,'AUDIO-C-RNG'); cursor=rng~cursor; initial=.array~new
  do i=1 to popSize
    genes=.array~new; do j=1 to 10; genes~append(cursor~nextUnit); end; initial~append(genes)
  end
  ignored=rng~commitCursor(cursor,'AUDIO_INITIAL_POPULATION')
  pop=.MLPopulation~new(initial,'AUDIO-C-POPULATION'); exp=.MLExperiment~new('AUDIO-C-SEARCH')
  ga=.MLGeneticAlgorithm~fromPolicy(pop,policy,rng,exp)
  scoreEvaluator=.AudioGAScoreEvaluator~new(ctx,records,cache)
  evaluator=.MLObjectiveFitnessAdapter~new(objective,scoreEvaluator)
  gaRun=ga~run(evaluator,plan~breedingSteps)
  steps=gaRun~steps
  do g=1 to steps~items
    step=steps[g]
    say 'GA evaluated_population='g'/'plan~evaluatedGenerations 'generation='step['evaluatedGeneration']~populationGeneration 'unique='records~items 'bestFitness='step['evaluatedGeneration']~bestFitness
  end
  finalGeneration=gaRun~finalEvaluation
  say 'GA evaluated_population='plan~evaluatedGenerations'/'plan~evaluatedGenerations 'generation='finalGeneration~populationGeneration 'unique='records~items 'bestFitness='finalGeneration~bestFitness 'FINAL=1'
  runMeta['final_population_generation']=gaRun~finalPopulationGeneration
  runMeta['generation_registry_count']=ga~generationRegistry~count
  return


runCheckpointedExploration: procedure
  use strict arg ctx,limit,records,cache,runMeta,stateDir
  if limit<1 then limit=1
  if stateDir='' then raise syntax 88.900 array('Strategy E requires AUDIO_SEARCH_STATE_DIR')
  call ensureDir stateDir
  seed=20905
  expectedKey=value('AUDIO_SEARCH_RESUME_KEY',,'ENVIRONMENT')
  if expectedKey='' then raise syntax 88.900 array('Strategy E requires AUDIO_SEARCH_RESUME_KEY')
  statePath=stateDir'/exploration.state'; recordsPath=stateDir'/exploration_records.tsv'
  processed=loadExplorationState(statePath,expectedKey,seed)
  if processed>limit then processed=limit
  loaded=loadExplorationRecords(recordsPath,limit,records,cache)
  runMeta['checkpoint_seed']=seed
  runMeta['processed_before_resume']=processed
  runMeta['checkpoint_records_loaded']=loaded
  runMeta['checkpoint_interval_candidates']=1
  runMeta['resume_key']=expectedKey
  runMeta['resume_supported']=1
  runMeta['provisioning_model']='standard'

  rng=.MLDeterministicRNG~new(seed,'AUDIO-E-RNG'); cursor=rng~cursor
  objective=.MLObjective~new('quality-target-distance','MINIMIZE','0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal + 18*pre_limiter_over + 40*post_limiter_clip + low-silence penalty','lower score is better; artefact weights require perceptual calibration')
  evaluator=.AudioGAScoreEvaluator~new(ctx,records,cache)
  do i=1 to limit
    genes=.array~new; do j=1 to 10; genes~append(cursor~nextUnit); end
    if i<=processed then iterate
    genome=.MLGenome~new('E-SLOT-'||i,genes)
    c=evaluator~decodeGenome(genome); key=configKey(c); wasCached=cache~hasIndex(key)
    ignored=evaluator~score(genome)
    if \wasCached then call appendExplorationRecord recordsPath,i,records[records~items]
    call writeExplorationState statePath,expectedKey,seed,i
    call syncExplorationCheckpoint recordsPath,statePath
    if i//10=0 | i=limit then say 'CHECKPOINTED evaluated_slot='i'/'limit 'unique='records~items 'checkpoint='statePath
  end
  ignored=rng~commitCursor(cursor,'AUDIO_E_CHECKPOINTED_EXPLORATION_COMPLETE')
  runMeta['processed_slots']=limit
  runMeta['unique_candidates']=records~items
  return

loadExplorationState: procedure
  use strict arg path,expectedKey,seed
  if \fileExists(path) then return 0
  d=.directory~new; s=.stream~new(path); s~open('read')
  do while s~lines>0
    line=s~linein~strip; if line='' | line~left(1)='#' then iterate
    p=line~pos('='); if p=0 then iterate
    d[line~left(p-1)~strip]=line~substr(p+1)~strip
  end
  s~close
  if \d~hasIndex('resume_key') | d['resume_key']<>expectedKey then raise syntax 88.900 array('Strategy E checkpoint resume key mismatch; reset state before changing package/job/sample inputs')
  if \d~hasIndex('seed') | d['seed']+0<>seed then raise syntax 88.900 array('Strategy E checkpoint seed mismatch')
  if d~hasIndex('processed_slots') then return d['processed_slots']+0
  return 0

loadExplorationRecords: procedure
  use strict arg path,maxSlot,records,cache
  if \fileExists(path) then return 0
  loaded=0; s=.stream~new(path); s~open('read')
  do while s~lines>0
    line=s~linein
    if line='' | line~left(1)='#' then iterate
    f=line~makeArray('09'x)
    if f~items<22 then raise syntax 88.900 array('Malformed Strategy E checkpoint record',line)
    slot=f[1]+0; if slot>maxSlot then iterate
    c=.directory~new
    c['gain_db']=f[2]+0; c['highpass']=f[3]+0; c['lowpass']=f[4]+0
    if f[5]='N' then c['denoise_nf']=.nil; else c['denoise_nf']=f[5]+0
    c['echo_delay_ms']=f[6]+0; c['echo_gain']=f[7]+0; c['cancel_strength']=f[8]+0; c['cancel_tweak_ms']=f[9]+0
    c['compress']=(f[10]='1'); c['compress_ratio']=f[11]+0; c['compress_threshold_db']=f[12]+0
    r=.directory~new; r['config']=copyConfig(c); r['score']=f[13]+0; r['pcm_hash64']=f[14]
    r['global_distance']=f[15]+0; r['window_median_distance']=f[16]+0; r['window_p25_distance']=f[17]+0; r['temporal_distance']=f[18]+0
    r['silence_fraction']=f[19]+0; r['post_limiter_clip_fraction']=f[20]+0; r['pre_limiter_over_fraction']=f[21]+0; r['pre_filter_peak']=f[22]+0; r['chain']=chainText(c)
    key=configKey(c)
    if \cache~hasIndex(key) then do; records~append(r); cache[key]=r; loaded=loaded+1; end
  end
  s~close
  return loaded

appendExplorationRecord: procedure
  use strict arg path,slot,r
  c=r['config']; tab='09'x
  if c~hasIndex('denoise_nf') then do; if c['denoise_nf']==.nil then nf='N'; else nf=c['denoise_nf']~string; end; else nf='N'
  if c~hasIndex('compress') & c['compress'] then comp='1'; else comp='0'
  line=slot||tab||configValue(c,'gain_db',24)||tab||configValue(c,'highpass',50)||tab||configValue(c,'lowpass',3000)||tab||nf||tab||configValue(c,'echo_delay_ms',0)||tab||configValue(c,'echo_gain',0)||tab||configValue(c,'cancel_strength',0)||tab||configValue(c,'cancel_tweak_ms',0)||tab||comp||tab||configValue(c,'compress_ratio',2)||tab||configValue(c,'compress_threshold_db',-18)||tab||r['score']||tab||r['pcm_hash64']||tab||r['global_distance']||tab||r['window_median_distance']||tab||r['window_p25_distance']||tab||r['temporal_distance']||tab||r['silence_fraction']||tab||r['post_limiter_clip_fraction']||tab||r['pre_limiter_over_fraction']||tab||r['pre_filter_peak']
  fresh=\fileExists(path)
  s=.stream~new(path); s~open('write append')
  if fresh then s~lineout('# audio.search.checkpoint.records/2')
  s~lineout(line); s~close
  return

writeExplorationState: procedure
  use strict arg path,resumeKey,seed,processed
  tmp=path'.new'; s=.stream~new(tmp); s~open('write replace')
  s~lineout('schema=audio.search.checkpoint.state/2'); s~lineout('resume_key='resumeKey); s~lineout('seed='seed); s~lineout('processed_slots='processed); s~close
  address system 'mv -f -- 'shellQuote(tmp) shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot publish Strategy E checkpoint state',path)
  return

syncExplorationCheckpoint: procedure
  use strict arg recordsPath,statePath
  helper=value('AUDIO_SEARCH_FSYNC_HELPER',,'ENVIRONMENT')
  if helper='' then raise syntax 88.900 array('Strategy E requires AUDIO_SEARCH_FSYNC_HELPER')
  address system shellQuote(helper) shellQuote(recordsPath) shellQuote(statePath)
  if rc<>0 then raise syntax 88.900 array('Strategy E checkpoint fsync failed',rc)
  return

fileExists: procedure
  use strict arg path
  address system 'test -f 'shellQuote(path)
  return rc=0

sharedSpaceA: procedure
  return .MLSearchSpace~new('A-SHARED',.array~of(,
    .MLParameterDomain~new('gain_db',.array~of(16,18,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,38,40)),,
    .MLParameterDomain~new('highpass',.array~of(40,50,60,70,80,90,110,130,150)),,
    .MLParameterDomain~new('lowpass',.array~of(2400,2600,2800,3000,3200,3400,3600,3800,4000)),,
    .MLParameterDomain~new('denoise_nf',.array~of(999,-45,-40,-35,-32,-30,-28,-25))))
sharedSpaceB: procedure
  return .MLSearchSpace~new('B-SHARED',.array~of(,
    .MLParameterDomain~new('gain_db',.array~of(18,20,22,24,26,28,30,32,34,36,38)),,
    .MLParameterDomain~new('highpass',.array~of(40,50,70,90,120)),,
    .MLParameterDomain~new('lowpass',.array~of(2200,2400,2600,2800,3000,3400)),,
    .MLParameterDomain~new('denoise_nf',.array~of(999,-40,-35,-30))))
sharedSpaceD: procedure
  return .MLSearchSpace~new('D-SHARED',.array~of(,
    .MLParameterDomain~new('gain_db',.array~of(20,22,24,26,28,30,32,34)),,
    .MLParameterDomain~new('highpass',.array~of(40,50,70,90)),,
    .MLParameterDomain~new('lowpass',.array~of(2200,2400,2600,2800,3000)),,
    .MLParameterDomain~new('denoise_nf',.array~of(999,-40,-35,-30))))
sharedSpaceC: procedure
  return .MLSearchSpace~new('C-SHARED',.array~of(,
    .MLParameterDomain~new('gain_db',.array~of(16,18,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,38,40)),,
    .MLParameterDomain~new('highpass',.array~of(40,50,60,70,80,90,110,120,130,150)),,
    .MLParameterDomain~new('lowpass',.array~of(2200,2400,2600,2800,3000,3200,3400,3600,3800,4000)),,
    .MLParameterDomain~new('denoise_nf',.array~of(999,-45,-40,-35,-32,-30,-28,-25))))

gridA: procedure
  out=.array~new
  do g over .array~of(16,18,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,38,40)
    do hp over .array~of(40,50,60,70,80,90,110,130,150)
      do lp over .array~of(2400,2600,2800,3000,3200,3400,3600,3800,4000)
        do nf over .array~of(999,-45,-40,-35,-32,-30,-28,-25)
          c=.directory~new;c['gain_db']=g;c['highpass']=hp;c['lowpass']=lp;if nf=999 then c['denoise_nf']=.nil;else c['denoise_nf']=nf;c['cancel_strength']=0;c['cancel_tweak_ms']=0;c['compress']=0;c['echo_delay_ms']=0;c['echo_gain']=0;out~append(c)
        end
      end
    end
  end
  return out


gridB: procedure
  out=.array~new
  do g over .array~of(18,20,22,24,26,28,30,32,34,36,38)
    do cs over .array~of(.10,.20,.30,.40,.50,.60,.75,1.0)
      do tw over .array~of(-20,-10,-5,0,5,10,20)
        do hp over .array~of(40,50,70,90,120)
          do lp over .array~of(2200,2400,2600,2800,3000,3400)
            do nf over .array~of(999,-40,-35,-30)
              c=.directory~new;c['gain_db']=g;c['highpass']=hp;c['lowpass']=lp;if nf=999 then c['denoise_nf']=.nil;else c['denoise_nf']=nf;c['cancel_strength']=cs;c['cancel_tweak_ms']=tw;c['compress']=0;c['echo_delay_ms']=0;c['echo_gain']=0;out~append(c)
            end
          end
        end
      end
    end
  end
  return out

gridD: procedure
  out=.array~new
  do g over .array~of(20,22,24,26,28,30,32,34)
    do cs over .array~of(.10,.20,.30,.40,.50,.60,.75,1.0)
      do tw over .array~of(-20,-10,-5,0,5,10,20)
        do hp over .array~of(40,50,70,90)
          do lp over .array~of(2200,2400,2600,2800,3000)
            do nf over .array~of(999,-40,-35,-30)
              c=.directory~new;c['gain_db']=g;c['highpass']=hp;c['lowpass']=lp;if nf=999 then c['denoise_nf']=.nil;else c['denoise_nf']=nf;c['cancel_strength']=cs;c['cancel_tweak_ms']=tw;c['compress']=0;c['echo_delay_ms']=0;c['echo_gain']=0;out~append(c)
            end
          end
        end
      end
    end
  end
  return out


gridI: procedure
  /* ED209i: deliberately high-cancellation residual lane.  It is not a
     duplicate of D: the domain is biased toward strong subtraction so the
     retained shortlist supplies quiet speech-bearing residuals which H can
     review alone or combine with rank 1 using the additive voice-mix path. */
  out=.array~new
  do g over .array~of(22,24,26,28,30,32,34,36)
    do cs over .array~of(.60,.75,1.0)
      do tw over .array~of(-20,-10,-5,0,5,10,20)
        do hp over .array~of(60,70,80,90,110,120)
          do lp over .array~of(2200,2400,2600,2800,3000,3200,3400)
            do nf over .array~of(999,-45,-40,-35,-30)
              c=.directory~new;c['gain_db']=g;c['highpass']=hp;c['lowpass']=lp;if nf=999 then c['denoise_nf']=.nil;else c['denoise_nf']=nf;c['cancel_strength']=cs;c['cancel_tweak_ms']=tw;c['compress']=0;c['echo_delay_ms']=0;c['echo_gain']=0;out~append(c)
            end
          end
        end
      end
    end
  end
  return out

copyConfig: procedure
  use strict arg c
  d=.directory~new;do k over c;d[k]=c[k];end;return d
configKey: procedure
  use strict arg c
  keys=.array~of('gain_db','highpass','lowpass','denoise_nf','echo_delay_ms','echo_gain','cancel_strength','cancel_tweak_ms','compress','compress_ratio','compress_threshold_db','reject_bands');s=''
  do k over keys;if c~hasIndex(k) then do;if c[k]==.nil then v='NONE';else v=canonicalNumber(c[k]);end;else v='';s=s||k||'='||v||';';end;return s
canonicalNumber: procedure
  use strict arg v
  s=v~string
  if s~left(1)='.' then return '0'||s
  if s~left(2)='-.' then return '-0'||s~substr(2)
  return s
chainText: procedure
  use strict arg c
  s='gain='canonicalNumber(c['gain_db'])'dB'
  if c~hasIndex('cancel_strength') & c['cancel_strength']<>0 then s=s||' -> cancel='canonicalNumber(c['cancel_strength'])'@'canonicalNumber(c['cancel_tweak_ms'])'ms'
  s=s||' -> hp='canonicalNumber(c['highpass'])'Hz -> lp='canonicalNumber(c['lowpass'])'Hz'; if c~hasIndex('reject_bands') then if c['reject_bands']<>'' then s=s||' -> reject=['||c['reject_bands']||']Hz'; if c~hasIndex('denoise_nf') then if c['denoise_nf']<>.nil then s=s||' -> native_gate='canonicalNumber(c['denoise_nf'])'dB'
  if c~hasIndex('echo_gain') then if c['echo_gain']<>0 then s=s||' -> echo='canonicalNumber(c['echo_delay_ms'])'ms@'canonicalNumber(c['echo_gain']);if c~hasIndex('compress') then if c['compress'] then s=s||' -> compressor='canonicalNumber(c['compress_ratio'])':1';s=s||' -> soft_limiter=.88/.98';return s

writeResults: procedure
  use strict arg path,job,source,companion,align,shared,runMeta,candidateCount,results,pareto
  s=.stream~new(path); s~open('write replace')
  s~lineout('{')
  s~lineout('  "schema": "audio.search.result/rexx-native-0.12-dev12",')
  s~lineout('  "engine": "ooRexx 5.3.0 r13196 + ooRexx ML v0.1-dev5 + Foreign Runtime native DSP",')
  s~lineout('  "python_execution": false,')
  s~lineout('  "node": 'jstr(job['node'])',')
  s~lineout('  "strategy": 'jstr(job['strategy'])',')
  s~lineout('  "purpose": 'jstr(job['purpose'])',')
  s~lineout('  "candidate_count": 'candidateCount',')
  s~lineout('  "workspace_budget_gib": 'jnum(jobValue(job,'workspace_budget_gib',.nil))',')
  s~lineout('  "objective": "quality-target resemblance with global/window/temporal distance and artefact penalties",')
  s~lineout('  "scoring": {"formula": "0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal + 18*pre_limiter_over + 40*post_limiter_clip; plus low-silence penalty", "lower_is_better": true, "weight_status": "experimental; MLReview pairwise perceptual calibration required"},')
  s~lineout('  "processing_semantics": {"band_reject": "optional up-to-six native rejected bands; interior bands use three cascaded RBJ band-stop sections", "denoise": "native adaptive envelope gate; not SciPy FFT spectral subtraction", "limiter": "sample-local soft limiter threshold=0.88 ceiling=0.98; no whole-waveform peak normalisation", "exclusion": "known CCTV alarm intervals are detected on original/unamplified PCM and zeroed before search while timeline is preserved"},')
  s~lineout('  "source": 'jstr(source)',')
  s~lineout('  "source_window": {"recording": 'jstr(jobValue(job,'source_recording',.nil))', "start_sec": 'jnum(jobValue(job,'source_start_sec',.nil))', "duration_sec": 'jnum(jobValue(job,'source_duration_sec',.nil))', "wallclock": 'jstr(jobValue(job,'source_wallclock',.nil))'},')
  s~lineout('  "companion": 'jstr(companion)',')
  s~lineout('  "companion_window": {"recording": 'jstr(jobValue(job,'companion_recording',.nil))', "start_sec": 'jnum(jobValue(job,'companion_start_sec',.nil))', "duration_sec": 'jnum(jobValue(job,'companion_duration_sec',.nil))'},')
  s~lineout('  "sample_manifest": "SAMPLES.sha256",')
  s~lineout('  "exclusion": {"policy": 'jstr(jobValue(job,'exclusion_policy','CCTV-ALARM-EXCLUSION-V1'))', "manifest": 'jstr(jobValue(job,'exclusion_manifest','exclusions/campaign0945_cctv_alarm_source_master.tsv'))', "timeline_preserved": true, "detected_from": "original/unamplified primary PCM"},')
  s~lineout('  "quality_targets": {"set": 'jstr(jobValue(job,'quality_target_set','AUDIO-QUALITY-TARGETS-V2'))', "corpus": 'jstr(jobValue(job,'quality_corpus','QUALITY_CORPUS.tsv'))', "target_count": 'jobValue(job,'quality_target_count','4')', "score_compatibility": 'jstr(jobValue(job,'score_compatibility','NOT_COMPARABLE_WITH_PRE_V2_REFERENCE_PROFILE'))'},')
  s~lineout('  "alignment": {"offset_sec": 'align['offset_sec']', "drift_ppm": 'align['drift_ppm']', "correlation": 'align['correlation']', "offset_min_sec": 'align['offset_min_sec']', "offset_max_sec": 'align['offset_max_sec']', "nominal_offset_sec": 'align['nominal_offset_sec']'},')
  s~lineout('  "shared_component_diagnostics": 'sharedJson(shared)',')
  s~lineout('  "execution_context": 'executionJson(job)',')
  s~lineout('  "search_contract": {"workspace": 'jstr(runMeta['workspace_contract'])', "retention": 'jstr(runMeta['retention_contract'])'},')
  s~lineout('  "review": {"candidate_catalog": "review_candidates.tsv", "framework": "MLReview/MLObjectiveCalibration", "status": "UNQUALIFIED_PENDING_HUMAN_EVIDENCE"},')
  s~lineout('  "pareto": 'paretoJson(pareto)',')
  s~lineout('  "ml": 'mlJson(job,runMeta)',')
  s~lineout('  "results": [')
  do i=1 to results~items
    r=results[i]; c=r['config']; comma=','; if i=results~items then comma=''
    s~lineout('    {"rank": 'i', "score": 'r['score']', "pcm_hash64": 'jstr(r['pcm_hash64']~string)', "output": 'jstr(r['output'])', "chain": 'jstr(r['chain'])', "config": 'configJson(c)', "evidence": {"global_distance": 'r['global_distance']', "window_median_distance": 'r['window_median_distance']', "window_p25_distance": 'r['window_p25_distance']', "temporal_distance": 'r['temporal_distance']', "silence_fraction": 'r['silence_fraction']', "pre_filter_peak": 'r['pre_filter_peak']', "pre_limiter_over_fraction": 'r['pre_limiter_over_fraction']', "post_limiter_clip_fraction": 'r['post_limiter_clip_fraction']'}}'comma)
  end
  s~lineout('  ]'); s~lineout('}'); s~close
  return
buildParetoAnalysis: procedure
  use strict arg job,results
  d=.directory~new
  objectives=.AudioParetoObjectives~create
  candidates=.array~new
  laneId=job['node']||':'||job['strategy']
  do i=1 to results~items
    r=results[i]
    candidateId=job['node']||':'||job['strategy']||':'||r['pcm_hash64']~string
    materials=.array~of(r['output'])
    candidates~append(.AudioParetoObjectives~candidateFromRecord(candidateId,laneId,r['config'],r,materials))
  end
  analysis=.MLParetoSearchAnalysis~analyze(objectives,candidates)
  d['objectives']=objectives; d['analysis']=analysis; d['candidates']=candidates
  return d
paretoJson: procedure
  use strict arg pareto
  objectives=pareto['objectives']; analysis=pareto['analysis']; front=analysis~front(1)
  return '{"objective_set": '||jstr(objectives~id)||', "candidate_catalog": "pareto_candidates.tsv", "non_dominated_count": '||front~items||', "scalar_score_status": "EXPERIMENTAL_UNTIL_PERCEPTUAL_CALIBRATION", "objectives": ["reference_distance","pre_limiter_over_fraction","post_limiter_clip_fraction"]}'
writeParetoCatalog: procedure
  use strict arg path,job,results,pareto
  tab='09'x; analysis=pareto['analysis']
  s=.stream~new(path); s~open('write replace')
  s~lineout('candidate_id'||tab||'lane_id'||tab||'scalar_rank'||tab||'scalar_score'||tab||'pareto_rank'||tab||'crowding_distance'||tab||'reference_distance'||tab||'pre_limiter_over_fraction'||tab||'post_limiter_clip_fraction'||tab||'material_ref'||tab||'chain')
  do i=1 to results~items
    r=results[i]
    candidateId=job['node']||':'||job['strategy']||':'||r['pcm_hash64']~string
    point=analysis~point(candidateId)
    refDistance=.35*r['global_distance']+.40*r['window_median_distance']+.10*r['window_p25_distance']+.15*r['temporal_distance']
    chain=r['chain']~changeStr('09'x,' ')~changeStr('0a'x,' ')~changeStr('0d'x,' ')
    s~lineout(candidateId||tab||job['node']||':'||job['strategy']||tab||i||tab||canonicalNumber(r['score'])||tab||point~rank||tab||canonicalNumber(point~crowdingDistance)||tab||canonicalNumber(refDistance)||tab||canonicalNumber(r['pre_limiter_over_fraction'])||tab||canonicalNumber(r['post_limiter_clip_fraction'])||tab||r['output']||tab||chain)
  end
  s~close
  return

writeReviewCatalog: procedure
  use strict arg path,job,results
  tab='09'x
  s=.stream~new(path); s~open('write replace')
  s~lineout('candidate_id'||tab||'lane_id'||tab||'rank'||tab||'score'||tab||'material_ref'||tab||'pcm_hash64'||tab||'objective_id'||tab||'chain')
  do i=1 to results~items
    r=results[i]
    candidateId=job['node']||':'||job['strategy']||':'||r['pcm_hash64']~string
    laneId=job['node']||':'||job['strategy']
    chain=r['chain']~changeStr('09'x,' ')~changeStr('0a'x,' ')~changeStr('0d'x,' ')
    s~lineout(candidateId||tab||laneId||tab||i||tab||canonicalNumber(r['score'])||tab||r['output']||tab||r['pcm_hash64']~string||tab||'quality-target-distance'||tab||chain)
  end
  s~close
  return

writeCandidateConfigs: procedure
  use strict arg path,job,results
  tab='09'x
  s=.stream~new(path); s~open('write replace')
  s~lineout('candidate_id'||tab||'lane_id'||tab||'rank'||tab||'score'||tab||'gain_db'||tab||'highpass_hz'||tab||'lowpass_hz'||tab||'denoise_floor_db'||tab||'echo_delay_ms'||tab||'echo_gain'||tab||'cancel_strength'||tab||'cancel_tweak_ms'||tab||'compress'||tab||'compress_ratio'||tab||'compress_threshold_db'||tab||'reject_bands'||tab||'chain')
  do i=1 to results~items
    r=results[i]; c=r['config']
    candidateId=job['node']||':'||job['strategy']||':'||r['pcm_hash64']~string
    laneId=job['node']||':'||job['strategy']
    nf=configValue(c,'denoise_nf',.nil); if nf==.nil then nfText='NONE'; else nfText=canonicalNumber(nf)
    chain=r['chain']~changeStr('09'x,' ')~changeStr('0a'x,' ')~changeStr('0d'x,' ')
    line=candidateId||tab||laneId||tab||i||tab||canonicalNumber(r['score'])||tab||canonicalNumber(configValue(c,'gain_db',24))||tab||canonicalNumber(configValue(c,'highpass',50))||tab||canonicalNumber(configValue(c,'lowpass',3000))||tab||nfText||tab||canonicalNumber(configValue(c,'echo_delay_ms',0))||tab||canonicalNumber(configValue(c,'echo_gain',0))||tab||canonicalNumber(configValue(c,'cancel_strength',0))||tab||canonicalNumber(configValue(c,'cancel_tweak_ms',0))||tab||canonicalNumber(configValue(c,'compress',0))||tab||canonicalNumber(configValue(c,'compress_ratio',2))||tab||canonicalNumber(configValue(c,'compress_threshold_db',-18))||tab||configValue(c,'reject_bands','')||tab||chain
    s~lineout(line)
  end
  s~close
  return

jobValue: procedure
  use strict arg d,k,default
  if d~hasIndex(k) then return d[k]
  return default
jnum: procedure
  use strict arg x
  if x==.nil then return 'null'
  return x~string
configJson: procedure
  use strict arg c
  g=configValue(c,'gain_db',24); hp=configValue(c,'highpass',50); lp=configValue(c,'lowpass',3000)
  nf=configValue(c,'denoise_nf',.nil); ed=configValue(c,'echo_delay_ms',0); eg=configValue(c,'echo_gain',0)
  cs=configValue(c,'cancel_strength',0); ct=configValue(c,'cancel_tweak_ms',0); co=configValue(c,'compress',0)
  cr=configValue(c,'compress_ratio',2); th=configValue(c,'compress_threshold_db',-18); rb=configValue(c,'reject_bands','')
  if nf==.nil then nfj='null'; else nfj=nf~string
  if co then coj='true'; else coj='false'
  return '{"gain_db": 'g', "highpass_hz": 'hp', "lowpass_hz": 'lp', "denoise_floor_db": 'nfj', "echo_delay_ms": 'ed', "echo_gain": 'eg', "cancel_strength": 'cs', "cancel_tweak_ms": 'ct', "compress": 'coj', "compress_ratio": 'cr', "compress_threshold_db": 'th', "reject_bands": 'jstr(rb)'}'
configValue: procedure
  use strict arg c,k,default
  if c~hasIndex(k) then return c[k]
  return default
mlJson: procedure
  use strict arg job,meta
  strategy=job['strategy']~upper
  if strategy='C' then return '{"implementation": "ooRexx ML v0.1-dev5", "search_driver": "MLGeneticAlgorithm~run", "seed": 20903, "objective": {"id": '||jstr(meta['objective_id'])||', "direction": '||jstr(meta['objective_direction'])||'}, "population_size": '||meta['population_size']||', "evaluated_population_rounds": '||meta['evaluated_population_rounds']||', "breeding_steps": '||meta['breeding_steps']||', "evaluation_slots": '||meta['evaluation_slots']||', "unused_slots": '||meta['unused_slots']||', "final_population_evaluated": true, "final_population_generation": '||meta['final_population_generation']||', "generation_registry_count": '||meta['generation_registry_count']||', "mutation_rate": '||meta['mutation_rate']||', "mutation_scale": '||meta['mutation_scale']||', "crossover_rate": '||meta['crossover_rate']||', "elite_count": '||meta['elite_count']||', "shared_parameter_domain": "C is an explicit superset of A/B/D shared gain/filter/denoise ranges", "space_relations": {"A_to_C": '||jstr(meta['space_a_to_c'])||', "B_to_C": '||jstr(meta['space_b_to_c'])||', "D_to_C": '||jstr(meta['space_d_to_c'])||'}}'
  if strategy='E' then return '{"implementation": "ooRexx ML v0.1-dev5", "search_driver": "MLDeterministicRNG checkpointed exploration", "seed": '||meta['checkpoint_seed']||', "resume_supported": true, "processed_before_resume": '||meta['processed_before_resume']||', "processed_slots": '||meta['processed_slots']||', "checkpoint_records_loaded": '||meta['checkpoint_records_loaded']||', "checkpoint_interval_candidates": '||meta['checkpoint_interval_candidates']||', "shared_parameter_domain": "same semantic genome decoder as strategy C"}'
  return '{"implementation": "ooRexx ML v0.1-dev5", "search_driver": "deterministic grid"}'

executionJson: procedure
  use strict arg job
  return '{"cloud_provider": '||jstr(jobValue(job,'cloud_provider',.nil))||', "cloud_zone": '||jstr(jobValue(job,'cloud_zone',.nil))||', "machine_type": '||jstr(jobValue(job,'machine_type',.nil))||', "provisioning_model": '||jstr(jobValue(job,'provisioning_model',.nil))||', "preemption_notice_sec": '||jnum(jobValue(job,'preemption_notice_sec',.nil))||', "termination_action": '||jstr(jobValue(job,'termination_action',.nil))||'}'

sharedJson: procedure
  use strict arg shared
  keys=.array~of('-20','-10','-5','0','5','10','20'); out='{'
  do i=1 to keys~items
    k=keys[i]; x=shared[k]; if i>1 then out=out||', '
    out=out||jstr(k)||': {"alpha": '||x['alpha']||', "correlation": '||x['correlation']||'}'
  end
  return out||'}'
jstr: procedure
  use strict arg x
  if x==.nil then return 'null'
  t=x~string; t=t~changeStr('\\','\\\\')~changeStr('"','\\"')~changeStr('0a'x,'\\n')~changeStr('0d'x,'\\r')
  return '"'||t||'"'

::class AudioGAScoreEvaluator public
::method init
  expose ctx records cache
  use strict arg ctx,records,cache
::method score
  expose ctx records cache
  use strict arg genome
  c=self~decodeGenome(genome); key=self~configKey(c)
  if cache~hasIndex(key) then return cache[key]['score']
  st=ctx~evaluate(c); r=.directory~new; r['config']=self~copyConfig(c); r['score']=st['score']; r['pcm_hash64']=st['pcm_hash64']; r['global_distance']=st['global_distance']; r['window_median_distance']=st['window_median_distance']; r['window_p25_distance']=st['window_p25_distance']; r['temporal_distance']=st['temporal_distance']; r['silence_fraction']=st['silence_fraction']; r['post_limiter_clip_fraction']=st['post_limiter_clip_fraction']; r['pre_limiter_over_fraction']=st['pre_limiter_over_fraction']; r['pre_filter_peak']=st['pre_filter_peak']; r['chain']=self~chainText(c)
  records~append(r); cache[key]=r
  return r['score']
::method decodeGenome
  use strict arg genome
  c=.directory~new
  /* Shared gain/filter/denoise dimensions are a superset of A/B/D so C is
     not structurally excluded from a boundary that a grid lane may find. */
  c['gain_db']=self~pick(.array~of(16,18,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,38,40),genome~gene(1)); c['highpass']=self~pick(.array~of(40,50,60,70,80,90,110,120,130,150),genome~gene(2)); c['lowpass']=self~pick(.array~of(2200,2400,2600,2800,3000,3200,3400,3600,3800,4000),genome~gene(3)); nf=self~pick(.array~of(999,-45,-40,-35,-32,-30,-28,-25),genome~gene(4)); if nf=999 then c['denoise_nf']=.nil; else c['denoise_nf']=nf
  c['echo_delay_ms']=self~pick(.array~of(0,4,8,12,15,18,25,35,50),genome~gene(5)); c['echo_gain']=self~pick(.array~of(-.35,-.2,-.1,0,.1,.15,.2,.35),genome~gene(6)); if c['echo_delay_ms']=0 then c['echo_gain']=0
  c['cancel_strength']=self~pick(.array~of(0,.10,.20,.30,.40,.50,.60,.75),genome~gene(7)); c['cancel_tweak_ms']=self~pick(.array~of(-20,-10,-5,0,5,10,20),genome~gene(8)); if c['cancel_strength']=0 then c['cancel_tweak_ms']=0
  c['compress']=(self~clamp(genome~gene(9))>=.45); c['compress_ratio']=self~pick(.array~of(1.5,2,2.5,3),genome~gene(10)); c['compress_threshold_db']=-18
  return c
::method pick private
  use strict arg a,x
  x=self~clamp(x); idx=1+trunc(x*a~items); if idx>a~items then idx=a~items; return a[idx]
::method clamp private
  use strict arg x
  if x<0 then return 0
  if x>1 then return 1
  return x
::method configKey private
  use strict arg c
  keys=.array~of('gain_db','highpass','lowpass','denoise_nf','echo_delay_ms','echo_gain','cancel_strength','cancel_tweak_ms','compress','compress_ratio','compress_threshold_db','reject_bands'); s=''
  do k over keys
    if c~hasIndex(k) then do; if c[k]==.nil then v='NONE'; else v=self~canonicalNumber(c[k]); end; else v=''
    s=s||k||'='||v||';'
  end
  return s
::method canonicalNumber private
  use strict arg v
  s=v~string
  if s~left(1)='.' then return '0'||s
  if s~left(2)='-.' then return '-0'||s~substr(2)
  return s
::method copyConfig private
  use strict arg c
  d=.directory~new; do k over c; d[k]=c[k]; end; return d
::method chainText private
  use strict arg c
  s='gain='self~canonicalNumber(c['gain_db'])'dB'
  if c['cancel_strength']<>0 then s=s||' -> cancel='self~canonicalNumber(c['cancel_strength'])'@'self~canonicalNumber(c['cancel_tweak_ms'])'ms'
  s=s||' -> hp='self~canonicalNumber(c['highpass'])'Hz -> lp='self~canonicalNumber(c['lowpass'])'Hz'
  if c~hasIndex('reject_bands') then if c['reject_bands']<>'' then s=s||' -> reject=['||c['reject_bands']||']Hz'
  if c['denoise_nf']<>.nil then s=s||' -> native_gate='self~canonicalNumber(c['denoise_nf'])'dB'
  if c['echo_gain']<>0 then s=s||' -> echo='self~canonicalNumber(c['echo_delay_ms'])'ms@'self~canonicalNumber(c['echo_gain'])
  if c['compress'] then s=s||' -> compressor='self~canonicalNumber(c['compress_ratio'])':1'
  return s||' -> soft_limiter=.88/.98'

::class AudioRecordComparator public
::method compare
  use strict arg a,b
  if a['score']<b['score'] then return -1
  if a['score']>b['score'] then return 1
  return 0
::requires 'AudioSearchNative.cls'
::requires 'OorexxML.cls'
::requires 'AudioParetoObjectives.cls'
