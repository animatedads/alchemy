::class SecurityTestSupport public
::method basePolicy class
  use arg now
  policy = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE', '1.0', now - .TimeSpan~new(0,0,0,1,0), .nil, 'SECURITY_TEAM', 'RISK_COMMITTEE')

  gold = .SecurityPolicyRule~new('PAY-031', 100, 'PURCHASE', 'HOLD', 'high-value stored payment under identity-continuity concern')
  gold~requireFinding('GEO_CONTINUITY_ANOMALY')
  gold~addCriterion('PAYMENT_INSTRUMENT', 'EQ', 'STORED')
  gold~addCriterion('ASSET_CLASS', 'EQ', 'HIGH_VALUE_LIQUID_ASSET')
  gold~addCriterion('AMOUNT', 'GE', 20000)
  gold~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED', 'TRANSACTION')
  gold~addConstraint('FREEZE_RECOVERY_CHANNEL_MUTATION', 'ACCOUNT')
  gold~addUnaffectedAbility('BOOKING_STATUS_READ')
  gold~addUnaffectedAbility('CUSTOMER_SERVICE_CONVERSATION')
  policy~addRule(gold~seal)

  recovery = .SecurityPolicyRule~new('REC-008', 110, 'CHANGE_VERIFIED_PHONE', 'HOLD', 'trusted recovery channel mutation while identity continuity is unresolved')
  recovery~requireFinding('GEO_CONTINUITY_ANOMALY')
  recovery~addConstraint('FREEZE_RECOVERY_CHANNEL_MUTATION', 'ACCOUNT')
  recovery~addConstraint('USE_EXISTING_OUT_OF_BAND_CHANNEL', 'VERIFICATION')
  policy~addRule(recovery~seal)

  bags = .SecurityPolicyRule~new('RESTRICTED-014', 120, 'PURCHASE_MORE_BAGS', 'REVIEW_REQUIRED', 'unresolved prior interaction evidence relevant to restricted product sale')
  bags~requireFinding('RESTRICTED_PRODUCT_MISUSE_POSSIBLE')
  bags~addConstraint('ROUTE_TO_REVIEW', 'TRANSACTION')
  bags~addUnaffectedAbility('VIEW_EXISTING_ORDER')
  bags~addUnaffectedAbility('CUSTOMER_SERVICE_CONVERSATION')
  policy~addRule(bags~seal)

  exploit = .SecurityPolicyRule~new('EXP-021', 130, 'PRIVILEGED_API_MUTATION', 'HOLD', 'active exploit-probe concern around privileged mutation')
  exploit~requireFinding('ACTIVE_EXPLOIT_PROBE')
  exploit~addConstraint('REQUIRE_SECURITY_REVIEW', 'ACTION')
  exploit~addUnaffectedAbility('PUBLIC_READ')
  policy~addRule(exploit~seal)
  return policy~seal

::method geoFinding class
  use arg subject, now
  f = .SecurityFinding~new('F-GEO-1', 'GEO_CONTINUITY_ANOMALY', 'CONCERN', subject, 95, now - .TimeSpan~new(0,0,5,0,0), now + .TimeSpan~new(0,0,2,0,0), 'London observed 30 minutes before Kazakhstan login', 'SECURITY_EFFECT')
  f~addCounterEvidence(.SecurityEvidenceAnchor~new('AUTH-OK','AUTHENTICATION','credential authentication succeeded',now,100))
  return f~seal

::method finding class
  use arg id, kind, subject, now, sourceDomain = 'SECURITY_EFFECT', state = 'CONCERN'
  return .SecurityFindingFactory~external(id, kind, state, subject, 90, sourceDomain, .nil, '', now, now + .TimeSpan~new(0,0,2,0,0))

::requires 'SecurityEffect.cls'
