parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
registry=.MessagingPresenceProviderRegistry~new
messaging=.Messaging~new(registry)
presence=.Presence~new(registry)
addresses=.RegisteredMessagingAddressResolver~new
me=.MessagingAddress~new("agent-alpha","example.test")
addresses~register("agent alpha",me)
runtime=.MessagingPresenceIntentionRuntime~new(messaging,presence,addresses,me)
service=.IntentionService~new
.MessagingPresenceIntentionInstaller~install(service,registry,runtime)
decision=service~input("send message to agent beta: hello")
say decision~status
::requires "MessagingPresence.cls"
::requires "MessagingPresenceIntentions.cls"
