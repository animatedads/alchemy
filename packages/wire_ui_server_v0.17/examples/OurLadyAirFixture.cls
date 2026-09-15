/* OurLadyAir booking/search fixture for Wire UI journey and agent-profile acceptance. */
::class OurLadyAirApplication subclass WireUIApplication public
::attribute journey get
::attribute planner get

::method init
  expose journey planner
  use arg applicationId, sessionId, accessPointId, view, projection, journey, planner
  self~init:super(applicationId, sessionId, accessPointId, view, projection)

::method onInteractionProfileChanged
  expose journey planner
  use arg previousProfile, newProfile, message
  if newProfile = .WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED then do
    evidence=.table~new
    evidence["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT
    evidence["messageId"]=message["messageId"]
    r=journey~enter("AI_SEARCH", .WireUIProtocol~INTERACTION_PROFILE_SELECT, evidence)
    if \r~ok then return r
    p=planner~apply(self, journey)
    if \p~ok then return p
    emitted=self~emitJourneyPlan
    if \emitted~ok then return emitted
    return .WireUIResult~success(newProfile, "AI_AGENT_OPTIMISED_PROCESS_SELECTED")
  end
  return .WireUIResult~success(newProfile, "INTERACTION_PROFILE_SELECTED")

::class OurLadyAirFixture public
::method build class
  view=.WireUIView~new("OurLadyAir.Booking", "root")
  root=.table~new; root["visible"]=.true
  ignore=self~must(view~createInstance("root","OLA_BOOKING_ROOT@1",root), "root")
  search=.table~new; search["visible"]=.true; search["action"]="FLIGHT.SEARCH.SUBMIT"
  ignore=self~must(view~createInstance("search","OLA_SEARCH_FORM@1",search,"root"), "search")
  agent=.table~new; agent["visible"]=.false; agent["enabled"]=.true; agent["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT; agent["profile"]=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED
  ignore=self~must(view~createInstance("agentOffer","AI_AGENT_OPTIMISED_PROCESS_OFFER@1",agent,"root"), "agent offer")
  view~setActionAvailable("search","FLIGHT.SEARCH.SUBMIT",.true)

  projection=.WireUIProjection~new
  journey=.WireUIJourneyPlan~new
  journey~defineState("SEARCH", .array~of("UI.SEARCH"), .array~of("UI.FLIGHT_OFFERS","UI.FLIGHT_SELECTION","UI.PASSENGER_DETAILS"), .array~new)
  ignore=self~must(journey~addOnDemand("SEARCH","INSURANCE_TERMS","UI.INSURANCE.TERMS"), "on-demand insurance")
  journey~defineState("FLIGHT_OFFERS", .array~of("UI.FLIGHT_OFFERS"), .array~of("UI.FLIGHT_SELECTION","UI.PASSENGER_DETAILS"), .array~new)
  ignore=self~must(journey~addOnDemand("FLIGHT_OFFERS","INSURANCE_TERMS","UI.INSURANCE.TERMS"), "on-demand insurance offers")
  journey~defineState("AI_SEARCH", .array~of("UI.AGENT.SEARCH"), .array~of("UI.AGENT.OFFERS"), .array~new)
  journey~allowTransition("SEARCH","FLIGHT_OFFERS","FLIGHT.SEARCH.SUBMIT","customer submitted flight search")
  journey~allowTransition("SEARCH","AI_SEARCH",.WireUIProtocol~INTERACTION_PROFILE_SELECT,"explicit agent-optimised process selection")
  ignore=self~must(journey~enter("SEARCH","INITIAL"), "enter search")
  planner=.WireUIDefinitionPlanner~new
  app=.OurLadyAirApplication~new("OLA-APP","OLA-SESSION","OLA-AP",view,projection,journey,planner)
  app~attachJourney(journey,planner)

  defs=.array~of( -
    .WireUIElementDefinition~new("OLA_BOOKING_ROOT","1","PANEL"), -
    .WireUIElementDefinition~new("OLA_SEARCH_FORM","1","FORM","FLIGHT.SEARCH.SUBMIT"), -
    .WireUIElementDefinition~new("AI_AGENT_OPTIMISED_PROCESS_OFFER","1","MODE_SWITCH_OFFER",.WireUIProtocol~INTERACTION_PROFILE_SELECT,"ai_agent_optimised_process"), -
    .WireUIElementDefinition~new("OLA_FLIGHT_OFFER_LIST","1","OFFER_LIST"), -
    .WireUIElementDefinition~new("OLA_FLIGHT_SELECTOR","1","OFFER_SELECTOR","FLIGHT.SELECT"), -
    .WireUIElementDefinition~new("OLA_PASSENGER_DETAILS","1","FORM"), -
    .WireUIElementDefinition~new("OLA_INSURANCE_TERMS","1","DOCUMENT"), -
    .WireUIElementDefinition~new("AGENT_SEARCH_STATE","1","SEMANTIC_RECORD","FLIGHT.SEARCH.SUBMIT"), -
    .WireUIElementDefinition~new("AGENT_OFFER_SET","1","SEMANTIC_COLLECTION","FLIGHT.SELECT") )
  do d over defs; ignore=self~must(app~registerDefinition(d), "definition"); end

  ignore=self~addSub(app,"UI.SEARCH",.array~of("OLA_BOOKING_ROOT@1","OLA_SEARCH_FORM@1","AI_AGENT_OPTIMISED_PROCESS_OFFER@1"),"booking search")
  ignore=self~addSub(app,"UI.FLIGHT_OFFERS",.array~of("OLA_FLIGHT_OFFER_LIST@1"),"flight offers")
  ignore=self~addSub(app,"UI.FLIGHT_SELECTION",.array~of("OLA_FLIGHT_SELECTOR@1"),"flight selection")
  ignore=self~addSub(app,"UI.PASSENGER_DETAILS",.array~of("OLA_PASSENGER_DETAILS@1"),"passenger details")
  ignore=self~addSub(app,"UI.INSURANCE.TERMS",.array~of("OLA_INSURANCE_TERMS@1"),"insurance terms on explicit request")
  ignore=self~addSub(app,"UI.AGENT.SEARCH",.array~of("AGENT_SEARCH_STATE@1"),"agent semantic search projection")
  ignore=self~addSub(app,"UI.AGENT.OFFERS",.array~of("AGENT_OFFER_SET@1"),"agent semantic offer projection")

  p=planner~apply(app,journey)
  ignore=self~must(p,"initial plan")
  bundle=.directory~new; bundle["app"]=app; bundle["journey"]=journey; bundle["planner"]=planner
  return bundle

::method addSub class private
  use arg app,id,defs,purpose
  s=.WireUISubscription~new(id,"1",purpose,"policy:ourladyair")
  do d over defs; ignore=s~addDefinition(d); end
  app~addSubscription(s)
  return s

::method must class private
  use arg result,label
  if result~isA(.WireUIResult) then if \result~ok then raise syntax 88.900 array(label,result~code,result~detail)
  return result

::requires "WireUIAll.cls"
