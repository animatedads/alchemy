/* Face SLAM POSE2D/1 interchange codec. ooRexx validates the complete
 * provider-returned record; no Python subprocess, parser eval, or identity
 * decision is included. A projected Python object may return this UTF-8 text
 * through existing Foreign Runtime / Python Macrospace, or a native provider
 * can implement the same read-only method.
 *
 * Header: POSE2D/1|source|camera|track|PTS_us|width|height|topology|model_sha|source_sha|NORMALIZED_IMAGE
 * Rows: 0|x|y|visibility through 32 (MEDIAPIPE33), or 16 (COCO17).
 */
::class FaceSlamPosePacket public
::method decode class
  use strict arg packet
  numeric digits 30
  if \packet~isA(.String) then raise syntax 88.900 array('pose provider packet must be text')
  lines=packet~makeArray('0a'x)
  if lines~items<2 then raise syntax 88.900 array('pose provider packet lacks landmarks')
  header=lines[1]~strip('T','0d'x)~makeArray('|')
  if header~items<>11 | header[1]\='POSE2D/1' then raise syntax 88.900 array('invalid POSE2D/1 header')
  source=header[2]; camera=header[3]; track=header[4]
  t=header[5]; width=header[6]; height=header[7]
  topo=header[8]; model=header[9]; digest=header[10]; space=header[11]
  if topo='MEDIAPIPE33' then expected=33
  else if topo='COCO17' then expected=17
  else raise syntax 88.900 array('unknown model landmark topology')
  if \t~datatype('W') | \width~datatype('W') | \height~datatype('W') then -
    raise syntax 88.900 array('invalid source time or dimensions')
  if t<0 | width<1 | height<1 then raise syntax 88.900 array('invalid source time or dimensions')
  if source='' | camera='' | track='' | model='' | digest='' then raise syntax 88.900 array('source authority fields required')
  if space\='NORMALIZED_IMAGE' then raise syntax 88.900 array('unsupported coordinate space')
  if lines~items=expected+2 & lines[lines~items]='' then ignored=lines~remove(lines~items)
  if lines~items<>expected+1 then raise syntax 88.900 array('pose landmark count mismatch')
  values=.array~new
  do i=1 to expected
    words=lines[i+1]~strip('T','0d'x)~makeArray('|')
    if words~items<>4 then raise syntax 88.900 array('pose row arity mismatch',i)
    idx=words[1]; x=words[2]; y=words[3]; confidence=words[4]
    if \idx~datatype('W') | idx<>i-1 then raise syntax 88.900 array('missing, duplicated or unordered landmark',i)
    if \x~datatype('N') | \y~datatype('N') | \confidence~datatype('N') then -
      raise syntax 88.900 array('non-numeric pose coordinate',i)
    if x<0 | x>1 | y<0 | y>1 | confidence<0 | confidence>1 then -
      raise syntax 88.900 array('out-of-range normalized pose coordinate',i)
    values~append(.array~of(x+0,y+0,confidence+0))
  end
  landmarks=.FaceSlamPoseTopology~fromOrdered(topo,values)
  return .FaceSlamPoseFrame~new(source,camera,track,t,width,height,landmarks,model,digest,space)

::class FaceSlamProjectedPoseProvider public
::method init
  expose projected
  use strict arg projected
  if projected==.nil then raise syntax 88.900 array('projected provider is required')
::method observe
  expose projected
  use strict arg sourceWindowToken
  if sourceWindowToken='' then raise syntax 88.900 array('source window token required')
  /* The underlying projected object is constructed by the established
   * Python Macrospace / Foreign Runtime facilities, NOT spawned here. */
  return .FaceSlamPosePacket~decode(projected~pose2dPacket(sourceWindowToken))

::requires 'FaceSlamGait.cls'
