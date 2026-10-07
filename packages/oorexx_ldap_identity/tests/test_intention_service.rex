/* dev14 dynamic Intention Service integration. */
dir=.IdentityDirectory~new("peer-a")
ignore=.LdapIdentityTest~assert(dir~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"seed Alice")
ops=.DirectoryIdentityReadIntentionOperations~new(dir)
service=.IntentionService~new
ignore=.LdapIdentityIntentionInstaller~install(service,ops)

d1=service~input("show identity directory status")
ignore=.LdapIdentityTest~equal("READY",d1~status,"status intention ready")
ignore=.LdapIdentityTest~equal(1,d1~discoveryGeneration,"initial dynamic discovery generation")
r1=service~dispatch(d1)
ignore=.LdapIdentityTest~assert(r1~ok,"status dispatch")
ignore=.LdapIdentityTest~equal(1,r1~value["entryCount"],"status sees current count")

/* Same operational world -> refresh but no semantic discovery generation. */
d2=service~input("show ldap status")
ignore=.LdapIdentityTest~equal(1,d2~discoveryGeneration,"unchanged world keeps generation")

/* Directory mutation changes the provider revision.  The next input MUST
 * rediscover; there is no startup-only action/evidence catalogue. */
ignore=.LdapIdentityTest~assert(dir~createGroup("group:ops","cn=ops,dc=example,dc=org","Ops")~ok,"add group")
d3=service~input("identity directory status")
ignore=.LdapIdentityTest~equal(2,d3~discoveryGeneration,"directory revision advances discovery generation")
r3=service~dispatch(d3)
ignore=.LdapIdentityTest~equal(2,r3~value["entryCount"],"rediscovered status sees new count")

find=service~input("find identity directory entry principal:alice")
ignore=.LdapIdentityTest~equal("READY",find~status,"find ready")
fr=service~dispatch(find)
ignore=.LdapIdentityTest~assert(fr~ok,"find dispatch")
ignore=.LdapIdentityTest~equal("principal:alice",fr~value~entityId,"find returns authoritative object")

facts=service~evidenceFacts("LDAP_IDENTITY","ENTRY_COUNT")
ignore=.LdapIdentityTest~equal(1,facts~items,"stale discovery evidence replaced")
ignore=.LdapIdentityTest~equal("2",facts[1]~value~string,"current count evidence")

say "LDAP IDENTITY INTENTION DISCOVERY: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapIdentityIntentions.cls"
