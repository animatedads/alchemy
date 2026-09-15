/*
 * Evidence-safe assessment helpers for Civic-normalized Companies House
 * accounts. This is a policy/plugin layer over AccountingExternalStatement;
 * it is not part of native GL posting mechanics and it does not infer missing
 * journals from filed totals.
 */

::options digits 50

::class AccountingAssessmentFinding public
::attribute code get
::attribute status get
::attribute message get
::attribute expected get
::attribute actual get
::method init
  expose code status message expected actual evidenceRefs details
  use arg codeArg, statusArg, messageArg, expectedArg = "", actualArg = "", evidenceArg = .nil, detailsArg = .nil
  code = .AccountingUtil~requireText(codeArg, "assessment finding code")
  status = .AccountingUtil~requireText(statusArg, "assessment finding status")~upper
  if wordpos(status, "PASS INFO WARN FAIL NOT_EVALUATED") = 0 then -
    raise syntax 93.900 additional("Unsupported assessment finding status: " || status)
  message = messageArg~string
  expected = expectedArg~string
  actual = actualArg~string
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  details = .AccountingUtil~copyDirectory(detailsArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method details
  expose details
  return .AccountingUtil~copyDirectory(details)

::class AccountingCompaniesHouseAssessmentReport public
::attribute statementIdentity get
::method init
  expose statementIdentity findings
  use arg identityArg
  statementIdentity = .AccountingUtil~requireText(identityArg, "statementIdentity")
  findings = .array~new

::method add
  expose findings
  use arg finding
  if finding == .nil | \finding~isA(.AccountingAssessmentFinding) then -
    raise syntax 93.900 additional("AccountingAssessmentFinding required")
  findings~append(finding)
  return finding

::method findings
  expose findings
  return .AccountingUtil~copyArray(findings)

::method finding
  expose findings
  use arg code
  wanted = code~string
  do f over findings
    if f~code = wanted then return f
  end
  return .nil

::method countStatus
  expose findings
  use arg status
  wanted = status~string~upper
  count = 0
  do f over findings
    if f~status = wanted then count += 1
  end
  return count

::class AccountingCompaniesHouseAssessment public
::constant POLICY "accounting.assessment.companieshouse/0.1"

::method assess class
  use arg statement
  if statement == .nil | \statement~isA(.AccountingExternalStatement) then -
    raise syntax 93.900 additional("AccountingExternalStatement required")
  if statement~sourceSystem \= "CIVIC" then raise syntax 93.900 additional("Companies House assessment requires Civic evidence")
  if statement~sourceContract~left("civic.companieshouse.accounts/"~length) \= "civic.companieshouse.accounts/" then -
    raise syntax 93.900 additional("Unsupported Companies House assessment source contract: " || statement~sourceContract)

  report = .AccountingCompaniesHouseAssessmentReport~new(statement~externalIdentity)
  completeness = statement~completeness

  delivered = completeness["income_statement_delivered"]
  if delivered \== .nil & \self~truth(delivered) then do
    details = .directory~new
    omission = completeness["income_statement_omission_statement"]
    if omission \== .nil then details["omission_statement"] = omission
    report~add(.AccountingAssessmentFinding~new("INCOME_STATEMENT_NOT_DELIVERED", "INFO", -
      "The filed package states that the income statement was not delivered; assessment must not treat absent income-statement detail as zero.", "", "", .nil, details))
  end

  self~checkDifference(report, statement, "CURRENT_ASSET_ARITHMETIC", "CurrentAssets", "Creditors", "NetCurrentAssetsLiabilities", -
    "Current assets less current creditors agrees to net current assets")
  self~checkSum(report, statement, "TOTAL_ASSET_ARITHMETIC", "InvestmentsFixedAssets", "NetCurrentAssetsLiabilities", "TotalAssetsLessCurrentLiabilities", -
    "Fixed-asset investments plus net current assets agrees to total assets less current liabilities")
  self~checkSum(report, statement, "CREDITOR_DETAIL_ARITHMETIC", "CorporationTaxPayable", "AccruedLiabilities", "Creditors", -
    "Corporation tax plus accrued liabilities agrees to current creditors")

  shareCapital = self~factWithMember(statement, "Equity", "ShareCapital")
  retained = self~factWithMember(statement, "Equity", "RetainedEarningsAccumulatedLosses")
  totalEquity = self~plainFact(statement, "Equity")
  self~checkFactSum(report, "EQUITY_ARITHMETIC", shareCapital, retained, totalEquity, -
    "Share capital plus retained earnings agrees to shareholders' funds")

  directorClosing = self~latestPositiveFact(statement, "AmountSpecificAdvanceOrCreditDirectors")
  if directorClosing \== .nil then do
    details = .directory~new
    details["normalized_value"] = directorClosing~normalizedValue
    details["currency"] = directorClosing~currency
    report~add(.AccountingAssessmentFinding~new("DIRECTOR_ADVANCE_BALANCE_REPORTED", "INFO", -
      "The filing reports an outstanding director advance/credit balance; its legal, tax and accounting treatment requires entity-specific assessment.", "", directorClosing~normalizedValue, .array~of(directorClosing~sourcePointer), details))
  end

  profit = self~plainOrAnyFact(statement, "ProfitLoss")
  if profit \== .nil & delivered \== .nil & \self~truth(delivered) then do
    report~add(.AccountingAssessmentFinding~new("PROFIT_DISCLOSED_OUTSIDE_UNDELIVERED_INCOME_STATEMENT", "INFO", -
      "A profit/loss fact is present in the filed notes/reserves even though the income statement itself was not delivered.", "", profit~normalizedValue, .array~of(profit~sourcePointer)))
  end

  framework = self~plainOrAnyFact(statement, "StatementComplianceWithApplicableReportingFramework")
  if framework == .nil then report~add(.AccountingAssessmentFinding~new("REPORTING_FRAMEWORK_DISCLOSURE", "WARN", "No normalized reporting-framework disclosure was found."))
  else report~add(.AccountingAssessmentFinding~new("REPORTING_FRAMEWORK_DISCLOSURE", "PASS", "A reporting-framework disclosure is retained as source evidence.", "", framework~lexicalValue, .array~of(framework~sourcePointer)))

  return report

::method checkDifference class private
  use arg report, statement, code, leftName, subtractName, resultName, message
  left = self~plainOrAnyFact(statement, leftName)
  sub = self~plainOrAnyFact(statement, subtractName)
  result = self~plainOrAnyFact(statement, resultName)
  if left == .nil | sub == .nil | result == .nil then do
    report~add(.AccountingAssessmentFinding~new(code, "NOT_EVALUATED", message || ": required normalized facts are absent"))
    return
  end
  a = self~whole(left); b = self~whole(sub); c = self~whole(result)
  if a == .nil | b == .nil | c == .nil then do
    report~add(.AccountingAssessmentFinding~new(code, "NOT_EVALUATED", message || ": facts are not exact whole-number values"))
    return
  end
  expected = a - b
  pointers = .array~of(left~sourcePointer, sub~sourcePointer, result~sourcePointer)
  if expected = c then report~add(.AccountingAssessmentFinding~new(code, "PASS", message, expected, c, pointers))
  else report~add(.AccountingAssessmentFinding~new(code, "FAIL", message, expected, c, pointers))

::method checkSum class private
  use arg report, statement, code, leftName, rightName, resultName, message
  left = self~plainOrAnyFact(statement, leftName)
  right = self~plainOrAnyFact(statement, rightName)
  result = self~plainOrAnyFact(statement, resultName)
  self~checkFactSum(report, code, left, right, result, message)

::method checkFactSum class private
  use arg report, code, left, right, result, message
  if left == .nil | right == .nil | result == .nil then do
    report~add(.AccountingAssessmentFinding~new(code, "NOT_EVALUATED", message || ": required normalized facts are absent"))
    return
  end
  a = self~whole(left); b = self~whole(right); c = self~whole(result)
  if a == .nil | b == .nil | c == .nil then do
    report~add(.AccountingAssessmentFinding~new(code, "NOT_EVALUATED", message || ": facts are not exact whole-number values"))
    return
  end
  expected = a + b
  pointers = .array~of(left~sourcePointer, right~sourcePointer, result~sourcePointer)
  if expected = c then report~add(.AccountingAssessmentFinding~new(code, "PASS", message, expected, c, pointers))
  else report~add(.AccountingAssessmentFinding~new(code, "FAIL", message, expected, c, pointers))

::method plainFact class private
  use arg statement, localName
  do fact over statement~factsByLocalConcept(localName)
    if fact~isDuplicate then iterate
    if fact~dimensions~items = 0 then return fact
  end
  return .nil

::method plainOrAnyFact class private
  use arg statement, localName
  plain = self~plainFact(statement, localName)
  if plain \== .nil then return plain
  do fact over statement~factsByLocalConcept(localName)
    if \fact~isDuplicate then return fact
  end
  return .nil

::method factWithMember class private
  use arg statement, localName, memberLocalName
  do fact over statement~factsByLocalConcept(localName)
    if fact~isDuplicate then iterate
    dimensions = fact~dimensions
    do key over dimensions
      if self~localPart(dimensions[key]) = memberLocalName~string then return fact
    end
  end
  return .nil

::method latestPositiveFact class private
  use arg statement, localName
  candidate = .nil
  do fact over statement~factsByLocalConcept(localName)
    if fact~isDuplicate then iterate
    value = self~whole(fact)
    if value == .nil | value <= 0 then iterate
    if candidate == .nil then candidate = fact
    else if fact~instantDate > candidate~instantDate then candidate = fact
  end
  return candidate

::method whole class private
  use arg fact
  if fact == .nil then return .nil
  text = fact~normalizedValue~string~strip
  if \datatype(text, "W") then return .nil
  numeric digits 50
  return text + 0

::method localPart class private
  use arg value
  text = value~string
  if text~left(1) = "{" then do
    p = text~pos("}")
    if p > 0 then return text~substr(p + 1)
  end
  p = text~pos(":")
  if p > 0 then return text~substr(p + 1)
  return text

::method truth class private
  use arg value
  if value == .nil then return .false
  /* json.cls represents JSON booleans as proxy objects whose STRING is
   * descriptive ("a JSONBoolean"), while VALUE is the logical 0/1. */
  if value~class~id = "JSONBoolean" then return value~value
  text = value~string~strip~upper
  return wordpos(text, "TRUE 1 YES") > 0

::requires "AccountingAssessment.cls"
