/* Federation regulated intermediary Wire UI <-> Queue Fabric Web Gateway seam. */
::class RIDWireWebGatewayBuild public
::constant VERSION "0.5"
::constant API_VERSION "regulated.intermediary.wire-web-gateway/0.5"

::class RIDWireWebGatewayService public
::attribute server get
::attribute application get
::attribute accessPointId get
::attribute browserPrincipal get
::attribute inboundQueue get
::attribute outboundQueue get

::method init
  expose server application accessPointId browserPrincipal inboundQueue outboundQueue
  use arg manager,topicFabric,applicationArg,accessPointIdArg="WEB",browserPrincipalArg="rid-browser-gateway",adminPrincipal="RID_ADMIN"
  application=applicationArg
  accessPointId=accessPointIdArg~string~strip~translate
  browserPrincipal=browserPrincipalArg~string~strip
  if application==.nil then raise syntax 88.900 array("RID Wire application required")
  if accessPointId="" | browserPrincipal="" then raise syntax 88.900 array("RID browser access point configuration required")
  /* Construction-time projection patches predate any browser revision. A new
     web access point begins from UI_HELLO -> authoritative snapshot only. */
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
    correlation=""
    if message~hasIndex("messageId") then correlation=message["messageId"]
    q=server~enqueueToAccessPoint(accessPointId,message,correlation)
    if \q~ok then return q
  end
  return .WireUIResult~success(outbound~items,"RID_WIRE_WEB_MESSAGE_PROCESSED")

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
      q=server~enqueueToAccessPoint(accessPointId,message,"")
      if \q~ok then return q
    end
    processed+=1
  end
  return .WireUIResult~success(processed,"RID_WIRE_WEB_DRAINED")

::requires "WireUIServer.cls"
