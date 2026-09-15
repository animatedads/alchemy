failures=0
catalog=.AudioProcessorCatalog~researchCorpus

-- Input multiplicity and per-material channel shape are different concepts.
mv=catalog~at('transform.mvdr.dual')
call check mv~inputRoles~items=2, 'MVDR has two semantic input roles'
call check mv~contractForRole('A')~accepts(16000,1,'f32le',.false), 'MVDR role A accepts one mono material'
call check \mv~contractForRole('A')~accepts(16000,2,'f32le',.false), 'MVDR role A is not a two-channel material'
call check mv~contractForRole('B')~accepts(16000,1,'f32le',.false), 'MVDR role B independently accepts mono material'

fixture=.ForeignPython~import('audio_processing_fixture')
session=.AudioForeignPythonProcessingSession~new
noise=fixture~noisy_signal(.ForeignPython~integer(16000),.ForeignPython~float(1.5))
noiseBuf=nativeBuffer(noise); noise~close
pair=fixture~coherent_pair_box(.ForeignPython~integer(16000),.ForeignPython~float(1.5))
a=pair[1]; b=pair[2]; aBuf=nativeBuffer(a); bBuf=nativeBuffer(b)
a~close; b~close; pair~close

-- Newly promoted research methods.
rp=session~execute('V20-ROOM',catalog~at('measurement.room_profile'),.AudioProcessorConfig~new('room','measurement.room_profile'),noiseBuf,16000)
call check rp~outputs~items=1, 'room profile returns semantic output'
call check rp~outputs[1]~object~isa(.AudioRoomReflectionProfile), 'room profile is owned audio object'
call check rp~measurements[1]~mathsEvidence~isa(.MathEvidence), 'room profile confidence carries Maths evidence'

hp=session~execute('V20-HPS',catalog~at('measurement.harmonic_product'),.AudioProcessorConfig~new('hps','measurement.harmonic_product'),noiseBuf,16000)
call check hp~measurements~items=1, 'harmonic product returns measurement'
call check hp~measurements[1]~mathsEvidence~isa(.MathEvidence), 'harmonic product carries Maths evidence'
call check hp~outputs~items=1 & hp~outputs[1]~object~isa(.AudioFeatureMapDescriptor), 'harmonic product feature map is semantic object'
call check hp~outputs[1]~attributes['tensor']~isa(.ForeignTensor), 'harmonic feature map retains runtime tensor separately'

tilt=session~execute('V20-TILT',catalog~at('measurement.spectral_tilt'),.AudioProcessorConfig~new('tilt','measurement.spectral_tilt'),noiseBuf,16000)
call check tilt~measurements~items=1, 'spectral tilt returns one measurement'
call check tilt~measurements[1]~unit='dB/octave', 'spectral tilt has physical unit'
call check tilt~measurements[1]~mathsEvidence~isa(.MathEvidence), 'spectral tilt carries Maths evidence'

md=session~execute('V20-MD',catalog~at('mask.coherence.multi_domain'),.AudioProcessorConfig~new('md','mask.coherence.multi_domain'),aBuf,16000,bBuf)
call check md~outputs~items=2, 'multi-domain coherence returns audio plus mask'
call check md~outputs[1]~object~isa(.ForeignTensor), 'multi-domain derived audio remains tensor'
call check md~outputs[2]~object~isa(.AudioMaskDescriptor), 'multi-domain mask is semantic object'

lf=session~execute('V20-LLF',catalog~at('transform.log_likelihood_fusion'),.AudioProcessorConfig~new('llf','transform.log_likelihood_fusion'),aBuf,16000,bBuf)
call check lf~outputs~items=2, 'log-likelihood fusion returns audio plus feed-weight mask'
call check lf~outputs[1]~object~isa(.ForeignTensor), 'log-likelihood fused audio remains tensor'

-- Typed graph: external runtime material -> denoise -> CLEAN, no byte materialisation.
g=.AudioProcessingGraph~new('typed-chain')
in1=.Directory~new; in1['PRIMARY']=.AudioProcessingPortRef~external('SOURCE')
c1=.AudioProcessorConfig~new('g-denoise','transform.adaptive_spectral_denoise')
g~addNode(.AudioProcessingNode~new('denoise',c1,in1,.Array~of('clean')))
in2=.Directory~new; in2['PRIMARY']=.AudioProcessingPortRef~node('denoise','clean')
c2=.AudioProcessorConfig~new('g-clean','transform.clean_spectral_lines')
g~addNode(.AudioProcessingNode~new('clean',c2,in2,.Array~of('clean')))
g~bindOutput('final','clean','clean')
ext=.Directory~new; ext['SOURCE']=noiseBuf
executor=.AudioProcessingGraphExecutor~new(catalog,session,16000)
grun=executor~execute(g,ext)
call check grun~executionOrder~items=2, 'graph executor runs two dependent nodes'
call check grun~executionOrder[1]='denoise' & grun~executionOrder[2]='clean', 'typed graph topological order is deterministic'
call check grun~outputs['final']~object~isa(.ForeignTensor), 'graph final output remains runtime tensor'
call check grun~nodeResults['denoise']~outputs[1]~object~isa(.ForeignTensor), 'intermediate graph output remains tensor'
call check g~canonicalText~pos('PORT=EXTERNAL:SOURCE')>0 & g~canonicalText~pos('PORT=NODE:denoise:clean')>0, 'typed graph edges canonicalise deterministically'

-- Clean up resident tensor pins.
hp~outputs[1]~attributes['tensor']~close
md~outputs[1]~object~close; md~outputs[2]~attributes['tensor']~close
lf~outputs[1]~object~close; lf~outputs[2]~attributes['tensor']~close
grun~nodeResults['clean']~outputs[1]~object~close
grun~nodeResults['clean']~outputs[2]~attributes['tensor']~close
grun~nodeResults['denoise']~outputs[1]~object~close
noiseBuf~close; aBuf~close; bBuf~close
session~close; fixture~close

if failures=0 then do; say 'AUDIO PROCESSING v0.20: OK'; exit 0; end
say 'AUDIO PROCESSING v0.20: FAIL failures='failures; exit 1

nativeBuffer: procedure
  use arg proxy
  data=proxy~tobytes
  b=.foreign~buffer(data~length)
  b~putBytes(0,data)
  return b

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return

::requires '../AudioForeignPythonProcessing.cls'
