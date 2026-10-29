lib = .SocialLibrary~new
mem = .SocialMemoryProvider~new
lib~register(mem)
if lib~discover('memory') == .nil then exit 11
msg = .SocialEnvelope~new('m001','post','brand:demo','Hello, community')
msg~addAudience('community:public')
msg~addMedia('asset:video1')
if msg~media~items <> 1 then exit 12
/* The policy must deny before a provider operation can run. */
call onDenial lib, msg
if mem~operations~items <> 0 then exit 13
rights = .SocialTestGrant~new
rights~grant('publish')
lib~policy = .SocialPolicy~new(rights)
receipt = lib~execute('memory','publish',msg)
if receipt['status'] <> 'simulated' then exit 14
if lib~audit~items <> 1 then exit 15
say 'PASS: semantic envelope, capability discovery, default-deny, explicit test grant and simulated receipt'
exit 0
onDenial: procedure
  use arg lib, msg
  signal on syntax name denied
  lib~execute('memory','publish',msg)
  return
  denied:
  return
::requires 'SocialMedia.cls'
