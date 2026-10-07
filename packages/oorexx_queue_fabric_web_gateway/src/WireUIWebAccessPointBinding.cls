/*
 * WireUIWebAccessPointBinding.cls
 *
 * Deployment seam between WireUIServer and the Queue Fabric browser gateway.
 * Derives queue names and ownership from the authoritative server/application
 * objects.  It deliberately exposes two views:
 *   - privateEdgeEnvironment(): bridge/gateway process configuration
 *   - browserBootstrap(): browser-safe runtime configuration
 *
 * No Queue Fabric claim token is ever materialised here for browser use.
 */
::class WireUIWebAccessPointBinding public
::attribute inQueue get
::attribute outQueue get
::attribute accessPointId get
::attribute bridgeListener get

::method init
  expose manager server app gatewayPrincipal bridgeToken pathToken moduleUrl siteId bridgeHost bridgePort webSocketPath inQueue outQueue accessPointId bridgeListener provisioned
  use strict arg managerArg, serverArg, appArg, gatewayPrincipalArg, bridgeTokenArg, pathTokenArg, moduleUrlArg, siteIdArg = "WIRE_UI", bridgeHostArg = "127.0.0.1", bridgePortArg = 0, webSocketPathArg = "/wire-ui"
  manager = managerArg
  server = serverArg
  app = appArg
  gatewayPrincipal = gatewayPrincipalArg~string~strip
  bridgeToken = bridgeTokenArg~string
  pathToken = pathTokenArg~string
  moduleUrl = moduleUrlArg~string~strip
  siteId = siteIdArg~string~strip
  bridgeHost = bridgeHostArg~string~strip
  bridgePort = bridgePortArg
  webSocketPath = webSocketPathArg~string~strip
  accessPointId = app~accessPointId
  inQueue = server~directQueueName(accessPointId, "IN")
  outQueue = server~directQueueName(accessPointId, "OUT")
  bridgeListener = .nil
  provisioned = .false
  if manager == .nil | server == .nil | app == .nil then raise syntax 93.906 array("Wire UI gateway binding objects")
  if gatewayPrincipal = "" | bridgeToken = "" | moduleUrl = "" | siteId = "" | bridgeHost = "" | webSocketPath = "" then raise syntax 93.906 array("Wire UI gateway binding configuration")

::method provision
  expose manager server app gatewayPrincipal bridgeToken bridgeHost bridgePort inQueue outQueue bridgeListener provisioned
  if provisioned then return .true
  r = server~provisionAccessPoint(app~accessPointId, gatewayPrincipal)
  if \r~ok then return .false
  backend = .QueueFabricWebGatewayBackend~new(manager, inQueue, outQueue, gatewayPrincipal, bridgeToken)
  bridgeListener = .QueueFabricWebGatewayBridgeListener~new(backend, bridgeHost, bridgePort)
  provisioned = .true
  return .true

::method startBridge
  expose bridgeListener
  if \self~provision then return .false
  if bridgeListener~running then return .true
  result = bridgeListener~serveAsync
  return result \== .false

::method stopBridge
  expose bridgeListener
  if bridgeListener == .nil then return .true
  return bridgeListener~stop

::method privateEdgeEnvironment
  expose app bridgeListener bridgeToken pathToken moduleUrl siteId inQueue webSocketPath
  use strict arg publicGatewayUrl = "", gatewayHost = "127.0.0.1", gatewayPort = 0, bootstrapPath = ""
  if \self~startBridge then return .nil
  if bootstrapPath = "" then bootstrapPath = webSocketPath~strip("T", "/")||"/bootstrap"
  if bootstrapPath~left(1) \= "/" then bootstrapPath = "/"||bootstrapPath
  d = .directory~new
  d["QF_BRIDGE_HOST"] = "127.0.0.1"
  d["QF_BRIDGE_PORT"] = bridgeListener~port~string
  d["QF_BRIDGE_TOKEN"] = bridgeToken
  d["WIRE_UI_INBOUND_QUEUE"] = inQueue
  d["WIRE_UI_GATEWAY_HOST"] = gatewayHost~string
  d["WIRE_UI_GATEWAY_PORT"] = gatewayPort~string
  d["WIRE_UI_GATEWAY_PATH"] = webSocketPath
  d["WIRE_UI_GATEWAY_PATH_TOKEN"] = pathToken
  d["WIRE_UI_BOOTSTRAP_PATH"] = bootstrapPath
  if publicGatewayUrl \= "" then d["WIRE_UI_PUBLIC_GATEWAY_URL"] = publicGatewayUrl~string
  d["WIRE_UI_APPLICATION_ID"] = app~applicationId
  d["WIRE_UI_SESSION_ID"] = app~sessionId
  d["WIRE_UI_ACCESS_POINT_ID"] = app~accessPointId
  d["WIRE_UI_MODULE_URL"] = moduleUrl
  d["WIRE_UI_SITE_ID"] = siteId
  return d

::method browserBootstrap
  expose app moduleUrl siteId inQueue
  use strict arg gatewayUrl
  d=.directory~new
  d["moduleUrl"] = moduleUrl
  d["gatewayUrl"] = gatewayUrl~string
  d["outboundQueue"] = inQueue
  d["siteId"] = siteId
  ownership=.directory~new
  ownership["applicationId"] = app~applicationId
  ownership["sessionId"] = app~sessionId
  ownership["accessPointId"] = app~accessPointId
  d["ownership"] = ownership
  return d

::requires "QueueFabricWebGatewayBridge.cls"
