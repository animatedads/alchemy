/* This test captures the integration rule: VMM stays an external legal entity.
   An investment product may reference Merchant Bank as provider while VMM may
   appear only in downstream execution/hedge evidence, never by relabelling it
   as a Federation internal product authority. */
merchant=.RIDProviderIdentity~new("FEDERATIONBANK_MERCHANT_BANK","FEDERATION_MERCHANT_DISTRIBUTION","FEDERATION_GROUP")
p=.RIDProductReference~new("INV-1",merchant,"INVEST-1","1","INVEST-1|1|SEM","INVESTMENT","GB")
.RIDTestSupport~assertEq("FEDERATIONBANK_MERCHANT_BANK",p~providerIdentity~legalEntityId)
.RIDTestSupport~assertFalse(p~providerIdentity~legalEntityId = "VECTOR_MERIDIAN_MARKETS_LTD")
say "PASS VMM remains outside intermediary product authority"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "TestSupport.cls"
