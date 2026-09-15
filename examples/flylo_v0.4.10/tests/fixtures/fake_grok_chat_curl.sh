#!/usr/bin/env bash
set -euo pipefail
EXPECTED='FAKE-FLYLO-XAI-SECRET'
header_path=''; response_path=''; config_path=''; request_path=''; url=''
if [[ "$*" == *"$EXPECTED"* ]]; then echo 'secret appeared in argv' >&2; exit 70; fi
while (($#)); do
  case "$1" in
    --dump-header) header_path="$2"; shift 2 ;;
    --output) response_path="$2"; shift 2 ;;
    --config) config_path="$2"; shift 2 ;;
    --data-binary) request_path="${2#@}"; shift 2 ;;
    --proto|--max-time|--request|--header|--max-redirs) shift 2 ;;
    --silent|--show-error) shift ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$header_path" && -n "$response_path" && -n "$config_path" && -n "$request_path" && -n "$url" ]] || exit 71
[[ "$(stat -c '%a' "$config_path")" == "600" ]] || exit 72
grep -Fq "Authorization: Bearer $EXPECTED" "$config_path" || exit 73
grep -Fq '"model":"fixture-model"' "$request_path" || exit 74
# Every passenger-assistant model turn must use xAI strict schema output.
grep -Fq '"response_format"' "$request_path" || { echo 'missing response_format' >&2; exit 75; }
grep -Fq '"type":"json_schema"' "$request_path" || { echo 'not json_schema response_format' >&2; exit 76; }
grep -Fq '"strict":true' "$request_path" || { echo 'structured output is not strict' >&2; exit 79; }
if grep -Fq 'secret@example.com' "$request_path"; then echo 'browser PII leaked to model prompt' >&2; exit 77; fi
if grep -Fq 'tok_super_secret' "$request_path"; then echo 'payment token leaked to model prompt' >&2; exit 78; fi

empty_slots='"origin":"","destination":"","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false'
content=''
if grep -Fq 'FLYLO STRUCTURED LANGUAGE UNDERSTANDING' "$request_path"; then
  grep -Fq 'flylo_assistant_interpretation' "$request_path" || exit 80
  if grep -Fq 'CUSTOMER MESSAGE:\ncan I book 10 tickets to new york' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"","destination":"New York","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":10,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nglasgow on 29 september 2026 one way' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"SEARCH","slots":{"origin":"Glasgow","destination":"","outboundDay":29,"outboundMonth":9,"outboundYear":2026,"monthRelation":"NONE","passengers":0,"tripType":"ONE_WAY","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\ntell me about my booking' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"MANAGE_BOOKING","serviceRequest":"BOOKING_LOOKUP","informationRequest":"NONE","requestAction":"NONE","slots":{'"$empty_slots"'}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nI want to fly to new york' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"","destination":"New York","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\none way please' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"SEARCH","slots":{'"$empty_slots"',"tripType":"ONE_WAY"}}'
    # remove duplicate tripType introduced by convenience template
    content=${content/\"tripType\":\"\",/}
  elif grep -Fq 'CUSTOMER MESSAGE:\nnext month' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"","destination":"","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NEXT_MONTH","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\n29th and 2' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"","destination":"","outboundDay":29,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":2,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nGlasgow to New York' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"Glasgow","destination":"New York","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nI want to book a flight' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"BOOK_JOURNEY","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{'"$empty_slots"'}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nCan I bring a cabin bag?' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"AIRLINE_HELP","serviceRequest":"NONE","informationRequest":"BAGGAGE_RULES","requestAction":"NONE","slots":{'"$empty_slots"'}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nhi, I booked a flight and I need help with it' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"MANAGE_BOOKING","serviceRequest":"BOOKING_LOOKUP","informationRequest":"NONE","requestAction":"NONE","slots":{'"$empty_slots"'}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nI need an extra bag on my flight Tom Dyer, Glasgow to Newark on 29-08' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"MANAGE_BOOKING","serviceRequest":"ADD_CHECKED_BAG","informationRequest":"NONE","requestAction":"NONE","slots":{"origin":"Glasgow","destination":"Newark","outboundDay":29,"outboundMonth":8,"outboundYear":0,"monthRelation":"NONE","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"Dyer","documentCountry":"","travellerAge":0,"companionChildMentioned":false,"tobaccoForCompanion":false}}'
  elif grep -Fq 'my daugher wants the extra bags for our duty free cigarettes' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"CUSTOMS_HELP","serviceRequest":"NONE","informationRequest":"CUSTOMS_TOBACCO","requestAction":"NONE","slots":{"origin":"","destination":"","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":0,"tripType":"","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"","travellerAge":0,"companionChildMentioned":true,"tobaccoForCompanion":true}}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nme and my daughter, one way.  Will I have a problem at migration?  I am columbian' "$request_path"; then
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"TRAVEL_REQUIREMENTS","serviceRequest":"NONE","informationRequest":"IMMIGRATION_ENTRY","requestAction":"NONE","slots":{"origin":"","destination":"","outboundDay":0,"outboundMonth":0,"outboundYear":0,"monthRelation":"NONE","passengers":2,"tripType":"ONE_WAY","returnDay":0,"returnMonth":0,"returnYear":0,"bookingRef":"","familyName":"","documentCountry":"Colombia","travellerAge":0,"companionChildMentioned":true,"tobaccoForCompanion":false}}'
  else
    content='{"schema":"flylo.assistant.interpretation/0.2","intent":"UNKNOWN","serviceRequest":"NONE","informationRequest":"NONE","requestAction":"NONE","slots":{'"$empty_slots"'}}'
  fi
elif grep -Fq 'FLYLO STRUCTURED RESPONSE GENERATION' "$request_path"; then
  grep -Fq 'flylo_assistant_utterance_plan' "$request_path" || exit 81
  if grep -Fq 'CUSTOMER MESSAGE:\ncan I book 10 tickets to new york' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Yes, I can help look for 10 seats to New York, subject to availability. Where are you flying from, what date do you want to travel, and is it one-way or return?","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"COLLECT_LARGE_PARTY_SEARCH_DETAILS","intendedRegister":"HELPFUL","intendedOutcome":"SEARCH_CAN_CONTINUE"}'
  elif grep -Fq '\"operation\":\"SEARCH_UNAVAILABLE\"' "$request_path" || grep -Fq '"operation":"SEARCH_UNAVAILABLE"' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"I could not find an itinerary from Glasgow to New York on 29 September 2026 with 10 seats available together. I can try a different date, departure airport, or party size.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"EXPLAIN_SEARCH_UNAVAILABLE","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_CAN_ADJUST_SEARCH"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\ntell me about my booking' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Of course. Please give me the FlyLo booking reference and the booking surname so I can retrieve the right booking.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"REQUEST_BOOKING_IDENTIFIERS","intendedRegister":"HELPFUL","intendedOutcome":"BOOKING_CAN_BE_RETRIEVED"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nI want to fly to new york' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"I can help with New York. Where are you flying from, what date do you want to travel, how many passengers are travelling, and is it one-way or return?","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"COLLECT_SEARCH_DETAILS","intendedRegister":"HELPFUL","intendedOutcome":"SEARCH_CAN_CONTINUE"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nmy daugher wants the extra bags for our duty free cigarettes over her allowance,  This can be checked bags right?' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Yes, ordinary cigarettes can be carried in checked baggage. But putting them in a checked bag, or buying them duty-free, does not change U.S. customs rules. The CBP guidance supplied to me cites a tobacco personal exemption for adults aged 21+ and a quantity of up to 200 cigarettes in that cited exemption; excess must be declared and can be detained or seized. I do not know your daughter’s age, so I should not count an allowance for her yet. How old is she? I also still need your booking reference to retrieve the booking before FlyLo can continue the extra-bag request.","communicativeAct":"INFORMATION","intendedAct":"EXPLAIN_TOBACCO_BAGGAGE_AND_RESUME_BAG_SERVICE","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_INFORMED_AND_SERVICE_PENDING"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nme and my daughter, one way.  Will I have a problem at migration?  I am columbian' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"I can keep helping with the extra bag; I still need your booking reference to retrieve the booking. On U.S. entry, a Colombian passport is not covered by the Visa Waiver Program in the supplied State Department evidence. FlyLo can check travel documents for carriage, but U.S. authorities decide admission. You will need the appropriate U.S. visa or other valid entry status/document for your circumstances; I cannot predict the border decision.","communicativeAct":"INFORMATION","intendedAct":"EXPLAIN_ENTRY_AND_RESUME_BAG_SERVICE","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_INFORMED_AND_SERVICE_PENDING"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nI need an extra bag on my flight Tom Dyer, Glasgow to Newark on 29-08' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Yes, I can help with the extra checked bag for the Glasgow to Newark journey on 29 August. I have the surname Dyer. I just need the FlyLo booking reference to retrieve the booking before I can continue with the bag request.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"REQUEST_BOOKING_REFERENCE_FOR_BAG","intendedRegister":"HELPFUL","intendedOutcome":"BOOKING_CAN_BE_RETRIEVED"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nhi, I booked a flight and I need help with it' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Of course. I can help with an existing FlyLo booking. Please give me the booking reference and the booking surname so I can retrieve the correct booking.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"REQUEST_BOOKING_IDENTIFIERS","intendedRegister":"HELPFUL","intendedOutcome":"BOOKING_CAN_BE_RETRIEVED"}'
  elif grep -Fq '\"operation\":\"SEARCH\"' "$request_path" || grep -Fq '"operation":"SEARCH"' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"I found a FlyLo itinerary from Glasgow to New York on 29 September 2026 for 2 passengers: GLA to PIK on FL201, then PIK to EWR on FL101. The total fare is GBP 476.00. You can select the itinerary shown to continue.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"PRESENT_FLIGHT_OPTIONS","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_CAN_SELECT"}'
  elif grep -Fq 'CUSTOMER MESSAGE:\nCan I bring a cabin bag?' "$request_path"; then
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"Yes. FlyLo offers a cabin-bag extra; check the displayed price and conditions before you add it.","communicativeAct":"INFORMATION","intendedAct":"EXPLAIN_CABIN_BAG_OPTION","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_INFORMED"}'
  else
    content='{"schema":"flylo.assistant.utterance-plan/0.2","text":"I have kept the details you have already given me. Tell me the remaining detail and I will use it without asking you to repeat anything.","communicativeAct":"SERVICE_RESOLUTION","intendedAct":"COLLECT_MISSING_DETAIL","intendedRegister":"HELPFUL","intendedOutcome":"CUSTOMER_CAN_CONTINUE"}'
  fi
else
  echo 'unexpected prompt mode' >&2
  exit 82
fi

# Validate our fixture itself before putting it in the provider envelope.
printf '%s' "$content" | python3 -m json.tool >/dev/null
escaped=${content//\\/\\\\}
escaped=${escaped//\"/\\\"}
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
printf '%s' "{\"id\":\"fixture-chat-structured\",\"model\":\"fixture-model-actual\",\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"$escaped\"},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":31,\"completion_tokens\":21,\"total_tokens\":52}}" >"$response_path"
