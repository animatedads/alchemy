/* FAA SCDS monitoring bridge.  The default is a non-transacted synchronous
 * AUTO_ACKNOWLEDGE session, matching the tested monitoring profile. Set
 * FAA_SWIM_JMS_SESSION_MODE=CLIENT_ACKNOWLEDGE to defer JMS acknowledgement
 * until after Queue Fabric acceptance when that profile is supported. */
providerUrl = value("FAA_SWIM_JMS_URL", , "ENVIRONMENT")
connectionFactory = value("FAA_SWIM_JMS_CONNECTION_FACTORY", , "ENVIRONMENT")
remoteQueue = value("FAA_SWIM_JMS_QUEUE", , "ENVIRONMENT")
vpn = value("FAA_SWIM_JMS_VPN", , "ENVIRONMENT")
localQueue = value("ALCHEMY_QUEUE", , "ENVIRONMENT")
storeRoot = value("ALCHEMY_QUEUE_STORE", , "ENVIRONMENT")
sessionMode = value("FAA_SWIM_JMS_SESSION_MODE", , "ENVIRONMENT")
transportMode = value("FAA_SWIM_JMS_TRANSPORT_MODE", , "ENVIRONMENT")
if localQueue = "" then localQueue = "FAA.SWIM.AIM_FNS"
if sessionMode = "" then sessionMode = "AUTO_ACKNOWLEDGE"
if transportMode = "" then transportMode = "ADMINISTERED"

credentials = .JMSBridgeEnvironmentCredentials~new("FAA_SWIM_JMS_USERNAME", "FAA_SWIM_JMS_PASSWORD")
config = .JMSBridgeConfig~new("faa-swim", "SOLACE", providerUrl, connectionFactory, remoteQueue, "", vpn, "", "", localQueue, "", "queue-admin", .true, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", sessionMode, transportMode)
codec = .JMSBridgeQueueCodecFactory~newCodec
manager = .ObjectQueueManager~new(storeRoot, codec)
if manager~queue(localQueue) == .nil then do
  made = manager~createQueue(localQueue, "PERMANENT", "FAA-SWIM", 0, "queue-admin")
  if \made~ok then raise syntax 88.900 array(made~code || ":" || made~detail)
end
provider = .JMSBSFProvider~new(config, credentials)
bridge = .JMSQueueBridgeService~new(manager, provider, config)
started = bridge~start
if \started~ok then raise syntax 88.900 array(started~code || ":" || started~detail)

say "FAA SWIM JMS bridge running ->" localQueue "session=" sessionMode "transport=" transportMode
say "Press Ctrl-C to stop."
do forever
  r = bridge~pumpInbound(1000)
  if \r~ok then do
    say .DateTime~new~string r~code r~detail
    call SysSleep 1
  end
end

::requires "JMSQueueBridgeBSF.cls"
