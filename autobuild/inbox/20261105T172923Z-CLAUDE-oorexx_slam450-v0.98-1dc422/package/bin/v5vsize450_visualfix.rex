/* SLAM 450 v0.92: wire size of the visual-fix grid with Tom Dyer's V5V codec.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * usage: rexx v5vsize450_visualfix.rex grid.txt [keyInterval]
 * Feeds each grid surface (96 x 24, 4 bits, 13 values) in file order
 * (serpentine) through V5VTemporalCodec~encodeSurface, decodes every record
 * again with ~decodeRecord and checks the round trip is exact, and counts
 * wire bytes: KEYFRAME = the surface's packedBytes; DELTA = the changed
 * mask's packedBytes + the changed values' packedBytes.
 * Codec: packages/oorexx_vision (dev15-repaired1 onward). dev14's
 * encodeSurface called a nonexistent VisionSurfaceDelta~between; that is
 * fixed upstream ("VisionSurfaceDelta is constructed directly"), so this
 * tool no longer works around it. V5V_DIR overrides the location. */
parse arg file keyEvery .
if keyEvery=='' then keyEvery=25
v5vDir=value('V5V_DIR',,'ENVIRONMENT')
if v5vDir=='' then do
  root=value('ALCHEMY_REPO',,'ENVIRONMENT')
  if root=='' then root='/home/claude/alchemy'
  v5vDir=root'/packages/oorexx_vision/src'
end
.context~package~loadPackage(v5vDir'/V5VCodec.cls')
n=96*24
enc=.V5VTemporalCodec~new(.V5VCodecPolicy~new(keyEvery))
dec=.V5VTemporalCodec~new(.V5VCodecPolicy~new(keyEvery))
magic=word(linein(file),1)
keys=0;keyBytes=0;deltas=0;changed=0;deltaBytes=0;okN=0;bad=0
do while lines(file)>0
  parse value linein(file) with . . . . status gm hex
  if status\=='OK' then iterate
  okN+=1
  if magic=='VISUALFIX2' then s=hex~translate(xrange('00'x,'0C'x),'abcdefghijklm')
  else s=x2c(hex)
  surf=.VisionSurface~new(96,24,4,13)
  do k=0 to n-1;surf~packed~put(k,c2d(s~substr(k+1,1)));end
  surf~timestamp=okN
  rec=enc~encodeSurface(surf)
  if rec~recordType=='KEYFRAME' then do
    keys+=1;keyBytes+=length(rec~payload~packedBytes)
  end
  else do
    deltas+=1;changed+=rec~changedCount
    deltaBytes+=length(rec~payload~changedMask~packedBytes)+length(rec~payload~changedValues~packedBytes)
  end
  back=dec~decodeRecord(rec)
  if back~packedBytes\==surf~packedBytes then bad+=1
end
call stream file,'C','CLOSE'
raw=okN*(n*4%8)
say 'V5V' filespec('name',file) 'SURFACES' okN 'RAW_BYTES' raw 'KEYFRAMES' keys 'KEY_BYTES' keyBytes 'DELTAS' deltas,
    'MEAN_CHANGED_POINTS' format(changed/max(1,deltas),,1) 'DELTA_BYTES' deltaBytes 'V5V_TOTAL' keyBytes+deltaBytes,
    'RATIO' format(raw/(keyBytes+deltaBytes),,2) 'ROUND_TRIP' word('EXACT MISMATCH',1+(bad>0)) bad
exit (bad>0)
