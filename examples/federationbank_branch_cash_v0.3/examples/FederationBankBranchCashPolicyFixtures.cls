/* Development fixture policy only. Production service adapters should source
 * decisions from Institutional Policy rather than treating this file as bank
 * policy. */
::class FederationBankBranchCashPolicyFixtures public
::method defaultPolicy class
  return .FederationBankBranchCashFixturePolicy~new
::requires "FederationBankBranchCash.cls"
