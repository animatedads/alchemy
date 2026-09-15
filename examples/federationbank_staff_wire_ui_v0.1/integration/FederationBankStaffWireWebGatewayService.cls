/* FederationBank Staff Banking Wire UI <-> Queue Fabric Web Gateway seam. */
::class FederationBankStaffWireWebGatewayBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.wire-web-gateway/0.1"

::class FederationBankStaffWireWebGatewayService public
::attribute server get
::attribute application get
::attribute accessPointId get
::attribute browserPrincipal get
::attribute inboundQueue get
::attribute outboundQueue get

::method init
  expose server application accessPointId browserPrincipal inboundQueue outboundQueue
  use arg manager,topicFabric,applicationArg,accessPointIdArg="WEB",browserPrincipalArg="staff-browser-gateway",adminPrincipal="STAFF_WIRE_ADMIN"
  application=applicationArg
  accessPointId=accessPointIdArg~string~strip~translate
  browserPrincipal=browserPrincipalArg~string~strip
  if application==.nil then raise syntax 88.900 array("FederationBank Staff Wire application required")
  if accessPointId="" | browserPrincipal="" then raise syntax 88.900 array("Staff browser access point configuration required")
  /* Construction-time patches predate the browser revision.  The browser
     starts from UI_HELLO and receives the server-authoritative snapshot. */
  ignore=application~drainOutbound
  server=.WireUIServer~new(manager,topicFabric,adminPrincipal)
  r=server~provisionAccessPoint(accessPointId,browserPrincipal); if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  server~registerApplication(application)
  inboundQueue="WIREUI.IN."||accessPointId
  outboundQueue="WIREUI.OUT."||accessPointId

::method processOne
  expose server application accessPointId browserPrincipal
  r=server~receiveFromAccessPoint(accessPointId,browserPrincipal)
  if \r~ok then return r
  outbound=application~drainOutbound
  do message over outbound
    correlation=""; if message~hasIndex("messageId") then correlation=message["messageId"]
    q=server~enqueueToAccessPoint(accessPointId,message,correlation); if \q~ok then return q
  end
  return .WireUIResult~success(outbound~items,"FB_STAFF_WIRE_WEB_MESSAGE_PROCESSED")

::method processAvailable
  expose server application accessPointId browserPrincipal
  processed=0
  do forever
    r=server~receiveFromAccessPoint(accessPointId,browserPrincipal)
    if \r~ok then do
      if r~code="QUEUE_EMPTY" then leave
      return r
    end
    outbound=application~drainOutbound
    do message over outbound
      q=server~enqueueToAccessPoint(accessPointId,message,""); if \q~ok then return q
    end
    processed+=1
  end
  return .WireUIResult~success(processed,"FB_STAFF_WIRE_WEB_DRAINED")

::requires "WireUIServer.cls"
