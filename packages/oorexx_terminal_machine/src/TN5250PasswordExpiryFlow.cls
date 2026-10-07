/*
 * Safety policy for the observed IBM i expired-password continuation.
 *
 * This object does not send AIDs, acquire credentials, or authorize terminal
 * mutation.  It only validates the semantic host-state sequence observed by
 * the caller.  The caller must still hold whatever terminal/control authority
 * is required for each explicit action.
 *
 * Confirmed PUB400 sequence (2026-08-22):
 *   IBM_I_SIGNON
 *       -- explicit ENTER after credential staging -->
 *   IBM_I_PASSWORD_EXPIRED_NOTICE
 *       -- explicit ENTER -->
 *   IBM_I_CHANGE_PASSWORD
 *
 * A direct SIGNON -> CHANGE_PASSWORD observation is intentionally rejected.
 * If a host/version legitimately behaves that way later, learn and approve a
 * distinct flow rather than weakening this confirmed one.
 */

::class TN5250PasswordExpiryFlowBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.tn5250.password-expiry-flow/0.1"

::class TN5250PasswordExpiryFlow public
::attribute phase get

::method init
  expose catalog phase
  use arg catalogArg
  if catalogArg == .nil then raise syntax 88.900 array("TN5250PasswordExpiryFlow requires a KnownStateCatalog")
  catalog = catalogArg
  phase = "EXPECT_SIGNON"

::method expectedStateId
  expose phase
  select
    when phase == "EXPECT_SIGNON" then return "IBM_I_SIGNON"
    when phase == "EXPECT_PASSWORD_EXPIRED_NOTICE" then return "IBM_I_PASSWORD_EXPIRED_NOTICE"
    when phase == "EXPECT_CHANGE_PASSWORD" then return "IBM_I_CHANGE_PASSWORD"
    when phase == "READY_FOR_PASSWORD_CHANGE" then return ""
    otherwise return ""
  end

::method readyForPasswordChange
  expose phase
  return phase == "READY_FOR_PASSWORD_CHANGE"

::method observe
  expose catalog phase
  use arg snapshot
  if snapshot == .nil then return .TerminalResult~failure("PASSWORD_EXPIRY_FLOW_NO_SNAPSHOT", phase)
  if phase == "READY_FOR_PASSWORD_CHANGE" then return .TerminalResult~failure("PASSWORD_EXPIRY_FLOW_COMPLETE", phase)

  expected = self~expectedStateId
  matched = catalog~match(snapshot)
  if matched~status \== .TerminalMatchStatus~MATCH then do
    return .TerminalResult~failure("PASSWORD_EXPIRY_FLOW_STATE_NOT_CONFIRMED", "phase=" || phase || " expected=" || expected || " match=" || matched~status)
  end
  if matched~matchedStateId \== expected then do
    return .TerminalResult~failure("PASSWORD_EXPIRY_FLOW_ORDER", "phase=" || phase || " expected=" || expected || " got=" || matched~matchedStateId)
  end

  select
    when phase == "EXPECT_SIGNON" then phase = "EXPECT_PASSWORD_EXPIRED_NOTICE"
    when phase == "EXPECT_PASSWORD_EXPIRED_NOTICE" then phase = "EXPECT_CHANGE_PASSWORD"
    when phase == "EXPECT_CHANGE_PASSWORD" then phase = "READY_FOR_PASSWORD_CHANGE"
    otherwise return .TerminalResult~failure("PASSWORD_EXPIRY_FLOW_PHASE_INVALID", phase)
  end
  return .TerminalResult~success(matched~matchedStateId)

::requires "TerminalCore.cls"
