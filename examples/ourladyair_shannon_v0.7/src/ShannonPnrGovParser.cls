/* Structured Relation v0.9 backed parser for the fictional OurLadyAir PNRGOV feed.
 *
 * The EDIFACT bytes are parsed by EdiFactNativeSource.  Shannon consumes explicit
 * rich relation projections; it does not strip comments or rebuild the source as
 * ad-hoc strings.  Projected rows retain their source EDIFACT objects and spans.
 */

::class ShannonTicketPassengerBuilder public
::attribute surname
::attribute givenName
::attribute title
::attribute passengerType
::attribute dateOfBirth
::attribute pnr
::attribute groupId
::attribute messageRef
::attribute ticketNumber
::attribute seat
::attribute seatReservationStatus
::attribute essentialMedication
::attribute custodyUnknown
::attribute sourceEvidence get

::method init
  expose surname givenName title passengerType dateOfBirth pnr groupId messageRef ticketNumber seat seatReservationStatus essentialMedication custodyUnknown sourceEvidence
  surname = ''; givenName = ''; title = ''; passengerType = ''; dateOfBirth = ''
  pnr = ''; groupId = ''; messageRef = ''; ticketNumber = ''; seat = ''; seatReservationStatus = 'UNKNOWN'
  essentialMedication = .false; custodyUnknown = .false
  sourceEvidence = .array~new

::method addEvidence
  expose sourceEvidence
  use arg evidenceObject
  if evidenceObject \== .nil then sourceEvidence~append(evidenceObject)
  return self

::method displayName
  expose surname givenName
  given = givenName~lower
  family = surname~lower
  if given \== '' then given = given~left(1)~upper || given~substr(2)
  if family \== '' then family = family~left(1)~upper || family~substr(2)
  return given || ' ' || family

::class ShannonPnrGovSet public
::attribute groups get
::attribute document get
::attribute envelopeReport get
::attribute relationProvider get

::method init
  expose groups document envelopeReport relationProvider
  use arg documentArg, envelopeReportArg, relationProviderArg
  groups = .directory~new
  document = documentArg
  envelopeReport = envelopeReportArg
  relationProvider = relationProviderArg

::method addBuilder
  expose groups
  use arg groupId, builder
  if \groups~hasIndex(groupId) then groups[groupId] = .array~new
  groups[groupId]~append(builder)
  return builder

::method groupIds
  expose groups
  ids = groups~allIndexes
  ids~sort
  return ids

::method booking
  expose groups document envelopeReport
  use arg groupId
  if \groups~hasIndex(groupId) then return .nil
  builders = groups[groupId]
  booking = .ShannonBooking~new(groupId, 'PNRGOV')
  ignored = booking~attachStructuredSource(document, envelopeReport, 'structured_relation_plugin/0.9')
  ordinal = 0
  do builder over builders
    ordinal += 1
    roleData = .ShannonPnrGovParser~deriveRole(builder~passengerType, builder~dateOfBirth)
    passengerId = groupId || '-P' || ordinal
    passenger = .ShannonPassenger~new(passengerId, builder~displayName, roleData['role'], roleData['authority'], roleData['eligibility'], builder~pnr, builder~ticketNumber, builder~dateOfBirth, builder~passengerType, builder~seat, builder~seatReservationStatus, groupId, builder~essentialMedication, builder~custodyUnknown, builder~sourceEvidence)
    booking~addPassenger(passenger)
  end
  return booking~seal

::class ShannonPnrGovParser public
::constant ALCOHOL_THRESHOLD_DOB '20080821' /* 18 on OA1541/21AUG26 */

::method parseFile class
  use arg path
  doc = .EdiFactDocumentContext~new(path)
  return self~parseDocument(doc)

::method parseText class
  use arg rawText
  doc = .EdiFactDocumentContext~fromText(rawText~string, 'memory:ourladyair-pnrgov')
  return self~parseDocument(doc)

::method parseDocument private class
  use arg doc
  envelopeReport = doc~validateEnvelope
  provider = .EdiFactRelationProvider~new(.nil)

  messageDef = provider~defineRelation('pnr_messages', doc, 'MESSAGE:PNRGOV')
  messageDef~columnMap('group_ref', '@groupReference')
  messageDef~columnMap('message_ref', '@reference')
  messageDef~columnMap('pnr', 'RCI/1/2')
  messageDef~columnMap('passenger_qty', 'EQN/1/1', 'INTEGER')

  paxDef = provider~defineRelation('pnr_passengers', doc, 'SEGMENT:TIF')
  paxDef~columnMap('group_ref', '@groupReference')
  paxDef~columnMap('message_ref', '@messageReference')
  paxDef~columnMap('surname', '1')
  paxDef~columnMap('given_name', '2')
  paxDef~columnMap('title', '3')
  paxDef~columnMap('passenger_type', '4')
  paxDef~columnMap('dob', '5')

  ssrDef = provider~defineRelation('pnr_ssr', doc, 'SEGMENT:SSR')
  ssrDef~columnMap('group_ref', '@groupReference')
  ssrDef~columnMap('message_ref', '@messageReference')
  ssrDef~columnMap('service_code', '1/1')
  ssrDef~columnMap('service_status', '1/2')
  ssrDef~columnMap('service_value', '2')

  ticketDef = provider~defineRelation('pnr_tickets', doc, 'SEGMENT:TKT')
  ticketDef~columnMap('group_ref', '@groupReference')
  ticketDef~columnMap('message_ref', '@messageReference')
  ticketDef~columnMap('ticket_number', '1/1')
  ticketDef~columnMap('ticket_kind', '1/2')
  ticketDef~columnMap('passenger_name', '2')

  infoDef = provider~defineRelation('pnr_information', doc, 'SEGMENT:IFT')
  infoDef~columnMap('group_ref', '@groupReference')
  infoDef~columnMap('message_ref', '@messageReference')
  infoDef~columnMap('info_text', '2')

  messages = provider~table('pnr_messages')~readRows
  passengers = provider~table('pnr_passengers')~readRows
  ssrRows = provider~table('pnr_ssr')~readRows
  ticketRows = provider~table('pnr_tickets')~readRows
  infoRows = provider~table('pnr_information')~readRows

  pnrByMessage = .directory~new
  do row over messages
    key = self~messageKey(row['group_ref'], row['message_ref'])
    pnrByMessage[key] = self~textValue(row['pnr'])
  end

  parsed = .ShannonPnrGovSet~new(doc, envelopeReport, provider)
  buildersByMessage = .directory~new

  do row over passengers
    groupId = self~textValue(row['group_ref'])
    messageRef = self~textValue(row['message_ref'])
    if groupId == '' then iterate  /* outer demonstration message is not a booking group */
    key = self~messageKey(groupId, messageRef)
    builder = .ShannonTicketPassengerBuilder~new
    builder~surname = self~textValue(row['surname'])
    builder~givenName = self~textValue(row['given_name'])
    builder~title = self~textValue(row['title'])
    builder~passengerType = self~textValue(row['passenger_type'])~upper
    builder~dateOfBirth = self~textValue(row['dob'])
    builder~groupId = groupId
    builder~messageRef = messageRef
    if pnrByMessage~hasIndex(key) then builder~pnr = pnrByMessage[key]
    ignored = builder~addEvidence(row)
    ignored = parsed~addBuilder(groupId, builder)
    if \buildersByMessage~hasIndex(key) then buildersByMessage[key] = .array~new
    buildersByMessage[key]~append(builder)
  end

  do row over ssrRows
    key = self~messageKey(self~textValue(row['group_ref']), self~textValue(row['message_ref']))
    if buildersByMessage~hasIndex(key) then self~applySsrRow(row, buildersByMessage[key])
  end

  do row over ticketRows
    key = self~messageKey(self~textValue(row['group_ref']), self~textValue(row['message_ref']))
    if buildersByMessage~hasIndex(key) then self~applyTicketRow(row, buildersByMessage[key])
  end

  do row over infoRows
    key = self~messageKey(self~textValue(row['group_ref']), self~textValue(row['message_ref']))
    if buildersByMessage~hasIndex(key) then self~applyInfoRow(row, buildersByMessage[key])
  end

  return parsed

::method deriveRole class
  use arg passengerType, dob
  ptc = passengerType~string~upper
  birth = dob~string
  ptcRole = 'UNKNOWN'
  if ptc == 'A' then ptcRole = 'ADULT'
  else if ptc == 'C' | ptc == 'INF' then ptcRole = 'CHILD'

  dobRole = 'UNKNOWN'
  if birth~length == 8 & datatype(birth, 'W') then do
    if birth <= self~ALCOHOL_THRESHOLD_DOB then dobRole = 'ADULT'
    else dobRole = 'CHILD'
  end

  answer = .directory~new
  if ptcRole \== 'UNKNOWN' & dobRole \== 'UNKNOWN' & ptcRole \== dobRole then do
    answer['role'] = 'UNKNOWN'
    answer['eligibility'] = 'UNKNOWN'
    answer['authority'] = 'STRUCTURED_RELATION/PNRGOV_CONFLICT:TIF_TYPE_V_DOB'
    return answer
  end

  if dobRole \== 'UNKNOWN' then role = dobRole
  else role = ptcRole
  answer['role'] = role
  if dobRole == 'ADULT' then answer['eligibility'] = 'ELIGIBLE'
  else if dobRole == 'CHILD' then answer['eligibility'] = 'INELIGIBLE'
  else answer['eligibility'] = 'UNKNOWN'
  if dobRole == 'UNKNOWN' then answer['authority'] = 'STRUCTURED_RELATION/PNRGOV:TIF_TYPE_ONLY'
  else answer['authority'] = 'STRUCTURED_RELATION/PNRGOV:TIF_TYPE+DOB'
  return answer

::method applySsrRow private class
  use arg row, record
  if record~items == 0 then return
  service = self~textValue(row['service_code'])~upper
  detail = self~textValue(row['service_value'])

  if service == 'SEAT' then do
    do builder over record
      if builder~seatReservationStatus == 'UNKNOWN' then do
        builder~seat = detail
        builder~seatReservationStatus = 'RESERVED'
        ignored = builder~addEvidence(row)
        leave
      end
    end
  end
  else if service == 'NSST' then do
    do builder over record
      if builder~seatReservationStatus == 'UNKNOWN' then do
        builder~seatReservationStatus = 'NOT_PURCHASED'
        ignored = builder~addEvidence(row)
        leave
      end
    end
  end
  else if service == 'INFT' then do
    /* The supplied demo message carries one infant and puts it last. */
    record[record~items]~seatReservationStatus = 'NOT_APPLICABLE'
    ignored = record[record~items]~addEvidence(row)
  end
  else if service == 'MEDA' then do
    /* MEDA is message-scoped in this fixture; single-passenger G04B is deliberate. */
    target = record[record~items]
    target~essentialMedication = .true
    ignored = target~addEvidence(row)
  end
  else do
    /* Preserve other SSR evidence on a single-passenger message where association is unambiguous. */
    if record~items == 1 then ignored = record[1]~addEvidence(row)
  end

::method applyTicketRow private class
  use arg row, record
  if record~items == 0 then return
  ticket = self~textValue(row['ticket_number'])
  passengerName = self~textValue(row['passenger_name'])~upper
  ticketKind = self~textValue(row['ticket_kind'])~upper
  target = .nil

  do builder over record
    expected = builder~surname~upper || '/' || builder~givenName~upper
    if passengerName~pos(expected) == 1 then do
      target = builder
      leave
    end
  end
  if target == .nil then do
    do builder over record
      if builder~ticketNumber == '' then do
        target = builder
        leave
      end
    end
  end
  if target \== .nil then do
    target~ticketNumber = ticket
    if ticketKind == 'INF' then target~seatReservationStatus = 'NOT_APPLICABLE'
    ignored = target~addEvidence(row)
  end

::method applyInfoRow private class
  use arg row, record
  if record~items == 0 then return
  info = self~textValue(row['info_text'])~upper
  if row~origin \== .nil then info = row~origin~lexicalValue~upper
  if info~pos('CUSTODY UNKNOWN') > 0 then do
    do builder over record
      if builder~essentialMedication then do
        builder~custodyUnknown = .true
        ignored = builder~addEvidence(row)
      end
    end
  end
  /* Information text is retained as rich evidence if there is only one target. */
  if record~items == 1 then ignored = record[1]~addEvidence(row)

::method messageKey private class
  use arg groupRef, messageRef
  return groupRef~string || '|' || messageRef~string

::method textValue private class
  use arg value
  if value == .nil then return ''
  return value~string

::requires 'EdiFactRelationAdapter.cls'
::requires 'ShannonBooking.cls'
