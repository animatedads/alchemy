/* FederationBank Merchant Wire UI <-> Queue Fabric Web Gateway seam v0.1.
   Transport only: no Merchant business authority lives here. */
::class FBMerchantWireWebGatewayBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.merchant.wire-web-gateway/0.1"

::class FBMerchantWireWebGatewayService public
::attribute server get
::attribute application get
::attribute accessPointId get
::attribute browserPrincipal get
::attribute inboundQueue get
::attribute outboundQueue get

::method init
  expose server application accessPointId browserPrincipal inboundQueue outboundQueue
  use arg manager,topicFabric,applicationArg,accessPointIdArg="WEB",browserPrincipalArg="merchant-browser-gateway",adminPrincipal="FBM_WIRE_ADMIN"
  application=applicationArg
  accessPointId=accessPointIdArg~string~strip~translate
  browserPrincipal=browserPrincipalArg~string~strip
  if application==.nil then raise syntax 88.900 array("FederationBank Merchant Wire application required")
  if accessPointId="" | browserPrincipal="" then raise syntax 88.900 array("Merchant browser access point configuration required")
  /* Browser starts from UI_HELLO. Do not leak construction-time patches. */
  ignore=application~drainOutbound
  server=.WireUIServer~new(manager,topicFabric,adminPrincipal)
  r=server~provisionAccessPoint(accessPointId,browserPrincipal); if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  server~registerApplication(application)
  inboundQueue="WIREUI.IN."||accessPointId
  outboundQueue="WIREUI.OUT."||accessPointId

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
  return .WireUIResult~success(processed,"FBM_WIRE_WEB_DRAINED")

::requires "WireUIServer.cls"
