identity=.InstrumentationCodec~identity("alchemy","ldap-identity","peer-a","node-a")
obs=.LdapIdentityInstrumentationSource~new(identity)
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1,"node-a")~ok,"epoch active")
a=.IdentityDirectory~new("peer-a")
b=.IdentityDirectory~new("peer-b")
transport=.MemoryIdentityPeerTransport~new
transport~register("peer-b",.IdentityPeerReceiver~new("peer-b",b,epoch))
coord=.IdentityPeerCoordinator~new(a,epoch,transport,.MemoryIdentityPeerOutbox~new,"node-a",obs)
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"change")
r=coord~multicastChange(a~changesSince(0)[1],1,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r~ok,"replication")
snap=obs~snapshot
ignore=.LdapIdentityTest~assert(snap<>.nil,"mesh snapshot")
ignore=.LdapIdentityTest~assert(snap["samples"]~items>0,"mesh samples emitted")
say "LDAP IDENTITY INSTRUMENTATION MESH: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapIdentityInstrumentation.cls"
