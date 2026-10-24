/* Concurrent three-piece renderer: peer ooRexx activities for guitar, bass, drums. */
numeric digits 30

::class BandStemResult public
::method init
  expose _samples _noteCount _kind _elapsed
  use strict arg kind,samples,noteCount,elapsedSeconds
  _kind=kind; _samples=samples; _noteCount=noteCount; _elapsed=elapsedSeconds
::method kind; expose _kind; return _kind
::method samples; expose _samples; return _samples
::method noteCount; expose _noteCount; return _noteCount
::method elapsedSeconds; expose _elapsed; return _elapsed

::class GuitarBandRenderer public
::method render
  use strict arg song,startSeconds,durationSeconds,sr=6000
  t0=time('R')
  total=(durationSeconds*sr)~trunc
  ctx=.MathContext~binary64('NUMPY')
  out=.array~new(total); do i=1 to total; out[i]=0; end
  models=.array~new
  do f over .array~of(329.6275569,246.9416506,195.997718,146.832384,110,82.4068892)
    models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,6))
  end
  count=0; renderEnd=startSeconds+durationSeconds
  do n over song~notes
    if n~startSeconds>=renderEnd then iterate
    if n~startSeconds+n~durationSeconds<=startSeconds then iterate
    if n~program<>30 then iterate
    v=.MidiGuitarVoicer~voiceNote(n,24,5)
    if v==.nil then iterate
    self~addNote(out,models[v~stringNumber],v~fret,n,startSeconds,durationSeconds,sr,ctx,.82,.00055)
    count+=1
  end
  do i=1 to total; out[i]=self~soft(out[i]*.0065); end
  return .BandStemResult~new('GUITAR',out,count,time('E'))

::method addNote
  use strict arg target,model,fret,note,windowStart,windowDuration,sr,ctx,pickupPosition,basePluck
  relStart=note~startSeconds-windowStart; noteOffset=0
  if relStart<0 then do; noteOffset=-relStart; relStart=0; end
  start=(relStart*sr)~trunc+1
  if start>target~items then return
  dur=note~durationSeconds-noteOffset+.06
  if dur>.72 then dur=.72
  remain=windowDuration-relStart; if dur>remain then dur=remain
  if dur<=0 then return
  count=(dur*sr)~trunc; if count<2 then return
  vel=note~velocity/127; pluck=basePluck*(.35+.65*vel)
  renderer=.GuitarMathsModalRenderer~new(model,ctx)
  y=renderer~renderDisplacement(fret,pickupPosition,sr,count,(noteOffset*sr)~trunc,.18,pluck,'PICK',0)
  prev=y[1]
  do j=1 to count
    idx=start+j-1; if idx>target~items then leave
    cur=y[j]; if j=1 then vv=0; else vv=(cur-prev)*sr
    target[idx]=target[idx]+vv; prev=cur
  end

::method soft
  use strict arg x
  return x/(1+abs(x))

::class BassBandRenderer public
::method render
  use strict arg song,startSeconds,durationSeconds,sr=6000
  t0=time('R')
  total=(durationSeconds*sr)~trunc
  ctx=.MathContext~binary64('NUMPY')
  out=.array~new(total); do i=1 to total; out[i]=0; end
  models=.BassInstrumentFactory~standardStringSet
  count=0; renderEnd=startSeconds+durationSeconds
  do n over song~notes
    if n~startSeconds>=renderEnd then iterate
    if n~startSeconds+n~durationSeconds<=startSeconds then iterate
    if n~program<>26 then if n~program<>28 then iterate
    v=.MidiBassVoicer~voiceNote(n,24,5)
    if v==.nil then iterate
    model=models[5-v~stringNumber]
    self~addNote(out,model,v~fret,n,startSeconds,durationSeconds,sr,ctx,.78,.0011)
    count+=1
  end
  do i=1 to total; out[i]=self~soft(out[i]*.0100); end
  return .BandStemResult~new('BASS',out,count,time('E'))

::method addNote
  use strict arg target,model,fret,note,windowStart,windowDuration,sr,ctx,pickupPosition,basePluck
  relStart=note~startSeconds-windowStart; noteOffset=0
  if relStart<0 then do; noteOffset=-relStart; relStart=0; end
  start=(relStart*sr)~trunc+1
  if start>target~items then return
  dur=note~durationSeconds-noteOffset+.06
  if dur>.90 then dur=.90
  remain=windowDuration-relStart; if dur>remain then dur=remain
  if dur<=0 then return
  count=(dur*sr)~trunc; if count<2 then return
  vel=note~velocity/127; pluck=basePluck*(.35+.65*vel)
  renderer=.GuitarMathsModalRenderer~new(model,ctx)
  y=renderer~renderDisplacement(fret,pickupPosition,sr,count,(noteOffset*sr)~trunc,.18,pluck,'PICK',0)
  prev=y[1]
  do j=1 to count
    idx=start+j-1; if idx>target~items then leave
    cur=y[j]; if j=1 then vv=0; else vv=(cur-prev)*sr
    target[idx]=target[idx]+vv; prev=cur
  end

::method soft
  use strict arg x
  return x/(1+abs(x))

::class DrumBandRenderer public
::method render
  use strict arg song,startSeconds,durationSeconds,sr=6000
  t0=time('R')
  r=.MidiDrumRenderer~render(song,startSeconds,durationSeconds,sr)
  return .BandStemResult~new('DRUMS',r~samples,r~events~items,time('E'))

::class ConcurrentBandRenderer public
::method render class
  use strict arg song,startSeconds,durationSeconds,sr=6000
  t0=time('R')
  guitarWorker=.GuitarBandRenderer~new
  bassWorker=.BassBandRenderer~new
  drumWorker=.DrumBandRenderer~new

  /* Three peer ooRexx activities. */
  mg=guitarWorker~start('render',song,startSeconds,durationSeconds,sr)
  mb=bassWorker~start('render',song,startSeconds,durationSeconds,sr)
  md=drumWorker~start('render',song,startSeconds,durationSeconds,sr)

  guitar=mg~result
  bass=mb~result
  drums=md~result

  dR=self~rms(drums~samples); gR=self~rms(guitar~samples); bR=self~rms(bass~samples)
  if dR=0 then dGain=0; else dGain=.72/dR
  if gR=0 then gGain=0; else gGain=.58/gR
  if bR=0 then bGain=0; else bGain=.50/bR
  total=drums~samples~items; mix=.array~new(total)
  do i=1 to total
    x=dGain*drums~samples[i]+gGain*guitar~samples[i]+bGain*bass~samples[i]
    mix[i]=self~soft(x*.72)
  end
  d=.directory~new
  d['MIX']=mix; d['GUITAR']=guitar; d['BASS']=bass; d['DRUMS']=drums
  d['DRUM_GAIN']=dGain; d['GUITAR_GAIN']=gGain; d['BASS_GAIN']=bGain
  d['ELAPSED']=time('E')
  return d

::method soft class
  use strict arg x
  return x/(1+abs(x))
::method rms class
  use strict arg a
  if a~items=0 then return 0
  s=0; do x over a; s+=x*x; end
  return RxCalcSqrt(s/a~items,30)

::requires 'rxmath' LIBRARY
::requires 'MidiDrumRenderer.cls'
::requires 'BassGuitarMechanics.cls'
::requires 'GuitarMathsAcceleration.cls'
::requires 'MathNumpyProvider.cls'
