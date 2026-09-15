/* Authoritative booking-party state for OurLadyAir Shannon.
 * Passenger facts come from booking/ticket evidence, never from model prose.
 */

::class ShannonPassenger public
::attribute passengerId get
::attribute displayName get
::attribute role get
::attribute authority get
::attribute ageRestrictedEligibility get
::attribute pnr get
::attribute ticketNumber get
::attribute dateOfBirth get
::attribute passengerType get
::attribute seat get
::attribute seatReservationStatus get
::attribute groupId get
::attribute essentialMedication get
::attribute custodyUnknown get
::attribute sourceEvidence get

::method init
  expose passengerId displayName role authority ageRestrictedEligibility pnr ticketNumber dateOfBirth passengerType seat seatReservationStatus groupId essentialMedication custodyUnknown sourceEvidence
  use arg passengerIdArg, displayNameArg, roleArg = 'UNKNOWN', authorityArg = 'BOOKING_SYSTEM', ageEligibilityArg = 'UNKNOWN', pnrArg = '', ticketArg = '', dobArg = '', passengerTypeArg = '', seatArg = '', seatStatusArg = 'UNKNOWN', groupIdArg = '', essentialMedicationArg = .false, custodyUnknownArg = .false, sourceEvidenceArg = .nil
  passengerId = passengerIdArg~string
  displayName = displayNameArg~string
  role = roleArg~string~upper
  authority = authorityArg~string
  ageRestrictedEligibility = ageEligibilityArg~string~upper
  pnr = pnrArg~string
  ticketNumber = ticketArg~string
  dateOfBirth = dobArg~string
  passengerType = passengerTypeArg~string~upper
  seat = seatArg~string~upper
  seatReservationStatus = seatStatusArg~string~upper
  groupId = groupIdArg~string
  essentialMedication = essentialMedicationArg
  custodyUnknown = custodyUnknownArg
  if sourceEvidenceArg == .nil then sourceEvidence = .array~new
  else sourceEvidence = sourceEvidenceArg
  if passengerId == '' then raise syntax 88.900 array('Passenger id must not be empty')
  if role \== 'ADULT' & role \== 'CHILD' & role \== 'UNKNOWN' then raise syntax 88.900 array('Unsupported passenger role:' role)
  if ageRestrictedEligibility \== 'ELIGIBLE' & ageRestrictedEligibility \== 'INELIGIBLE' & ageRestrictedEligibility \== 'UNKNOWN' then raise syntax 88.900 array('Unsupported age-restricted eligibility:' ageRestrictedEligibility)
  if seatReservationStatus \== 'RESERVED' & seatReservationStatus \== 'NOT_PURCHASED' & seatReservationStatus \== 'NOT_APPLICABLE' & seatReservationStatus \== 'UNKNOWN' then raise syntax 88.900 array('Unsupported seat reservation status:' seatReservationStatus)

::method adultKnowledge
  expose role
  select
    when role == 'ADULT' then return .RYTAConstant~KNOWLEDGE_KNOWN
    when role == 'CHILD' then return .RYTAConstant~KNOWLEDGE_KNOWN
    otherwise return .RYTAConstant~KNOWLEDGE_UNKNOWN
  end

::method isAdult
  expose role
  return role == 'ADULT'

::method isChild
  expose role
  return role == 'CHILD'

::method ageEligibilityKnowledge
  expose ageRestrictedEligibility
  if ageRestrictedEligibility == 'UNKNOWN' then return .RYTAConstant~KNOWLEDGE_UNKNOWN
  return .RYTAConstant~KNOWLEDGE_KNOWN

::method isAgeRestrictedEligible
  expose ageRestrictedEligibility
  return ageRestrictedEligibility == 'ELIGIBLE'

::method seatReservationKnowledge
  expose seatReservationStatus
  if seatReservationStatus == 'UNKNOWN' then return .RYTAConstant~KNOWLEDGE_UNKNOWN
  return .RYTAConstant~KNOWLEDGE_KNOWN

::method seatReservationMissing
  expose seatReservationStatus
  return seatReservationStatus == 'NOT_PURCHASED'

::method sourcePaths
  expose sourceEvidence
  paths = .array~new
  do evidenceObject over sourceEvidence
    if evidenceObject == .nil then iterate
    if evidenceObject~hasMethod('ORIGIN') then do
      origin = evidenceObject~origin
      if origin \== .nil then do
        if origin~hasMethod('PATH') then paths~append(origin~path)
      end
    end
    else if evidenceObject~hasMethod('PATH') then paths~append(evidenceObject~path)
  end
  return paths

::class ShannonBooking public
::attribute bookingId get
::attribute sealed get
::attribute sourceFormat get
::attribute sourceDocument get
::attribute sourceEnvelopeReport get
::attribute sourceAdapter get

::method init
  expose bookingId passengerList sealed sourceFormat sourceDocument sourceEnvelopeReport sourceAdapter
  use arg bookingIdArg = 'SHANNON-BOOKING', sourceFormatArg = 'MANUAL'
  bookingId = bookingIdArg~string
  sourceFormat = sourceFormatArg~string~upper
  sourceDocument = .nil
  sourceEnvelopeReport = .nil
  sourceAdapter = ''
  passengerList = .array~new
  sealed = .false

::method attachStructuredSource
  expose sealed sourceDocument sourceEnvelopeReport sourceAdapter
  use arg documentArg, envelopeReportArg, adapterArg
  if sealed then raise syntax 88.900 array('Booking is sealed')
  sourceDocument = documentArg
  sourceEnvelopeReport = envelopeReportArg
  sourceAdapter = adapterArg~string
  return self

::method sourceEnvelopeStatus
  expose sourceEnvelopeReport
  if sourceEnvelopeReport == .nil then return 'NOT_APPLICABLE'
  return sourceEnvelopeReport~status

::method sourceParserName
  expose sourceDocument
  if sourceDocument == .nil then return ''
  if sourceDocument~hasMethod('PARSERNAME') then return sourceDocument~parserName
  return ''

::method sourceAnnotationCount
  expose sourceDocument
  if sourceDocument == .nil then return 0
  if sourceDocument~hasMethod('ANNOTATIONS') then return sourceDocument~annotations~items
  return 0

::method addPassenger
  expose passengerList sealed
  use arg passenger
  if sealed then raise syntax 88.900 array('Booking is sealed')
  if passenger == .nil then raise syntax 88.900 array('Passenger must not be nil')
  do existing over passengerList
    if existing~passengerId == passenger~passengerId then raise syntax 88.900 array('Duplicate passenger id:' passenger~passengerId)
  end
  passengerList~append(passenger)
  return self

::method seal
  expose passengerList sealed
  if passengerList~items == 0 then raise syntax 88.900 array('Cannot seal an empty booking')
  sealed = .true
  return self

::method passengers
  expose passengerList
  copy = .array~new
  do passenger over passengerList
    copy~append(passenger)
  end
  return copy

::method passengerCount
  expose passengerList
  return passengerList~items

::method passenger
  expose passengerList
  use arg passengerId
  wanted = passengerId~string
  do passenger over passengerList
    if passenger~passengerId == wanted then return passenger
  end
  return .nil

::method noSeatPurchaseCount
  expose passengerList
  count = 0
  do passenger over passengerList
    if passenger~seatReservationStatus == 'NOT_PURCHASED' then count += 1
  end
  return count

::method applyWorldEvidence
  expose passengerList bookingId
  use arg world
  if world == .nil then raise syntax 88.900 array('Booking world evidence requires a HardWorld world')
  hasMedication = .false
  hasUnknownCustody = .false
  medicationEvidence = .array~new
  do passenger over passengerList
    if passenger~essentialMedication then do
      hasMedication = .true
      do evidenceObject over passenger~sourceEvidence
        medicationEvidence~append(evidenceObject)
      end
      if passenger~custodyUnknown then hasUnknownCustody = .true
    end
  end
  if hasMedication then do
    source = 'BOOKING/' || bookingId || '/PNRGOV/STRUCTURED_RELATION'
    ignored = world~putKnown('ESSENTIAL_MEDICATION', .true, source, 'TICKET_EVIDENCE', medicationEvidence)
    ignored = world~putKnown('IMMEDIATE_ACCESS', .true, source, 'TICKET_EVIDENCE', medicationEvidence)
    ignored = world~putKnown('SAFETY_RELEVANCE_DETECTED', .true, source, 'TICKET_EVIDENCE', medicationEvidence)
    if hasUnknownCustody then do
      ignored = world~putUnknown('GUARANTEED_CUSTODY', source, 'TICKET_EVIDENCE', medicationEvidence)
      ignored = world~putUnknown('BAG_MAY_ENTER_HOLD', source, 'TICKET_EVIDENCE', medicationEvidence)
      ignored = world~putKnown('CRITICAL_FACTS_UNRESOLVED', .true, source, 'DETERMINISTIC', medicationEvidence)
      ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .true, source, 'DETERMINISTIC', medicationEvidence)
    end
  end
  return world

::method defaultSingleAdult class
  booking = .ShannonBooking~new('SHANNON-DEFAULT-BOOKING')
  booking~addPassenger(.ShannonPassenger~new('P1', 'Passenger', 'ADULT', 'BOOKING_SYSTEM', 'ELIGIBLE'))
  return booking~seal

::requires 'HardWorld.cls'
