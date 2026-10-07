/*
 * Trusted IBM i 5250 password-change staging v0.1.
 *
 * The workflow deliberately separates four things:
 *   1. semantic confirmation of IBM_I_CHANGE_PASSWORD;
 *   2. local acquisition of current/new password material;
 *   3. transactional staging into three host-declared NONDISPLAY fields;
 *   4. the ENTER AID, which remains a separate caller decision.
 *
 * No secret is exposed through the result, snapshots, WatchAlong or action
 * trace.  Rexx does not promise secure memory wiping; retire() removes held
 * references on a best-effort basis only.
 */

::class TN5250PasswordChangeBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.tn5250.password-change/0.1"

::class TN5250PasswordChangeLease public
::attribute reference get
::attribute retired get

::method init
  expose reference currentSecret newSecret retired
  use arg referenceArg, currentSecretArg, newSecretArg
  reference = referenceArg~string
  currentSecret = currentSecretArg~string
  newSecret = newSecretArg~string
  retired = .false

::method secretsForTrustedConsumer
  expose currentSecret newSecret retired
  if retired then return .TerminalResult~failure("PASSWORD_CHANGE_LEASE_RETIRED", "password-change lease has already been retired")
  d = .directory~new
  d["current"] = currentSecret
  d["new"] = newSecret
  return .TerminalResult~success(d)

::method retire
  expose currentSecret newSecret retired
  currentSecret = ""
  newSecret = ""
  retired = .true
  return self

::method safeDescription
  expose reference retired
  d = .directory~new
  d["reference"] = reference
  d["retired"] = retired
  return d

::class TN5250PasswordChangeStageResult public
::attribute reference get
::attribute stateId get
::attribute currentFieldId get
::attribute newFieldId get
::attribute verifyFieldId get
::attribute snapshot get

::method init
  expose reference stateId currentFieldId newFieldId verifyFieldId snapshot
  use arg referenceArg, stateIdArg, currentFieldIdArg, newFieldIdArg, verifyFieldIdArg, snapshotArg
  reference = referenceArg~string
  stateId = stateIdArg~string
  currentFieldId = currentFieldIdArg~string
  newFieldId = newFieldIdArg~string
  verifyFieldId = verifyFieldIdArg~string
  snapshot = snapshotArg~copyDetached

::class TN5250PasswordChange public
::method stage class
  use arg runtime, catalog, leaseArg, expectedStateIdArg = "IBM_I_CHANGE_PASSWORD"
  if runtime == .nil then return .TerminalResult~failure("PASSWORD_CHANGE_RUNTIME_REQUIRED", "runtime is required")
  if catalog == .nil then return .TerminalResult~failure("PASSWORD_CHANGE_CATALOG_REQUIRED", "known-state catalog is required")
  if leaseArg == .nil then return .TerminalResult~failure("PASSWORD_CHANGE_LEASE_REQUIRED", "trusted password-change lease is required")
  if \leaseArg~isA(.TN5250PasswordChangeLease) then return .TerminalResult~failure("PASSWORD_CHANGE_LEASE_REQUIRED", "trusted password-change lease is required")

  snap = runtime~snapshot
  matched = catalog~match(snap)
  if matched~status \== .TerminalMatchStatus~MATCH then return .TerminalResult~failure("PASSWORD_CHANGE_STATE_NOT_CONFIRMED", matched~status)
  if matched~matchedStateId \== expectedStateIdArg~string then return .TerminalResult~failure("PASSWORD_CHANGE_WRONG_KNOWN_STATE", matched~matchedStateId)

  mapped = .KnownState5250Factory~findChangePasswordFields(snap)
  if \mapped~ok then return mapped
  fields = mapped~value

  secretsResult = leaseArg~secretsForTrustedConsumer
  if \secretsResult~ok then return secretsResult
  secrets = secretsResult~value
  currentSecret = secrets["current"]
  newSecret = secrets["new"]

  staged = runtime~stageNondisplaySecretTriple(snap~generation, fields["current"]~fieldId, currentSecret, fields["new"]~fieldId, newSecret, fields["verify"]~fieldId, newSecret, "PASSWORD_CHANGE_BROKER")

  currentSecret = ""
  newSecret = ""
  leaseArg~retire
  if \staged~ok then return staged

  safeSnap = runtime~snapshot
  result = .TN5250PasswordChangeStageResult~new(leaseArg~reference, expectedStateIdArg, fields["current"]~fieldId, fields["new"]~fieldId, fields["verify"]~fieldId, safeSnap)
  return .TerminalResult~success(result)

::requires "TN5250CredentialLogin.cls"
