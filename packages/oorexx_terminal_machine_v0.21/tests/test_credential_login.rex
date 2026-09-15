failures = 0
cp = .CodePage037~new
runtime = .TN5250RuntimeSession~new("CREDTEST", "IBM-3179-2", "AIBOT01")
client = runtime~automationPort

/* Synthetic host sign-on panel with a pending READ MDT. */
wtd = "0411"x || "0008"x ||,
      "11"x || d2c(5) || d2c(1) || cp~encode("Your user name:") ||,
      "11"x || d2c(6) || d2c(1) || cp~encode("Password (max. 128):") ||,
      "11"x || d2c(5) || d2c(24) || "1D400020000A"x ||,
      "11"x || d2c(6) || d2c(24) || "1D4000270080"x ||,
      "13"x || d2c(5) || d2c(25) ||,
      "04520000"x
rec = .TN5250RecordCodec~encode(.TN5250Opcode~PUT_GET, wtd)
call assertTrue rec~ok, "signon record"
fed = runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(rec~value))
call assertTrue fed~ok, "signon feed"
snap = runtime~snapshot
call assertEq snap~fields~items, 2, "two credential fields"

known = .KnownState5250Factory~ibmISignon(snap, "IBM_I_SIGNON", "TEST_HUMAN")
call assertTrue known~ok, "learn signon"
catalog = .KnownStateCatalog~new
call assertTrue catalog~register(known~value)~ok, "register signon"

provider = .TestCredentialProvider~new
provider~put("TOO_LONG", "SHORT", copies("X", 129))
provider~put("PUB400_TEST", "FRED", "VERYSECRET")
broker = .TerminalCredentialBroker~new(provider)
failedStage = .TN5250CredentialLogin~stage(runtime, broker, catalog, "TOO_LONG", "IBM_I_SIGNON")
call assertTrue \failedStage~ok, "oversize password refused"
call assertEq failedStage~code, "CREDENTIAL_PASSWORD_OVERFLOW", "overflow reason"
call assertEq runtime~snapshot~field("F0345")~value, "", "failed pair leaves username untouched"
staged = .TN5250CredentialLogin~stage(runtime, broker, catalog, "PUB400_TEST", "IBM_I_SIGNON")
call assertTrue staged~ok, "stage credential"
call assertEq staged~value~credentialReference, "PUB400_TEST", "safe reference returned"
call assertTrue \staged~value~hasMethod("SECRET"), "stage result has no secret getter"
call assertTrue \staged~value~hasMethod("USERNAME"), "stage result has no username getter"
call assertEq staged~value~snapshot~field(staged~value~passwordFieldId)~value, "<SECRET>", "safe staged snapshot redacts password"
call assertTrue pos("VERYSECRET", staged~value~snapshot~visibleText) = 0, "password absent from safe screen"
secretInTrace = .false
do event over client~terminalSession~trace~events
  if event~eventType == "ACTION" then do
    if pos("VERYSECRET", event~payload~value) > 0 then secretInTrace = .true
  end
end
call assertTrue \secretInTrace, "password absent from action trace"

/* The AI-facing object still cannot invoke the trusted credential lease API. */
call assertTrue \client~hasMethod("APPLYCREDENTIALLEASE"), "automation facade cannot consume credential leases"

/* Submit is deliberately a separate AID action. */
g = client~snapshot~generation
pressed = client~press(g, "ENTER")
call assertTrue pressed~ok, "separate Enter"
call assertTrue pressed~value~transportOutputPending, "wire response pending"
wire = runtime~drainTerminalOutput
call assertTrue wire~ok, "trusted drain"
call assertTrue pos(cp~encode("VERYSECRET"), wire~value) > 0, "secret reaches trusted wire only"
call assertTrue pos("VERYSECRET", client~snapshot~visibleText) = 0, "secret remains absent from observer snapshot"

/* Wrong/unknown state must refuse before a one-shot credential is consumed. */
badRuntime = .TN5250RuntimeSession~new("BADSTATE")
one = .OneShotCredentialProvider~new("ONCE", "BOB", "SECRET2")
oneBroker = .TerminalCredentialBroker~new(one)
refused = .TN5250CredentialLogin~stage(badRuntime, oneBroker, catalog, "ONCE", "IBM_I_SIGNON")
call assertTrue \refused~ok, "unknown state refused"
call assertEq refused~code, "LOGIN_STATE_NOT_CONFIRMED", "refusal reason"
call assertTrue oneBroker~acquire("ONCE")~ok, "credential was not consumed on wrong state"

if failures > 0 then do
  say "FAIL test_credential_login" failures
  exit 1
end
say "PASS test_credential_login"
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
