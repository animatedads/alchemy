/* AudioMathsEvidence.cls - bridge numerical processing measurements to ooRexx Maths v0.5 evidence */

::class AudioMathsEvidence public

::method binary64 class
  use strict arg operation, algorithm, providerVersion='', details='', checks=.nil, independenceTags=''
  if checks==.nil then checks=.Directory~new
  ctx=.MathContext~binary64('NUMPY')
  ev=.MathEvidence~new(operation,ctx)
  step=.MathPathStep~new(operation,'NUMPY',providerVersion,algorithm,'BINARY64',ctx~workingDigits,'float64',details,'NUMERICAL_MEASUREMENT',independenceTags)
  ev~addStep(step)
  do k over checks; ev~putCheck(k,checks[k]); end
  return ev


::method measurement class
  use strict arg operation, value, unit='', algorithm='', providerVersion='', details='', checks=.nil, independenceTags='audio-processing-measurement'
  if checks==.nil then checks=.Directory~new
  checks['value']=value
  checks['unit']=unit
  return self~binary64(operation,algorithm,providerVersion,details,checks,independenceTags)

::method correlation class
  use strict arg value, sampleCount, providerVersion='', algorithm='pearson-correlation'
  checks=.Directory~new
  checks['sample_count']=sampleCount
  checks['correlation']=value
  checks['bounded']=value>=-1 & value<=1
  return self~binary64('audio.channel.correlation',algorithm,providerVersion,'Correlation is numerical evidence; it does not by itself establish speaker/source identity.',checks,'audio-channel-statistics')

::method alignment class
  use strict arg method, lagSamples, sampleRateHz, confidence, confidenceKind, providerVersion=''
  checks=.Directory~new
  checks['lag_samples']=lagSamples
  checks['sample_rate_hz']=sampleRateHz
  checks['confidence']=confidence
  checks['confidence_kind']=confidenceKind
  return self~binary64('audio.alignment.measurement',method,providerVersion,'Lag/confidence are method-specific numerical evidence, not an exact synchronization proof.',checks,'audio-alignment')

::requires 'Maths.cls'
