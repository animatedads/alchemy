identity=.InstrumentationCodec~identity("alchemy","ldap-identity","peer-a","node-a")
obs=.LdapIdentityInstrumentationSource~new(identity)
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1,"node-a")~ok,"epoch active")
a=.IdentityDirectory~new("peer-a")
b=.IdentityDirectory~new("peer-b")
transport=.MemoryIdentityPeerTransport~new
transport~register("peer-b",.IdentityPeerReceiver~new("peer-b",b,epoch))
outbox=.MemoryIdentityPeerOutbox~new
coord=.IdentityPeerCoordinator~new(a,epoch,transport,outbox,"node-a",obs)
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"change")
r=coord~multicastChange(a~changesSince(0)[1],1,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r~ok,"replication")
loaded=outbox~loadRequests
ignore=.LdapIdentityTest~assert(loaded~ok,"request loaded")
request=loaded~value[1]

events=obs~events
ignore=.LdapIdentityTest~assert(events~items>=3,"replication events emitted")
do event over events
  ignore=.LdapIdentityTest~assert(event["correlation_id"]=request~requestId,"request correlation id preserved")
end

registry=.InstrumentationRegistry~new
registry~register("ldap",obs)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(40)
collectorService=.InstrumentationCollectorService~new(collector)
collectorTransport=.InstrumentationLocalCollectorTransport~new(collectorService,"node-a")
publisher=.InstrumentationPublisher~new("ldap-node-a",service,collectorTransport,"ldap")
receipt=publisher~publish("2026-10-15T08:00:00Z",1792047600)
ignore=.LdapIdentityTest~assert(receipt~ok,"publication accepted")
view=.InstrumentationCorrelationView~new(collector)
group=view~byId(request~requestId)
ignore=.LdapIdentityTest~assert(group<>.nil,"correlation group exists")
ignore=.LdapIdentityTest~assert(group["event_count"]>=3,"request/ack/commit grouped")
ignore=.LdapIdentityTest~assert(group["basis"]="EXPLICIT_CORRELATION_ID","explicit correlation only")
ignore=.LdapIdentityTest~assert(group["causation_edges"]~items>=2,"causation edges retained")
ignore=.LdapIdentityTest~assert(group["context_refs"]~items>=4,"semantic context refs retained")

say "LDAP IDENTITY INSTRUMENTATION CORRELATION: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapIdentityInstrumentation.cls"
::requires "InstrumentationCorrelation.cls"
