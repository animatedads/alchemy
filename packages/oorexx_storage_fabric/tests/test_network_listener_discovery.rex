/* Storage named listener never downgrades and discovery frames are atomic. */
ordinary=.Ordinary~new
network=.StorageServiceNetworkPort~new(ordinary)
call check network~listener<>.nil,'unconfigured ordinary listener remains supported'
call check ordinary~count=1,'one deliberate ordinary listener'
call check network~listener('ed209c')==.nil,'explicit named peer cannot downgrade without manager'
call check ordinary~count=1,'named peer denial never invoked ordinary listener'
call check network~listener('')==.nil,'empty named target fails closed'
call check ordinary~count=1,'empty named peer never invoked ordinary listener'
manager=.Named~new
network=.StorageServiceNetworkPort~new(ordinary,.nil,manager)
call check network~listener('ed209c')<>.nil,'named manager handles explicit named listener'
call check manager~last='ed209c','logical peer preserved'
call check ordinary~count=1,'successful named listener did not downgrade'
call check network~listener<>.nil,'unbound listener still selects ordinary socket'
call check ordinary~count=2,'ordinary listener deliberately selected'
hash='ab'~copies(32)
transport=.DiscoverySocket~new
m=.StorageMulticastDiscovery~new(transport)
call check m~probe(hash,'challenge_123'),'valid one-token hint sent'
call check m~advertise(hash,'challenge_123'),'valid one-token offer sent'
call check m~parseHint(transport~last)['status']='UNTRUSTED_HINT','valid frame remains only a hint'
transport~short=.true
call check \m~probe(hash,'challenge_123'),'partial search write rejected'
call check \m~advertise(hash,'challenge_123'),'partial offer write rejected'
transport~short=.false
call check \m~probe(hash,'two tokens'),'space-containing challenge rejected'
call check \m~advertise(hash,'bad'||'09'x||'tab'),'control character rejected'
call check m~parseHint('STORAGE-DISCOVERY/1 OFFER '||hash||' challenge_123 extra')['status']='INVALID','malformed multiple-token hint rejected'
call check m~parseHint('STORAGE-DISCOVERY/1 OFFER '||hash||' bad'||'09'x||'tab')['status']='INVALID','control character hint rejected'
call check m~parseHint('STORAGE-DISCOVERY/1 OFFER '||hash||' challenge_123')['status']='UNTRUSTED_HINT','valid offer parses'
say 'PASS listener no-downgrade and multicast discovery frame integrity'
exit 0
check: procedure
  parse arg truth,why
  if truth then return
  say 'FAIL:' why
  exit 1
::class Ordinary public
::attribute count get
::method init
  expose count
  count=0
::method listener
  expose count
  count+=1
  return .Object~new
::class Named public
::attribute last get
::method listener
  expose last
  use strict arg peer
  last=peer
  return .Object~new
::class DiscoverySocket public
::attribute last get
::attribute short
::method init
  expose short
  short=.false
::method send
  expose last short
  use strict arg frame
  last=frame
  if short then return length(frame)-1
  return length(frame)
::requires 'StorageNetworkServices.cls'
