/*
 * All Japan Insurance early operations UI semantic release.
 * Presentation vocabulary only: no rating, underwriting, billing, claims or
 * accounting authority lives here.
 */
::class AllJapanInsuranceWireUIFixture public
::method build class
  w=.WireUIDesignWorkspace~new("AllJapanInsurance.Operations")

  record=.WireUIVisualComponent~new("RECORD","2","SEMANTIC_RECORD")
  list=.WireUIVisualComponent~new("LIST","2","OFFER_LIST")
  do x over .array~of(record,list); call must w~register(x); end

  portfolio=.WireUISemanticElement~new("AJI_PORTFOLIO","2","PORTFOLIO",.array~of("asOfRef","currency","policyCount","openReceivableMinor","claimsOutstandingMinor","projectionMode"),.array~new,"AUTHENTICATED")
  policyList=.WireUISemanticElement~new("AJI_POLICY_LIST","1","POLICY_COLLECTION",.array~of("items"),.array~of("AJI.POLICY.OPEN"),"AUTHENTICATED")
  policy=.WireUISemanticElement~new("AJI_POLICY","2","POLICY",.array~of("policyId","productCode","status","currency","premiumMinor","contractRef","productProgramRef","ratingFunctionRef"),.array~new,"AUTHENTICATED")
  billing=.WireUISemanticElement~new("AJI_BILLING","2","BILLING_POSITION",.array~of("policyId","openDebitMinor","unappliedCreditMinor","unappliedCashMinor","allocationFunctionRef"),.array~new,"AUTHENTICATED")
  claim=.WireUISemanticElement~new("AJI_CLAIM","2","CLAIM_POSITION",.array~of("claimId","policyId","assessmentId","assessedPayableMinor","paidMinor","outstandingMinor","payoutFunctionRef"),.array~new,"AUTHENTICATED")
  accounting=.WireUISemanticElement~new("AJI_ACCOUNTING","2","ACCOUNTING_PROJECTION",.array~of("bookRef","currency","sourceEventRef","journalRef","accountingPolicyRef"),.array~new,"AUTHENTICATED")
  do x over .array~of(portfolio,policyList,policy,billing,claim,accounting); call must w~register(x); end

  tokens=.table~new
  tokens["space.unit"]="8"; tokens["radius.control"]="7"; tokens["density"]="compact"
  tokens["brand.entity"]="ALL_JAPAN_INSURANCE_CO_LTD"; tokens["currency.default"]="JPY"
  recipes=.table~new
  recipes["aji.portfolio"]="surface.primary/record.portfolio"
  recipes["aji.policy-list"]="surface.primary/list.policies"
  recipes["aji.policy"]="surface.primary/record.policy"
  recipes["aji.billing"]="surface.secondary/record.billing"
  recipes["aji.claim"]="surface.secondary/record.claim"
  recipes["aji.accounting"]="surface.secondary/record.accounting"
  material=.WireUIMaterialSet~new("AJI_OPERATIONS_MATERIAL","2",tokens,recipes); call must w~register(material)

  bp=self~identityBindings(.array~of("asOfRef","currency","policyCount","openReceivableMinor","claimsOutstandingMinor","projectionMode"))
  bpol=self~identityBindings(.array~of("policyId","productCode","status","currency","premiumMinor","contractRef","productProgramRef","ratingFunctionRef"))
  bbill=self~identityBindings(.array~of("policyId","openDebitMinor","unappliedCreditMinor","unappliedCashMinor","allocationFunctionRef"))
  bclaim=self~identityBindings(.array~of("claimId","policyId","assessmentId","assessedPayableMinor","paidMinor","outstandingMinor","payoutFunctionRef"))
  bacct=self~identityBindings(.array~of("bookRef","currency","sourceEventRef","journalRef","accountingPolicyRef"))

  pPortfolio=.WireUIProjectionDesign~new("AJI_PORTFOLIO","2","HUMAN_VISUAL",portfolio~ref,record~ref,"AJI_WUI_PORTFOLIO","","aji.portfolio","aji.portfolio",bp)
  pPolicyList=.WireUIProjectionDesign~new("AJI_POLICY_LIST","1","HUMAN_VISUAL",policyList~ref,list~ref,"AJI_WUI_POLICY_LIST","AJI.POLICY.OPEN","aji.policy-list","aji.policy-list")
  pPolicy=.WireUIProjectionDesign~new("AJI_POLICY","2","HUMAN_VISUAL",policy~ref,record~ref,"AJI_WUI_POLICY","","aji.policy","aji.policy",bpol)
  pBilling=.WireUIProjectionDesign~new("AJI_BILLING","2","HUMAN_VISUAL",billing~ref,record~ref,"AJI_WUI_BILLING","","aji.billing","aji.billing",bbill)
  pClaim=.WireUIProjectionDesign~new("AJI_CLAIM","2","HUMAN_VISUAL",claim~ref,record~ref,"AJI_WUI_CLAIM","","aji.claim","aji.claim",bclaim)
  pAccounting=.WireUIProjectionDesign~new("AJI_ACCOUNTING","2","HUMAN_VISUAL",accounting~ref,record~ref,"AJI_WUI_ACCOUNTING","","aji.accounting","aji.accounting",bacct)
  do x over .array~of(pPortfolio,pPolicyList,pPolicy,pBilling,pClaim,pAccounting); call must w~register(x); end

  j=.WireUIJourneyDesign~new("AJI_OPERATIONS","2","PORTFOLIO")
  call must j~defineState("PORTFOLIO",.array~of("AJI_PORTFOLIO","AJI_POLICY_LIST"),.array~of("AJI_POLICY","AJI_BILLING","AJI_CLAIM","AJI_ACCOUNTING"),.array~new)
  /* Keep portfolio/list definitions authorised after drill-down so a resync is self-contained. */
  call must j~defineState("POLICY",.array~of("AJI_PORTFOLIO","AJI_POLICY_LIST","AJI_POLICY","AJI_BILLING","AJI_CLAIM"),.array~of("AJI_ACCOUNTING"),.array~new)
  call must j~allowTransition("PORTFOLIO","POLICY","AJI.POLICY.OPEN","operator selects server-issued policy semantic identity")
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("ALL_JAPAN_INSURANCE_OPERATIONS","2")
  do x over .array~of(record,list,portfolio,policyList,policy,billing,claim,accounting,material,pPortfolio,pPolicyList,pPolicy,pBilling,pClaim,pAccounting,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)
  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; d["material"]=material
  return d

::method identityBindings class private
  use arg names
  b=.table~new
  do n over names; b[n]=n; end
  return b

::routine must
  use arg result
  if result~isA(.WireUIDesignResult) then if \result~ok then raise syntax 88.900 array(result~code,result~detail)
  return result
::requires "WireUIBuilderAll.cls"
