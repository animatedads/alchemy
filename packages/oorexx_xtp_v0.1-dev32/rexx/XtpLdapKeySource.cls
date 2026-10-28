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
 * What counts as working (review H3, ML1).  fetch succeeds only if all of
 * these hold; otherwise it reports every problem and installs nothing, so the
 * caller falls back to the key file and keeps the LDAP keys it already has:
 *   - the bind and all three searches succeed;
 *   - at least one XTP key is found (zero usually means the bind DN cannot
 *     read the key sets, or baseDn is wrong);
 *   - every XTP key set is owned by a service principal in the directory and
 *     sits under that principal's entry; no two sets share an entity id;
 *   - every usable generation of an XTP set sits under its set's entry, has a
 *     16-hex-digit key id, valid dates, and a secret reference that starts with
 *     secretRefPrefix || service || '/', and Secret Broker resolves it to 64
 *     hex digits.
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
  problems = .array~new
  /* principal entity id -> DN */
  principalDn = .directory~new
  do entry over principals~value
    principalDn[entry~attributes~first('oorexxEntityId')] = entry~dn~lower
  end
  /* XTP key set id -> service, protection, DN */
  services = .directory~new
  protections = .directory~new
  setDn = .directory~new
  do entry over sets~value
    a = entry~attributes
    usage = a~first('oorexxKeyUsage')~upper
    if usage = 'XTP_AUTHENTICATE' then protection = 'authenticate'
    else if usage = 'XTP_ENCRYPT' then protection = 'encrypt'
    else iterate
    setId = a~first('oorexxEntityId')
    owner = a~first('oorexxOwnerId')
    if services~hasIndex(setId) | setDn~hasIndex(setId) then do; problems~append('key set' setId 'appears twice'); iterate; end
    if owner~left(8) <> 'service:' | owner~length < 9 then do; problems~append('key set' setId 'is owned by' owner', not by a service:<name> principal'); setDn[setId] = ''; iterate; end
    if \principalDn~hasIndex(owner) then do; problems~append('key set' setId 'is owned by' owner', which is not in the directory'); setDn[setId] = ''; iterate; end
    if \.XtpLdapKeySource~isUnder(entry~dn, principalDn[owner]) then do; problems~append('key set' setId 'is not under its owner' owner); setDn[setId] = ''; iterate; end
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
  if problems~items = 0 & fetched['KEYS']~items = 0 then problems~append('no XTP keys under' baseDn '(can' bindDn 'read the key sets?)')
  if problems~items > 0 then do
    do key over fetched['KEYS']; key['SECRET'] = ''; end
    fetched['KEYS'] = .array~new
    fetched['ERROR'] = problems~makeString('L', '; ')
    return fetched
  end
  fetched['OK'] = .true
  return fetched

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
