failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live IBM i catalogue"
catalog = loaded~value

signon = catalog~state("IBM_I_SIGNON")~exemplars[1]~snapshot
notice = catalog~state("IBM_I_PASSWORD_EXPIRED_NOTICE")~exemplars[1]~snapshot
change = catalog~state("IBM_I_CHANGE_PASSWORD")~exemplars[1]~snapshot

flow = .TN5250PasswordExpiryFlow~new(catalog)
call assertEq flow~phase, "EXPECT_SIGNON", "initial phase"
call assertEq flow~expectedStateId, "IBM_I_SIGNON", "initial state"

s1 = flow~observe(signon)
call assertTrue s1~ok, "accept signon"
call assertEq flow~phase, "EXPECT_PASSWORD_EXPIRED_NOTICE", "after signon"

/* The live observation matters: going straight to the changer is not this
 * approved PUB400 recovery flow.  A rejected observation does not advance it. */
direct = flow~observe(change)
call assertTrue \direct~ok, "reject direct signon-to-change shortcut"
call assertEq direct~code, "PASSWORD_EXPIRY_FLOW_ORDER", "direct shortcut error"
call assertEq flow~phase, "EXPECT_PASSWORD_EXPIRED_NOTICE", "rejection leaves phase unchanged"

s2 = flow~observe(notice)
call assertTrue s2~ok, "accept password-expired notice"
call assertEq flow~phase, "EXPECT_CHANGE_PASSWORD", "after notice"

/* Replaying the notice is also out of order; we require the host to advance. */
repeatNotice = flow~observe(notice)
call assertTrue \repeatNotice~ok, "reject repeated notice when changer expected"
call assertEq repeatNotice~code, "PASSWORD_EXPIRY_FLOW_ORDER", "repeat notice error"
call assertEq flow~phase, "EXPECT_CHANGE_PASSWORD", "repeat rejection leaves phase unchanged"

s3 = flow~observe(change)
call assertTrue s3~ok, "accept change-password panel"
call assertTrue flow~readyForPasswordChange, "flow ready for trusted password staging"
call assertEq flow~phase, "READY_FOR_PASSWORD_CHANGE", "ready phase"

extra = flow~observe(change)
call assertTrue \extra~ok, "flow cannot be silently reused"
call assertEq extra~code, "PASSWORD_EXPIRY_FLOW_COMPLETE", "complete error"

/* A fresh flow presented the notice before sign-on must fail closed. */
outOfOrder = .TN5250PasswordExpiryFlow~new(catalog)
badFirst = outOfOrder~observe(notice)
call assertTrue \badFirst~ok, "notice cannot be first state"
call assertEq badFirst~code, "PASSWORD_EXPIRY_FLOW_ORDER", "first-state order error"
call assertEq outOfOrder~phase, "EXPECT_SIGNON", "bad first observation does not advance"

if failures > 0 then do
  say "FAIL test_password_expiry_flow_order" failures
  exit 1
end
say "PASS test_password_expiry_flow_order"
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

::requires "TN5250PasswordExpiryFlow.cls"
::requires "KnownStateJsonStore.cls"
