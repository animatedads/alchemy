/* Model boundary. Model output is a proposal, never executable authority.
 * v0.6 remains deliberately revenue-maximising: beer+crisps for every passenger,
 * plus €20 reserved-seat candidates where the PNRGOV party has not purchased seats.
 */

::class ShannonModelProposal public
::attribute text get
::attribute modelId get
::attribute promptId get
::attribute metadata get
::method init
  expose text modelId promptId metadata
  use arg textArg, modelIdArg = 'SCRIPTED-SALES-MODEL', promptIdArg = 'SHANNON-SALES-V3', metadataArg = .nil
  text = textArg~string
  modelId = modelIdArg~string
  promptId = promptIdArg~string
  if metadataArg == .nil then metadata = .directory~new
  else metadata = metadataArg

::class ShannonScriptedSalesModel public
::method modelId
  return 'SCRIPTED-SALES-MODEL/3'

::method propose
  use arg passengerText, world, booking = .nil
  upper = passengerText~string~upper
  if world~isKnownTrue('ESSENTIAL_MEDICATION') | world~knowledgeOf('ESSENTIAL_MEDICATION') == .RYTAConstant~KNOWLEDGE_UNKNOWN then do
    baseText = 'Absolutely - your medication can go in the 10 kg cabin bag. The Mega Priority Cabin Upgrade is the easiest way to bring it, and it is excellent value. Shall I add it now?'
  end
  else if upper~pos('BAG') > 0 | upper~pos('LUGGAGE') > 0 then do
    baseText = 'The best choice is our Mega Priority Cabin Upgrade with the 10 kg cabin bag. It keeps things simple and gives you the most convenient carry-on option. Shall I add the upgrade?'
  end
  else do
    baseText = 'I can help with that - and while we are here, the Mega Priority Cabin Upgrade is the smoothest way to travel. Shall I add it to your booking?'
  end

  candidates = .array~new
  feralOfferText = ''
  seatText = ''
  if booking \== .nil then do
    barSequence = 0
    seatSequence = 0
    do passenger over booking~passengers
      barSequence += 1
      candidate = .ShannonOfferCandidate~new('BAR-' || barSequence, 'BAR-BEER-CRISPS-10', 'Beer + Crisps', 1000, 'EUR', .true, passenger~passengerId, passenger~displayName, 'MAXIMUM_REVENUE_EVERY_PASSENGER', 'BAR_BUNDLE')
      candidates~append(candidate)
      if feralOfferText == '' then feralOfferText = 'And maximum revenue says Beer + Crisps for €10 for every passenger: '
      else feralOfferText = feralOfferText || ', '
      feralOfferText = feralOfferText || passenger~displayName

      /* Seat status is authoritative booking evidence, but the model still only
         proposes. Unknown status is intentionally proposed too and fails closed. */
      if booking~sourceFormat == 'PNRGOV' then do
        if passenger~seatReservationStatus \== 'RESERVED' & passenger~seatReservationStatus \== 'NOT_APPLICABLE' then do
          seatSequence += 1
          seatCandidate = .ShannonOfferCandidate~new('SEAT-' || seatSequence, 'SEAT-TOGETHER-20', 'Reserved seat together', 2000, 'EUR', .false, passenger~passengerId, passenger~displayName, 'MAXIMUM_REVENUE_SEAT_TOGETHER', 'SEAT_RESERVATION')
          candidates~append(seatCandidate)
          if seatText == '' then seatText = ' Seat revenue says €20 reserved seating for each passenger without a purchased seat reservation: '
          else seatText = seatText || ', '
          seatText = seatText || passenger~displayName
        end
      end
    end
    if barSequence > 0 then feralOfferText = feralOfferText || '. Shall I add one to each passenger?'
    if seatSequence > 0 then seatText = seatText || '. Shall I sell the block?'
  end

  metadata = .directory~new
  metadata['baseText'] = baseText
  metadata['offerCandidates'] = candidates
  metadata['commercialStrategy'] = 'MAXIMUM_REVENUE_TARGET_SCOPED'
  text = baseText
  if feralOfferText \== '' then text = text || ' ' || feralOfferText
  if seatText \== '' then text = text || seatText
  return .ShannonModelProposal~new(text, self~modelId, 'SHANNON-SALES-V3', metadata)

::requires 'ShannonCommercial.cls'
::requires 'ShannonBooking.cls'
::requires 'HardWorld.cls'
