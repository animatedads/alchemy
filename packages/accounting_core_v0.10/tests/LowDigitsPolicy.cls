/*
 * Intentional negative qualification fixture.
 * Do NOT add ::OPTIONS DIGITS 50 here.
 */
::class LowDigitsPolicy public subclass AccountingPolicy
::method init
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  use arg event, book
  return .AccountingPolicyDecision~reject("LOW_DIGITS_SHOULD_NOT_EXECUTE")

::requires "AccountingTransactions.cls"
