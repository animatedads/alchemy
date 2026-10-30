principal=.FakePrincipal~new("principal:alice","PRINCIPAL","ACTIVE")
staff=.FakeGroup~new("group:crm-staff","GROUP","ACTIVE")
staff~addMember("principal:alice")
dir=.FakeDirectory~new
call dir~put principal
call dir~put staff
bindings=.array~of(.OdooRelationshipCRMLdapRoleBinding~new("STAFF","group:crm-staff"))
resolver=.OdooRelationshipCRMLdapActorResolver~new(dir,bindings)

session=.FakeSession~new("ldap-session-1","principal:alice",.true)
r=resolver~resolve(session)
call assertTrue r~ok,"authenticated mapped principal accepted"
call assertEq "principal:alice",r~value~actorId,"semantic LDAP principal is actor id"
call assertEq "STAFF",r~value~actorRole,"explicit group binding selects CRM role"
call assertEq "ldap-session-1",r~value~sessionId,"session attribution retained"

r=resolver~resolve(.FakeSession~new("ldap-session-2","principal:alice",.false))
call assertTrue ~ok,"unauthenticated session refused"
call assertEq "LDAP_AUTHENTICATION_REQUIRED",r~code,"unauthenticated code"

principal~state="DISABLED"
r=resolver~resolve(session)
call assertTrue ~ok,"inactive principal refused"
call assertEq "LDAP_PRINCIPAL_NOT_ACTIVE",r~code,"inactive code"
principal~state="ACTIVE"

other=.FakePrincipal~new("principal:bob","PRINCIPAL","ACTIVE")
call dir~put other
r=resolver~resolve(.FakeSession~new("ldap-session-3","principal:bob",.true))
call assertTrue ~ok,"unbound principal refused"
call assertEq "LDAP_CRM_ROLE_DENIED",r~code,"unbound role code"

say "PASS test_ldap_actor_adapter"
exit 0

::routine assertTrue
  use arg a,l
  if a then raise syntax 88.900 array("ASSERT:" l)
::routine assertEq
  use arg e,a,l
  if e==a then raise syntax 88.900 array("ASSERT:" l "expected="e "actual="a)

::class FakeSession
::attribute sessionId get
::attribute principalId get
::attribute authenticated get
::method init
  expose sessionId principalId authenticated
  use arg sessionId,principalId,authenticated

::class FakePrincipal
::attribute entityId get
::attribute kind get
::attribute state
::method init
  expose entityId kind state
  use arg entityId,kind,state

::class FakeGroup subclass FakePrincipal
::method init
  expose members
  use arg entityId,kind,state
  self~init:super(entityId,kind,state)
  members=.directory~new
::method addMember
  expose members
  use arg id
  members[id]=.true
::method hasMember
  expose members
  use arg id
  return members~hasIndex(id)

::class FakeDirectory
::method init
  expose entries
  entries=.directory~new
::method put
  expose entries
  use arg entry
  entries[entry~entityId]=entry
::method entryById
  expose entries
  use arg id
  return entries~at(id)

::requires "OdooRelationshipCRMLdapActor.cls"
