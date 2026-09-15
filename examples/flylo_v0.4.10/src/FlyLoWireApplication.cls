/* FlyLo's authoritative stateful Wire UI application.
   Browser semantic actions are revalidated by WireUIApplication before reaching
   this class. Business state remains in FlyLo services; browser identities are
   never accepted as price/booking authority. */
::class FlyLoWireApplication subclass WireUIApplication public
::method init
  expose actionController assistant offersById passengerCount saleId passengerNames manageWorkspaceBookings
  use arg applicationId, sessionId, accessPointId, view, projection, controllerArg, assistantArg=.nil
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  if controllerArg==.nil then raise syntax 88.900 array("FLYLO_ACTION_CONTROLLER_REQUIRED")
  actionController=controllerArg
  assistant=assistantArg
  offersById=.table~new
  passengerCount=1
  saleId=""
  passengerNames=.array~new
  manageWorkspaceBookings=.table~new

::method installInitialView
  v=self~view
  shell=.table~new; shell["visible"]=.true
  call must v~createInstance("root","FLYLO_APP_SHELL@1",shell)

  search=.table~new
  search["origin"]="PIK"; search["destination"]="EWR"; search["date"]="2026-09-01"; search["passengers"]="1"; search["visible"]=.true; search["action"]="FLIGHT.SEARCH"
  call must v~createInstance("search","FLYLO_SEARCH_FORM@2",search,"root")
  v~setActionAvailable("search","FLIGHT.SEARCH",.true)

  trigger=.table~new; trigger["label"]="Ask FlyLo"; trigger["enabled"]=.true; trigger["visible"]=.true; trigger["action"]="ASSISTANT.OPEN"
  call must v~createInstance("assistant-trigger","FLYLO_ASSISTANT_TRIGGER@1",trigger,"root")
  v~setActionAvailable("assistant-trigger","ASSISTANT.OPEN",.true)

  ask=.table~new; ask["message"]=""; ask["conversationId"]="CHAT-"self~sessionId; ask["answer"]="Ask FlyLo is ready."; ask["visible"]=.false; ask["action"]="ASSISTANT.ASK"
  call must v~createInstance("assistant","FLYLO_ASSISTANT@2",ask,"root")
  v~setActionAvailable("assistant","ASSISTANT.ASK",.true)

  offers=.table~new; offers["offers"]=.array~new; offers["visible"]=.false; offers["action"]="FLIGHT.SELECT"
  call must v~createInstance("offers","FLYLO_OFFER_CARDS@2",offers,"root")
  v~setActionAvailable("offers","FLIGHT.SELECT",.true)

  lookup=.table~new; lookup["bookingRef"]=""; lookup["familyName"]=""; lookup["visible"]=.true; lookup["action"]="BOOKING.LOOKUP"
  call must v~createInstance("booking-lookup","FLYLO_BOOKING_LOOKUP@1",lookup,"root")
  v~setActionAvailable("booking-lookup","BOOKING.LOOKUP",.true)

  status=.table~new; status["flightNo"]=""; status["date"]=""; status["visible"]=.true; status["action"]="FLIGHT.STATUS"
  call must v~createInstance("flight-status","FLYLO_FLIGHT_STATUS@1",status,"root")
  v~setActionAvailable("flight-status","FLIGHT.STATUS",.true)

  p=self~projection
  p~bind("assistantVisible","assistant","visible")
  p~bind("assistantAnswer","assistant","answer")
  p~bind("offers","offers","offers")
  p~bind("offersVisible","offers","visible")
  p~bind("searchVisible","search","visible")
  p~bindSlots("manageWorkspace","manage-passengers")
  return .WireUIResult~success(.true,"FLYLO_INITIAL_VIEW_INSTALLED")

::method dispatchSemanticAction
  expose actionController assistant offersById passengerCount saleId passengerNames manageWorkspaceBookings
  use arg action, message
  detail=self~detailOf(message)
  select
    when action="ASSISTANT.OPEN" then do
      return self~mutateState("assistantVisible",.true)
    end
    when action="ASSISTANT.ASK" then do
      question=self~fieldOf(detail,"message","")
      if question="" then return .WireUIResult~failure("FLYLO_ASSISTANT_QUESTION_REQUIRED")
      if assistant==.nil then return .WireUIResult~failure("FLYLO_ASSISTANT_NOT_CONFIGURED")
      reply=assistant~explain(question,self~assistantOperationalEvidence,self~assistantLegalEvidence)
      if \reply~ok then return .WireUIResult~failure("FLYLO_ASSISTANT_FAILED",reply~detail)
      ignore=self~mutateState("assistantAnswer",reply~text)
      return .WireUIResult~success(reply~text,"FLYLO_ASSISTANT_ANSWERED")
    end
    when action="FLIGHT.SEARCH" then do
      pc=self~fieldOf(detail,"passengers","1")
      if datatype(pc,"W") then passengerCount=pc+0; else passengerCount=1
      if passengerCount<1 then passengerCount=1
      offer=actionController~handle(action,detail)
      id=self~fieldOf(offer,"offerId","")
      if id="" then return .WireUIResult~failure("FLYLO_OFFER_ID_REQUIRED")
      offersById[id]=offer
      evidence=.table~new; evidence["offerId"]=id; evidence["source"]="FLIGHT.SEARCH"
      r=self~advanceJourney("OFFERS","FLIGHT.SEARCH",evidence); if \r~ok then return r
      ignore=self~mutateState("offers",.array~of(self~publicOffer(offer)))
      ignore=self~mutateState("offersVisible",.true)
      ignore=self~mutateState("searchVisible",.false)
      return .WireUIResult~success(id,"FLYLO_OFFERS_READY")
    end
    when action="FLIGHT.SELECT" then do
      id=self~fieldOf(detail,"offerId","")
      if id="" | \offersById~hasIndex(id) then return .WireUIResult~failure("FLYLO_OFFER_NOT_SERVER_OWNED",id)
      selectDetail=.directory~new; selectDetail["offer"]=offersById[id]; selectDetail["passengers"]=passengerCount
      sale=actionController~handle(action,selectDetail)
      saleId=self~fieldOf(sale,"saleId","")
      if saleId="" then return .WireUIResult~failure("FLYLO_SALE_ID_REQUIRED")
      evidence=.table~new; evidence["offerId"]=id; evidence["saleId"]=saleId; evidence["source"]="FLIGHT.SELECT"
      r=self~advanceJourney("PASSENGERS","FLIGHT.SELECT",evidence); if \r~ok then return r
      slots=.table~new; slots["saleId"]=saleId; slots["givenName"]=""; slots["familyName"]=""; slots["email"]=""; slots["visible"]=.true; slots["action"]="PASSENGER.SAVE"
      cr=self~createViewInstance("passengers","FLYLO_PASSENGERS@1",slots,"root"); if \cr~ok then return cr
      self~view~setActionAvailable("passengers","PASSENGER.SAVE",.true)
      ignore=self~mutateState("offersVisible",.false)
      return .WireUIResult~success(saleId,"FLYLO_OFFER_SELECTED")
    end
    when action="PASSENGER.SAVE" then do
      if saleId="" then return .WireUIResult~failure("FLYLO_SALE_NOT_SELECTED")
      passengerList=self~fieldOf(detail,"passengers",.nil)
      if passengerList==.nil then do
        passenger=.directory~new
        passenger["givenName"]=self~fieldOf(detail,"givenName","")
        passenger["familyName"]=self~fieldOf(detail,"familyName","")
        passenger["email"]=self~fieldOf(detail,"email","")
        passengerList=.array~of(passenger)
      end
      if \passengerList~isA(.Array) then return .WireUIResult~failure("FLYLO_PASSENGERS_INVALID")
      passengerNames=.array~new
      do passenger over passengerList
        passengerNames~append(self~fieldOf(passenger,"givenName","")" "self~fieldOf(passenger,"familyName",""))
      end
      d=.directory~new; d["saleId"]=saleId; d["passengers"]=passengerList
      state=actionController~handle(action,d)
      evidence=.table~new; evidence["saleId"]=saleId; evidence["source"]="PASSENGER.SAVE"
      r=self~advanceJourney("EXTRAS","PASSENGER.SAVE",evidence); if \r~ok then return r
      slots=.table~new; slots["saleId"]=saleId; slots["CABIN_BAG"]=.false; slots["CHECKED_BAG"]=.false; slots["SEAT_SELECTION"]=.false; slots["PRIORITY_BOARDING"]=.false; slots["visible"]=.true; slots["action"]="ANCILLARY.SAVE"
      cr=self~createViewInstance("extras","FLYLO_EXTRAS@1",slots,"root"); if \cr~ok then return cr
      self~view~setActionAvailable("extras","ANCILLARY.SAVE",.true)
      return .WireUIResult~success(state,"FLYLO_PASSENGERS_SAVED")
    end
    when action="ANCILLARY.SAVE" then do
      if saleId="" then return .WireUIResult~failure("FLYLO_SALE_NOT_SELECTED")
      sourceChoices=self~fieldOf(detail,"selections",detail)
      choices=.directory~new
      do code over .array~of("CABIN_BAG","CHECKED_BAG","SEAT_SELECTION","PRIORITY_BOARDING")
        choices[code]=self~truth(self~fieldOf(sourceChoices,code,.false))
      end
      d=.directory~new; d["saleId"]=saleId; d["selections"]=choices
      state=actionController~handle(action,d)
      evidence=.table~new; evidence["saleId"]=saleId; evidence["source"]="ANCILLARY.SAVE"
      r=self~advanceJourney("REVIEW","ANCILLARY.SAVE",evidence); if \r~ok then return r
      slots=.table~new; slots["saleId"]=saleId; slots["totalMinor"]=state["totalMinor"]; slots["currency"]="GBP"; slots["termsVersion"]="FLYLO-COC-2026.08.24"; slots["visible"]=.true; slots["action"]="SALE.REVIEW"
      cr=self~createViewInstance("review","FLYLO_REVIEW@1",slots,"root"); if \cr~ok then return cr
      self~view~setActionAvailable("review","SALE.REVIEW",.true)
      return .WireUIResult~success(state,"FLYLO_EXTRAS_SAVED")
    end
    when action="SALE.REVIEW" then do
      if saleId="" then return .WireUIResult~failure("FLYLO_SALE_NOT_SELECTED")
      d=.directory~new; d["saleId"]=saleId; d["termsVersion"]="FLYLO-COC-2026.08.24"
      state=actionController~handle(action,d)
      evidence=.table~new; evidence["saleId"]=saleId; evidence["source"]="SALE.REVIEW"
      r=self~advanceJourney("PAYMENT","SALE.REVIEW",evidence); if \r~ok then return r
      slots=.table~new; slots["saleId"]=saleId; slots["paymentMethodToken"]=""; slots["totalMinor"]=state["totalMinor"]; slots["currency"]="GBP"; slots["visible"]=.true; slots["action"]="PAYMENT.AUTHORIZE"
      cr=self~createViewInstance("payment","FLYLO_PAYMENT@1",slots,"root"); if \cr~ok then return cr
      self~view~setActionAvailable("payment","PAYMENT.AUTHORIZE",.true)
      return .WireUIResult~success(state,"FLYLO_REVIEW_ACCEPTED")
    end
    when action="PAYMENT.AUTHORIZE" then do
      if saleId="" then return .WireUIResult~failure("FLYLO_SALE_NOT_SELECTED")
      token=self~fieldOf(detail,"paymentMethodToken","")
      if token="" then return .WireUIResult~failure("FLYLO_PAYMENT_TOKEN_REQUIRED")
      d=.directory~new; d["saleId"]=saleId; d["paymentMethodToken"]=token
      state=actionController~handle(action,d)
      evidence=.table~new; evidence["saleId"]=saleId; evidence["source"]="PAYMENT.AUTHORIZE"
      r=self~advanceJourney("CONFIRMED","PAYMENT.AUTHORIZE",evidence); if \r~ok then return r
      booking=state["booking"]
      slots=.table~new; slots["saleId"]=saleId; slots["bookingRef"]=booking["bookingRef"]; slots["status"]=booking["status"]; slots["visible"]=.true
      cr=self~createViewInstance("confirmation","FLYLO_BOOKED@1",slots,"root"); if \cr~ok then return cr
      return .WireUIResult~success(state,"FLYLO_BOOKING_CONFIRMED")
    end
    when action="BOOKING.LOOKUP" then do
      booking=actionController~handle(action,detail)
      bookingRef=self~fieldOf(booking,"bookingRef","")
      if bookingRef="" then return .WireUIResult~failure("FLYLO_BOOKING_REF_REQUIRED")
      workspaceRef="BOOKING." || bookingRef || ".PASSENGERS"
      registered=self~registerWorkspace(workspaceRef); if \registered~ok then return registered
      manageWorkspaceBookings[workspaceRef]=booking
      slots=.table~new
      slots["bookingRef"]=bookingRef; slots["workspaceRef"]=workspaceRef; slots["passengers"]=booking["passengers"]
      slots["checkedBagUnitPriceMinor"]=4900; slots["currency"]="GBP"; slots["visible"]=.true; slots["action"]="BOOKING.ADD_CHECKED_BAG"
      if self~view~instance("manage-passengers")==.nil then do
        cr=self~createViewInstance("manage-passengers","FLYLO_MANAGE_PASSENGERS@1",slots,"root"); if \cr~ok then return cr
      end
      else do
        cr=self~mutateState("manageWorkspace",slots); if \cr~ok then return cr
      end
      self~view~setActionAvailable("manage-passengers","BOOKING.ADD_CHECKED_BAG",.true)
      published=self~publishBookingWorkspaceResult(workspaceRef); if \published~ok then return published
      return .WireUIResult~success(self~manageWorkspacePayload(workspaceRef),"FLYLO_BOOKING_WORKSPACE_READY")
    end
    when action="BOOKING.ADD_CHECKED_BAG" then do
      ctx=self~fieldOf(detail,"workspaceContext",.nil)
      if ctx==.nil then return .WireUIResult~failure("WORKSPACE_CONTEXT_REQUIRED")
      workspaceRef=self~fieldOf(ctx,"workspaceRef","")
      if \manageWorkspaceBookings~hasIndex(workspaceRef) then return .WireUIResult~failure("FLYLO_BOOKING_WORKSPACE_NOT_FOUND",workspaceRef)
      selected=self~fieldOf(ctx,"selectedIds",.array~new)
      if selected~items<1 then return .WireUIResult~failure("FLYLO_BOOKING_PASSENGER_SELECTION_REQUIRED")
      quantity=self~fieldOf(detail,"quantity",1)
      if \datatype(quantity,"W") | quantity<1 | quantity>10 then return .WireUIResult~failure("CHECKED_BAG_QUANTITY_INVALID",quantity)
      token=self~fieldOf(detail,"paymentMethodToken","")
      if token="" then return .WireUIResult~failure("FLYLO_PAYMENT_TOKEN_REQUIRED")
      booking=manageWorkspaceBookings[workspaceRef]
      bookingRef=booking["bookingRef"]
      idem="BAG:" || bookingRef || ":S" || ctx["selectionRevision"] || ":Q" || quantity
      d=.directory~new; d["bookingRef"]=bookingRef; d["passengerIds"]=selected; d["quantity"]=quantity; d["paymentMethodToken"]=token; d["idempotencyKey"]=idem
      updated=actionController~handle(action,d)
      manageWorkspaceBookings[workspaceRef]=updated
      slots=.table~new; slots["bookingRef"]=bookingRef; slots["workspaceRef"]=workspaceRef; slots["passengers"]=updated["passengers"]; slots["checkedBagUnitPriceMinor"]=4900; slots["currency"]="GBP"; slots["visible"]=.true; slots["action"]="BOOKING.ADD_CHECKED_BAG"
      sr=self~mutateState("manageWorkspace",slots); if \sr~ok then return sr
      published=self~publishBookingWorkspaceResult(workspaceRef); if \published~ok then return published
      return .WireUIResult~success(self~manageWorkspacePayload(workspaceRef),"FLYLO_CHECKED_BAG_ADDED")
    end
    when action="FLIGHT.STATUS" then do
      state=actionController~handle(action,detail)
      return .WireUIResult~success(state,"FLYLO_FLIGHT_STATUS_READY")
    end
    otherwise return .WireUIResult~failure("FLYLO_WIRE_ACTION_UNSUPPORTED",action)
  end

::method offerById
  expose offersById
  use arg id
  if offersById~hasIndex(id) then return offersById[id]
  return .nil

::method saleSnapshot
  expose actionController
  use arg id
  return actionController~saleStatus(id)

::method setBookingWorkspaceSelection
  expose manageWorkspaceBookings
  use arg workspaceRef, expectedScopeRevision, selectedIds
  if \manageWorkspaceBookings~hasIndex(workspaceRef) then return .WireUIResult~failure("FLYLO_BOOKING_WORKSPACE_NOT_FOUND",workspaceRef)
  booking=manageWorkspaceBookings[workspaceRef]
  valid=.set~new
  do passenger over booking["passengers"]; valid~put(passenger["passengerId"]~string); end
  do id over selectedIds
    if \valid~hasIndex(id~string) then return .WireUIResult~failure("FLYLO_BOOKING_PASSENGER_ID_INVALID",id)
  end
  return self~setWorkspaceSelection(workspaceRef,expectedScopeRevision,selectedIds)

::method setBookingWorkspaceSort
  expose manageWorkspaceBookings
  use arg workspaceRef, sortRef, direction="ASC"
  if \manageWorkspaceBookings~hasIndex(workspaceRef) then return .WireUIResult~failure("FLYLO_BOOKING_WORKSPACE_NOT_FOUND",workspaceRef)
  sorted=self~setWorkspaceSort(workspaceRef,sortRef,direction)
  if \sorted~ok then return sorted
  return self~publishBookingWorkspaceResult(workspaceRef)

::method publishBookingWorkspaceResult private
  expose manageWorkspaceBookings
  use arg workspaceRef
  if \manageWorkspaceBookings~hasIndex(workspaceRef) then return .WireUIResult~failure("FLYLO_BOOKING_WORKSPACE_NOT_FOUND",workspaceRef)
  booking=manageWorkspaceBookings[workspaceRef]
  passengers=booking["passengers"]
  totalBags=0
  do passenger over passengers
    if passenger~hasIndex("checkedBagCount") then totalBags += passenger["checkedBagCount"] + 0
  end
  aggregates=.table~new
  aggregates["passengerCount"]=passengers~items
  aggregates["checkedBagCount"]=totalBags
  asOf=""
  if booking~hasIndex("lastAncillaryService") then do
    svc=booking["lastAncillaryService"]
    if svc<>.nil then if svc~hasIndex("confirmedAt") then asOf=svc["confirmedAt"]~string
  end
  if asOf="" then if booking~hasIndex("confirmedAt") then asOf=booking["confirmedAt"]~string
  return self~publishWorkspaceResult(workspaceRef,passengers~items,aggregates,"FLYLO.BOOKING.ENGINE",asOf)

::method manageWorkspacePayload
  expose manageWorkspaceBookings
  use arg workspaceRef
  if \manageWorkspaceBookings~hasIndex(workspaceRef) then return .nil
  d=.directory~new
  booking=manageWorkspaceBookings[workspaceRef]
  d["bookingRef"]=booking["bookingRef"]; d["status"]=booking["status"]; d["origin"]=booking["origin"]; d["destination"]=booking["destination"]; d["travelDate"]=booking["travelDate"]
  d["passengers"]=booking["passengers"]; d["workspaceContext"]=self~workspaceContext(workspaceRef); d["checkedBagUnitPriceMinor"]=4900; d["currency"]="GBP"; d["source"]=booking["source"]
  if booking~hasIndex("lastAncillaryService") then d["lastAncillaryService"]=booking["lastAncillaryService"]
  do key over .array~of("lastAncillaryFinancialStatus","lastAncillaryCaptureId","lastAncillaryAccountingStatus","lastAncillaryAccountingEntryId")
    if booking~hasIndex(key) then d[key]=booking[key]
  end
  return d

::method publicOffer private
  use arg offer
  d=.directory~new
  do key over .array~of("offerId","flightNo","origin","destination","date","fareMinor","fareGBP","currency","mandatoryChargesIncluded")
    if offer~hasIndex(key) then d[key]=offer[key]
  end
  return d

::method assistantOperationalEvidence private
  expose offersById passengerNames saleId
  text=""
  do id over offersById
    o=offersById[id]
    text ||= "offerId="id" flight="self~fieldOf(o,"flightNo","")" route="self~fieldOf(o,"origin","")"-"self~fieldOf(o,"destination","")" fareMinor="self~fieldOf(o,"fareMinor","")" currency="self~fieldOf(o,"currency","")'; '
  end
  if saleId<>"" then text ||= "saleRef="saleId'; '
  if passengerNames~items>0 then do
    text ||= "passengerNames="
    first=.true
    do name over passengerNames
      if \first then text ||= ", "
      text ||= name
      first=.false
    end
    text ||= '; '
  end
  return text

::method assistantLegalEvidence private
  return "No legal entitlement is inferred from booking or ancillary context. Transactional actions remain outside the assistant boundary."

::method detailOf private
  use arg message
  if message==.nil then return .directory~new
  if message~hasIndex("detail") & message["detail"]\==.nil then return message["detail"]
  return .directory~new

::method fieldOf private
  use arg object,key,default=.nil
  if object==.nil then return default
  if object~hasIndex(key) then return object[key]
  return default

::method truth private
  use arg value
  if value==.nil then return .false
  if value==.true then return .true
  text=value~request("STRING")
  if text==.nil then text=value~string
  text=text~strip~translate
  return text="TRUE" | text="1" | text="YES" | text="ON"

::class FlyLoWireRuntimeFactory public
::method build class
  use arg applicationId, sessionId, accessPointId, actionController, assistant=.nil
  if actionController==.nil then raise syntax 88.900 array("FLYLO_ACTION_CONTROLLER_REQUIRED")
  design=.FlyLoDesignFixture~build
  compiled=.WireUICompiler~new~compile(design["workspace"],design["release"])
  if \compiled~ok then return compiled
  catalogue=.WireUICompiledCatalogue~new(compiled~value)
  view=.WireUIView~new("FlyLo.Booking","root")
  projection=.WireUIProjection~new
  app=.FlyLoWireApplication~new(applicationId,sessionId,accessPointId,view,projection,actionController,assistant)
  bound=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL,"HOME")
  if \bound~ok then return bound
  installed=app~installInitialView
  if \installed~ok then return installed
  return .WireUIResult~success(app,"FLYLO_WIRE_APPLICATION_READY")

::method buildDemo class
  use arg applicationId="FLYLO-APP", sessionId="FLYLO-DEMO", accessPointId="WEB", assistant=.nil
  ops=.FlyLoDemoOperationsAdapter~new(.true)
  pay=.FlyLoDemoPaymentAdapter~new(.true)
  sales=.FlyLoSalesProcess~new(ops,pay)
  controller=.FlyLoActionController~new(sales,ops)
  return self~build(applicationId,sessionId,accessPointId,controller,assistant)

::routine must
  use arg r
  if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r

::requires "WireUIAll.cls"
::requires "WireUICompiledCatalogue.cls"
::requires "FlyLoDesignFixture.cls"
::requires "FlyLoActionController.cls"
::requires "FlyLoGrokAssistant.cls"
