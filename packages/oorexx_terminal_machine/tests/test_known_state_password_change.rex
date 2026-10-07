failures = 0

/* Confirm the password-expired notice seen live after successful authentication. */
noticeModel = .PresentationSpace5250~new
noticeSession = .TerminalSession~new("PWEXP", noticeModel)
noticeModel~writeText(1, 31, "Sign-on Information")
noticeModel~writeText(2, 61, "System:   PUB400")
noticeModel~writeText(3, 2, "Password has expired.  Password must be changed to continue sign-on")
noticeModel~writeText(4, 2, "request.")
noticeModel~writeText(8, 2, "Password verifications not valid . . . . . :   5")
noticeModel~writeText(21, 2, "Press Enter to change your password.")
noticeModel~writeText(23, 2, "F3=Exit sign-on request")
noticeModel~setCursor(1,1)
noticeModel~setKeyboardState("UNLOCKED")
noticeModel~setSessionState("OPERATOR_WAIT")
noticeModel~hostCommit
noticeSnap = noticeSession~commit

madeNotice = .KnownState5250Factory~ibmIPasswordExpiredNotice(noticeSnap, "IBM_I_PASSWORD_EXPIRED_NOTICE", "TEST_HUMAN")
call assertTrue madeNotice~ok, "factory recognizes password expired notice"
noticeState = madeNotice~value
catalog = .KnownStateCatalog~new
call assertTrue catalog~register(noticeState)~ok, "register notice"
call assertEq catalog~match(noticeSnap)~status, "MATCH", "notice matches"

/* The live change-password panel has three password entry fields.  Cursor is
 * intentionally placed in protected space: that must not alter state identity.
 */
changeModel = .PresentationSpace5250~new
changeSession = .TerminalSession~new("PWCHANGE", changeModel)
changeModel~writeText(1, 34, "Change Password")
changeModel~writeText(3, 3, "User profile . . . . . . . . . . . . : DASHADYER")
changeModel~writeText(5, 3, "Password last changed . . . . . . . . : 26-08-21")
changeModel~writeText(7, 3, "Type choices, press Enter.")
changeModel~writeText(9, 5, "Current password  . . . . . . . . . .")
changeModel~writeText(12, 5, "New password  . . . . . . . . . . . .")
changeModel~writeText(15, 5, "New password (to verify)  . . . . . .")
changeModel~writeText(23, 3, "F3=Exit            F9=Display password rules            F12=Cancel")
call assertTrue changeModel~defineField("CURRENT", 9, 42, 128, "", .true, .false, .true)~ok, "current password field"
call assertTrue changeModel~defineField("NEW", 12, 42, 128, "", .true, .false, .true)~ok, "new password field"
call assertTrue changeModel~defineField("VERIFY", 15, 42, 128, "", .true, .false, .true)~ok, "verify password field"
changeModel~setCursor(16, 80)  /* protected area on purpose */
changeModel~setKeyboardState("UNLOCKED")
changeModel~setSessionState("OPERATOR_WAIT")
changeModel~hostCommit
changeSnap = changeSession~commit

madeChange = .KnownState5250Factory~ibmIChangePassword(changeSnap, "IBM_I_CHANGE_PASSWORD", "TEST_HUMAN")
call assertTrue madeChange~ok, "factory recognizes change password"
changeState = madeChange~value
call assertTrue catalog~register(changeState)~ok, "register change password"
matchChange = catalog~match(changeSnap)
call assertEq matchChange~status, "MATCH", "change password matches with cursor protected"
call assertEq matchChange~matchedStateId, "IBM_I_CHANGE_PASSWORD", "change password state id"

/* Moving the cursor elsewhere remains same semantic state. */
changeModel~setCursor(9,42)
changeModel~hostCommit
changeSnap2 = changeSession~commit
call assertEq catalog~match(changeSnap2)~matchedStateId, "IBM_I_CHANGE_PASSWORD", "cursor position ignored"

/* But field topology remains authoritative. */
badModel = .PresentationSpace5250~new
badSession = .TerminalSession~new("PWBAD", badModel)
badModel~writeText(1,34,"Change Password")
badModel~writeText(9,5,"Current password")
badModel~writeText(12,5,"New password")
badModel~writeText(15,5,"New password (to verify)")
call assertTrue badModel~defineField("CURRENT",9,42,128,"",.true,.false,.true)~ok, "bad current"
call assertTrue badModel~defineField("NEW",12,42,16,"",.true,.false,.true)~ok, "bad new"
call assertTrue badModel~defineField("VERIFY",15,42,128,"",.true,.false,.true)~ok, "bad verify"
badModel~setKeyboardState("UNLOCKED")
badModel~setSessionState("OPERATOR_WAIT")
badModel~hostCommit
badSnap = badSession~commit
call assertEq catalog~match(badSnap)~status, "NO_MATCH", "different password field topology rejected"

/* Transition is knowledge, not authority. */
noticeState~addTransition(.KnownStateTransition~new("IBM_I_PASSWORD_EXPIRED_NOTICE", "AID", "ENTER", "IBM_I_CHANGE_PASSWORD", 1, "Observed/confirmed continuation to change-password panel."))
path = "known_password_change_test.json"
call assertTrue .KnownStateJsonStore~save(catalog, path)~ok, "save states"
loaded = .KnownStateJsonStore~load(path)
call assertTrue loaded~ok, "load states"
call assertEq loaded~value~match(noticeSnap)~matchedStateId, "IBM_I_PASSWORD_EXPIRED_NOTICE", "notice survives persistence"
call assertEq loaded~value~match(changeSnap)~matchedStateId, "IBM_I_CHANGE_PASSWORD", "change state survives persistence"
call assertEq loaded~value~state("IBM_I_PASSWORD_EXPIRED_NOTICE")~transitions~items, 1, "transition survives persistence"
call sysFileDelete path

if failures > 0 then do
  say "FAIL test_known_state_password_change" failures
  exit 1
end
say "PASS test_known_state_password_change"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "TN5250CredentialLogin.cls"
