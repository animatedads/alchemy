/* XtpServiceKeys.cls: per-service XTP keys, from LDAP first and a key file second
 * (decision D-07).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 *
 * XTP links are per named service, so keys and the protection profile are per
 * named service.  libxtp only applies the keys it holds; this class decides
 * where they come from and installs them:
 *
 *   sources = .array~of(ldapSource, fileSource)      -- in order of preference
 *   keys    = .XtpServiceKeys~new(sources)
 *   outcome = keys~refresh                           -- SOURCE COUNT ERRORS
 *
 * The first source that works wins.  When LDAP works, keys from a key file are
 * dropped: the file is only the fallback when LDAP is unavailable.  When LDAP
 * fails, keys fetched from it earlier are kept until they expire, and the file
 * is loaded as well.  Call refresh again on a timer, or on an LDAP change.
 *
 * A source has a method name ('ldap', 'file', ...) and a method apply, which
 * installs its keys in one step and returns a directory with OK, COUNT and
 * ERROR.  A source that raises an error counts as failed, and the next source
 * is tried.  rexx/XtpLdapKeySource.cls is the LDAP source; XtpFileKeySource is
 * below.
 *
 * Profiles are sticky in libxtp.  A service that has had keys keeps its
 * profile when its keys expire or a source no longer lists them: its opens
 * then fail rather than fall back to clear.  forgetProfile lowers a profile
 * deliberately; require raises one before any keys exist.
 */
::class XtpServiceKeys public
::attribute lastSource get
::method init
  expose sources lastSource
  use strict arg sources
  if \sources~isA(.array) then raise syntax 88.900 array('XtpServiceKeys needs an array of key sources')
  lastSource = ''

::method refresh
  expose sources lastSource
  outcome = .directory~new
  outcome['SOURCE'] = ''
  outcome['COUNT'] = 0
  errors = .array~new
  do source over sources
    applied = self~tryApply(source)
    if applied['OK'] then do
      outcome['SOURCE'] = source~name
      outcome['COUNT'] = applied['COUNT']
      /* a working directory makes the fallback file irrelevant */
      if source~name = 'ldap' then ignore = xtpNativeKeyClearSource('file')
      lastSource = source~name
      outcome['ERRORS'] = errors
      return outcome
    end
    errors~append(source~name': 'applied['ERROR'])
  end
  lastSource = ''
  outcome['ERRORS'] = errors
  return outcome

/* A source that raises a condition has failed; it does not stop the refresh. */
::method tryApply private
  use strict arg source
  signal on syntax name failed
  return source~apply
failed:
  applied = .directory~new
  applied['OK'] = .false
  applied['COUNT'] = 0
  applied['ERROR'] = condition('O')['ADDITIONAL']~makeString
  return applied

/* Declare a profile ahead of keys (authenticate or encrypt); never lowers one. */
::method require
  use strict arg service, protection
  return xtpNativeServiceRequire(service, protection)

/* Lower a service's profile to what its current keys give.  An operator action:
 * after it, a service with no keys accepts and opens unprotected sessions again. */
::method forgetProfile
  use strict arg service
  return xtpNativeServiceForgetProfile(service)

/* The protection profile libxtp now applies to service: none, authenticate or encrypt. */
::method protectionOf
  use strict arg service
  return xtpNativeServiceProtection(service)

/* The keys libxtp holds, without secrets: one directory per key. */
::method list
  listing = .array~new
  text = xtpNativeKeyList()
  do while text <> ''
    parse var text line '0a'x text
    if line = '' then iterate
    parse var line service keyId protection suite principal source state notBefore notAfter
    key = .directory~new
    key['SERVICE'] = service; key['KEYID'] = keyId; key['PROTECTION'] = protection; key['SUITE'] = suite
    key['PRINCIPAL'] = principal; key['SOURCE'] = source; key['STATE'] = state
    key['NOTBEFORE'] = notBefore; key['NOTAFTER'] = notAfter
    listing~append(key)
  end
  return listing

/* Key file source.  The file format and its mode-600 rule are libxtp's
 * (docs/SECURITY.md); loading replaces every key that came from a file. */
::class XtpFileKeySource public
::attribute path get
::method init
  expose path
  use strict arg path
::method name
  return 'file'
::method apply
  expose path
  applied = .directory~new
  applied['OK'] = .false
  applied['COUNT'] = 0
  applied['ERROR'] = ''
  signal on syntax name failed
  applied['COUNT'] = xtpNativeKeyLoadFile(path)
  applied['OK'] = .true
  return applied
failed:
  applied['ERROR'] = condition('O')['ADDITIONAL']~makeString
  return applied

::routine xtpNativeKeyInstall public external "library oorexx_xtp_native xtpNativeKeyInstall"
::routine xtpNativeKeyClearSource public external "library oorexx_xtp_native xtpNativeKeyClearSource"
::routine xtpNativeKeyLoadFile external "library oorexx_xtp_native xtpNativeKeyLoadFile"
::routine xtpNativeKeyRevoke public external "library oorexx_xtp_native xtpNativeKeyRevoke"
::routine xtpNativeServiceProtection external "library oorexx_xtp_native xtpNativeServiceProtection"
::routine xtpNativeKeyList external "library oorexx_xtp_native xtpNativeKeyList"
::routine xtpNativeKeyReplaceSource public external "library oorexx_xtp_native xtpNativeKeyReplaceSource"
::routine xtpNativeServiceRequire external "library oorexx_xtp_native xtpNativeServiceRequire"
::routine xtpNativeServiceForgetProfile external "library oorexx_xtp_native xtpNativeServiceForgetProfile"
