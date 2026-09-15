/* Target-scoped commercial proposal and governance objects. */

::class ShannonOfferCandidate public
::attribute offerId get
::attribute productId get
::attribute productName get
::attribute productClass get
::attribute priceCents get
::attribute currency get
::attribute ageRestricted get
::attribute targetPassengerId get
::attribute targetDisplayName get
::attribute modelReason get

::method init
  expose offerId productId productName productClass priceCents currency ageRestricted targetPassengerId targetDisplayName modelReason
  use arg offerIdArg, productIdArg, productNameArg, priceCentsArg, currencyArg, ageRestrictedArg, targetPassengerIdArg, targetDisplayNameArg, modelReasonArg = '', productClassArg = 'GENERAL'
  offerId = offerIdArg~string
  productId = productIdArg~string
  productName = productNameArg~string
  productClass = productClassArg~string~upper
  priceCents = priceCentsArg
  currency = currencyArg~string
  ageRestricted = ageRestrictedArg
  targetPassengerId = targetPassengerIdArg~string
  targetDisplayName = targetDisplayNameArg~string
  modelReason = modelReasonArg~string

::class ShannonOfferDecision public
::attribute candidate get
::attribute targetRole get
::attribute legalAssessment get
::attribute hardWorldRun get
::attribute permitted get
::attribute reason get

::method init
  expose candidate targetRole legalAssessment hardWorldRun permitted reason
  use arg candidateArg, targetRoleArg, legalArg, hardRunArg, permittedArg, reasonArg
  candidate = candidateArg
  targetRole = targetRoleArg~string
  legalAssessment = legalArg
  hardWorldRun = hardRunArg
  permitted = permittedArg
  reason = reasonArg~string

::class ShannonCommercialPlan public
::attribute candidates get
::attribute decisions get
::attribute modelGrossCents get
::attribute governedGrossCents get

::method init
  expose candidates decisions modelGrossCents governedGrossCents
  use arg candidatesArg, decisionsArg
  candidates = candidatesArg
  decisions = decisionsArg
  modelGrossCents = 0
  governedGrossCents = 0
  do candidate over candidates
    modelGrossCents += candidate~priceCents
  end
  do decision over decisions
    if decision~permitted then governedGrossCents += decision~candidate~priceCents
  end

::method permittedCount
  expose decisions
  count = 0
  do decision over decisions
    if decision~permitted then count += 1
  end
  return count

::method blockedCount
  expose decisions
  count = 0
  do decision over decisions
    if \decision~permitted then count += 1
  end
  return count

::method governedGrossFor
  expose decisions
  use arg productClass
  wanted = productClass~string~upper
  cents = 0
  do decision over decisions
    if decision~permitted then do
      if decision~candidate~productClass == wanted then cents += decision~candidate~priceCents
    end
  end
  return cents

::method renderPermitted
  expose decisions
  text = ''
  seatCount = 0
  seatTotal = 0
  seatNames = ''
  do decision over decisions
    if \decision~permitted then iterate
    candidate = decision~candidate
    if candidate~productClass == 'SEAT_RESERVATION' then do
      seatCount += 1
      seatTotal += candidate~priceCents
      if seatNames == '' then seatNames = candidate~targetDisplayName
      else seatNames = seatNames || ', ' || candidate~targetDisplayName
      iterate
    end
    if candidate~productClass == 'BAR_BUNDLE' then do
      if candidate~targetDisplayName == 'Passenger' then line = 'Beer + Crisps is €10 for you. Shall I add one?'
      else line = 'For ' || candidate~targetDisplayName || ': Beer + Crisps is €10. Shall I add one?'
    end
    else do
      line = 'For ' || candidate~targetDisplayName || ': ' || candidate~productName || ' is €' || format(candidate~priceCents / 100, , 2) || '. Shall I add it?'
    end
    if text == '' then text = line
    else text = text || ' ' || line
  end
  if seatCount > 0 then do
    seatLine = 'Your party has ' || seatCount || ' passenger seat reservations still unpurchased. I can sell reserved seats together at €20 per passenger (€' || format(seatTotal / 100, , 2) || ' total for ' || seatNames || '). Shall I add them?'
    if text == '' then text = seatLine
    else text = text || ' ' || seatLine
  end
  return text
