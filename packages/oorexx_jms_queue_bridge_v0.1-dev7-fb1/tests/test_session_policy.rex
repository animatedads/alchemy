base = .array~of("id", "SOLACE", "tcps://example:55443", "CF", "Q", "", "VPN", "", "", "IN", "", "bridge", .true, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory")

auto = .JMSBridgeConfig~new(base[1],base[2],base[3],base[4],base[5],base[6],base[7],base[8],base[9],base[10],base[11],base[12],base[13],base[14],base[15],base[16])
call assert auto~sessionMode = .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE, "AUTO default"
call assert auto~transportMode = .JMSBridgeTransportMode~ADMINISTERED, "administered transport default"

client = .JMSBridgeConfig~new(base[1],base[2],base[3],base[4],base[5],base[6],base[7],base[8],base[9],base[10],base[11],base[12],base[13],base[14],base[15],base[16], "CLIENT_ACKNOWLEDGE", "GUARANTEED")
call assert client~sessionMode = .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE, "client ack accepted"
call assert client~transportMode = .JMSBridgeTransportMode~GUARANTEED, "guaranteed override accepted"

transacted = .JMSBridgeConfig~new(base[1],base[2],base[3],base[4],base[5],base[6],base[7],base[8],base[9],base[10],base[11],base[12],base[13],base[14],base[15],base[16], "TRANSACTED", "ADMINISTERED")
call assert transacted~sessionMode = .JMSBridgeSessionMode~TRANSACTED, "transacted optional"

say "JMS SESSION POLICY PASS 5"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "JMSQueueBridge.cls"
