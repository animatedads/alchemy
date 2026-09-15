/* Versioned external travel-information snapshots for FlyLo assistant.
 * These are bounded explanatory authorities, not immigration/customs decisions.
 * Sources are official government publications checked 2026-08-28.
 */

::class FlyLoTravelInformationBuild public
::constant VERSION "0.1"
::constant SNAPSHOT_DATE "2026-08-28"

::class FlyLoTravelInformationAuthority public
::method source private
  use arg authority, sourceId, url, statement
  d = .directory~new
  d["authority"] = authority
  d["sourceId"] = sourceId
  d["url"] = url
  d["checkedAt"] = .FlyLoTravelInformationBuild~SNAPSHOT_DATE
  d["statement"] = statement
  return d

::method usEntryEvidence
  use arg documentCountry
  out = .directory~new
  out["schema"] = "flylo.travel.entry-evidence/0.1"
  out["destinationCountry"] = "USA"
  out["documentCountry"] = documentCountry~string
  out["decisionAuthority"] = "US_GOVERNMENT"
  out["admissionDecisionBy"] = "US_CUSTOMS_AND_BORDER_PROTECTION"
  out["airlineRole"] = "DOCUMENT_CHECK_ONLY"
  out["governmentAdmissionAuthority"] = .true
  out["airlineDocumentCheckOnly"] = .true
  out["sources"] = .array~new
  if documentCountry~string = "COL" then do
    out["visaWaiverProgram"] = .false
    out["summary"] = "A Colombian passport is not itself enough to determine US admissibility. Colombia is not listed as a Visa Waiver Program country; a traveller normally needs an appropriate US visa or another independently valid US status/document. FlyLo must not infer visa status from nationality alone."
    out["needsDocumentStatus"] = .true
    out["sources"]~append(self~source("US_DEPARTMENT_OF_STATE", "VISA_WAIVER_PROGRAM", "https://travel.state.gov/content/travel/en/us-visas/tourism-visit/visa-waiver-program.html", "Colombia is not in the published Visa Waiver Program country list."))
    out["sources"]~append(self~source("US_DEPARTMENT_OF_STATE", "COLOMBIA_RECIPROCITY", "https://travel.state.gov/content/travel/en/us-visas/Visa-Reciprocity-and-Civil-Documents-by-Country/Colombia.html", "The State Department publishes Colombian nonimmigrant visa classifications, including B-1/B-2."))
  end
  else do
    out["summary"] = "FlyLo does not have a sufficiently specific entry-rule snapshot for this travel-document country. Check the current destination-government requirement before travel."
    out["needsDocumentStatus"] = .true
  end
  return out

::method usTobaccoEvidence
  use arg companionChildMentioned = .false, travellerAge = 0, tobaccoForCompanion = .false
  out = .directory~new
  out["schema"] = "flylo.travel.customs-tobacco-evidence/0.1"
  out["destinationCountry"] = "USA"
  out["decisionAuthority"] = "US_CUSTOMS_AND_BORDER_PROTECTION"
  out["checkedBaggageDoesNotChangeCustomsAllowance"] = .true
  out["dutyFreeShopDoesNotOverrideImportRules"] = .true
  out["adultMinimumAge"] = 21
  out["publishedCigaretteQuantity"] = 200
  out["excessRisk"] = "DETENTION_SEIZURE_PENALTIES_ABANDONMENT_OR_DESTRUCTION"
  out["mustDeclareExcess"] = .true
  out["sources"] = .array~new
  out["sources"]~append(self~source("US_CUSTOMS_AND_BORDER_PROTECTION", "TOBACCO_PERSONAL_USE", "https://www.help.cbp.gov/s/article/Article-1376?language=en_US", "CBP states that the tobacco exemption is available to each adult aged 21 or over and describes a limit of not more than 200 cigarettes for the cited personal exemption."))
  out["sources"]~append(self~source("US_CUSTOMS_AND_BORDER_PROTECTION", "DECLARE_ITEMS", "https://www.help.cbp.gov/s/article/Article-1909?language=en_US", "CBP states that one carton/200 cigarettes is the cited duty-free quantity and excess must be declared."))
  out["sources"]~append(self~source("US_CUSTOMS_AND_BORDER_PROTECTION", "CUSTOMS_DUTY_INFORMATION", "https://www.cbp.gov/travel/international-visitors/know-before-you-visit/customs-duty-information", "Duty-free-shop purchase does not itself make an item exempt on entry to the destination country; excess tobacco can be detained or seized."))
  if companionChildMentioned & tobaccoForCompanion then do
    if travellerAge = 0 then out["ageClarificationNeeded"] = .true
    else out["ageClarificationNeeded"] = .false
    if travellerAge > 0 & travellerAge < 21 then out["companionAllowanceEligible"] = .false
    else if travellerAge >= 21 then out["companionAllowanceEligible"] = .true
  end
  else out["ageClarificationNeeded"] = .false
  return out

::method cigaretteBaggageEvidence
  out = .directory~new
  out["schema"] = "flylo.travel.baggage-cigarettes-evidence/0.1"
  out["ordinaryCigarettesCheckedBag"] = "PERMITTED_BY_TSA_LIST"
  out["ordinaryCigarettesCarryOn"] = "PERMITTED_BY_TSA_LIST"
  out["ordinaryCigarettesCheckedBaggagePermitted"] = .true
  out["ordinaryCigarettesCarryOnPermitted"] = .true
  out["lighterRuleSeparate"] = .true
  out["customsRulesSeparate"] = .true
  out["customsRulesRemainSeparate"] = .true
  out["sources"] = .array~new
  out["sources"]~append(self~source("US_TRANSPORTATION_SECURITY_ADMINISTRATION", "WHAT_CAN_I_BRING_CIGARETTES", "https://www.tsa.gov/travel/security-screening/whatcanibring/all-list", "TSA lists ordinary cigarettes as permitted in carry-on and checked bags; security officers retain final screening discretion."))
  out["sources"]~append(self~source("UK_GOVERNMENT", "UK_HAND_LUGGAGE_PERSONAL_ITEMS", "https://www.gov.uk/hand-luggage-restrictions/personal-items", "UK rules separately restrict cigarette lighters in hold luggage; FlyLo should not conflate a lighter with ordinary cigarettes."))
  return out

::method checkedBagProductEvidence
  out = .directory~new
  out["schema"] = "flylo.ancillary.checked-bag-evidence/0.1"
  out["product"] = "CHECKED_BAG"
  out["currency"] = "GBP"
  out["unitPriceMinor"] = 4900
  out["priceBasis"] = "CURRENT_FLYLO_ENGINE_ANCILLARY_SCHEDULE"
  out["transactionRequired"] = .true
  out["quietTransactionForbidden"] = .true
  out["quietTransactionPermitted"] = .false
  return out
