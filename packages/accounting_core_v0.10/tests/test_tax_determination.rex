t = .AccountingTest~new
numeric digits 50

/* Exact rational and quantization mechanics are jurisdiction-neutral. */
raw = .AccountingTaxExactAmount~fromBasisRate("999", "20", "100")
t~assertEq("19980", raw~numerator, "exact VAT numerator retained")
t~assertEq("100", raw~denominator, "exact VAT denominator retained")
t~assertEq("200", raw~toMinorUnits("HALF_UP"), "199.8p rounds to 200p with generic half-up")
t~assertEq("199", raw~toMinorUnits("TRUNCATE"), "generic truncation remains separately selectable")
t~assertEq("5", .AccountingTaxExactAmount~new(5, 1)~toMinorUnits("HALF_UP"), "already-whole tax amount is unchanged by half-up")
q4 = raw~quantizeMajor(2, 4, "HALF_UP")
t~assertEq("19980", q4~numerator, "GBP four-decimal quantization retains 199.80 hundredths of penny")
t~assertEq("100", q4~denominator, "GBP four-decimal quantization denominator")
neg = .AccountingTaxExactAmount~fromBasisRate("-999", "20", "100")
t~assertEq("-200", neg~toMinorUnits("HALF_UP"), "signed credit-note tax can be represented exactly")
t~assertTrue(taxPrecisionOverflowRejected(), "tax intermediate exceeding DIGITS 50 is rejected rather than rounded")

entity = "GLOBAL_SERVICES_LLP"
engine = makeTaxEngine(entity)
call registerScopes engine, entity
ukPolicy = .DemoUKVATPolicy~new("uk.vat.tax/2026", "sha256:uk-vat-code-2026", "uk.vat.rules/2026", "UK-VAT-RULESET-ID-2026")
auPolicy = .DemoAUGSTPolicy~new("au.gst.tax/2026", "sha256:au-gst-code-2026", "au.gst.rules/2026", "AU-GST-RULESET-ID-2026")
engine~registerTaxPolicy(ukPolicy)
engine~registerTaxPolicy(auPolicy)
acctPolicy = .DemoTaxAccountingPolicy~new("firm.accounting.tax/0.6", "sha256:firm-tax-accounting-06", entity, "TAX_DETERMINED", "2026-01-01")
engine~registerPolicy(acctPolicy)

ukDims = .directory~new
ukDims[.AccountingDimensionKeys~MATTER_REF] = "000123"
ukEvidence = .array~of("INVOICE:GB:001", "VAT-ELECTION-EVIDENCE:2026")
ukReq = .AccountingTaxRequest~new("INV:GB:001:LINE:1", entity, "2026-08-28", "GBP", 2, "999", "TAX-GB-VAT", "PER_LINE", "INVOICE:GB:001", "UK_CLIENT_LTD", "BILLING.SYSTEM", ukEvidence, ukDims)
uk = engine~determineTax(ukReq)
t~assertTrue(uk~ok, "UK VAT tax request determines")
t~assertEq("200", uk~determination~taxMinor, "UK sample policy applies elected nearest-penny result")
t~assertEq("ELECT-GB-VAT-2026", uk~determination~taxElectionRef, "exact UK election ref retained")
t~assertEq("sha256:gb-vat-election-2026", uk~determination~taxElectionIdentity, "exact UK election identity retained")
t~assertEq("UK-VAT-RULESET-ID-2026", uk~determination~rulesetIdentity, "exact UK ruleset identity retained")
t~assertEq("sha256:uk-vat-code-2026", uk~determination~taxPolicyIdentity, "exact executable UK tax policy identity retained")
t~assertEq("HMRC-NEAREST-PENNY", uk~determination~roundingAlgorithmRef, "elected UK rounding method retained")
detProjection = .AccountingTaxDeterminationCodec~toProjection(uk~determination)
detRoundTrip = .AccountingTaxDeterminationCodec~fromProjection(detProjection)
t~assertEq(uk~determination~fingerprint, detRoundTrip~fingerprint, "tax determination projection round-trips exactly")
t~assertEq("000123", uk~determination~dimensions[.AccountingDimensionKeys~MATTER_REF], "opaque matter identity survives tax determination")

/* Request projections are transport-neutral and fingerprint-stable. */
ukProjection = .AccountingTaxRequestCodec~toProjection(ukReq)
ukRoundTrip = .AccountingTaxRequestCodec~fromProjection(ukProjection)
t~assertEq(ukReq~fingerprint, ukRoundTrip~fingerprint, "tax request projection round-trips exactly")
ukProjectionResult = engine~determineTaxProjection(ukProjection)
t~assertTrue(ukProjectionResult~ok, "tax request projection can determine")
projectionPostReq = .AccountingTaxRequest~new("INV:GB:PROJECTION:LINE:1", entity, "2026-08-28", "GBP", 2, "100", "TAX-GB-VAT", "PER_LINE", "INVOICE:GB:PROJECTION")
projectionPost = engine~transactTaxProjection(.AccountingTaxRequestCodec~toProjection(projectionPostReq))
t~assertTrue(projectionPost~ok, "transport tax request can determine and transact")

/* Same core, different jurisdiction pack/ruleset. */
auReq = .AccountingTaxRequest~new("INV:AU:001:LINE:1", entity, "2026-08-28", "AUD", 2, "95", "TAX-AU-GST", "PER_LINE", "INVOICE:AU:001", "AU_CLIENT_PTY", "BILLING.SYSTEM")
au = engine~determineTax(auReq)
t~assertTrue(au~ok, "AU GST tax request determines through same core")
t~assertEq("10", au~determination~taxMinor, "9.5 cents rounds to 10 cents under AU sample policy")
t~assertEq("ATO-NEAREST-CENT", au~determination~roundingAlgorithmRef, "AU election remains distinct from UK election")
t~assertEq("AU-GST-RULESET-ID-2026", au~determination~rulesetIdentity, "AU exact ruleset identity retained")

/* Election controls granularity: callers cannot silently switch the elected method. */
badGranularity = .AccountingTaxRequest~new("INV:GB:002", entity, "2026-08-28", "GBP", 2, "1000", "TAX-GB-VAT", "PER_INVOICE")
t~assertEq("TAX_CALCULATION_GRANULARITY_MISMATCH", engine~determineTax(badGranularity)~errorCode, "elected calculation granularity enforced")

/* End-to-end determination -> AccountingEvent -> company accounting policy. */
posted = engine~transactTax(ukReq)
t~assertTrue(posted~ok, "tax determination can transact into company book")
t~assertEq("POSTED", posted~status, "tax accounting journal posts")
t~assertEq("1199", posted~entry~lines[1]~debitMinor, "gross receivable is exact")
t~assertEq("999", posted~entry~lines[2]~creditMinor, "net revenue is exact")
t~assertEq("200", posted~entry~lines[3]~creditMinor, "VAT payable is exact")
postDims = posted~entry~lines[3]~dimensions
t~assertEq("TAX-GB-VAT", postDims[.AccountingDimensionKeys~TAX_REGISTRATION_REF], "posted tax line retains tax registration")
t~assertEq("ELECT-GB-VAT-2026", postDims[.AccountingDimensionKeys~TAX_ELECTION_REF], "posted tax line retains election ref")
t~assertEq("sha256:gb-vat-election-2026", postDims[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY], "posted tax line retains election identity")
t~assertEq(4, ukPolicy~calls, "explicit, projected, transport-post and first transact determinations dispatch tax policy")
t~assertEq(2, acctPolicy~calls, "accounting policy called for transport and direct tax postings")

/* Once posted, replay is checked before BOTH tax and accounting policy dispatch. */
dup = engine~transactTax(ukReq)
t~assertTrue(dup~ok, "exact tax replay accepted idempotently")
t~assertEq("DUPLICATE", dup~status, "tax replay returns original journal")
t~assertEq(4, ukPolicy~calls, "posted tax replay does not redispatch tax policy")
t~assertEq(2, acctPolicy~calls, "posted tax replay does not redispatch accounting policy")
changedReq = .AccountingTaxRequest~new("INV:GB:001:LINE:1", entity, "2026-08-28", "GBP", 2, "1000", "TAX-GB-VAT", "PER_LINE", "INVOICE:GB:001", "UK_CLIENT_LTD", "BILLING.SYSTEM", ukEvidence, ukDims)
changedResult = engine~transactTax(changedReq)
t~assertEq("SOURCE_TAX_EVENT_CONFLICT", changedResult~errorCode, "same tax source identity with changed evidence conflicts before policy")
t~assertEq(4, ukPolicy~calls, "changed tax replay rejected before policy")

/* Credit note: tax determination is signed; company accounting policy reverses sides. */
creditReq = .AccountingTaxRequest~new("CRN:GB:001:LINE:1", entity, "2026-08-28", "GBP", 2, "-999", "TAX-GB-VAT", "PER_LINE", "CREDIT:GB:001", "UK_CLIENT_LTD", "BILLING.SYSTEM")
creditPosted = engine~transactTax(creditReq)
t~assertTrue(creditPosted~ok, "signed credit-note determination accounts")
t~assertEq("999", creditPosted~entry~lines[1]~debitMinor, "credit note debits revenue")
t~assertEq("200", creditPosted~entry~lines[2]~debitMinor, "credit note debits VAT payable")
t~assertEq("1199", creditPosted~entry~lines[3]~creditMinor, "credit note credits receivable")

/* Tax policy packages are under the same NUMERIC DIGITS 50 executable contract. */
low = .LowDigitsTaxPolicy~new("bad.tax/0.1", "sha256:bad-tax", "bad.rules/0.1", "BAD-RULESET")
t~assertEq(9, low~class~package~digits, "negative tax fixture uses default digits 9")
t~assertTrue(taxPolicyRegistrationFails(.AccountingTaxPolicyCatalog~new, low), "tax policy below digits 50 is rejected")

/* Missing exact ruleset implementation is explicit, not interpreted as no tax. */
missingEngine = makeTaxEngine("MISSING_POLICY_CO")
missingEngine~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-GB-VAT", "MISSING_POLICY_CO", "GB", "HMRC", "VAT", "GB999", "", "NON_ESTABLISHED_TAXABLE_PERSON", "2026-01-01"))
missingEngine~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB", "sha256:gb", "MISSING_POLICY_CO", "TAX-GB-VAT", "uk.vat.rules/2026", "UNAVAILABLE-RULESET", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01"))
missingReq = .AccountingTaxRequest~new("SALE:1", "MISSING_POLICY_CO", "2026-08-28", "GBP", 2, "100", "TAX-GB-VAT", "PER_LINE")
t~assertEq("TAX_POLICY_NOT_FOUND", missingEngine~determineTax(missingReq)~errorCode, "tax obligation without loaded exact ruleset is explicit")

say "tax determination assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine makeTaxEngine
  use arg entity
  e = .AccountingEngine~new(entity, "STAT")
  e~book~addAccount(.AccountingAccount~new("1000", "Receivable", "ASSET"))
  e~book~addAccount(.AccountingAccount~new("2200", "Tax payable", "LIABILITY"))
  e~book~addAccount(.AccountingAccount~new("4000", "Revenue", "REVENUE"))
  e~book~sealChart
  e~book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
  return e

::routine registerScopes
  use arg e, entity
  e~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-GB-VAT", entity, "GB", "HMRC", "VAT", "GB123456789", "", "NON_ESTABLISHED_OR_ESTABLISHED_AS_APPLICABLE", "2026-01-01"))
  e~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB-VAT-2026", "sha256:gb-vat-election-2026", entity, "TAX-GB-VAT", "uk.vat.rules/2026", "UK-VAT-RULESET-ID-2026", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01"))
  e~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-AU-GST", entity, "AU", "ATO", "GST", "ABN-GST-001", "", "GST_REGISTERED", "2026-01-01"))
  e~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-AU-GST-2026", "sha256:au-gst-election-2026", entity, "TAX-AU-GST", "au.gst.rules/2026", "AU-GST-RULESET-ID-2026", "ATO-NEAREST-CENT", "PER_LINE", "BAS", "2026-01-01"))

::routine taxPrecisionOverflowRejected
  signal on syntax name caught
  ignore = .AccountingTaxExactAmount~fromBasisRate("9999999999999999999999999999999999999999999999999", 99, 100)
  return .false
caught:
  return .true

::routine taxPolicyRegistrationFails
  use arg catalog, policy
  signal on syntax name caught
  catalog~register(policy)
  return .false
caught:
  return .true

::class DemoUKVATPolicy subclass AccountingTaxPolicy
::attribute calls get
::method init
  expose calls
  use arg policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg
  calls = 0
  self~init:super(policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg)
::method determine
  expose calls
  use arg request, registration, election
  calls += 1
  if registration~jurisdiction \= "GB" | registration~taxType \= "VAT" then return .AccountingTaxPolicyDecision~reject("UK_VAT_REGISTRATION_REQUIRED")
  if election~roundingAlgorithmRef \= "HMRC-NEAREST-PENNY" then return .AccountingTaxPolicyDecision~reject("UK_VAT_ROUNDING_ELECTION_UNSUPPORTED", election~roundingAlgorithmRef)
  raw = .AccountingTaxExactAmount~fromBasisRate(request~taxableBasisMinor, 20, 100)
  taxMinor = raw~toMinorUnits("HALF_UP")
  metadata = .directory~new
  metadata["jurisdictionPolicyExample"] = "UK VAT standard-rate sample; substantive rule lives outside Accounting Core"
  metadata["preRoundingArithmetic"] = "EXACT_RATIONAL_DIGITS_50"
  return .AccountingTaxPolicyDecision~accept(self~newDetermination(request, registration, election, taxMinor, "GB-VAT-STANDARD", "EXCLUSIVE_RATE_20_PERCENT", raw, .nil, .nil, metadata))

::class DemoAUGSTPolicy subclass AccountingTaxPolicy
::method determine
  use arg request, registration, election
  if registration~jurisdiction \= "AU" | registration~taxType \= "GST" then return .AccountingTaxPolicyDecision~reject("AU_GST_REGISTRATION_REQUIRED")
  if election~roundingAlgorithmRef \= "ATO-NEAREST-CENT" then return .AccountingTaxPolicyDecision~reject("AU_GST_ROUNDING_ELECTION_UNSUPPORTED", election~roundingAlgorithmRef)
  raw = .AccountingTaxExactAmount~fromBasisRate(request~taxableBasisMinor, 10, 100)
  taxMinor = raw~toMinorUnits("HALF_UP")
  return .AccountingTaxPolicyDecision~accept(self~newDetermination(request, registration, election, taxMinor, "AU-GST-TAXABLE", "EXCLUSIVE_RATE_10_PERCENT", raw))

::class DemoTaxAccountingPolicy subclass AccountingPolicy
::attribute calls get
::method init
  expose calls
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  calls = 0
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  expose calls
  use arg event, book
  calls += 1
  basis = .AccountingUtil~requireWholeSigned(event~value("taxableBasisMinor"), "taxableBasisMinor")
  tax = .AccountingUtil~requireWholeSigned(event~value("taxMinor"), "taxMinor")
  if (basis < 0 & tax > 0) | (basis > 0 & tax < 0) then return .AccountingPolicyDecision~reject("TAX_SIGN_MISMATCH")
  currency = event~value("currency")~string
  dims = event~value("accountingDimensions")
  draft = self~newDraft(event, book, event~eventDate, "Tax determination accounting")
  if basis >= 0 then do
    gross = basis + tax
    draft~addLine(.AccountingJournalLine~new("1000", currency, gross, 0, "Gross receivable", dims))
    draft~addLine(.AccountingJournalLine~new("4000", currency, 0, basis, "Net revenue", dims))
    draft~addLine(.AccountingJournalLine~new("2200", currency, 0, tax, "Tax payable", dims))
  end
  else do
    basisAbs = -basis
    taxAbs = -tax
    grossAbs = basisAbs + taxAbs
    draft~addLine(.AccountingJournalLine~new("4000", currency, basisAbs, 0, "Revenue reversal", dims))
    draft~addLine(.AccountingJournalLine~new("2200", currency, taxAbs, 0, "Tax reversal", dims))
    draft~addLine(.AccountingJournalLine~new("1000", currency, 0, grossAbs, "Receivable reversal", dims))
  end
  return .AccountingPolicyDecision~accept(draft)

::options digits 50
::requires "AccountingEngine.cls"
::requires "AccountingPersistence.cls"
::requires "LowDigitsTaxPolicy.cls"
::requires "TestSupport.cls"
