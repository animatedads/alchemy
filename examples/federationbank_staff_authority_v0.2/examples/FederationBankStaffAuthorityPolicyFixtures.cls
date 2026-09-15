/* Illustrative staff authority policy.  Limits are fixtures, not claims about
 * any real FederationBank employment or delegated authority policy. */
::class FederationBankStaffAuthorityPolicyFixtures public
::method standardPolicy class
  p=.FederationBankStaffAuthorityPolicy~new
  /* Branch teller can originate ordinary transfers up to 5,000 minor-unit
   * major currency value; 5,000.01..25,000 requires an independent supervisor. */
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-TRANSFER","TELLER","TRANSFER","*",500000,2500000,"SUPERVISOR",1,.true,.true,"","illustrative teller maker/checker transfer authority")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-BEN-ADD","TELLER","ADD_BENEFICIARY","*",0,0,"",0,.true,.true,"","ordinary beneficiary maintenance authority")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-BEN-AMEND","TELLER","AMEND_BENEFICIARY","*",0,0,"",0,.true,.true,"","ordinary beneficiary maintenance authority")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-BEN-SUSPEND","TELLER","SUSPEND_BENEFICIARY","*",0,0,"",0,.true,.true,"","ordinary beneficiary maintenance authority")~seal)
  /* Account opening is always maker/checker in this fixture. */
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-OPEN","TELLER","OPEN_ACCOUNT","*",0,0,"ONBOARDING_SUPERVISOR",1,.true,.false,"","illustrative account-opening checker requirement")~seal)
  /* Supervisor can make larger transfers, but above 25,000 still needs branch manager. */
  p~addRule(.FederationBankStaffAuthorityRule~new("SUPERVISOR-TRANSFER","SUPERVISOR","TRANSFER","*",2500000,10000000,"BRANCH_MANAGER",1,.true,.false,"","illustrative supervisor authority")~seal)
  /* A narrowly elevated cash override example. */
  p~addRule(.FederationBankStaffAuthorityRule~new("SUPERVISOR-CASH-OVERRIDE","SUPERVISOR","WITHDRAW_COMMIT","*",100000,500000,"BRANCH_MANAGER",1,.true,.false,"CASH_OVERRIDE","illustrative bounded break-glass cash override")~seal)
  /* Institutional staff authority is deliberately separate from customer/Core
   * Banking authority.  These rules only establish the employee-side authority
   * to act as a regulated intermediary representative; RID remains authoritative
   * for firm/representative/product/jurisdiction/activity/advice/case checks. */
  p~addRule(.FederationBankStaffAuthorityRule~new("INTERMEDIARY-INTRODUCE","INTERMEDIARY_REPRESENTATIVE","INTERMEDIARY_INTRODUCE","*",0,0,"",0,.true,.false,"","institutional intermediary introduction authority","INSTITUTIONAL")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("INTERMEDIARY-ADVISE","INTERMEDIARY_REPRESENTATIVE","INTERMEDIARY_ADVISE","*",0,0,"",0,.true,.false,"","institutional intermediary advice authority","INSTITUTIONAL")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("INTERMEDIARY-ARRANGE","INTERMEDIARY_REPRESENTATIVE","INTERMEDIARY_ARRANGE","*",0,0,"",0,.true,.false,"","institutional intermediary arranging authority","INSTITUTIONAL")~seal)
  return p~seal
::method publishedCatalog class
  p=self~standardPolicy
  c=.InstitutionalPolicyCatalog~new
  from=.DateTime~fromIsoDate("2025-01-01T00:00:00.000000")
  release=.InstitutionalPolicyRelease~new(.FederationBankStaffAuthorityBuild~DEFAULT_POLICY_ID,"1",from,.nil,"FederationBank Workforce Authority","Institutional Operations","",p)~seal
  r=c~publish(release)
  if \r~ok then raise syntax 88.950 array("Could not publish staff authority policy",r~code,r~detail)
  return c
::requires "FederationBankStaffAuthority.cls"
