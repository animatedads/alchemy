failures=0
catalog=.AudioProcessorCatalog~researchCorpus
fixture=.ForeignPython~import('audio_processing_fixture')
provider=.AudioForeignPythonProcessingSession~new

blocks=fixture~streaming_blocks_box(.ForeignPython~integer(16000),.ForeignPython~integer(4096),.ForeignPython~integer(4))
call check .ForeignPythonSequenceSupport~isSequence(blocks) & blocks~items=4, 'fixture returned four resident blocks'

-- Stateful adaptive denoiser: state must survive block boundaries.
spec=catalog~at('transform.adaptive_spectral_denoise')
params=.Directory~new; params['n_fft']=1024; params['hop']=256; params['state_alpha']=0.75
cfg=.AudioProcessorConfig~new('stream-denoise','transform.adaptive_spectral_denoise',params)
stream=provider~openStream('S-DENOISE',spec,cfg,16000)
do i=1 to blocks~items
  arr=blocks[i]
  tensor=arr~asTensor
  arr~close
  eos=(i=blocks~items)
  block=.AudioProcessingBlock~new(i,(i-1)*4096,4096,0,0,eos,.Array~of('fixture:'||i))
  br=stream~processBlock(block,tensor)
  call check br~result~status='COMPLETED', 'denoise block completed'
  call check br~result~outputs~items=1, 'denoise block returned one audio output'
  out=br~result~outputs[1]~object
  call check out~isa(.ForeignTensor), 'denoise block output is resident tensor'
  call check out~shape~items=1 & out~shape[1]=4096, 'denoise block preserves logical sample count'
  cp=br~checkpoint
  call check cp~nextSequence=i+1, 'checkpoint advances next sequence'
  call check cp~processedSamples=i*4096, 'checkpoint accumulates processed sample count'
  call check cp~stateKind='FOREIGNPYTHON', 'checkpoint names runtime state kind without storing live proxy'
  call check cp~stateSummary['provider_blocks']=i, 'provider state block count survives between calls'
  call check cp~canonicalText~pos('FOREIGNPYTHON')>0, 'checkpoint canonicalises state kind'
  out~close; tensor~close
end
call check stream~semanticSession~endOfStreamSeen, 'end-of-stream is observed but not silently flushed'
call check \stream~semanticSession~flushed, 'flush-required session stays open after EOS'
fr=stream~flush
call check fr~checkpoint~flushed, 'explicit flush closes semantic stream lifecycle'
call check fr~checkpoint~stateSummary['provider_blocks']=4, 'flush checkpoint retains provider state summary'
stream~close

-- Echo persistence has a different state shape: bounded delay/history survives blocks.
eparams=.Directory~new; eparams['n_fft']=1024; eparams['hop']=256; eparams['delay_max_ms']=80
espec=catalog~at('mask.echo_persistence')
ecfg=.AudioProcessorConfig~new('stream-echo','mask.echo_persistence',eparams)
echo=provider~openStream('S-ECHO',espec,ecfg,16000)
blocks2=fixture~streaming_blocks_box(.ForeignPython~integer(16000),.ForeignPython~integer(4096),.ForeignPython~integer(2))
do i=1 to blocks2~items
  arr=blocks2[i]; tensor=arr~asTensor; arr~close
  block=.AudioProcessingBlock~new(i,(i-1)*4096,4096,0,0,(i=blocks2~items),.Array~of('echo:'||i))
  br=echo~processBlock(block,tensor)
  call check br~result~outputs~items=2, 'echo stream returns derived audio and mask'
  call check br~result~outputs[1]~object~isa(.ForeignTensor), 'echo audio remains resident tensor'
  call check br~result~outputs[2]~object~isa(.AudioMaskDescriptor), 'echo mask remains semantic object'
  call check br~checkpoint~stateSummary['history_samples']>0, 'echo stream carries bounded delay history'
  br~result~outputs[1]~object~close
  br~result~outputs[2]~attributes['tensor']~close
  tensor~close
end
echo~flush
echo~close
blocks2~close


-- Dynamic filter plans are semantic/time-scoped; Python owns only numerical IIR state.
rules=.Array~new
rules~append(.AudioFilterRule~new('notch-1','NOTCH',0,4096,1000,25,2))
rules~append(.AudioFilterRule~new('hp-1','HIGHPASS',4096,12288,120,30,4))
plan=.AudioDynamicFilterPlan~new('PLAN-1',rules,4)
dparams=.Directory~new; dparams['filter_plan']=plan; dparams['max_filters_per_block']=4
dspec=catalog~at('transform.dynamic_filters')
call check dspec~implementationStatus='REFERENCE', 'dynamic filters promoted to reference implementation'
dcfg=.AudioProcessorConfig~new('stream-dynamic','transform.dynamic_filters',dparams)
dyn=provider~openStream('S-DYNAMIC',dspec,dcfg,16000)
blocks3=fixture~streaming_blocks_box(.ForeignPython~integer(16000),.ForeignPython~integer(4096),.ForeignPython~integer(3))
do i=1 to blocks3~items
  arr=blocks3[i]; tensor=arr~asTensor; arr~close
  block=.AudioProcessingBlock~new(i,(i-1)*4096,4096,0,0,(i=blocks3~items),.Array~of('dynamic:'||i))
  br=dyn~processBlock(block,tensor)
  call check br~result~outputs~items=1, 'dynamic filter stream returns one derived material'
  call check br~result~outputs[1]~object~isa(.ForeignTensor), 'dynamic filter output remains resident tensor'
  call check br~checkpoint~stateSummary['filters_applied_last_block']=1, 'time-scoped dynamic rule selected exactly one active filter'
  call check br~checkpoint~stateSummary['active_filter_states']=1, 'dynamic filter numerical state remains bounded to active rule set'
  br~result~outputs[1]~object~close; tensor~close
end
call check plan~activeRules(0,4096)[1]~id='notch-1', 'filter plan selects first sample interval deterministically'
call check plan~activeRules(4096,4096)[1]~id='hp-1', 'filter plan switches rule at sample boundary without wall-clock dependency'
dyn~flush; dyn~close; blocks3~close

blocks~close
provider~close; fixture~close

if failures=0 then do; say 'AUDIO PROCESSING STREAMING v0.21: OK'; exit 0; end
say 'AUDIO PROCESSING STREAMING v0.21: FAIL failures='failures; exit 1

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return

::requires '../AudioForeignPythonProcessing.cls'
