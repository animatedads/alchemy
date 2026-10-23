/* Decision-directed a priori SNR and Wiener amplitude gain.
   Power-domain frames; no phase reconstruction. */
::class AudioDecisionDirected public
::method init
 expose alpha floor prevGain prevGamma frames
 use strict arg alpha,floor
 if \datatype(alpha,'N') | \datatype(floor,'N') then raise syntax 93.900 array('numeric parameters required')
 if alpha<0 | alpha>=1 | floor<=0 then raise syntax 93.900 array('invalid parameters')
 prevGain=.nil; prevGamma=.nil; frames=0
::method advance
 expose alpha floor prevGain prevGamma frames
 use strict arg observed,noise
 if \observed~isA(.Array) | \noise~isA(.Array) then raise syntax 93.900 array('power arrays required')
 if observed~items<>noise~items then raise syntax 93.900 array('size mismatch')
 if prevGain\==.nil then if prevGain~items<>observed~items then raise syntax 93.900 array('size changed')
 gainsOut=.Array~new
 newGamma=.Array~new
 do i=1 to observed~items
  p=observed[i]; n=noise[i]
  if \datatype(p,'N') | \datatype(n,'N') then raise syntax 93.900 array('non-numeric power')
  if p<0 | n<0 then raise syntax 93.900 array('negative power')
  gamma=p/max(n,floor)
  post=max(gamma-1,0)
  if prevGain==.nil then xi=post
  else xi=alpha*prevGain[i]*prevGain[i]*prevGamma[i]+(1-alpha)*post
  g=xi/(1+xi)
  gainsOut~append(g)
  newGamma~append(gamma)
 end
 prevGain=gainsOut~copy; prevGamma=newGamma; frames=frames+1
 return gainsOut
::method snapshot
 expose prevGain prevGamma frames
 if prevGain==.nil then return .array~of(.nil,.nil,frames)
 return .array~of(prevGain~copy,prevGamma~copy,frames)
::method restore
 expose prevGain prevGamma frames
 use strict arg state
 if \state~isA(.Array) then raise syntax 93.900 array('invalid snapshot')
 if state~items<>3 then raise syntax 93.900 array('invalid snapshot size')
 if \datatype(state[3],'W') | state[3]<0 then raise syntax 93.900 array('invalid frame count')
 if state[1]==.nil then do
  if state[2]\==.nil | state[3]<>0 then raise syntax 93.900 array('invalid empty snapshot')
  prevGain=.nil; prevGamma=.nil
 end
 else do
  if \state[1]~isA(.Array) | \state[2]~isA(.Array) then raise syntax 93.900 array('invalid snapshot arrays')
  if state[1]~items<>state[2]~items then raise syntax 93.900 array('snapshot size mismatch')
  prevGain=state[1]~copy; prevGamma=state[2]~copy
 end
 frames=state[3]
 return self
