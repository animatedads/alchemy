/* RFE #882: optional, deployment-bound ADDRESS adapter for local DirectCall.
 *
 * This is a real ConnectSelector client, not a transport implementation.
 * Only an explicitly configured local selector may be installed.
 * Deployment owns the authoritative selector/policy; untrusted scripts
 * must not register handlers or supply their own policy instances.
 *
 * Requires a portable ooRexx build with .CommandHandler (r13289+).
 * Requires an exact-version ConnectSelector source on REXX_PATH.
 */
::class AlchemyConnectAddressLocal public inherit CommandHandler

::method init
  expose selector
  use strict arg selector
  if \selector~hasMethod('execute') | \selector~hasMethod('policy') then
    raise syntax 93.900 additional('ConnectSelector with a policy is required')
  if selector~policy == .nil then
    raise syntax 93.900 additional('an explicit ConnectSelector policy is required')

/* The only accepted grammar is CALL destination operation.
 * CommandContext is intentionally not used: no caller variable mutation,
 * stream redirection, untrusted credentials, or shell forwarding.
 */
::method command
  expose selector
  use arg command, caller
  if words(command) \== 3 then return 64
  verb = word(command, 1)~translate
  destination = word(command, 2)
  operation = word(command, 3)
  if verb \== 'CALL' then return 64
  alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
  if verify(destination,alphabet) \== 0 then return 64
  if verify(operation,alphabet) \== 0 then return 64

  /* No implicit provider fallback: local DIRECT only. */
  signal on syntax name failed
  signal on error name failed
  signal on failure name failed
  intent = .ConnectIntent~new(operation,'REQUEST','IMMEDIATE','DIRECT',destination)
  result = selector~execute(intent,.nil)
  signal off syntax
  signal off error
  signal off failure

  if \result~ok then return 13
  /* An ACCEPTED receipt alone is NOT completed execution. */
  if \result~completed then return 75
  return 0
failed:
  /* Caller-visible RC only; never print raw error/secret details. */
  return 70

::requires 'ConnectSelector.cls'
