/* XtpLdapKeySource.cls: XTP service keys from the Identity Directory over LDAP
 * (decision D-07).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 *
 * Uses the estate's own LDAP client (oorexx_ldap_identity LdapWireClient over
 * SocketSelector) and Secret Broker.  Key material never travels over LDAP:
 * the directory holds a secret reference, and Secret Broker resolves it.
 *
 * Directory mapping (Identity Directory key model, identity.keys/0.1):
 *   principal  service:<named service>          type SERVICE
 *   key set    owner service:<named service>    usage XTP_AUTHENTICATE or XTP_ENCRYPT
 *   generation algorithm AES256GCM or CHACHA20POLY1305
 *              public material = the 16-hex-digit XTP key id
 *              secret reference -> 64 hex digits (32 bytes) through Secret Broker
 *              state ACTIVE (opens and accepts) or RETIRING (accepts only)
 *              notBefore / notAfter honoured
 *
 *   source = .XtpLdapKeySource~new(sockets, 'xtp.keys.ldap', bindDn, bindSecretRef, baseDn, broker)
 *
 * What counts as working.  fetch fails, installs nothing, and the caller falls
 * back to the key file (keeping the LDAP keys it already has), only if the
 * bind or a search fails, or no usable XTP key is found at all (zero usually
 * means the bind DN cannot read the key sets, or baseDn is wrong).
 *
 * Every entry is checked, and an entry that fails is skipped and reported in
 * WARNINGS; it never stops the other services' keys from being refreshed
 * (dev33, review F2: one bad entry used to block every update, revocations
 * included).  A skipped entry's keys are simply not installed, so a service
 * whose set is broken loses its LDAP keys and its sticky profile makes its
 * opens fail: fail closed for that service only.
 *   - a key set must be owned by service:<name> where <name> is a valid XTP
 *     service name (no spaces or control characters: review F1), owned by a
 *     principal in the directory whose id appears only once (dev34), sit
 *     under that principal's entry, and have an entity id no other
 *     well-placed set has (a misplaced set never counts against it);
 *   - a usable generation must sit under its key set's entry, and have a
 *     16-hex-digit key id, readable dates, and a secret reference that starts
 *     with secretRefPrefix || service || '/', which Secret Broker resolves to
 *     64 hex digits.  An entry placed outside its set is ignored, not counted
 *     against the set it names, so nobody can block another service's keys.
 * The placement rules mean a principal that may write only its own subtree
 * cannot attach a key to another service, and the prefix rule means the
 * directory cannot make this process fetch an unrelated secret.
 *
 * Keys are installed in one step (xtpNativeKeyReplaceSource): there is no
 * moment at which a service has lost its old keys but not received its new ones.
 */
::class XtpLdapKeySource public
::method init
  expose sockets logicalName bindDn bindSecretRef baseDn broker secretRefPrefix
  use strict arg sockets, logicalName, bindDn, bindSecretRef, baseDn, broker, secretRefPrefix = 'secret://xtp/'
::method name
  return 'ldap'

::method apply
  applied = .directory~new
  applied['OK'] = .false
  applied['COUNT'] = 0
  applied['ERROR'] = ''
  signal on syntax name failed
  fetched = self~fetch
  if \fetched['OK'] then do
    applied['ERROR'] = fetched['ERROR']
    return applied
  end
  lines = ''
  do key over fetched['KEYS']
    lines = lines || key['SERVICE'] key['KEYID'] key['PROTECTION'] key['SUITE'] key['SECRET'] '-' key['NOTBEFORE'] key['NOTAFTER'] key['STATE'] || '0a'x
    key['SECRET'] = ''
  end
  applied['COUNT'] = xtpNativeKeyReplaceSource('ldap', lines)
  lines = ''
  applied['WARNINGS'] = fetched['WARNINGS']
  applied['OK'] = .true
  return applied
failed:
  applied['ERROR'] = 'LDAP key source failed:' condition('O')['ADDITIONAL']~makeString
  return applied

/* Read principals, key sets and generations; check them; resolve each secret.
 * Installs nothing.  OK is false, with every problem in ERROR, unless all is well. */
::method fetch
  expose sockets logicalName bindDn bindSecretRef baseDn broker secretRefPrefix
  fetched = .directory~new
  fetched['OK'] = .false
  fetched['ERROR'] = ''
  fetched['KEYS'] = .array~new
  fetched['WARNINGS'] = .array~new
  bindLease = broker~acquire(bindSecretRef)
  bindSecret = bindLease~secretForTrustedConsumer
  if \bindSecret~ok then do
    ignore = bindLease~retire
    fetched['ERROR'] = 'LDAP bind secret unavailable:' bindSecret~code
    return fetched
  end
  client = .LdapWireClient~new('', 0, sockets, logicalName)
  r = client~connect
  if \r~ok then do
    ignore = bindLease~retire
    fetched['ERROR'] = 'LDAP connect failed:' r~code
    return fetched
  end
  r = client~bind(bindDn, bindSecret~value)
  ignore = bindLease~retire
  if \r~ok then do
    client~unbind
    fetched['ERROR'] = 'LDAP bind failed:' r~code
    return fetched
  end
  principals = client~search(baseDn, 'SUB', '(objectClass=oorexxPrincipal)')
  sets = client~search(baseDn, 'SUB', '(objectClass=oorexxKeySet)')
  generations = client~search(baseDn, 'SUB', '(objectClass=oorexxKeyGeneration)')
  client~unbind
  if \principals~ok then do; fetched['ERROR'] = 'LDAP principal search failed:' principals~code; return fetched; end
  if \sets~ok then do; fetched['ERROR'] = 'LDAP key set search failed:' sets~code; return fetched; end
  if \generations~ok then do; fetched['ERROR'] = 'LDAP key generation search failed:' generations~code; return fetched; end
  problems = fetched['WARNINGS']
  /* principal entity id -> DN.  An id that appears twice is unusable (third
   * review L4: a planted principal with a victim's id must not take its place). */
  principalDn = .directory~new
  dupPrincipals = .set~new
  do entry over principals~value
    pid = entry~attributes~first('oorexxEntityId')
    if principalDn~hasIndex(pid) then do
      if \dupPrincipals~hasIndex(pid) then problems~append('principal' pid~left(80)~changeStr('0a'x, ' ') 'appears twice; neither is trusted')
      dupPrincipals~put(pid)
      principalDn[pid] = ''
      iterate
    end
    principalDn[pid] = entry~dn~lower
  end
  /* XTP key set id -> service, protection, DN.  Only sets that pass the owner
   * and placement checks count; a set that fails is reported and ignored, so a
   * misplaced set carrying another set's id cannot knock that set out. */
  services = .directory~new
  protections = .directory~new
  setDn = .directory~new
  dupSets = .set~new
  do entry over sets~value
    a = entry~attributes
    usage = a~first('oorexxKeyUsage')~upper
    if usage = 'XTP_AUTHENTICATE' then protection = 'authenticate'
    else if usage = 'XTP_ENCRYPT' then protection = 'encrypt'
    else iterate
    setId = a~first('oorexxEntityId')
    owner = a~first('oorexxOwnerId')
    if owner~left(8) <> 'service:' | \.XtpLdapKeySource~validServiceName(owner~substr(9)) then do; problems~append('key set' setId~left(80)~changeStr('0a'x, ' ') 'is owned by' owner~left(80)~changeStr('0a'x, ' ')', not by a service:<valid name> principal'); iterate; end
    if \principalDn~hasIndex(owner) then do; problems~append('key set' setId 'is owned by' owner', which is not in the directory'); iterate; end
    if principalDn[owner] = '' then do; problems~append('key set' setId 'is owned by' owner', whose principal id appears twice'); iterate; end
    if \.XtpLdapKeySource~isUnder(entry~dn, principalDn[owner]) then do; problems~append('key set' setId 'is not under its owner' owner); iterate; end
    if dupSets~hasIndex(setId) then iterate
    if services~hasIndex(setId) then do
      /* two well-placed sets with one id: neither is trusted */
      problems~append('key set' setId 'appears twice; both skipped')
      services~remove(setId); protections~remove(setId); setDn~remove(setId); dupSets~put(setId)
      iterate
    end
    services[setId] = owner~substr(9)
    protections[setId] = protection
    setDn[setId] = entry~dn~lower
  end
  do entry over generations~value
    a = entry~attributes
    setId = a~first('oorexxKeySetId')
    if \services~hasIndex(setId) then iterate      /* not an XTP set, or a set already reported */
    state = a~first('oorexxEntryState')~upper
    if state <> 'ACTIVE' & state <> 'RETIRING' then iterate
    genId = a~first('oorexxEntityId')
    service = services[setId]
    if \.XtpLdapKeySource~isUnder(entry~dn, setDn[setId]) then do; problems~append('generation' genId 'is not under its key set' setId); iterate; end
    algorithm = a~first('oorexxKeyAlgorithm')~upper
    if algorithm = 'AES256GCM' then suite = 'aes256gcm'
    else if algorithm = 'CHACHA20POLY1305' then suite = 'chacha20poly1305'
    else do; problems~append('generation' genId 'has algorithm' algorithm', not AES256GCM or CHACHA20POLY1305'); iterate; end
    keyId = a~first('oorexxPublicKey')
    if length(keyId) <> 16 | \datatype(keyId, 'X') then do; problems~append('generation' genId 'has no 16-hex-digit key id'); iterate; end
    notBefore = .XtpLdapKeySource~unixMs(a~first('oorexxNotBefore'))
    notAfter = .XtpLdapKeySource~unixMs(a~first('oorexxNotAfter'))
    if notBefore = '' | notAfter = '' then do; problems~append('generation' genId 'has an unreadable notBefore or notAfter'); iterate; end
    secretRef = a~first('oorexxSecretRef')
    wantPrefix = secretRefPrefix || service || '/'
    if secretRef~left(wantPrefix~length) \== wantPrefix then do; problems~append('generation' genId 'names secret' secretRef', outside' wantPrefix); iterate; end
    lease = broker~acquire(secretRef)
    secret = lease~secretForTrustedConsumer
    if \secret~ok then do
      ignore = lease~retire
      problems~append('generation' genId': Secret Broker could not resolve its secret:' secret~code)
      iterate
    end
    value = secret~value
    ignore = lease~retire
    if length(value) <> 64 | \datatype(value, 'X') then do; problems~append('generation' genId': its secret is not 64 hex digits'); iterate; end
    key = .directory~new
    key['SERVICE'] = service
    key['PROTECTION'] = protections[setId]
    key['SUITE'] = suite
    key['KEYID'] = keyId~lower
    key['SECRET'] = value
    key['NOTBEFORE'] = notBefore
    key['NOTAFTER'] = notAfter
    if state = 'ACTIVE' then key['STATE'] = 'active'
    else key['STATE'] = 'retiring'
    fetched['KEYS']~append(key)
  end
  if fetched['KEYS']~items = 0 then do
    fetched['ERROR'] = 'no usable XTP keys under' baseDn '(can' bindDn 'read the key sets?)'
    if problems~items > 0 then fetched['ERROR'] = fetched['ERROR']'; skipped:' problems~makeString('L', '; ')
    return fetched
  end
  fetched['OK'] = .true
  return fetched

/* An XTP named service name, by the rule libxtp applies (valid_service_name):
 * 1-255 characters, none of them a space or control character, no [ or ],
 * at most one colon, and not an IPv4 literal. */
::method validServiceName class
  use strict arg name
  if name~length < 1 | name~length > 255 then return .false
  if name~verify(xrange('00'x, '20'x) || '7f[]', 'M') > 0 then return .false
  if name~countStr(':') > 1 then return .false
  parse var name a '.' b '.' c '.' d
  if name~countStr('.') = 3 & datatype(a, 'W') & datatype(b, 'W') & datatype(c, 'W') & datatype(d, 'W') then return .false
  return .true

/* Is dn inside the subtree of parentDn (case-insensitive, parent itself excluded)? */
::method isUnder class
  use strict arg dn, parentDn
  if parentDn = '' then return .false
  dn = dn~lower
  tail = ',' || parentDn~lower
  return dn~length > tail~length & dn~right(tail~length) == tail

/* Identity Directory instants are UTC ISO text; libxtp wants Unix ms (0 = unbounded).
 * Returns '' for text that is not a date, so a bad entry is reported, not raised. */
::method unixMs class
  use strict arg text
  numeric digits 20
  if text = '' then return 0
  signal on syntax name notADate
  /* both instants are read without a zone, so the difference is exact UTC */
  instant = .DateTime~fromIsoDate(text~strip('T', 'Z'))
  epoch = .DateTime~new(1970, 1, 1)
  ms = (instant - epoch)~totalMicroseconds % 1000
  if ms < 0 then return ''
  return ms
notADate:
  return ''

::requires 'XtpServiceKeys.cls'
::requires 'src/LdapWireClient.cls'
