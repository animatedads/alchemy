/* Architecture: Tom Dyer. Coding: ChatGPT. Bootstrap component, test-key only. */
::requires 'crypto.cls'
::requires 'LoggingCore.cls'

::class XtpRoleRecord public
::method init
  expose canonical name main spare epoch version seeds keys
  use strict arg canonical
  numeric digits 30
  if canonical~length > 4096 then raise syntax 93.900 array('ROLE_TOO_LONG')
  a = canonical~makeArray('|')
  if a~items \= 8 then raise syntax 93.900 array('ROLE_FIELDS')
  if a[1] \== 'ROLE' | a[2] \== 'LDAP' then raise syntax 93.900 array('ROLE_NAME')
  name = a[2]; main = a[3]; spare = a[4]; epoch = a[5]; version = a[6]
  if \validPeer(main) then raise syntax 93.900 array('MAIN')
  if spare \== '' then if \validPeer(spare) | spare == main then raise syntax 93.900 array('SPARE')
  if \validNumber(epoch) | \validNumber(version) then raise syntax 93.900 array('COUNTER')
  seeds = parseList(a[7], .true)
  keys = parseList(a[8], .false)
::attribute canonical get
::attribute name get
::attribute main get
::attribute spare get
::attribute epoch get
::attribute version get
::method seeds
  expose seeds
  return seeds~copy
::method keys
  expose keys
  return keys~copy
::method newerThan
  expose epoch version
  use strict arg old
  numeric digits 30
  return epoch > old~epoch | (epoch = old~epoch & version > old~version)
::method peers
  expose main spare seeds
  out = .array~of(main)
  if spare \== '' then out~append(spare)
  do p over seeds
    if \out~hasItem(p) then out~append(p)
  end
  return out

::routine validPeer
  use strict arg s
  if s~length < 1 | s~length > 128 then return .false
  return verify(s,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-') = 0
::routine validNumber
  use strict arg n
  if n~length < 1 | n~length > 18 then return .false
  if verify(n,'0123456789') \= 0 then return .false
  return n~left(1) \== '0'
::routine parseList
  use strict arg s, allowEmpty
  if s == '' then do
    if allowEmpty then return .array~new
    raise syntax 93.900 array('EMPTY_KEYS')
  end
  a=s~makeArray(','); seen=.directory~new
  if a~items > 16 then raise syntax 93.900 array('LIST_LIMIT')
  do p over a
    if \validPeer(p) then raise syntax 93.900 array('LIST_TOKEN')
    if seen~hasIndex(p) then raise syntax 93.900 array('DUPLICATE_TOKEN')
    seen[p]=1
  end
  return a

/* Deliberately test-only HMAC. No signing authority in daemon API. */
::class XtpTestRoleVerifier public
::method init
  expose keys
  use strict arg testKeys
  keys=testKeys~copy
::method verify
  expose keys
  use strict arg key, canonical, tag
  if \keys~hasIndex(key) then return .false
  if tag~length \= 128 then return .false
  return .HMACSHA512~verify(keys[key], 'XTP-ROLE-TEST/1:'canonical, tag)
::method mode
  return 'TEST_ONLY_HMAC'

/* Store contract: load -> exact signed envelope, replace -> true only on
   published+durable. Caller serializes; one xtpd owns the file. */
::class XtpRoleFile public
::method init
  expose path atomic options
  use strict arg path, atomic, options
  if options~durability \== 'FULL' | \options~noFollow then raise syntax 93.900 array('FULL_REQUIRED')
::method load
  expose path
  s=.stream~new(path)
  if s~open('READ') \== 'READY:' then do
    s~close
    raise syntax 93.900 array('ROLE_READ')
  end
  b=s~charin(1,8193); s~close
  if b~length > 8192 then raise syntax 93.900 array('ROLE_FILE_LIMIT')
  return b
::method replace
  expose path atomic options
  use strict arg bytes
  r=atomic~replace(path,bytes,options)
  /* FULL requested; published with a failed durability stage is ambiguous.
     Runtime quarantines on false and never continues with old routes. */
  return r~ok & r~published & r~durabilityAchieved & r~fileSynced & r~parentSynced & (r~errorStage == '')

::class XtpRoleBootstrap public
::method init
  expose store verifier logger record envelope quarantined
  use strict arg store, verifier, logger
  quarantined=.true
  envelope=store~load
  parsed=self~parseEnvelope(envelope)
  record=parsed[1]
  if \record~keys~hasItem(parsed[2]) then raise syntax 93.900 array('BOOT_UNTRUSTED')
  if \verifier~verify(parsed[2],record~canonical,parsed[3]) then raise syntax 93.900 array('BOOT_BAD_SIGNATURE')
  if \self~event('BOOT_ROLE_LOADED') then raise syntax 93.900 array('BOOT_LOG_UNAVAILABLE')
  quarantined=.false
::method parseEnvelope private
  use strict arg bytes
  if bytes~length > 8192 then raise syntax 93.900 array('ENVELOPE_LIMIT')
  a=bytes~makeArray('0a'x)
  if a~items \= 3 then raise syntax 93.900 array('ENVELOPE_FIELDS')
  if \validPeer(a[2]) then raise syntax 93.900 array('KEY_ID')
  if a[3]~length \= 128 | verify(a[3],'0123456789abcdefABCDEF') \= 0 then raise syntax 93.900 array('TAG')
  return .array~of(.XtpRoleRecord~new(a[1]),a[2],a[3])
::method event private
  expose logger record verifier
  use strict arg kind
  d=.directory~new
  d['KIND']=kind; d['ROLE']=record~name; d['EPOCH']=record~epoch; d['VERSION']=record~version; d['AUTH_MODE']=verifier~mode
  return logger~log(.Log~INFO,d)
::method record
  expose record
  return .XtpRoleRecord~new(record~canonical)
::method quarantined
  expose quarantined
  return quarantined
::method offer
  expose store verifier record envelope quarantined
  use strict arg bytes
  if quarantined then return 'QUARANTINED'
  signal on syntax name invalid
  a=self~parseEnvelope(bytes); next=a[1]
  if \record~keys~hasItem(a[2]) then return self~rejection('UNTRUSTED_KEY')
  if \verifier~verify(a[2],next~canonical,a[3]) then return self~rejection('BAD_SIGNATURE')
  if \next~newerThan(record) then return self~rejection('NOT_NEWER')
  /* R1 excludes key changes; test candidate does not support rotation. */
  if next~keys~makeString('L',',') \== record~keys~makeString('L',',') then return self~rejection('KEY_CHANGE_REFUSED')
  if \self~event('ROLE_CHANGE_REQUEST') then do
    quarantined=.true; return 'LOG_UNAVAILABLE'
  end
  quarantined=.true
  if \store~replace(bytes) then do
    ignore=self~event('ROLE_PUBLICATION_UNCERTAIN')
    return 'PUBLICATION_UNCERTAIN'
  end
  record=next; envelope=bytes
  if \self~event('ROLE_CHANGE_PUBLISHED') then return 'LOG_UNAVAILABLE'
  quarantined=.false
  return 'ACCEPTED'
  invalid:
  signal off syntax
  return self~rejection('INVALID_OR_FAILED')
::method rejection private
  expose quarantined
  use strict arg reason
  if \self~event('ROLE_'reason) then do
    quarantined=.true; return 'LOG_UNAVAILABLE'
  end
  return reason
::method catchUp
  expose record quarantined
  use strict arg transport
  if quarantined then return 'QUARANTINED'
  /* Snapshot initial sources: unverified offers never expand query targets. */
  peers=record~peers; found=.false
  do p over peers
    bytes=transport~fetchRole(p)
    if bytes == .nil then iterate
    outcome=self~offer(bytes)
    if outcome == 'ACCEPTED' then found=.true
    if outcome == 'NOT_NEWER' then do
      if bytes~makeArray('0a'x)[1] == record~canonical then found=.true
    end
    if quarantined then return 'QUARANTINED'
  end
  if found then return 'ROLE_SOURCE'
  return 'NO_ROLE_SOURCE'
/* Called by the single xtpd host at startup, not an independent daemon. */
::method start
  use strict arg transport, probe
  source=self~catchUp(transport)
  answer=self~resolve(probe)
  out=.directory~new
  out['SOURCE']=source; out['STATUS']=answer[1]; out['PEER']=answer[2]
  out['READY']=(answer[1] == 'FRESH')
  return out
::method resolve
  expose record quarantined
  use strict arg probe
  if quarantined then return .array~of('QUARANTINED','')
  /* A trusted adapter must obtain an authenticated, current response from
     the exact logical peer. No cached response or mere socket reachability. */
  if probe~confirms(record~main,'MAIN',record~epoch,record~version) then do
    if \self~event('LDAP_FRESH') then do
      quarantined=.true; return .array~of('LOG_UNAVAILABLE','')
    end
    return .array~of('FRESH',record~main)
  end
  if record~spare \== '' then do
    if probe~confirms(record~spare,'SPARE',record~epoch,record~version) then do
      if \self~event('LDAP_STALE') then do
        quarantined=.true; return .array~of('LOG_UNAVAILABLE','')
      end
      return .array~of('STALE',record~spare)
    end
  end
  if \self~event('LDAP_UNAVAILABLE') then quarantined=.true
  return .array~of('UNAVAILABLE','')
