/* RFC 2696 codec + association-local paging lifecycle. */
ctrl = .LdapPagingCodec~requestControl(2,"cookie-one",.true)
dec = .LdapPagingCodec~decodeControl(ctrl)
ignore = .LdapIdentityTest~assert(dec["ok"],"paged request control decodes")
ignore = .LdapIdentityTest~equal(2,dec["size"],"paged request size")
ignore = .LdapIdentityTest~equal("cookie-one",dec["cookie"],"paged request cookie")

entries = .array~new
do i = 1 to 5
  a = .LdapAttributeSet~new
  a~add("objectClass","top")
  a~put("uid","u" || i)
  entries~append(.LdapEntry~new("uid=u" || i || ",dc=example,dc=org",a,"principal:u" || i))
end
q = .LdapPagingRegistry~queryKey("native","dc=example,dc=org","SUB","(objectClass=*)",.array~of("uid"),.false,0,0,0)
qOther = .LdapPagingRegistry~queryKey("native","dc=example,dc=org","SUB","(uid=u1)",.array~of("uid"),.false,0,0,0)
reg = .LdapPagingRegistry~new("paging-unit-association")

r1 = reg~page(q,entries,2,"",0)
ignore = .LdapIdentityTest~assert(r1~ok,"first page")
p1 = r1~value
ignore = .LdapIdentityTest~equal(2,p1~entries~items,"first page count")
ignore = .LdapIdentityTest~equal(5,p1~estimatedSize,"first page estimate")
ignore = .LdapIdentityTest~assert(p1~cookie <> "","first page continuation cookie")
c1 = p1~cookie

r2 = reg~page(q,entries,1,c1,0)
ignore = .LdapIdentityTest~assert(r2~ok,"second page with changed page size")
p2 = r2~value
ignore = .LdapIdentityTest~equal(1,p2~entries~items,"second page count")
ignore = .LdapIdentityTest~assert(p2~cookie <> "" & p2~cookie <> c1,"cookie rotates")
c2 = p2~cookie
stale = reg~page(q,entries,1,c1,0)
ignore = .LdapIdentityTest~assert(\stale~ok,"previous cookie invalid after rotation")
ignore = .LdapIdentityTest~equal("LDAP_PAGING_UNRESUMABLE",stale~code,"old cookie code")

abandon = reg~page(q,entries,0,c2,0)
ignore = .LdapIdentityTest~assert(abandon~ok,"size zero abandons sequence")
ignore = .LdapIdentityTest~assert(abandon~value~abandoned,"abandon marked")
ignore = .LdapIdentityTest~equal("",abandon~value~cookie,"abandon closes cookie")
again = reg~page(q,entries,2,c2,0)
ignore = .LdapIdentityTest~assert(\again~ok,"abandoned cookie invalid")

m1 = reg~page(q,entries,2,"",0)
ignore = .LdapIdentityTest~assert(m1~ok,"mismatch seed page")
mismatch = reg~page(qOther,entries,2,m1~value~cookie,0)
ignore = .LdapIdentityTest~assert(\mismatch~ok,"query mismatch refused")
ignore = .LdapIdentityTest~equal("LDAP_PAGING_QUERY_MISMATCH",mismatch~code,"query mismatch code")

bounded = .LdapPagingRegistry~new("bounded",1)
b1 = bounded~page(q,entries,1,"",0)
ignore = .LdapIdentityTest~assert(b1~ok,"bounded first result set")
b2 = bounded~page(qOther,entries,1,"",0)
ignore = .LdapIdentityTest~assert(\b2~ok,"bounded registry refuses excess live result sets")
ignore = .LdapIdentityTest~equal("LDAP_PAGING_TOO_MANY_RESULT_SETS",b2~code,"bounded result-set code")

say "LDAP PAGING: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapPaging.cls"
