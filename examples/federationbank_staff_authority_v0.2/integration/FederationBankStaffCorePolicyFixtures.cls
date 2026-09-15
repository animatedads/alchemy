/* Core Banking STAFF-channel fixture policies.  These are deliberately
 * separate from staff employment authority.  Passing Staff Authority does not
 * imply the customer's transaction/product policy allows the operation. */
::class FederationBankStaffCorePolicyFixtures public
::method limitCatalog class
  p=.FederationBankLimitPolicy~new
  p~addRule(.FederationBankLimitRule~new("USD-RETAIL-STAFF","RETAIL","USD","TRANSFER","STAFF",5000000,10000000,"illustrative customer/corporate STAFF transfer limit"))
  p~addRule(.FederationBankLimitRule~new("AUD-RETAIL-STAFF","RETAIL","AUD","TRANSFER","STAFF",7500000,15000000,"illustrative customer/corporate STAFF transfer limit"))
  p~addRule(.FederationBankLimitRule~new("GBP-RETAIL-STAFF","RETAIL","GBP","TRANSFER","STAFF",2500000,5000000,"illustrative customer/corporate STAFF transfer limit"))
  p~addRule(.FederationBankLimitRule~new("EUR-RETAIL-STAFF","RETAIL","EUR","TRANSFER","STAFF",3000000,6000000,"illustrative customer/corporate STAFF transfer limit"))
  p~seal
  return self~publish(.FederationBankBuild~LIMIT_POLICY_DEFAULT,p,"FederationBank Product","FederationBank Risk")
::method beneficiaryCatalog class
  p=.FederationBankBeneficiaryPolicy~new
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-ADD-STAFF","RETAIL","ADD_BENEFICIARY","STAFF",10,"illustrative staff-assisted beneficiary policy"))
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-AMEND-STAFF","RETAIL","AMEND_BENEFICIARY","STAFF",10,"illustrative staff-assisted beneficiary policy"))
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-SUSPEND-STAFF","RETAIL","SUSPEND_BENEFICIARY","STAFF",10,"illustrative staff-assisted beneficiary policy"))
  p~seal
  return self~publish(.FederationBankBuild~BENEFICIARY_POLICY_DEFAULT,p,"FederationBank Product","FederationBank Risk")
::method openingCatalog class
  p=.FederationBankAccountOpeningPolicy~new
  do cur over .array~of("USD","AUD","GBP","EUR")
    p~addRule(.FederationBankOpeningRule~new("OPEN-"||cur||"-OFFSHORE-CURRENT-STAFF","OFFSHORE_CURRENT",cur,"STAFF",.true,.true,650,550,.false,"illustrative staff-assisted account-opening intelligence policy","FB-IJCIB-FIXTURE-"||cur))
  end
  p~seal
  return self~publish(.FederationBankBuild~OPENING_POLICY_DEFAULT,p,"FederationBank Product","FederationBank Risk")
::method publish private class
  use arg policyId,payload,author,approver
  c=.InstitutionalPolicyCatalog~new
  release=.InstitutionalPolicyRelease~new(policyId,"STAFF-1",.DateTime~fromIsoDate("2025-01-01T00:00:00.000000"),.nil,author,approver,"",payload)~seal
  r=c~publish(release)
  if \r~ok then raise syntax 88.951 array("Could not publish STAFF Core Banking policy",policyId,r~code,r~detail)
  return c
::method engine class
  database=.FederationBankFixtures~database
  customers=.FederationBankCustomerRegistry~new
  customers~add(.FederationBankCustomer~new("CUST-001","RETAIL","GB","GB","STANDARD",.nil,"Existing Customer","1980-01-01","SW1A 1AA","GB"))
  store=.FederationBankSqlLedgerStore~new(database,3,15)
  ledger=.FederationBankLedger~new(store)
  profiles=.FederationBankRegulatoryProfileRegistry~standard
  do cur over .array~of("USD","AUD","GBP","EUR")
    profile=profiles~byCurrency(cur)
    ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-"||cur,"FEDERATIONBANK",cur,"INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true))
  end
  policyGate=.FederationBankPolicyGate~new(self~limitCatalog)
  openingGate=.FederationBankOpeningPolicyGate~new(self~openingCatalog)
  beneficiaryGate=.FederationBankBeneficiaryPolicyGate~new(self~beneficiaryCatalog)
  legalGate=.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry)
  bouncer=.FederationBankBouncer~new(.FederationBankBouncer~standardFramework)
  external=.FederationBankFixtures~externalEnvironment
  return .FederationBankEngine~new(customers,ledger,profiles,policyGate,legalGate,bouncer,.nil,openingGate,external["checks"],.FederationBankBeneficiaryRegistry~new,beneficiaryGate)
::requires "FederationBankFixtures.cls"
