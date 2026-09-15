oldUser = value("JMS_BRIDGE_TEST_USERNAME", , "ENVIRONMENT")
oldPass = value("JMS_BRIDGE_TEST_PASSWORD", , "ENVIRONMENT")
ignore = value("JMS_BRIDGE_TEST_USERNAME", "env-user", "ENVIRONMENT")
ignore = value("JMS_BRIDGE_TEST_PASSWORD", "env-secret", "ENVIRONMENT")

credentials = .JMSBridgeEnvironmentCredentials~new("JMS_BRIDGE_TEST_USERNAME", "JMS_BRIDGE_TEST_PASSWORD")
outcome = credentials~acquire
call assert outcome~ok, "environment credential acquisition"
lease = outcome~value
call assert lease~active, "lease active"
call assert lease~username = "env-user", "username materialized"
call assert lease~password = "env-secret", "password materialized"
call assert lease~retire, "lease retire"
call assert \lease~active, "lease inactive"
call assert lease~username = "", "username unavailable after retire"
call assert lease~password = "", "password unavailable after retire"

config = .JMSBridgeConfig~new
call assert config~initialContextFactory = "com.solacesystems.jndi.SolJNDIInitialContextFactory", "default JNDI factory"

ignore = value("JMS_BRIDGE_TEST_USERNAME", oldUser, "ENVIRONMENT")
ignore = value("JMS_BRIDGE_TEST_PASSWORD", oldPass, "ENVIRONMENT")
say "JMS BRIDGE ENVIRONMENT CREDENTIALS PASS 9"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "JMSQueueBridge.cls"
