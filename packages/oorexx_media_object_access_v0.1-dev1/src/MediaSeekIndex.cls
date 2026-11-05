/* Presentation-time random-access index. Independent of MP4 atom layout and
 * decoder. All time coordinates are integer ticks in the track's timebase.
 * Access points must be proven decoder random-access points, not arbitrary
 * packets flagged with a convenient byte offset. */
::options digits 30

::class MediaAccessPoint public
::attribute presentationTicks get
::attribute decodeTicks get
::attribute byteOffset get
::attribute sampleOrdinal get
::attribute prerollSamples get
::method init
  expose presentationTicks decodeTicks byteOffset sampleOrdinal prerollSamples
  use strict arg pts,dts,byte,ordinal,preroll=0
  if datatype(pts,'W')=0 | datatype(dts,'W')=0 | datatype(byte,'W')=0 | -
     datatype(ordinal,'W')=0 | datatype(preroll,'W')=0 then -
    raise syntax 88.900 array('access point requires integer ticks and offsets')
  if byte<0 | ordinal<1 | preroll<0 then -
    raise syntax 88.900 array('invalid access point offset/ordinal/preroll')
  presentationTicks=pts; decodeTicks=dts; byteOffset=byte
  sampleOrdinal=ordinal; prerollSamples=preroll

::class MediaSeekIndex public
::attribute sourceIdentity get
::attribute trackId get
::attribute timeScale get
::attribute count get
::method init
  expose sourceIdentity trackId timeScale points count sealed
  use strict arg identity,id,scale
  if datatype(scale,'W')=0 | scale<1 then raise syntax 88.900 array('invalid track timescale')
  sourceIdentity=identity; trackId=id; timeScale=scale
  points=.array~new; count=0; sealed=.false
::method addAccessPoint
  expose points count sealed
  use strict arg item
  if sealed then raise syntax 88.900 array('cannot edit sealed seek index')
  if count>0 then do
    prior=points[count]
    if item~presentationTicks<=prior~presentationTicks then -
      raise syntax 88.900 array('seek points must be strictly increasing in presentation time')
  end
  points~append(item); count+=1
  return self
::method seal
  expose sealed
  sealed=.true
  return self
::method atOrBefore
  expose points count sealed
  use strict arg pts
  if \sealed then raise syntax 88.900 array('seek index is not sealed')
  if datatype(pts,'W')=0 then raise syntax 88.900 array('seek time must be integer track ticks')
  lo=1; hi=count; found=0
  do while lo<=hi
    mid=(lo+hi)%2
    if points[mid]~presentationTicks<=pts then do
      found=mid; lo=mid+1
    end
    else hi=mid-1
  end
  if found=0 then return .nil
  return points[found]
::method first
  expose points count sealed
  if \sealed then raise syntax 88.900 array('seek index is not sealed')
  if count=0 then return .nil
  return points[1]
