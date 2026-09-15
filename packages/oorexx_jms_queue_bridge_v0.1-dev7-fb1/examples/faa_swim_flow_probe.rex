/* Activate the configured FAA/SCDS inbound consumer, but receive no message. */
providerUrl = value("FAA_SWIM_JMS_URL", , "ENVIRONMENT")
connectionFactory = value("FAA_SWIM_JMS_CONNECTION_FACTORY", , "ENVIRONMENT")
remoteQueue = value("FAA_SWIM_JMS_QUEUE", , "ENVIRONMENT")
vpn = value("FAA_SWIM_JMS_VPN", , "ENVIRONMENT")
sessionMode = value("FAA_SWIM_JMS_SESSION_MODE", , "ENVIRONMENT")
transportMode = value("FAA_SWIM_JMS_TRANSPORT_MODE", , "ENVIRONMENT")
if sessionMode = "" then sessionMode = "AUTO_ACKNOWLEDGE"
if transportMode = "" then transportMode = "ADMINISTERED"

if providerUrl = "" then call missing "FAA_SWIM_JMS_URL"
if connectionFactory = "" then call missing "FAA_SWIM_JMS_CONNECTION_FACTORY"
if remoteQueue = "" then call missing "FAA_SWIM_JMS_QUEUE"
if vpn = "" then call missing "FAA_SWIM_JMS_VPN"

credentials = .JMSBridgeEnvironmentCredentials~new("FAA_SWIM_JMS_USERNAME", "FAA_SWIM_JMS_PASSWORD")
config = .JMSBridgeConfig~new("faa-swim-flow-probe", "SOLACE", providerUrl, connectionFactory, remoteQueue, "", vpn, "", "", "", "", "queue-admin", .false, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", sessionMode, transportMode)
provider = .JMSBSFProvider~new(config, credentials)
result = provider~probeInboundFlow
if \result~ok then do
  say "JMS FLOW PROBE FAIL" result~code result~detail
  exit 1
end
say "JMS FLOW PROBE PASS" result~code result~detail
exit 0

missing: procedure
  use arg name
  say "JMS FLOW PROBE CONFIG MISSING" name
  exit 2

::requires "JMSQueueBridgeBSF.cls"
