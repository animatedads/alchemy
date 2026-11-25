/* rexxos_arbitrator v0.1-dev6: how LDAP.main moves when LDAP.main is what died.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   Tom Dyer, 2026-11-25: probably with a preplanned LDAP.spare address in a
   file, which then takes over and switches to LDAP resolution.

   As DNS keeps root hints: every XTP daemon keeps a bootstrap file with
   the role record - where NAME.main and NAME.spare are, the role epoch, a
   version, a few seed MUs, and the keys trusted to announce a new record.
   The two role addresses are never looked up through LDAP; they come from
   the file, which breaks the loop.

   - While the main does not answer, a daemon reads from the spare (a
     replica; answers may be slightly behind: STALE).  It never decides the
     main is dead; the quorum does.
   - After the quorum, the promoted spare's record is signed by the role
     authority and sent to every daemon.  A daemon accepts it only if the
     key is one its file trusts, the signature checks, and the record is
     newer (higher epoch, or same epoch and higher version).  It rewrites
     its file and goes back to LDAP resolution through the new main.
   - An old main that comes back hears the higher epoch and stands down.
   - A daemon that slept through the change asks its file's main and spare;
     if both are gone, its seeds.  The newest verified record wins.  If no
     source answers it says NO_ROLE_SOURCE (and degrades to its emergency
     files, as the XTP daemon design says).
   - The trusted keys travel in the record itself, so the trust anchor is
     local: a daemon never asks the LDAP that may be dead whether an
     announcement about LDAP is genuine.

   RoleAuthority stands in for Tom's Auth (a key in a su-locked account
   that signs for n uses, with one lockout point).  Its signature is a
   keyed checksum: a STAND-IN, NOT CRYPTOGRAPHY.  The real one signs with a
   private key and daemons verify with the public key in their file. */

::requires 'PlanRunner.cls'

/* ------------------------------------------------------------------ */
::class RoleAuthority public
::method init
  expose keys
  keys = .Directory~new
::method addKey
  expose keys
  use strict arg keyId, secret, uses = 1000
  k = .Directory~new; k['SECRET'] = secret; k['LOCKED'] = .false; k['USES'] = uses
  keys[keyId] = k
  return self
/* The single lockout point: a locked key signs nothing. */
::method lock
  expose keys
  use strict arg keyId
  keys[keyId]['LOCKED'] = .true
  return self
::method unlock
  expose keys
  use strict arg keyId
  keys[keyId]['LOCKED'] = .false
  return self
::method sign
  expose keys
  use strict arg keyId, text
  if \keys~hasIndex(keyId) then raise syntax 93.900 array ('AUTH_UNKNOWN_KEY' keyId)
  k = keys[keyId]
  if k['LOCKED'] then raise syntax 93.900 array ('AUTH_LOCKED' keyId)
  if k['USES'] <= 0 then raise syntax 93.900 array ('AUTH_EXHAUSTED' keyId)
  k['USES'] -= 1
  return keyedSum(k['SECRET'], text)
/* Stand-in for public-key verification. */
::method verify
  expose keys
  use strict arg keyId, text, sig
  if \keys~hasIndex(keyId) then return .false
  return keyedSum(keys[keyId]['SECRET'], text) == sig

::routine keyedSum
  use strict arg secret, text
  numeric digits 20
  h = 7
  s = secret'|'text
  do i = 1 to length(s)
    h = (h * 131 + c2d(substr(s, i, 1))) // 1000000007
  end
  return 'SUM' || h

/* ------------------------------------------------------------------ */
::class RoleRecord public
::method init
  expose name main spare epoch version seeds keys
  use strict arg name, main, spare, epoch, version, seeds, keys
::attribute name get
::attribute main get
::attribute spare get
::attribute epoch get
::attribute version get
::attribute seeds get
::attribute keys get
::method canonical
  expose name main spare epoch version seeds keys
  return 'ROLE|'name'|'main'|'spare'|'epoch'|'version'|'seeds~makeString('L', ',')'|'keys~makeString('L', ',')
/* Newer means a higher epoch, or the same epoch and a higher version. */
::method newerThan
  expose epoch version
  use strict arg other
  if epoch > other~epoch then return .true
  if epoch = other~epoch & version > other~version then return .true
  return .false
::method fromCanonical class
  use strict arg line
  parse var line tag '|' name '|' main '|' spare '|' epoch '|' version '|' seeds '|' keys
  if tag \== 'ROLE' then raise syntax 93.900 array ('Not a role record:' line)
  return self~new(name, main, spare, epoch, version, seeds~makeArray(','), keys~makeArray(','))

/* ------------------------------------------------------------------ */
/* One XTP daemon's view: its bootstrap file and what it does with it. */
::class XtpDaemonSim public
::method init
  expose mu world record keyId sig accepted rejected lastSource
  use strict arg mu, world, record, keyId, sig
  accepted = 0; rejected = .Array~new; lastSource = ''
::attribute mu get
::attribute record get
::attribute keyId get
::attribute sig get
::attribute accepted get
::attribute rejected get
::attribute lastSource get
/* An announcement or an answer: accept it only if trusted, genuine and newer. */
::method offer
  expose record keyId sig accepted rejected world
  use strict arg rec, recKey, recSig
  if rec~name \== record~name then do; rejected~append('OTHER_ROLE'); return 'REJECTED_OTHER_ROLE'; end
  if record~keys~hasItem(recKey) = .false then do; rejected~append('UNTRUSTED_KEY'); return 'REJECTED_UNTRUSTED_KEY'; end
  if \world~authority~verify(recKey, rec~canonical, recSig) then do; rejected~append('BAD_SIGNATURE'); return 'REJECTED_BAD_SIGNATURE'; end
  if \rec~newerThan(record) then do; rejected~append('NOT_NEWER'); return 'REJECTED_NOT_NEWER'; end
  record = rec; keyId = recKey; sig = recSig
  accepted += 1
  return 'ACCEPTED'
/* Resolve a service address: through the main when it answers at the
   file's epoch, else from the spare's replica, marked STALE. */
::method lookup
  expose record world
  use strict arg address
  if world~answersAsMain(record~main, record~epoch) then return .Array~of('FRESH', world~routes[address])
  if record~spare \== '' & world~alive(record~spare) then return .Array~of('STALE', world~routes[address])
  return .Array~of('UNAVAILABLE', '')
/* On waking: ask the file's main, then its spare, then the seeds.  The
   newest verified record wins. */
::method start
  expose record world lastSource
  lastSource = 'NO_ROLE_SOURCE'
  adopted = ''; answered = ''
  asked = .Array~new
  order = .Array~of(record~main, record~spare)
  do mu over record~seeds; order~append(mu); end
  do mu over order
    if mu == '' | asked~hasItem(mu) | mu == self~mu then iterate
    asked~append(mu)
    if \world~alive(mu) then iterate
    d = world~daemon(mu)
    r = self~offer(d~record, d~keyId, d~sig)
    if r == 'ACCEPTED' then adopted = mu
    if r == 'REJECTED_NOT_NEWER' & answered == '' then answered = mu
  end
  /* The source of the record adopted; else one that confirmed the file. */
  if adopted \== '' then lastSource = adopted
  else if answered \== '' then lastSource = answered
  return lastSource

/* ------------------------------------------------------------------ */
/* A cluster with XTP daemons, LDAP role holders and a role authority. */
::class RoleWorld public subclass SimulatedCluster
::method init
  expose daemons up ldapRole ldapEpoch authority announceKey versions
  use strict arg authority, announceKey
  self~init:super
  daemons = .Directory~new; up = .Directory~new
  ldapRole = .Directory~new; ldapEpoch = .Directory~new; versions = .Directory~new
::attribute authority get
::method addMu
  use strict arg mu, state
  self~addMachine(mu, state)
  self~setUp(mu, .true)
  return self
::method setUp private
  expose up
  use strict arg mu, b
  up[mu] = b
::method alive
  expose up
  use strict arg mu
  if \up~hasIndex(mu) then return .false
  return up[mu]
::method kill
  use strict arg mu
  self~setUp(mu, .false)
  return self
/* A daemon that slept: down for announcements, keeps its file. */
::method sleep
  use strict arg mu
  self~setUp(mu, .false)
  return self
::method wake
  use strict arg mu
  self~setUp(mu, .true)
  return self~daemon(mu)~start
/* An MU that comes back: its daemon catches up, then an old main stands down. */
::method returnMu
  expose ldapRole ldapEpoch
  use strict arg mu, roleName
  self~setUp(mu, .true)
  d = self~daemon(mu)
  src = d~start
  if ldapRole[mu] == 'main' & d~record~epoch > ldapEpoch[mu] & d~record~main \== mu then ldapRole[mu] = 'stood-down'
  return src
::method daemon
  expose daemons
  use strict arg mu
  return daemons[mu]
/* First record, signed and written to every daemon's file. */
::method bootstrap
  expose daemons ldapRole ldapEpoch authority announceKey versions
  use strict arg name, main, spare, seeds
  rec = .RoleRecord~new(name, main, spare, 1, 1, seeds, .Array~of(announceKey))
  sig = authority~sign(announceKey, rec~canonical)
  do mu over self~machineIds; daemons[mu] = .XtpDaemonSim~new(mu, self, rec, announceKey, sig); end
  ldapRole[main] = 'main'; ldapEpoch[main] = 1; ldapRole[spare] = 'spare'; ldapEpoch[spare] = 1
  versions[name] = 1
  e = self~epochs; e[name] = 1
  self~setRoute(name'.main', main); self~setRoute(name'.spare', spare)
  return self
::method answersAsMain
  expose ldapRole ldapEpoch
  use strict arg mu, epoch
  if \self~alive(mu) then return .false
  if \ldapRole~hasIndex(mu) then return .false
  return ldapRole[mu] == 'main' & ldapEpoch[mu] >= epoch
::method ldapRoleOf
  expose ldapRole
  use strict arg mu
  if ldapRole~hasIndex(mu) then return ldapRole[mu]
  return ''
::method perform
  expose daemons ldapRole ldapEpoch authority announceKey versions
  use strict arg step, key, now
  if step~kind \== 'ANNOUNCE_ROLE' then return self~perform:super(step, key, now)
  self~breaker('BEFORE_PERFORM', step~sequenceNo)
  parse value step~address with name '.' role
  routes = self~routes
  main = routes[name'.main']; spare = routes[name'.spare']
  if role == 'main' then do
    main = step~mu
    if spare == main then spare = ''
  end
  else spare = step~mu
  epoch = self~epochs[name]
  version = versions[name] + 1
  seeds = self~machineIds
  rec = .RoleRecord~new(name, main, spare, epoch, version, seeds, .Array~of(announceKey))
  sig = authority~sign(announceKey, rec~canonical)      /* a locked authority stops here */
  versions[name] = version
  routes[name'.main'] = main; routes[name'.spare'] = spare
  ldapRole[main] = 'main'; ldapEpoch[main] = epoch
  if spare \== '' then do; ldapRole[spare] = 'spare'; ldapEpoch[spare] = epoch; end
  do mu over daemons~allIndexes~sort
    if self~alive(mu) then daemons[mu]~offer(rec, announceKey, sig)
  end
  self~remember(key)
  self~breaker('AFTER_PERFORM', step~sequenceNo)
  return .true
