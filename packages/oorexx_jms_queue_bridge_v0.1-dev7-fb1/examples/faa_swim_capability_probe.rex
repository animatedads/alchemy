/*
 * Bounded FAA/SCDS inbound capability matrix.  Creates and activates temporary
 * JMS consumers but never calls receive().  The default matrix compares
 * AUTO_ACKNOWLEDGE and CLIENT_ACKNOWLEDGE over ADMINISTERED and GUARANTEED
 * transport.  DIRECT can be included explicitly as a diagnostic control.
 */
providerUrl = value("FAA_SWIM_JMS_URL", , "ENVIRONMENT")
connectionFactory = value("FAA_SWIM_JMS_CONNECTION_FACTORY", , "ENVIRONMENT")
remoteQueue = value("FAA_SWIM_JMS_QUEUE", , "ENVIRONMENT")
vpn = value("FAA_SWIM_JMS_VPN", , "ENVIRONMENT")
includeDirect = value("JMS_FLOW_MATRIX_INCLUDE_DIRECT", , "ENVIRONMENT") = "1"

if providerUrl = "" then call missing "FAA_SWIM_JMS_URL"
if connectionFactory = "" then call missing "FAA_SWIM_JMS_CONNECTION_FACTORY"
if remoteQueue = "" then call missing "FAA_SWIM_JMS_QUEUE"
if vpn = "" then call missing "FAA_SWIM_JMS_VPN"

credentials = .JMSBridgeEnvironmentCredentials~new("FAA_SWIM_JMS_USERNAME", "FAA_SWIM_JMS_PASSWORD")
config = .JMSBridgeConfig~new("faa-swim-capability-probe", "SOLACE", providerUrl, connectionFactory, remoteQueue, "", vpn, "", "", "", "", "queue-admin", .false, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "AUTO_ACKNOWLEDGE", "ADMINISTERED")
provider = .JMSBSFProvider~new(config, credentials)
result = provider~probeInboundCapabilities(includeDirect)
if \result~ok then do
  say "JMS FLOW CAPABILITY PROBE ERROR" result~code result~detail
  exit 1
end

report = result~value
say "JMS FLOW CAPABILITY" report~classification
say "SESSION TRANSPORT RESULT CODE DETAIL"
do row over report~evidence
  if row~ok then outcome = "PASS"
  else outcome = "FAIL"
  say row~sessionMode row~transportMode outcome row~code row~detail
end
if report~preferredEvidence \== .nil then say "PREFERRED" report~preferredSessionMode report~preferredTransportMode
else say "PREFERRED NONE"
say "DISPOSITION" report~operationalDisposition
say "ACTION" report~operatorAction

/* Diagnostic mode always returns the evidence. Deployment/CI callers may ask
 * the same no-receive probe to fail unless a usable flow is actually ready. */
if value("JMS_FLOW_REQUIRE_READY", , "ENVIRONMENT") = "1" then do
  if report~operationalDisposition \= .JMSBridgeOperationalDisposition~READY then exit 3
end
exit 0

missing: procedure
  use arg name
  say "JMS FLOW CAPABILITY CONFIG MISSING" name
  exit 2

::requires "JMSQueueBridgeBSF.cls"
