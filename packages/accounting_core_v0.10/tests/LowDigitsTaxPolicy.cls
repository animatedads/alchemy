/* Deliberately omits ::OPTIONS DIGITS 50. */
::class LowDigitsTaxPolicy public subclass AccountingTaxPolicy
::method determine
  use arg request, registration, election
  return .AccountingTaxPolicyDecision~reject("LOW_DIGITS_FIXTURE")
::requires "AccountingTax.cls"
