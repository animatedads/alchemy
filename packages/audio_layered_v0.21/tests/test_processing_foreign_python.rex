failures=0
fixture=.ForeignPython~import('audio_processing_fixture')
pair=fixture~shifted_pair_box(.ForeignPython~integer(16000),.ForeignPython~float(1.0),.ForeignPython~integer(80))
a=pair[1]; b=pair[2]
aBuf=nativeBuffer(a); bBuf=nativeBuffer(b)
a~close; b~close; pair~close

session=.AudioForeignPythonProcessingSession~new
catalog=.AudioProcessorCatalog~researchCorpus

stats=session~channelStatistics(aBuf,bBuf)
call check stats~items=5, 'dual channel statistics return rms/peak/correlation measurements'
corr=stats[5]
call check corr~kind='channel_correlation', 'correlation measurement typed'
call check corr~mathsEvidence~isa(.MathEvidence), 'correlation carries ooRexx Maths evidence'
call check corr~mathsEvidence~canonical~pos('audio.channel.correlation')>0, 'MathEvidence identifies correlation operation'

params=.Directory~new; params['max_lag_sec']=0.02
cfg=.AudioProcessorConfig~new('gcc-80','alignment.gcc_phat',params)
r=session~execute('REQ-GCC',catalog~at('alignment.gcc_phat'),cfg,aBuf,16000,bBuf)
call check r~status='COMPLETED', 'gcc-phat completes through ForeignPython'
shift=r~outputs[1]~object
call check abs(shift~samples)=80, 'gcc-phat recovers injected 80 sample shift'
call check r~measurements[1]~mathsEvidence~isa(.MathEvidence), 'alignment confidence carries Maths evidence'

noise=fixture~noisy_signal(.ForeignPython~integer(16000),.ForeignPython~float(1.0))
noiseBuf=nativeBuffer(noise); noise~close
cfg2=.AudioProcessorConfig~new('denoise-default','transform.adaptive_spectral_denoise')
r2=session~execute('REQ-DENOISE',catalog~at('transform.adaptive_spectral_denoise'),cfg2,noiseBuf,16000)
outBuf=r2~outputs[1]~object
call check outBuf~isa(.ForeignTensor), 'denoise returns provider-neutral ForeignTensor'
call check outBuf~shape[1]*4=noiseBuf~size, 'denoise preserves sample extent'
call check outBuf~shape[1]>0, 'denoise output is non-empty'

chainCfg=.AudioProcessorConfig~new('chain-clean','transform.clean_spectral_lines')
chain=session~execute('REQ-CHAIN',catalog~at('transform.clean_spectral_lines'),chainCfg,outBuf,16000)
call check chain~outputs[1]~object~isa(.ForeignTensor), 'ForeignTensor derived material feeds next processor without byte materialisation'

coh=fixture~coherent_pair_box(.ForeignPython~integer(16000),.ForeignPython~float(1.0))
ca=coh[1]; cb=coh[2]; caBuf=nativeBuffer(ca); cbBuf=nativeBuffer(cb)
ca~close; cb~close; coh~close
cfg3=.AudioProcessorConfig~new('coherence-default','mask.phase_coherence_wiener')
r3=session~execute('REQ-COH',catalog~at('mask.phase_coherence_wiener'),cfg3,caBuf,16000,cbBuf)
call check r3~outputs~items=3, 'phase coherence returns two derived audios plus mask'
call check r3~outputs[1]~object~isa(.ForeignTensor), 'phase coherence A output is ForeignTensor'
call check r3~outputs[3]~object~isa(.AudioMaskDescriptor), 'phase coherence mask has semantic descriptor'
call check r3~outputs[3]~attributes['tensor']~isa(.ForeignTensor), 'mask retains transient tensor separately'

cfg4=.AudioProcessorConfig~new('cross-default','alignment.cross_ambiguity')
r4=session~execute('REQ-XA',catalog~at('alignment.cross_ambiguity'),cfg4,aBuf,16000,bBuf)
call check r4~outputs[1]~object~isa(.AudioTimeShift), 'cross ambiguity returns semantic shift'

cfg5=.AudioProcessorConfig~new('mvdr-default','transform.mvdr.dual')
r5=session~execute('REQ-MVDR',catalog~at('transform.mvdr.dual'),cfg5,caBuf,16000,cbBuf)
call check r5~outputs[1]~object~isa(.ForeignTensor), 'mvdr returns runtime tensor material'

cfg6=.AudioProcessorConfig~new('clean-default','transform.clean_spectral_lines')
r6=session~execute('REQ-CLEAN',catalog~at('transform.clean_spectral_lines'),cfg6,noiseBuf,16000)
call check r6~outputs~items=2, 'CLEAN returns material plus suppression mask'

cfg7=.AudioProcessorConfig~new('echo-default','mask.echo_persistence')
r7=session~execute('REQ-ECHO',catalog~at('mask.echo_persistence'),cfg7,noiseBuf,16000)
call check r7~outputs~items=2, 'echo persistence returns material plus mask'

cfg8=.AudioProcessorConfig~new('eigen-default','transform.eigen_noise_projection')
r8=session~execute('REQ-EIGEN',catalog~at('transform.eigen_noise_projection'),cfg8,caBuf,16000,cbBuf)
call check r8~outputs~items=2, 'eigen projection preserves two output streams'

cfg9=.AudioProcessorConfig~new('syllabic-default','mask.syllabic_modulation')
r9=session~execute('REQ-SYL',catalog~at('mask.syllabic_modulation'),cfg9,noiseBuf,16000)
call check r9~measurements~items=1 & r9~outputs~items=1, 'syllabic modulation returns score and mask'

-- McGill A-law fixture: left and right are independent material and must not be silently downmixed.
mc=fixture~load_stereo_wav_box(.ForeignPython~text(value('MCGILL_FIXTURE',,'ENVIRONMENT')))
ml=mc[1]; mr=mc[2]; msr=mc[3]
mlBuf=nativeBuffer(ml); mrBuf=nativeBuffer(mr)
ml~close; mr~close; mc~close
mstats=session~channelStatistics(mlBuf,mrBuf)
mcorr=mstats[5]
call check msr=8000, 'McGill A-law sample decodes at 8kHz'
call check abs(mcorr~value)<0.05, 'McGill left/right correlation remains near zero (no downmix)'
call check mcorr~mathsEvidence~isa(.MathEvidence), 'McGill correlation has numerical evidence'

-- close transient runtime resources
chain~outputs[1]~object~close; chain~outputs[2]~attributes['tensor']~close
outBuf~close; noiseBuf~close
do o over r3~outputs
  if o~kind=.AudioProcessingConstant~OUTPUT_AUDIO then o~object~close
  if o~kind=.AudioProcessingConstant~OUTPUT_MASK then o~attributes['tensor']~close
end
r5~outputs[1]~object~close
r6~outputs[1]~object~close; r6~outputs[2]~attributes['tensor']~close
r7~outputs[1]~object~close; r7~outputs[2]~attributes['tensor']~close
do o over r8~outputs; o~object~close; end
r9~outputs[1]~attributes['tensor']~close
caBuf~close; cbBuf~close; mlBuf~close; mrBuf~close; aBuf~close; bBuf~close
session~close; fixture~close

if failures=0 then do; say 'AUDIO PROCESSING FOREIGNPYTHON: OK'; exit 0; end
say 'AUDIO PROCESSING FOREIGNPYTHON: FAIL failures='failures; exit 1


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
