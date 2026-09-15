/* Queryable audit projection for OurLadyAir Shannon.
 *
 * The authoritative audit remains the rich object graph held by Queue Fabric.
 * This class builds deliberately scalar NoSQLServer object-table projections
 * for investigation and management queries.  Projection never replaces the
 * source audit object and never mutates governance state.
 */

::class ShannonAuditTurnRow public
::attribute sessionId get
::attribute turnNumber get
::attribute mode get
::attribute hardWorldState get
::attribute salesAllowed get
::attribute modelGrossCents get
::attribute governedGrossCents get
::attribute permittedCount get
::attribute blockedCount get
::attribute legalApiVersion get
::attribute legalGeneration get
::attribute sourceFormat get
::attribute sourceEnvelopeStatus get
::attribute finalText get

::method init
  expose sessionId turnNumber mode hardWorldState salesAllowed modelGrossCents governedGrossCents permittedCount blockedCount legalApiVersion legalGeneration sourceFormat sourceEnvelopeStatus finalText
  use arg audit
  sessionId = audit['sessionId']~string
  turnNumber = audit['turn']
  mode = audit['governance']['mode']~string
  hardWorldState = audit['governance']['hardWorldState']~string
  if audit['governance']['salesAllowed'] then salesAllowed = 1
  else salesAllowed = 0
  modelGrossCents = audit['commercial']['modelGrossCents']
  governedGrossCents = audit['commercial']['governedGrossCents']
  permittedCount = audit['commercial']['permittedCount']
  blockedCount = audit['commercial']['blockedCount']
  legalApiVersion = audit['governance']['legalApiVersion']~string
  legalGeneration = audit['governance']['legalGeneration']~string
  sourceFormat = audit['booking']['sourceFormat']~string
  sourceEnvelopeStatus = audit['booking']['sourceEnvelopeStatus']~string
  finalText = audit['finalText']~string

::class ShannonAuditDecisionRow public
::attribute sessionId get
::attribute turnNumber get
::attribute offerId get
::attribute productId get
::attribute productClass get
::attribute targetPassengerId get
::attribute targetDisplayName get
::attribute targetRole get
::attribute ageRestrictedEligibility get
::attribute seatReservationStatus get
::attribute priceCents get
::attribute legalStatus get
::attribute legalPromotionAuthority get
::attribute hardWorldState get
::attribute hardWorldDisposition get
::attribute hardWorldSelected get
::attribute permitted get
::attribute reason get

::method init
  expose sessionId turnNumber offerId productId productClass targetPassengerId targetDisplayName targetRole ageRestrictedEligibility seatReservationStatus priceCents legalStatus legalPromotionAuthority hardWorldState hardWorldDisposition hardWorldSelected permitted reason
  use arg audit, view
  sessionId = audit['sessionId']~string
  turnNumber = audit['turn']
  offerId = view['offerId']~string
  productId = view['productId']~string
  productClass = view['productClass']~string
  targetPassengerId = view['targetPassengerId']~string
  targetDisplayName = view['targetDisplayName']~string
  targetRole = view['targetRole']~string
  ageRestrictedEligibility = self~textOrUnknown(view['ageRestrictedEligibility'])
  seatReservationStatus = self~textOrUnknown(view['seatReservationStatus'])
  priceCents = view['priceCents']
  legalStatus = view['legalStatus']~string
  legalPromotionAuthority = view['legalPromotionAuthority']~string
  hardWorldState = view['hardWorldState']~string
  hardWorldDisposition = view['hardWorldDisposition']~string
  if view['hardWorldSelected'] then hardWorldSelected = 1
  else hardWorldSelected = 0
  if view['permitted'] then permitted = 1
  else permitted = 0
  reason = view['reason']~string

::method textOrUnknown private
  use arg item
  if item == .nil then return 'UNKNOWN'
  return item~string

::class ShannonAuditCatalog public
::attribute engine get
::attribute turnRows get
::attribute decisionRows get
::attribute indexedCount get

::method init
  expose engine turnRows decisionRows indexedCount
  turnRows = .array~new
  decisionRows = .array~new
  indexedCount = 0
  engine = .ObjectDatabaseEngine~new

  turnMap = .ObjectTableMapping~new('shannon_turns')
  ignored = turnMap~column('session_id', 'VARCHAR', 'sessionId')
  ignored = turnMap~column('turn_number', 'INTEGER', 'turnNumber')
  ignored = turnMap~column('mode', 'VARCHAR', 'mode')
  ignored = turnMap~column('hardworld_state', 'VARCHAR', 'hardWorldState')
  ignored = turnMap~column('sales_allowed', 'INTEGER', 'salesAllowed')
  ignored = turnMap~column('model_gross_cents', 'INTEGER', 'modelGrossCents')
  ignored = turnMap~column('governed_gross_cents', 'INTEGER', 'governedGrossCents')
  ignored = turnMap~column('permitted_count', 'INTEGER', 'permittedCount')
  ignored = turnMap~column('blocked_count', 'INTEGER', 'blockedCount')
  ignored = turnMap~column('legal_api_version', 'VARCHAR', 'legalApiVersion')
  ignored = turnMap~column('legal_generation', 'VARCHAR', 'legalGeneration')
  ignored = turnMap~column('source_format', 'VARCHAR', 'sourceFormat')
  ignored = turnMap~column('source_envelope_status', 'VARCHAR', 'sourceEnvelopeStatus')
  ignored = turnMap~column('final_text', 'VARCHAR', 'finalText')
  if \engine~register('shannon_turns', turnRows, turnMap) then raise syntax 88.900 array('Cannot register Shannon audit turn relation')

  decisionMap = .ObjectTableMapping~new('shannon_offer_decisions')
  ignored = decisionMap~column('session_id', 'VARCHAR', 'sessionId')
  ignored = decisionMap~column('turn_number', 'INTEGER', 'turnNumber')
  ignored = decisionMap~column('offer_id', 'VARCHAR', 'offerId')
  ignored = decisionMap~column('product_id', 'VARCHAR', 'productId')
  ignored = decisionMap~column('product_class', 'VARCHAR', 'productClass')
  ignored = decisionMap~column('target_passenger_id', 'VARCHAR', 'targetPassengerId')
  ignored = decisionMap~column('target_display_name', 'VARCHAR', 'targetDisplayName')
  ignored = decisionMap~column('target_role', 'VARCHAR', 'targetRole')
  ignored = decisionMap~column('age_restricted_eligibility', 'VARCHAR', 'ageRestrictedEligibility')
  ignored = decisionMap~column('seat_reservation_status', 'VARCHAR', 'seatReservationStatus')
  ignored = decisionMap~column('price_cents', 'INTEGER', 'priceCents')
  ignored = decisionMap~column('legal_status', 'VARCHAR', 'legalStatus')
  ignored = decisionMap~column('legal_promotion_authority', 'VARCHAR', 'legalPromotionAuthority')
  ignored = decisionMap~column('hardworld_state', 'VARCHAR', 'hardWorldState')
  ignored = decisionMap~column('hardworld_disposition', 'VARCHAR', 'hardWorldDisposition')
  ignored = decisionMap~column('hardworld_selected', 'INTEGER', 'hardWorldSelected')
  ignored = decisionMap~column('permitted', 'INTEGER', 'permitted')
  ignored = decisionMap~column('reason', 'VARCHAR', 'reason')
  if \engine~register('shannon_offer_decisions', decisionRows, decisionMap) then raise syntax 88.900 array('Cannot register Shannon offer decision relation')

::method indexAudit
  expose turnRows decisionRows indexedCount
  use arg audit
  if audit == .nil then return .false
  turnRows~append(.ShannonAuditTurnRow~new(audit))
  views = audit['commercial']['decisionViews']
  if views \== .nil then do view over views
    decisionRows~append(.ShannonAuditDecisionRow~new(audit, view))
  end
  indexedCount += 1
  return .true

::method query
  expose engine
  use arg sqlText
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method tableNames
  return .array~of('shannon_turns', 'shannon_offer_decisions')

::requires 'NoSQLServer.cls'
