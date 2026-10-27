/* RFE #882 smoke test: the .cls prolog installs the environment.
 * Run only with an interpreter containing the Rexx CommandHandler API
 * (portable builds r13289+); not qualified on r13196.
 * This tests isolated command dispatch, NOT ConnectSelector transport.
 */
address ALCHEMY_CS_PROBE "PING"
if rc \= 0 then do
  say "FAIL: PING returned RC" rc "instead of 0"
  exit 1
end

address ALCHEMY_CS_PROBE "DENY"
if rc \= 13 then do
  say "FAIL: DENY returned RC" rc "instead of 13"
  exit 2
end

address ALCHEMY_CS_PROBE "UNKNOWN_COMMAND"
if rc \= 64 then do
  say "FAIL: unknown command returned RC" rc "instead of 64"
  exit 3
end

say "PASS: Rexx ADDRESS handler dispatch and fail-closed unknown command"
exit 0

::requires "AlchemyAddressProbe.cls"
