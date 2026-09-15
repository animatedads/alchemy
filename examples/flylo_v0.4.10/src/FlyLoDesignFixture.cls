/* Wire UI Builder source of truth for the FlyLo public sale journey. */
::class FlyLoDesignFixture public
::method build class
  w=.WireUIDesignWorkspace~new("FlyLo.Website")

  searchSlots=.table~new; searchSlots["origin"]="TEXT"; searchSlots["destination"]="TEXT"; searchSlots["date"]="DATE"; searchSlots["passengers"]="INTEGER"
  offerSlots=.table~new; offerSlots["offerId"]="TEXT"; offerSlots["flightNo"]="TEXT"; offerSlots["fareMinor"]="INTEGER"; offerSlots["currency"]="TEXT"
  passengerSlots=.table~new; passengerSlots["saleId"]="TEXT"; passengerSlots["givenName"]="TEXT"; passengerSlots["familyName"]="TEXT"; passengerSlots["email"]="TEXT"
  extrasSlots=.table~new; extrasSlots["saleId"]="TEXT"; extrasSlots["CABIN_BAG"]="BOOLEAN"; extrasSlots["CHECKED_BAG"]="BOOLEAN"; extrasSlots["SEAT_SELECTION"]="BOOLEAN"; extrasSlots["PRIORITY_BOARDING"]="BOOLEAN"
  reviewSlots=.table~new; reviewSlots["saleId"]="TEXT"; reviewSlots["totalMinor"]="INTEGER"; reviewSlots["currency"]="TEXT"; reviewSlots["termsVersion"]="TEXT"
  paymentSlots=.table~new; paymentSlots["saleId"]="TEXT"; paymentSlots["paymentMethodToken"]="TOKEN"; paymentSlots["totalMinor"]="INTEGER"; paymentSlots["currency"]="TEXT"
  confirmationSlots=.table~new; confirmationSlots["saleId"]="TEXT"; confirmationSlots["bookingRef"]="TEXT"; confirmationSlots["status"]="TEXT"
  lookupSlots=.table~new; lookupSlots["bookingRef"]="TEXT"; lookupSlots["familyName"]="TEXT"
  managePassengerSlots=.table~new; managePassengerSlots["bookingRef"]="TEXT"; managePassengerSlots["workspaceRef"]="TEXT"; managePassengerSlots["passengers"]="COLLECTION"; managePassengerSlots["checkedBagUnitPriceMinor"]="INTEGER"; managePassengerSlots["currency"]="TEXT"
  statusSlots=.table~new; statusSlots["flightNo"]="TEXT"; statusSlots["date"]="DATE"
  shellSlots=.table~new; shellSlots["visible"]="BOOLEAN"
  assistantTriggerSlots=.table~new; assistantTriggerSlots["label"]="TEXT"
  assistantSlots=.table~new; assistantSlots["message"]="TEXT"; assistantSlots["conversationId"]="TEXT"; assistantSlots["answer"]="TEXT"
  rightsSlots=.table~new; rightsSlots["status"]="TEXT"; rightsSlots["obligations"]="COLLECTION"; rightsSlots["traceIdentity"]="TEXT"

  shell=.WireUIVisualComponent~new("APP_SHELL","1","PANEL",shellSlots,.array~of("surface"),.array~new)
  assistantTrigger=.WireUIVisualComponent~new("ASSISTANT_TRIGGER","1","ACTION_BUTTON",assistantTriggerSlots,.array~of("surface","action"),.array~of("SEMANTIC_ACTION"))
  searchForm=.WireUIVisualComponent~new("SEARCH_FORM","2","FORM",searchSlots,.array~of("surface","field","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  cardList=.WireUIVisualComponent~new("OFFER_CARD_LIST","2","OFFER_LIST",offerSlots,.array~of("surface","price","action"),.array~of("SEMANTIC_ACTION"))
  passengerForm=.WireUIVisualComponent~new("PASSENGER_FORM","1","FORM",passengerSlots,.array~of("surface","field","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  extrasForm=.WireUIVisualComponent~new("EXTRAS_FORM","1","CHOICE_LIST",extrasSlots,.array~of("surface","choice","price","action"),.array~of("SEMANTIC_ACTION"))
  reviewPanel=.WireUIVisualComponent~new("ORDER_REVIEW","1","SEMANTIC_RECORD",reviewSlots,.array~of("surface","price","terms","action"),.array~of("SEMANTIC_ACTION"))
  paymentForm=.WireUIVisualComponent~new("PAYMENT_FORM","1","TOKEN_FORM",paymentSlots,.array~of("surface","price","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  confirmation=.WireUIVisualComponent~new("BOOKING_CONFIRMATION","1","SEMANTIC_RECORD",confirmationSlots,.array~of("surface","status"),.array~new)
  compactForm=.WireUIVisualComponent~new("COMPACT_FORM","2","FORM",lookupSlots,.array~of("surface","field","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  managePassengers=.WireUIVisualComponent~new("MANAGE_PASSENGERS","1","SEMANTIC_RECORD",managePassengerSlots,.array~of("surface","collection","selection","action"),.array~of("SEMANTIC_ACTION"))
  chat=.WireUIVisualComponent~new("CHAT_PANEL","1","SEMANTIC_RECORD",assistantSlots,.array~of("surface","message","action"),.array~of("SEMANTIC_ACTION"))
  rights=.WireUIVisualComponent~new("RIGHTS_PANEL","1","SEMANTIC_RECORD",rightsSlots,.array~of("surface","status","evidence"),.array~of("SEMANTIC_ACTION"))
  semantic=.WireUIVisualComponent~new("SEMANTIC_RECORD","2","SEMANTIC_RECORD",searchSlots,.array~new,.array~of("SEMANTIC_ACTION"))
  do x over .array~of(shell,assistantTrigger,searchForm,cardList,passengerForm,extrasForm,reviewPanel,paymentForm,confirmation,compactForm,managePassengers,chat,rights,semantic); call must w~register(x); end

  appShell=.WireUISemanticElement~new("APP_SHELL","1","APP_SHELL",.array~new,.array~new,"PUBLIC")
  assistantOpen=.WireUISemanticElement~new("ASSISTANT_TRIGGER","1","ASSISTANT_TRIGGER",.array~new,.array~of("ASSISTANT.OPEN"),"PUBLIC")
  search=.WireUISemanticElement~new("FLIGHT_SEARCH","2","SEARCH",.array~of("origin","destination","date","passengers"),.array~of("FLIGHT.SEARCH"),"PUBLIC")
  offers=.WireUISemanticElement~new("FLIGHT_OFFERS","2","OFFER_COLLECTION",.array~of("offerId","flightNo","fareMinor","currency"),.array~of("FLIGHT.SELECT"),"PUBLIC")
  passenger=.WireUISemanticElement~new("PASSENGER_DETAILS","1","PASSENGER_COLLECTION",.array~of("saleId","givenName","familyName","email"),.array~of("PASSENGER.SAVE"),"PUBLIC")
  extras=.WireUISemanticElement~new("ANCILLARY_SELECTION","1","ANCILLARY_SELECTION",.array~of("saleId","CABIN_BAG","CHECKED_BAG","SEAT_SELECTION","PRIORITY_BOARDING"),.array~of("ANCILLARY.SAVE"),"PUBLIC")
  review=.WireUISemanticElement~new("ORDER_REVIEW","1","ORDER_REVIEW",.array~of("saleId","totalMinor","currency","termsVersion"),.array~of("SALE.REVIEW"),"PUBLIC")
  payment=.WireUISemanticElement~new("PAYMENT_INTENT","1","PAYMENT_INTENT",.array~of("saleId","paymentMethodToken","totalMinor","currency"),.array~of("PAYMENT.AUTHORIZE"),"PUBLIC")
  booked=.WireUISemanticElement~new("BOOKING_CONFIRMATION","1","BOOKING_CONFIRMATION",.array~of("saleId","bookingRef","status"),.array~new,"PUBLIC")
  booking=.WireUISemanticElement~new("BOOKING_LOOKUP","1","BOOKING_LOOKUP",.array~of("bookingRef","familyName"),.array~of("BOOKING.LOOKUP"),"PUBLIC")
  manageBooking=.WireUISemanticElement~new("MANAGE_PASSENGERS","1","BOOKING_PASSENGER_WORKSPACE",.array~of("bookingRef","workspaceRef","passengers","checkedBagUnitPriceMinor","currency"),.array~of("BOOKING.ADD_CHECKED_BAG"),"PUBLIC")
  status=.WireUISemanticElement~new("FLIGHT_STATUS","1","FLIGHT_STATUS",.array~of("flightNo","date"),.array~of("FLIGHT.STATUS"),"PUBLIC")
  assistant=.WireUISemanticElement~new("CUSTOMER_ASSISTANT","2","ASSISTANT",.array~of("message","conversationId","answer"),.array~of("ASSISTANT.ASK"),"PUBLIC")
  passengerRights=.WireUISemanticElement~new("PASSENGER_RIGHTS","1","LEGAL_EFFECT",.array~of("status","obligations","traceIdentity"),.array~of("RIGHTS.EXPLAIN"),"PUBLIC")
  do x over .array~of(appShell,assistantOpen,search,offers,passenger,extras,review,payment,booked,booking,manageBooking,status,assistant,passengerRights); call must w~register(x); end

  tokens=.table~new
  tokens["brand.pink"]="#ff2d88"; tokens["brand.yellow"]="#ffd61f"; tokens["brand.blue"]="#183b8f"; tokens["brand.ink"]="#10204f"; tokens["surface"]="#ffffff"; tokens["space.unit"]="8"; tokens["radius.control"]="14"; tokens["density"]="comfortable"
  recipes=.table~new; recipes["hero.search"]="brand.hero/search.card"; recipes["utility.card"]="surface.white/card"; recipes["sale.step"]="surface.white/sale.step"; recipes["sale.review"]="surface.white/order.review"; recipes["assistant.panel"]="surface.white/chat"; recipes["rights.panel"]="surface.white/legal-evidence"
  material=.WireUIMaterialSet~new("FLYLO_MATERIAL","2",tokens,recipes); call must w~register(material)

  b=.table~new; b["origin"]="origin"; b["destination"]="destination"; b["date"]="date"; b["passengers"]="passengers"
  bp=.table~new; bp["saleId"]="saleId"; bp["givenName"]="givenName"; bp["familyName"]="familyName"; bp["email"]="email"
  be=.table~new; be["saleId"]="saleId"; be["CABIN_BAG"]="CABIN_BAG"; be["CHECKED_BAG"]="CHECKED_BAG"; be["SEAT_SELECTION"]="SEAT_SELECTION"; be["PRIORITY_BOARDING"]="PRIORITY_BOARDING"
  br=.table~new; br["saleId"]="saleId"; br["totalMinor"]="totalMinor"; br["currency"]="currency"; br["termsVersion"]="termsVersion"
  bpay=.table~new; bpay["saleId"]="saleId"; bpay["paymentMethodToken"]="paymentMethodToken"; bpay["totalMinor"]="totalMinor"; bpay["currency"]="currency"
  bc=.table~new; bc["saleId"]="saleId"; bc["bookingRef"]="bookingRef"; bc["status"]="status"
  ba=.table~new; ba["message"]="message"; ba["conversationId"]="conversationId"; ba["answer"]="answer"
  shellProjection=.WireUIProjectionDesign~new("FLYLO_APP_SHELL","1","HUMAN_VISUAL",appShell~ref,shell~ref,"FLYLO_APP_SHELL","","","",.table~new)
  assistantTriggerProjection=.WireUIProjectionDesign~new("FLYLO_ASSISTANT_TRIGGER","1","HUMAN_VISUAL",assistantOpen~ref,assistantTrigger~ref,"FLYLO_ASSISTANT_TRIGGER","ASSISTANT.OPEN","assistant.panel","assistant.panel",.table~new)
  humanSearch=.WireUIProjectionDesign~new("FLYLO_SEARCH_FORM","2","HUMAN_VISUAL",search~ref,searchForm~ref,"FLYLO_SEARCH_FORM","FLIGHT.SEARCH","hero.search","hero.search",b)
  agentSearch=.WireUIProjectionDesign~new("FLYLO_SEARCH_STATE","2","AI_AGENT_OPTIMISED",search~ref,semantic~ref,"FLYLO_SEARCH_STATE","FLIGHT.SEARCH","","",b)
  humanOffers=.WireUIProjectionDesign~new("FLYLO_OFFER_CARDS","2","HUMAN_VISUAL",offers~ref,cardList~ref,"FLYLO_OFFER_CARDS","FLIGHT.SELECT","sale.step","sale.step")
  humanPassenger=.WireUIProjectionDesign~new("FLYLO_PASSENGERS","1","HUMAN_VISUAL",passenger~ref,passengerForm~ref,"FLYLO_PASSENGERS","PASSENGER.SAVE","sale.step","sale.step",bp)
  humanExtras=.WireUIProjectionDesign~new("FLYLO_EXTRAS","1","HUMAN_VISUAL",extras~ref,extrasForm~ref,"FLYLO_EXTRAS","ANCILLARY.SAVE","sale.step","sale.step",be)
  humanReview=.WireUIProjectionDesign~new("FLYLO_REVIEW","1","HUMAN_VISUAL",review~ref,reviewPanel~ref,"FLYLO_REVIEW","SALE.REVIEW","sale.review","sale.review",br)
  humanPayment=.WireUIProjectionDesign~new("FLYLO_PAYMENT","1","HUMAN_VISUAL",payment~ref,paymentForm~ref,"FLYLO_PAYMENT","PAYMENT.AUTHORIZE","sale.review","sale.review",bpay)
  humanBooked=.WireUIProjectionDesign~new("FLYLO_BOOKED","1","HUMAN_VISUAL",booked~ref,confirmation~ref,"FLYLO_BOOKED","","sale.review","sale.review",bc)
  humanBooking=.WireUIProjectionDesign~new("FLYLO_BOOKING_LOOKUP","1","HUMAN_VISUAL",booking~ref,compactForm~ref,"FLYLO_BOOKING_LOOKUP","BOOKING.LOOKUP","utility.card","utility.card")
  humanManageBooking=.WireUIProjectionDesign~new("FLYLO_MANAGE_PASSENGERS","1","HUMAN_VISUAL",manageBooking~ref,managePassengers~ref,"FLYLO_MANAGE_PASSENGERS","BOOKING.ADD_CHECKED_BAG","utility.card","utility.card")
  humanStatus=.WireUIProjectionDesign~new("FLYLO_FLIGHT_STATUS","1","HUMAN_VISUAL",status~ref,compactForm~ref,"FLYLO_FLIGHT_STATUS","FLIGHT.STATUS","utility.card","utility.card")
  humanAssistant=.WireUIProjectionDesign~new("FLYLO_ASSISTANT","2","HUMAN_VISUAL",assistant~ref,chat~ref,"FLYLO_ASSISTANT","ASSISTANT.ASK","assistant.panel","assistant.panel",ba)
  humanRights=.WireUIProjectionDesign~new("FLYLO_PASSENGER_RIGHTS","1","HUMAN_VISUAL",passengerRights~ref,rights~ref,"FLYLO_PASSENGER_RIGHTS","RIGHTS.EXPLAIN","rights.panel","rights.panel")
  do x over .array~of(shellProjection,assistantTriggerProjection,humanSearch,agentSearch,humanOffers,humanPassenger,humanExtras,humanReview,humanPayment,humanBooked,humanBooking,humanManageBooking,humanStatus,humanAssistant,humanRights); call must w~register(x); end

  j=.WireUIJourneyDesign~new("PUBLIC_BOOKING","2","HOME")
  call must j~defineState("HOME",.array~of("APP_SHELL","FLIGHT_SEARCH","BOOKING_LOOKUP","FLIGHT_STATUS","ASSISTANT_TRIGGER"),.array~of("FLIGHT_OFFERS","MANAGE_PASSENGERS","PASSENGER_RIGHTS","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("OFFERS",.array~of("APP_SHELL","FLIGHT_OFFERS","ASSISTANT_TRIGGER"),.array~of("PASSENGER_DETAILS","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("PASSENGERS",.array~of("APP_SHELL","PASSENGER_DETAILS","ASSISTANT_TRIGGER"),.array~of("ANCILLARY_SELECTION","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("EXTRAS",.array~of("APP_SHELL","ANCILLARY_SELECTION","ASSISTANT_TRIGGER"),.array~of("ORDER_REVIEW","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("REVIEW",.array~of("APP_SHELL","ORDER_REVIEW","ASSISTANT_TRIGGER"),.array~of("PAYMENT_INTENT","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("PAYMENT",.array~of("APP_SHELL","PAYMENT_INTENT","ASSISTANT_TRIGGER"),.array~of("BOOKING_CONFIRMATION","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("CONFIRMED",.array~of("APP_SHELL","BOOKING_CONFIRMATION","ASSISTANT_TRIGGER"),.array~of("BOOKING_LOOKUP","MANAGE_PASSENGERS","CUSTOMER_ASSISTANT"),.array~new)
  call must j~defineState("DISRUPTION",.array~of("APP_SHELL","FLIGHT_STATUS","PASSENGER_RIGHTS","ASSISTANT_TRIGGER"),.array~of("CUSTOMER_ASSISTANT"),.array~new)
  call must j~allowTransition("HOME","OFFERS","FLIGHT.SEARCH","customer submitted flight search")
  call must j~allowTransition("OFFERS","PASSENGERS","FLIGHT.SELECT","customer selected an exact offer")
  call must j~allowTransition("PASSENGERS","EXTRAS","PASSENGER.SAVE","passenger details captured")
  call must j~allowTransition("EXTRAS","REVIEW","ANCILLARY.SAVE","optional extras captured without preselection")
  call must j~allowTransition("REVIEW","PAYMENT","SALE.REVIEW","price and terms accepted")
  call must j~allowTransition("PAYMENT","CONFIRMED","PAYMENT.AUTHORIZE","payment authorised and host booking confirmed")
  call must j~allowTransition("HOME","DISRUPTION","FLIGHT.STATUS","customer checked a disrupted flight")
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("FLYLO_WEB","2026.08.28.4")
  do x over .array~of(shell,assistantTrigger,searchForm,cardList,passengerForm,extrasForm,reviewPanel,paymentForm,confirmation,compactForm,managePassengers,chat,rights,semantic,appShell,assistantOpen,search,offers,passenger,extras,review,payment,booked,booking,manageBooking,status,assistant,passengerRights,material,shellProjection,assistantTriggerProjection,humanSearch,agentSearch,humanOffers,humanPassenger,humanExtras,humanReview,humanPayment,humanBooked,humanBooking,humanManageBooking,humanStatus,humanAssistant,humanRights,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)

  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; d["material"]=material; return d

::routine must
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r
::requires "WireUIBuilderAll.cls"
