env = .FederationBankFixtures~freshIJCIBEnvironment
agency = env["external"]["creditAgency"]
cmd = .FederationBankCommand~new("IJCIB-OPEN-REQ-001", "OPEN_ACCOUNT", "IJCIB-IDEM-001", "CUST-IJCIB-1", "", "", "GBP", 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", "GBP-IJCIB-1", "Ima Customer", "1988-04-12", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
address = .directory~new
address["reference"] = "sha512:civicport-fixture-address-token"
requirements = .directory~new
requirements["creditProductCode"] = "FB-IJCIB-FIXTURE-GBP"
built = agency~buildRequest(cmd, address, requirements)
call must built, "build IJCIB request"
req = built~value
call assert req~correlationToken <> req~requestId, "correlation token differs from request id"
call assert req~nonce~length >= 16 & req~nonce~length <= 32, "nonce length contract"
call assert req~requestedAtText~pos("+00:00") > 0, "requested timestamp carries timezone offset"
call assert req~subjectAddressReference = address["reference"], "CivicPort reference is bureau address reference"
call assert req~requestedProductCode = "FB-IJCIB-FIXTURE-GBP", "bureau product comes from bank policy mapping"
call assert req~requestDigest~length = 128, "SHA-512 digest length"

codec = .FederationBankIJCIBJmsCodec~new
encoded = codec~requestMessage(req)
call must encoded, "encode IJCIB JMS request"
msg = encoded~value
call assert msg~bodyType = "MAP", "IJCIB uses JMS MAP body"
p = msg~properties
call assert p["IJCIB_PROTOCOL_VERSION"] = "IJCIB-CIR/0.1", "exact protocol property"
call assert p["IJCIB_REQUEST_ID"] = req~requestId, "exact request property"
call assert p["IJCIB_CORRELATION_TOKEN"] = req~correlationToken, "exact correlation property"
call assert p["IJCIB_REQUEST_DIGEST"] = req~requestDigest, "exact digest property"
call assert p["IJCIB_REQUESTING_INSTITUTION"] = "FEDERATIONBANK-IOM-OFFSHORE", "exact institution property"
call assert p["IJCIB_SUBJECT_ADDRESS_REFERENCE"] = address["reference"], "exact address property"
call assert p["IJCIB_REQUESTED_PRODUCT_CODE"] = "FB-IJCIB-FIXTURE-GBP", "exact product property"
call assert p["IJCIB_PURPOSE_CODE"] = "ACCOUNT_OPENING", "exact purpose property"

/* Synthetic reply shaped like the sealed bureau's documented selected JMS
   properties.  Reason codes are deliberately opaque and are only preserved. */
rp = .directory~new
rp["IJCIB_OVERALL_DISPOSITION"] = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS"
rp["IJCIB_BUREAU_REFERENCE"] = "OPAQUE-BUREAU-REF-1"
rp["IJCIB_SCORE_SCALED_VALUE"] = "712"
rp["IJCIB_SCORE_SCALE_DIRECTION"] = "HIGHER_INDICATES_LOWER_OBSERVED_STRESS"
rp["IJCIB_SCORE_BAND"] = "BAND-WE-DO-NOT-OWN"
rp["IJCIB_REASON_CODE_TREE"] = "IJCIB.QUAL.X.7|IJCIB.OPAQUE.Y.3"
rp["IJCIB_SUPPRESSION_FLAGS"] = ""
rp["IJCIB_METHODOLOGY"] = "IJCIB-METH-2026.3-REDACTED"
rp["IJCIB_NEXT_REFRESH"] = "2026-09-25T12:00:00+00:00"
rb = .directory~new
rb["protocolVersion"] = "IJCIB-CIP/0.1"
rb["requestId"] = req~requestId
rb["correlationToken"] = req~correlationToken
rb["bureauProductId"] = "OPAQUE-PRODUCT-77"
rb["generationTimestamp"] = "2026-08-25T12:00:00+00:00"
reply = .JMSBridgeMessage~new("ID:IJCIB-REPLY", "MAP", rb, .directory~new, rp, "IJCIB", "ijcib.credit.reply")
decoded = codec~productFromMessage(reply)
call must decoded, "decode IJCIB product"
product = decoded~value
call assert product~overallDisposition = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS", "disposition preserved"
call assert product~scaledValue = 712, "scaled value preserved"
call assert product~scaleDirection = "HIGHER_INDICATES_LOWER_OBSERVED_STRESS", "scale semantics preserved"
call assert product~reasonCodeTree~items = 2, "opaque reason tree preserved"
call assert product~reasonCodeTree[1] = "IJCIB.QUAL.X.7", "reason code not decoded"
call assert product~nextPermittedRefreshNotBefore = "2026-09-25T12:00:00+00:00", "bureau refresh embargo preserved"
say "PASS IJCIB exact JMS MAP/property contract and opaque product preservation"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
