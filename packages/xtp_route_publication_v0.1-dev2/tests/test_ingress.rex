/* Native ooRexx admission and framing regression */

keys = .TestResolver~new
base = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
ingress = .XtpProvisionIngress~new(keys, 16, 4, 100)
call chk 'encrypted bounded receive', ingress~receive(base)['OK'], .true
call chk 'payload', base~lastPayload, 'HELLO'

s = .TestSession~new('xtp.provision', 'none', '000000000000a11c', '1')
call chk 'clear forbidden', ingress~receive(s)['REASON'], 'ENCRYPTION_REQUIRED'
call chk 'clear abort', s~abortCount, 1
s = .TestSession~new('xtp.provision', 'authenticate', '000000000000a11c', '1')
call chk 'auth only forbidden', ingress~receive(s)['REASON'], 'ENCRYPTION_REQUIRED'
s = .TestSession~new('ssh.management', 'encrypt', '000000000000a11c', '1')
call chk 'service mismatch', ingress~receive(s)['REASON'], 'SERVICE_MISMATCH'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '0')
call chk 'closed context', ingress~receive(s)['REASON'], 'SESSION_NOT_OPEN'
s = .TestSession~new('xtp.provision', 'encrypt', '0000000000000000', '1')
call chk 'zero key', ingress~receive(s)['REASON'], 'KEY_ID_INVALID'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000aaaa', '1')
call chk 'unknown key', ingress~receive(s)['REASON'], 'IDENTITY_DENIED'
keys~shared = .true
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
call chk 'shared key refused', ingress~receive(s)['REASON'], 'EXCLUSIVE_KEY_REQUIRED'
keys~shared = .false
keys~unfenced = .true
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
call chk 'unfenced identity refused', ingress~receive(s)['REASON'], 'FENCE_REQUIRED'
keys~unfenced = .false
keys~wrongKey = .true
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
call chk 'key binding mismatch', ingress~receive(s)['REASON'], 'KEY_BINDING_MISMATCH'
keys~wrongKey = .false
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('12345678901234567'), .array~of('EOM'))
call chk 'oversize refused', ingress~receive(s)['REASON'], 'REQUEST_TOO_LARGE'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('12345678','123456789'), .array~of('','EOM'))
call chk 'cumulative oversize', ingress~receive(s)['REASON'], 'REQUEST_TOO_LARGE'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('A',''), .array~of('',''))
call chk 'no progress', ingress~receive(s)['REASON'], 'NO_PROGRESS'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('A'), .array~of('TIMEOUT'))
call chk 'timeout refused', ingress~receive(s)['REASON'], 'REQUEST_TIMEOUT'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('A'), .array~of('END'))
call chk 'premature end refused', ingress~receive(s)['REASON'], 'REQUEST_INCOMPLETE'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('A','B','C','D'), .array~of('','','',''))
call chk 'frame count refused', ingress~receive(s)['REASON'], 'FRAME_COUNT_EXCEEDED'
s = .TestSession~new('xtp.provision', 'encrypt', '000000000000a11c', '1')
s~setChunks(.array~of('AA','BB'), .array~of('','EOM'))
r = ingress~receive(s)
call chk 'two frame accepted', r['OK'], .true
call chk 'two frame payload', r['PAYLOAD'], 'AABB'

say 'All assertions passed' 
say 'PASS XtpProvisionIngress r13196 native suite'
exit 0

::requires "XtpProvisionIngress.cls"
::routine chk
  use strict arg title, actual, expected
  if actual == expected then say 'PASS' title
  else do
    say 'FAIL' title 'got:' actual 'expected:' expected
    raise syntax 93.900 array(title)
  end

::class TestResolver public
::attribute shared
::attribute unfenced
::attribute wrongKey
::method init
  expose shared unfenced wrongKey
  shared = .false; unfenced = .false; wrongKey = .false
::method resolveSession
  expose shared unfenced wrongKey
  use strict arg info
  v = .directory~new
  v['OK'] = info['KEYID'] = '000000000000a11c'
  v['EXCLUSIVE'] = \shared
  if wrongKey then v['KEYID'] = '000000000000bbbb'
  else v['KEYID'] = info['KEYID']
  v['SERVICE'] = 'xtp.provision'
  v['PRINCIPAL'] = 'mi:ed209a.mi1'
  v['AUTHORITY'] = 'LDAP'
  v['FENCED'] = \unfenced
  return v

::class TestSession public
::attribute abortCount
::attribute lastPayload
::attribute lastFlag
::method init
  expose service protection key open abortCount chunks flags index lastFlag lastPayload
  use strict arg service, protection, key, open
  abortCount = 0; lastFlag = ''; index = 1; lastPayload = ''
  chunks = .array~of('HELLO'); flags = .array~of('EOM')
::method setChunks
  expose chunks flags index
  use strict arg chunks, flags
  index = 1
::method info
  expose service protection key open
  d = .directory~new
  d['SERVICE'] = service
  d['PROTECTION'] = protection
  d['KEYID'] = key
  d['OPEN'] = open
  return d
::method read
  expose chunks flags index lastFlag lastPayload
  use strict arg maxBytes, timeoutMs
  if index > chunks~items then do
    lastFlag = 'TIMEOUT'
    return ''
  end
  part = chunks[index]
  lastFlag = flags[index]
  index = index + 1
  lastPayload = part
  return part
::method abort
  expose abortCount
  abortCount = abortCount + 1
  return 0
