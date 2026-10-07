parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

registry=.MessagingPresenceProviderRegistry~new
messaging=.Messaging~new(registry)
presence=.Presence~new(registry)

agentA=.MessagingAddress~new("agent-a","example.test","worker-1")
agentB=.MessagingAddress~new("agent-b","example.test")
message=.Message~new("msg-1",agentA,agentB,"TPS report is ready")

say "The application owns Message and MessagingAddress objects."
say "A provider is selected dynamically only when a current offer exists."
say "Current offers:" registry~discover~items

::requires "MessagingPresence.cls"
