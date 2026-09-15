provider = .TestSecretProvider~new
call assert provider~put("jms/faa/username", "test-user"), "username fixture"
call assert provider~put("jms/faa/password", "test-secret"), "password fixture"
broker = .SecretBroker~new(provider)
credentials = .JMSBridgeSecretBrokerCredentials~new(broker, "jms/faa/username", "jms/faa/password")

adoption = .AlchemyAdoptionVerifier~verify(credentials, "STANDARD")
call assert adoption~ok, "secret adapter STANDARD adoption"
call assert adoption~warnings~items = 0, "secret adapter adoption has zero warnings"

outcome = credentials~acquire
call assert outcome~ok, "credential acquisition"
lease = outcome~value
call assert lease~active, "bridge credential lease active"
call assert lease~username = "test-user", "username materialized"
call assert lease~password = "test-secret", "password materialized"
call assert broker~activeLeaseCount = 0, "Secret Broker leases retired after handoff"

call assert lease~retire, "bridge credential lease retired"
call assert \lease~active, "bridge credential lease inactive"
call assert lease~username = "", "retired username unavailable"
call assert lease~password = "", "retired password unavailable"

missing = .JMSBridgeSecretBrokerCredentials~new(broker, "jms/faa/username", "jms/faa/missing")~acquire
call assert \missing~ok, "missing password rejected"
call assert missing~code = "JMS_PASSWORD_SECRET_UNAVAILABLE", "missing password code"
call assert broker~activeLeaseCount = 0, "failed pair leaves no active Secret Broker lease"
call assert missing~detail \= "test-secret", "failure detail contains no password"

say "JMS BRIDGE SECRET BROKER CREDENTIALS PASS 16"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "AlchemyAdoption.cls"
::requires "JMSQueueBridgeSecrets.cls"
