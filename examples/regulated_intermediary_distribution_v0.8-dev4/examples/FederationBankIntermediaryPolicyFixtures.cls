/* FederationBank example distribution policy fixture.
 * These are product-distribution workflow semantics, not legal statements.
 */
::class FederationBankIntermediaryPolicyFixtures public
::method standardPolicy class
  p = .RIDDistributionPolicy~new("FEDERATION-INTERMEDIARY-DISTRIBUTION", "1", "FEDERATION-INTERMEDIARY-DISTRIBUTION|1|20260828")

  /* Discovery is available only to a properly appointed firm / representative. */
  do family over .array~of("MORTGAGE", "INVESTMENT", "INSURANCE")
    r = .RIDActionRule~new("START-" || family, family, "*", "OPEN", "START_DISCOVERY", "DISCOVERY", "INTRODUCE")
    self~standardAuthority(r)
    p~addRule(r)
  end

  /* ADVISED mortgage recommendation. */
  r = .RIDActionRule~new("MORTGAGE-ADVISED-RECOMMEND", "MORTGAGE", "ADVISED", "DISCOVERY", "RECOMMEND", "RECOMMENDED", "ADVISE")
  self~standardAuthority(r)
  r~requireEvidence("FACT_FIND")~requireEvidence("AFFORDABILITY_ASSESSMENT")~requireEvidence("SUITABILITY_ASSESSMENT")~requireEvidence("PRODUCT_DISCLOSURE")
  p~addRule(r)

  /* ADVISED investment recommendation. */
  r = .RIDActionRule~new("INVESTMENT-ADVISED-RECOMMEND", "INVESTMENT", "ADVISED", "DISCOVERY", "RECOMMEND", "RECOMMENDED", "ADVISE")
  self~standardAuthority(r)
  r~requireEvidence("FACT_FIND")~requireEvidence("SUITABILITY_ASSESSMENT")~requireEvidence("PRODUCT_DISCLOSURE")~requireEvidence("CONFLICT_CHECK")
  p~addRule(r)

  /* EXECUTION_ONLY investment route deliberately does not use RECOMMEND. */
  r = .RIDActionRule~new("INVESTMENT-EXEC-READY", "INVESTMENT", "EXECUTION_ONLY", "DISCOVERY", "PREPARE_APPLICATION", "APPLICATION_READY", "ARRANGE")
  self~standardAuthority(r)
  r~requireEvidence("APPROPRIATENESS_ASSESSMENT")~requireEvidence("PRODUCT_DISCLOSURE")~requireEvidence("CUSTOMER_INSTRUCTION")
  p~addRule(r)

  /* Insurance remains a provider-owned contract even when group ownership changes. */
  r = .RIDActionRule~new("INSURANCE-ADVISED-RECOMMEND", "INSURANCE", "ADVISED", "DISCOVERY", "RECOMMEND", "RECOMMENDED", "ADVISE")
  self~standardAuthority(r)
  r~requireEvidence("DEMANDS_AND_NEEDS")~requireEvidence("PRODUCT_DISCLOSURE")~requireEvidence("REMUNERATION_DISCLOSURE")
  p~addRule(r)

  /* Recommended cases become application-ready only after customer authority and remuneration disclosure. */
  do family over .array~of("MORTGAGE", "INVESTMENT", "INSURANCE")
    r = .RIDActionRule~new(family || "-APPLICATION-READY", family, "ADVISED", "RECOMMENDED", "PREPARE_APPLICATION", "APPLICATION_READY", "ARRANGE")
    self~standardAuthority(r)
    r~requireEvidence("CUSTOMER_CONSENT")~requireEvidence("REMUNERATION_DISCLOSURE")
    p~addRule(r)
  end

  /* Requesting provider submission is a distribution action, not provider acceptance. */
  do family over .array~of("MORTGAGE", "INVESTMENT", "INSURANCE")
    do mode over .array~of("ADVISED", "EXECUTION_ONLY")
      r = .RIDActionRule~new(family || "-" || mode || "-SUBMIT", family, mode, "APPLICATION_READY", "REQUEST_SUBMISSION", "SUBMISSION_REQUESTED", "ARRANGE")
      self~standardAuthority(r)
      r~requireEvidence("CUSTOMER_CONSENT")
      p~addRule(r)
    end
  end
  return p~seal

::method standardAuthority class
  use arg rule
  rule~requireAuthority(.RIDAuthorityRequirement~new("FIRM-REGULATORY-PERMISSION", "REGULATORY_PERMISSION", "FIRM"))
  rule~requireAuthority(.RIDAuthorityRequirement~new("FIRM-FEDERATION-APPOINTMENT", "FEDERATION_APPOINTMENT", "FIRM"))
  rule~requireAuthority(.RIDAuthorityRequirement~new("REP-COMPETENCE", "REPRESENTATIVE_COMPETENCE", "REPRESENTATIVE"))
  return rule

::requires "RegulatedIntermediaryDistribution.cls"
