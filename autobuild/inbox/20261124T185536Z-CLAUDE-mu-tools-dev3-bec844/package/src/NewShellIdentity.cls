/* NewShellIdentity.cls - NewShell prototype: computer~sessions~loggedon~users
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  23 Nov 2026.
 * Target: ooRexx 5.3.0 trunk (uses CATCH / FINALLY / THROW, RFE #31).
 *
 * The question this answers: when a caller writes
 *     do u over computer~sessions~loggedon~users
 *       say u~name u~limits~storage
 *     end
 * it does not know whether a user came from LDAP, /etc/passwd or anywhere
 * else.  The rule implemented here:
 *   - a Session records the provider that AUTHENTICATED it;
 *   - a User is identified by (provider, principal), never by name alone;
 *   - other providers are asked by name only to enrich and to detect clashes;
 *   - every provider failure is kept as an object on the result set, so a
 *     partial answer says it is partial.
 * Progress goes through oorexx_logging v0.7 (LoggingCore.cls).
 */

::class NewShellLog public
::method setup class
  expose service logger shown
  use strict arg showProgress = .true
  shown = showProgress
  service = .LogService~new('newshell')
  service~addTarget(.NewShellProgressTarget~new('progress', .Log~INTERNAL, showProgress))
  rule = .LogRule~new('newshell-progress', 'newshell', 'NewShellLog', 'progress', -
    .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('progress'))
  service~addRule(rule)
  logger = service~loggerFor(.NewShellLog~new, 'progress', .array~new, .Log~INTERNAL)
  return self
::method progress class
  expose logger
  use strict arg text
  if var('logger') = 0 then self~setup
  logger~log(.Log~INFO, text)
  return .true
::method module_version class
  return '0.1-dev1'
::method module_lastChanged class
  return '2026-11-23'

/* A logging target that prints progress on stderr, so stdout stays results.
 * Belongs in oorexx_logging once accepted; kept here for the prototype. */
::class NewShellProgressTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::method init
  expose name scope scopeObject enabled shown events
  use strict arg name, scopeValue, showProgress = .true
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
  shown = showProgress
  events = .array~new
::method accept
  expose enabled shown events
  use strict arg event
  if \enabled then return .false
  events~append(event)
  if shown then .error~lineout('[ns]' event~payload)
  return .true
::method events
  expose events
  return events
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* The outcome of one host command: rc, stdout and stderr as objects. */
::class HostOutcome public
::attribute command get
::attribute rc get
::attribute out get
::attribute err get
::method init
  expose command rc out err
  use strict arg command, rc, out, err
::method ok
  expose rc
  return rc = 0
::method firstErr
  expose err
  if err~items = 0 then return ''
  return err[1]
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class HostCommand public
::method run class
  use strict arg commandText
  outLines = .array~new
  errLines = .array~new
  rcValue = 0
  do
    address system commandText with output using (outLines) error using (errLines)
  catch c = error, failure
    rcValue = c~rc
  end
  return .HostOutcome~new(commandText, rcValue, outLines, errLines)
/* Arguments reach the host only after this check; a string that could
 * change the meaning of the command line is refused, never quoted around. */
::method safeWord class
  use strict arg word
  if word~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/:') > 0 then
    throw user unsafeArgument description ('refused to pass' word 'to a host command')
  return word
::method module_version class
  return '0.1-dev1'
::method module_lastChanged class
  return '2026-11-23'

/* A provider that could not answer. Kept on the result set, never dropped. */
::class ProviderFailure public
::attribute providerId get
::attribute reason get
::method init
  expose providerId reason
  use strict arg providerId, reason
::method string
  expose providerId reason
  return providerId':' reason
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* Registration of features: session sources, identity providers and storage
 * limit providers, each kind kept in the order it was registered. */
::class ProviderRegistry public
::method init
  expose sessionSources identityProviders storageProviders
  sessionSources = .array~new
  identityProviders = .array~new
  storageProviders = .array~new
::method registerSessionSource
  expose sessionSources
  use strict arg provider
  sessionSources~append(provider)
  .NewShellLog~progress('registered session source' provider~id)
  return self
::method registerIdentityProvider
  expose identityProviders
  use strict arg provider
  identityProviders~append(provider)
  .NewShellLog~progress('registered identity provider' provider~id)
  return self
::method registerStorageProvider
  expose storageProviders
  use strict arg provider
  storageProviders~append(provider)
  .NewShellLog~progress('registered storage provider' provider~id)
  return self
::method sessionSources
  expose sessionSources
  return sessionSources
::method identityProviders
  expose identityProviders
  return identityProviders
::method storageProviders
  expose storageProviders
  return storageProviders
::method identityProvider
  expose identityProviders
  use strict arg providerId
  do p over identityProviders
    if p~id == providerId then return p
  end
  return .nil
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class Computer public
::attribute registry get
::attribute failures get
::method init
  expose registry failures
  use strict arg registry
  failures = .array~new
::method sessions
  expose registry failures
  found = .array~new
  setFailures = .array~new
  do source over registry~sessionSources
    .NewShellLog~progress('asking session source' source~id)
    do
      do s over source~sessions
        found~append(s)
      end
    catch c = any
      f = .ProviderFailure~new(source~id, conditionText(c))
      setFailures~append(f)
      failures~append(f)
      .NewShellLog~progress('session source failed:' f~string)
    end
  end
  return .SessionSet~new(self, found, setFailures)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* One login, console or agent connection. authenticatedBy names the provider
 * whose check created it; principal is that provider's own key. */
::class Session public
::attribute sourceId get
::attribute name get
::attribute authenticatedBy get
::attribute principal get
::attribute console get
::attribute pid get
::method init
  expose sourceId name authenticatedBy principal console pid
  use strict arg sourceId, name, authenticatedBy, principal, console, pid = ''
::method active
  expose pid
  if pid == '' then return .true
  return .File~new('/proc/'pid)~exists
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class SessionSet public
::attribute failures get
::method init
  expose computer items failures
  use strict arg computer, items, failures
::method makeArray
  expose items
  return items
::method items
  expose items
  return items~items
::method complete
  expose failures
  return failures~items = 0
::method loggedon
  expose computer items failures
  live = .array~new
  do s over items
    if s~active then live~append(s)
  end
  .NewShellLog~progress(live~items 'of' items~items 'sessions are live')
  return .SessionSet~new(computer, live, failures)
::method users
  expose computer items failures
  registry = computer~registry
  byKey = .table~new
  keys = .array~new
  userFailures = failures~copy
  do s over items
    key = s~authenticatedBy'|'s~principal
    if byKey~hasIndex(key) then iterate
    u = .User~new(s, registry)
    do
      u~resolve
    catch c = any
      f = .ProviderFailure~new(s~authenticatedBy, conditionText(c))
      userFailures~append(f)
      computer~failures~append(f)
      .NewShellLog~progress('identity failed:' f~string)
    end
    byKey[key] = u
    keys~append(key)
  end
  ordered = .array~new
  do key over keys~sort
    ordered~append(byKey[key])
  end
  /* two users with one name from different providers are different people */
  names = .table~new
  do u over ordered
    if names~hasIndex(u~name) then do
      u~flag('same name as' names[u~name]~identity)
      names[u~name]~flag('same name as' u~identity)
    end
    else names[u~name] = u
  end
  .NewShellLog~progress(ordered~items 'distinct users')
  return .UserSet~new(computer, ordered, userFailures)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class UserSet public
::attribute failures get
::method init
  expose computer items failures
  use strict arg computer, items, failures
::method makeArray
  expose items
  return items
::method items
  expose items
  return items~items
::method complete
  expose failures
  return failures~items = 0
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* A User is (provider, principal).  record is the authenticating provider's
 * own entry; alsoKnownTo lists other providers holding the same name. */
::class User public
::attribute name get
::attribute source get
::attribute record get
::attribute flags get
::attribute alsoKnownTo get
::method init
  expose name source principal registry record flags alsoKnownTo
  use strict arg session, registry
  name = session~name
  source = session~authenticatedBy
  principal = session~principal
  record = .nil
  flags = .array~new
  alsoKnownTo = .array~new
::method identity
  expose name source
  return name'@'source
::method resolve
  expose name source principal registry record alsoKnownTo
  provider = registry~identityProvider(source)
  if provider == .nil then throw user noProvider description ('no identity provider registered as' source)
  record = provider~lookupPrincipal(principal)
  if record == .nil then throw user unknownPrincipal description (source 'does not know' principal)
  do other over registry~identityProviders
    if other~id == source then iterate
    do
      otherRecord = other~lookupName(name)
      if otherRecord \== .nil then do
        alsoKnownTo~append(other~id 'uid' otherRecord['UID'])
        if otherRecord['UID'] \== record['UID'] then self~flag(other~id 'has' name 'as uid' otherRecord['UID'])
      end
    catch c = any
      .NewShellLog~progress('enrichment from' other~id 'failed:' conditionText(c))
    end
  end
  return self
::method flag
  expose flags
  use strict arg text
  flags~append(text)
  return self
::method uid
  expose record
  if record == .nil then return ''
  return record['UID']
::method home
  expose record
  if record == .nil then return ''
  return record['HOME']
::method limits
  expose registry
  return .Limits~new(self, registry)
::method string
  return self~identity
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class Limits public
::method init
  expose user registry
  use strict arg user, registry
::method storage
  expose user registry
  notes = .array~new
  do provider over registry~storageProviders
    do
      limit = provider~limitFor(user)
      /* "no quota" is a fact, not a bound: note it and ask the next provider */
      if limit \== .nil then do
        if limit~kind == 'NONE' then do
          notes~append(provider~id':' limit~basis)
          limit = .nil
        end
      end
      if limit \== .nil then do
        do n over notes
          limit~note(n)
        end
        return limit
      end
    catch c = any
      notes~append(provider~id 'unknown:' conditionText(c))
      .NewShellLog~progress('storage provider' provider~id 'failed for' user~identity':' conditionText(c))
    end
  end
  return .StorageLimit~new('UNKNOWN', 'no storage provider could answer', notes)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class StorageLimit public
::attribute kind get
::attribute basis get
::attribute notes get
::method init
  expose kind basis notes
  use strict arg kind, basis, notes = (.array~new)
::method note
  expose notes
  use strict arg text
  notes~append(text)
  return self
::method string
  expose kind basis notes
  text = kind':' basis
  do n over notes
    text = text '['n']'
  end
  return text
::method makeString
  return self~string
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* ---------------- session sources ---------------- */

/* Logins recorded in utmp by the operating system (PAM did the checking). */
::class UtmpSessionSource public
::method id
  return 'utmp'
::method sessions
  outcome = .HostCommand~run('who')
  if \outcome~ok then throw user sourceFailed description ('who rc' outcome~rc outcome~firstErr)
  found = .array~new
  do line over outcome~out
    parse var line who tty .
    found~append(.Session~new(self~id, who, 'files', who, tty))
  end
  return found
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* Sessions opened by NewShell consoles after they authenticated.  Each
 * console writes one entry; a dead pid means the session has ended. */
::class NewShellSessionSource public
::method init
  expose directory
  use strict arg directory
::method id
  return 'newshell'
::method sessions
  expose directory
  if \.File~new(directory)~isDirectory then throw user sourceFailed description ('no session registry at' directory)
  found = .array~new
  do f over .File~new(directory)~listFiles
    if \f~name~endsWith('.session') then iterate
    fields = .directory~new
    s = .stream~new(f~absolutePath)
    lines = s~arrayIn
    s~close
    do line over lines
      parse var line key '=' value
      fields[key~strip~upper] = value~strip
    end
    found~append(.Session~new(self~id, fields['NAME'], fields['PROVIDER'], fields['PRINCIPAL'], fields['CONSOLE'], fields['PID']))
  end
  return found
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* ---------------- identity providers ---------------- */

/* /etc/passwd read directly, so "files" never silently means NSS-plus-LDAP. */
::class FilesIdentityProvider public
::method init
  expose path
  use strict arg path = '/etc/passwd'
::method id
  return 'files'
::method entries
  expose path
  rows = .array~new
  s = .stream~new(path)
  lines = s~arrayIn
  s~close
  do line over lines
    parse var line name ':' . ':' uid ':' gid ':' gecos ':' home ':' shell
    entry = .directory~new
    entry['NAME'] = name; entry['UID'] = uid; entry['HOME'] = home; entry['SHELL'] = shell
    entry['SOURCE'] = 'files:'path
    rows~append(entry)
  end
  return rows
::method lookupName
  use strict arg wanted
  do entry over self~entries
    if entry['NAME'] == wanted then return entry
  end
  return .nil
::method lookupPrincipal
  use strict arg principal
  return self~lookupName(principal)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

::class LdapIdentityProvider public
::method init
  expose uri base
  use strict arg uri, base
::method id
  return 'ldap'
::method available
  if \.HostCommand~run('command -v ldapsearch')~ok then throw user providerUnavailable description ('ldapsearch is not installed')
  return .true
::method query
  expose uri base
  use strict arg filterText
  self~available
  outcome = .HostCommand~run('ldapsearch -x -LLL -H' .HostCommand~safeWord(uri) '-b' "'"base"'" "'"filterText"'" 'uid uidNumber homeDirectory loginShell')
  if \outcome~ok then throw user providerUnavailable description ('ldapsearch rc' outcome~rc outcome~firstErr)
  entry = .nil
  do line over outcome~out
    parse var line attr ':' value
    value = value~strip
    select
      when attr == 'dn' then do
        entry = .directory~new
        entry['DN'] = value
        entry['SOURCE'] = 'ldap:'uri
      end
      when attr == 'uid' then entry['NAME'] = value
      when attr == 'uidNumber' then entry['UID'] = value
      when attr == 'homeDirectory' then entry['HOME'] = value
      when attr == 'loginShell' then entry['SHELL'] = value
      otherwise nop
    end
  end
  return entry
::method lookupName
  use strict arg wanted
  return self~query('(uid='.HostCommand~safeWord(wanted)')')
::method lookupPrincipal
  use strict arg principal
  return self~lookupName(principal)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* ---------------- storage limit providers ---------------- */

/* Disk quota by numeric uid, so it works for users NSS cannot see. */
::class QuotaStorageProvider public
::method id
  return 'quota'
::method limitFor
  use strict arg user
  if \.HostCommand~run('command -v quota')~ok then throw user providerUnavailable description ('quota is not installed')
  uid = user~uid
  if uid == '' then throw user providerUnavailable description ('no uid for' user~identity)
  outcome = .HostCommand~run('quota -u' .HostCommand~safeWord(uid))
  if outcome~out~items > 0 then do
    if outcome~out[outcome~out~items]~strip~endsWith('none') then return .StorageLimit~new('NONE', 'no quota set for uid' uid)
  end
  /* quota prints nothing and returns 1 when no filesystem has quotas on */
  if outcome~rc = 1 then do
    if outcome~out~items = 0 then do
      if outcome~err~items = 0 then return .StorageLimit~new('NONE', 'no filesystem has quotas enabled')
    end
  end
  reason = outcome~firstErr
  if reason == '' then reason = 'quota rc' outcome~rc
  throw user providerUnavailable description (reason)
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* Without a quota, a user is bounded by the filesystem holding their home. */
::class FilesystemStorageProvider public
::method id
  return 'filesystem'
::method limitFor
  use strict arg user
  home = user~home
  if home == '' then throw user providerUnavailable description ('no home directory for' user~identity)
  probe = home
  note = ''
  do while \.File~new(probe)~exists
    note = 'home' home 'does not exist; measured parent'
    probe = .File~new(probe)~parent
  end
  outcome = .HostCommand~run('df -Pk' .HostCommand~safeWord(probe))
  if \outcome~ok then throw user providerUnavailable description ('df rc' outcome~rc outcome~firstErr)
  parse value outcome~out[outcome~out~items] with . sizeKb usedKb freeKb . mount
  limit = .StorageLimit~new('FILESYSTEM', 'bounded by' mount (freeKb % 1048576)'G free of' (sizeKb % 1048576)'G')
  if note \== '' then limit~note(note probe)
  return limit
::method module_version
  return '0.1-dev1'
::method module_lastChanged
  return '2026-11-23'

/* Condition objects from THROW carry a DESCRIPTION; SYNTAX ones an ERRORTEXT. */
::routine conditionText public
  use strict arg c
  if c~description \== '' then return c~description
  if c~condition == 'SYNTAX' then return 'SYNTAX' c~code c~errortext
  return c~condition

::requires 'LoggingCore.cls'
