failures=0

catalog=.AudioProcessorCatalog~researchCorpus
call check catalog~ids~items>=18, 'research corpus catalogues broad method family'
call check catalog~at('alignment.gcc_phat') \== .nil, 'gcc-phat catalogued'
call check catalog~at('transform.mvdr.dual')~family='TRANSFORM', 'mvdr is transform not magic enhancer'
call check catalog~at('mask.phase_coherence_wiener')~family='MASK', 'phase coherence is mask family'
call check catalog~at('spatial.tdoa.geo')~family='SPATIAL', 'tdoa geo is spatial family'
call check catalog~at('transform.mvdr.dual')~execution~gpuMode='PREFERRED', 'mvdr advertises gpu preference independently of semantics'
call check catalog~at('alignment.gcc_phat')~streaming~streamingCapable, 'gcc-phat has block/stream contract'

p1=.Directory~new; p1['max_lag_sec']='0.10'
p2=.Directory~new; p2['max_lag_sec']='0.25'
c1=.AudioProcessorConfig~new('cfg-fast','alignment.gcc_phat',p1,'short search')
c2=.AudioProcessorConfig~new('cfg-wide','alignment.gcc_phat',p2,'wide search')
call check c1~canonicalText \= c2~canonicalText, 'parameter variants are distinct configurations'

g=.AudioProcessingGraph~new('parallel-enhancement')
in1=.Directory~new; in1['A']='material:A'; in1['B']='material:B'
n1=.AudioProcessingNode~new('align-short',c1,in1,.Array~of('shift'))
n2=.AudioProcessingNode~new('align-wide',c2,in1,.Array~of('shift'))
g~addNode(n1); g~addNode(n2)
g~bindOutput('short','align-short','shift')
g~bindOutput('wide','align-wide','shift')
call check g~nodes~items=2, 'graph preserves parallel processor trials'
call check g~outputs~items=2, 'graph preserves independent branch outputs'
call check g~canonicalText~pos('align-short')>0 & g~canonicalText~pos('align-wide')>0, 'canonical graph carries both branches'

contract=.AudioSampleContract~new(16000,1,1,.Array~of('f32le'),'PACKED')
call check contract~accepts(16000,1,'f32le',.false), 'sample contract accepts canonical mono f32'
call check \contract~accepts(8000,1,'f32le',.false), 'sample contract rejects wrong rate'
call check \contract~accepts(16000,2,'f32le',.false), 'sample contract rejects wrong channels'


streamSpec=catalog~at('transform.adaptive_spectral_denoise')
stream=.AudioProcessingStreamSession~new('S1',.AudioProcessorConfig~new('denoise-stream','transform.adaptive_spectral_denoise'),streamSpec~streaming)
stream~acceptBlock(.AudioProcessingBlock~new(1,0,32768,0,0,.false,.Array~of('M1')))
stream~acceptBlock(.AudioProcessingBlock~new(2,32768,32768,0,0,.false,.Array~of('M1')))
call check stream~acceptedBlocks~items=2, 'stateful stream session preserves ordered block sequence while provider owns history'
stream~flush
call check stream~flushed, 'stream session has explicit flush lifecycle'

placement=.AudioProcessingPlacementRequirements~new(catalog~at('transform.mvdr.dual'),104857600)
call check placement~gpuPreferred, 'placement seam exposes gpu preference without allocating a node'
call check placement~asDirectory['estimated_working_set_bytes']=104857600, 'placement seam carries working-set estimate'

refA=.AudioProcessingInputRef~new('A','REC-1','TRACK-A',1,1000,5000,'MAT-A')
refB=.AudioProcessingInputRef~new('B','REC-2','TRACK-B',1,1200,5200,'MAT-B')
dispatch=.AudioProcessingDispatchEnvelope~new('JOB-1',catalog~at('transform.mvdr.dual'),.AudioProcessorConfig~new('mvdr-job','transform.mvdr.dual'),.Array~of(refA,refB),.nil,placement)
wire=dispatch~toDirectory
call check wire['schema']='layered-audio.processing.dispatch/0.1', 'offload envelope has stable value schema'
call check wire['input_refs']~items=2, 'offload envelope carries semantic input references'
call check wire['placement']['gpu_preferred'], 'offload envelope carries gpu placement hint but no allocator decision'



-- Stateful placement semantics are explicit: provider-affine state requires the
-- same selected implementation/node across successive blocks unless a future
-- implementation advertises checkpointable state.
statePlacement=.AudioProcessingPlacementRequirements~new(streamSpec,16777216)
call check statePlacement~stateMode='STATEFUL', 'stateful processor exposes state mode to placement adapter'
call check statePlacement~stateTransferMode='PROVIDER_AFFINE', 'current streaming reference state is provider-affine'
call check statePlacement~sessionAffinityRequired, 'provider-affine state requests session placement affinity'

filterRules=.Array~of(.AudioFilterRule~new('N1','NOTCH',0,4096,1000,30,2),.AudioFilterRule~new('H1','HIGHPASS',4096,8192,120,30,4))
filterPlan=.AudioDynamicFilterPlan~new('FILTERS-1',filterRules,4)
call check filterPlan~activeRules(0,4096)[1]~id='N1', 'dynamic filter plan selects rule by sample-domain interval'
call check filterPlan~activeRules(4096,4096)[1]~id='H1', 'dynamic filter plan changes rule at explicit sample boundary'
call check filterPlan~canonicalText~pos('AUDIO_FILTER_RULE=N1')>0, 'dynamic filter plan canonicalises complete rule semantics'

cp=stream~checkpoint('PROVIDER_AFFINE')
streamBlock=.AudioProcessingBlock~new(3,64000,4096,1536,0,.false,.Array~of('M1'))
streamRef=.AudioProcessingInputRef~new('PRIMARY','REC-1','TRACK-A',1,64000,68096,'MAT-STREAM')
streamDispatch=.AudioProcessingStreamDispatchEnvelope~new('STREAM-JOB-3','S1',streamSpec,stream~config,cp,streamBlock,.Array~of(streamRef),statePlacement)
sw=streamDispatch~toDirectory
call check sw['schema']='layered-audio.processing.stream.dispatch/0.1', 'stream offload envelope has stable value schema'
call check sw['session_id']='S1', 'stream offload envelope carries stable session identity'
call check sw['placement']['session_affinity_required'], 'stream offload envelope carries affinity requirement, not a node decision'
call check streamDispatch~canonicalText~pos('AUDIO_STREAM_CHECKPOINT=S1')>0, 'stream dispatch canonicalises checkpoint without live runtime handles'

shift=.AudioTimeShift~new(160,16000,4.2,'B later than A','fixture','E1')
call check shift~milliseconds=10, 'time shift is semantic object with unit conversion'

if failures=0 then do; say 'AUDIO PROCESSING TOOLKIT: OK'; exit 0; end
say 'AUDIO PROCESSING TOOLKIT: FAIL failures='failures; exit 1

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1
  say 'FAIL' label
  return

::requires '../AudioProcessingToolkit.cls'
