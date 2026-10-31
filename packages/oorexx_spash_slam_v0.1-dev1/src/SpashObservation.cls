/* SPASH SLAM v0.1: immutable acoustic observation and comparable likeness.
 * Architecture: Tom Dyer. Code: ChatGPT GPT-6, 2026-10-30.
 * No sound meaning, source count, geometry or speech identity is inferred.
 */
::class SpashObservation public
::method init
  expose _id _source _start _count _rate _block _centre _width _pitch _bins _energy _location _method _foundation
  use strict arg source, startSample, sampleCount, sampleRate, blockIndex, centreHz, bandwidthHz, pitchHz, bins, energy, locationId=.nil, methodId='UNSPECIFIED', methodFoundationId='UNSPECIFIED'
  if source == '' then raise syntax 88.900 array('nonempty source id',source)
  if \datatype(startSample,'N') then raise syntax 88.900 array('numeric start sample',startSample)
  if \datatype(sampleCount,'N') then raise syntax 88.900 array('numeric sample count',sampleCount)
  if \datatype(sampleRate,'N') then raise syntax 88.900 array('numeric sample rate',sampleRate)
  if \datatype(blockIndex,'N') then raise syntax 88.900 array('numeric block index',blockIndex)
  if startSample < 0 | startSample <> trunc(startSample) then raise syntax 88.900 array('nonnegative integer start',startSample)
  if sampleCount <= 0 | sampleCount <> trunc(sampleCount) then raise syntax 88.900 array('positive integer count',sampleCount)
  if sampleRate <= 0 then raise syntax 88.900 array('positive rate',sampleRate)
  if blockIndex < 0 | blockIndex <> trunc(blockIndex) then raise syntax 88.900 array('nonnegative integer block',blockIndex)
  if \datatype(centreHz,'N') then raise syntax 88.900 array('numeric frequency',centreHz)
  if \datatype(bandwidthHz,'N') then raise syntax 88.900 array('numeric bandwidth',bandwidthHz)
  if \datatype(energy,'N') then raise syntax 88.900 array('numeric energy',energy)
  if centreHz < 0 | bandwidthHz <= 0 | energy < 0 then raise syntax 88.900 array('nonnegative frequency/energy; positive width',centreHz bandwidthHz energy)
  if pitchHz \== .nil then do
    if \datatype(pitchHz,'N') then raise syntax 88.900 array('numeric or absent pitch',pitchHz)
    if pitchHz <= 0 then raise syntax 88.900 array('positive pitch',pitchHz)
  end
  if \bins~isA(.array) then raise syntax 88.900 array('spectral vector must be Array',bins)
  if bins~items = 0 then raise syntax 88.900 array('nonempty spectral vector',bins)
  total=0
  do i=1 to bins~items
    if \datatype(bins[i],'N') then raise syntax 88.900 array('numeric spectral bin',i)
    if bins[i] < 0 then raise syntax 88.900 array('nonnegative spectral bin',i)
    total=total+bins[i]
  end
  if total <= 0 then raise syntax 88.900 array('nonzero spectral energy',total)
  _bins=.array~new
  do i=1 to bins~items
    _bins~append(bins[i]/total)
  end
  if methodId=='' | methodFoundationId=='' then raise syntax 88.900 array('method identity and foundation required',methodId methodFoundationId)
  _method=methodId; _foundation=methodFoundationId
  _source=source; _start=startSample; _count=sampleCount; _rate=sampleRate; _block=blockIndex
  _centre=centreHz; _width=bandwidthHz; _pitch=pitchHz; _energy=energy; _location=locationId
  _id='OBS:'||length(source)||':'||source||':'||startSample||':'||sampleCount||':'||sampleRate||':'||blockIndex||':'||length(methodId)||':'||methodId
::method id; expose _id; return _id
::method sourceId; expose _source; return _source
::method startSample; expose _start; return _start
::method sampleCount; expose _count; return _count
::method sampleRate; expose _rate; return _rate
::method blockIndex; expose _block; return _block
::method startMs; expose _start _rate; return 1000*_start/_rate
::method endMs; expose _start _count _rate; return 1000*(_start+_count)/_rate
::method centreHz; expose _centre; return _centre
::method bandwidthHz; expose _width; return _width
::method pitchHz; expose _pitch; return _pitch
::method energy; expose _energy; return _energy
::method locationId; expose _location; return _location
::method methodId; expose _method; return _method
::method methodFoundationId; expose _foundation; return _foundation
::method spectralBins; expose _bins
  out=.array~new
  do i=1 to _bins~items
    out~append(_bins[i])
  end
  return out
::method likeness
  use strict arg other
  if \other~isA(.SpashObservation) then raise syntax 88.900 array('SpashObservation expected',other)
  a=self~spectralBins; b=other~spectralBins
  if a~items <> b~items then return .nil /* incomparable bin geometry, not dissimilarity */
  d=0
  do i=1 to a~items
    d=d+abs(a[i]-b[i])
  end
  shape=d/2
  frequency=abs(self~centreHz-other~centreHz)/max(100,self~centreHz,other~centreHz)
  width=abs(self~bandwidthHz-other~bandwidthHz)/max(100,self~bandwidthHz,other~bandwidthHz)
  cost=.50*shape + .25*min(1,frequency) + .10*min(1,width)
  weight=.85
  if self~pitchHz \== .nil then do
    if other~pitchHz \== .nil then do
      pd=abs(self~pitchHz-other~pitchHz)/max(50,self~pitchHz,other~pitchHz)
      cost=cost+.15*min(1,pd)
      weight=1
    end
  end
  return max(0,min(1,1-cost/weight))
