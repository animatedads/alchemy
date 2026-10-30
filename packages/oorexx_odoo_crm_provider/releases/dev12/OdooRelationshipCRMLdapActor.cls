/* LDAP-authenticated actor resolution for Relationship CRM service envelopes.
 *
 * This adapter intentionally depends only on the structural contract exposed by
 * oorexx_ldap_identity v0.1-dev22: LdapSession~authenticated/~principalId and
 * IdentityDirectory~entryById plus principal/group state.  It does not require
 * the LDAP package at load time, so core Odoo provider use remains independent.
 *
 * Identity and authorization stay separate.  principalType is never treated as
 * a CRM service role.  Roles are admitted only by explicit principal/group
 * bindings supplied by the application.
 */

::class OdooRelationshipCRMLdapRoleBinding public
::attribute actorRole get
::attribute subjectId get
::method init
  expose actorRole subjectId
  use strict arg actorRoleArg, subjectIdArg
  actorRole=actorRoleArg~string~upper
  subjectId=subjectIdArg~string
  if actorRole="" | subjectId="" then raise syntax 88.950 array("LDAP CRM role binding requires role and subject id")

::class OdooRelationshipCRMActorContext public
::attribute actorId get
::attribute actorRole get
::attribute principalId get
::attribute sessionId get
::method init
  expose actorId actorRole principalId sessionId
  use strict arg actorIdArg, actorRoleArg, principalIdArg="", sessionIdArg=""
  actorId=actorIdArg~string
  actorRole=actorRoleArg~string~upper
  principalId=principalIdArg~string
  sessionId=sessionIdArg~string
  if actorId="" | actorRole="" then raise syntax 88.951 array("CRM actor identity and role required")

::class OdooRelationshipCRMLdapActorResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg, codeArg, detailArg="", valueArg=.nil
  ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method success class
  use strict arg value
  return self~new(.true,"OK","",value)
::method failure class
  use strict arg code, detail=""
  return self~new(.false,code,detail,.nil)

::class OdooRelationshipCRMLdapActorResolver public
::attribute directory get
::attribute bindings get
::method init
  expose directory bindings
  use arg directoryArg, bindingsArg=.nil
  if directoryArg==.nil then raise syntax 88.952 array("IdentityDirectory required")
  directory=directoryArg
  if bindingsArg==.nil then bindings=.array~new
  else bindings=bindingsArg

::method activePrincipal private
  expose directory
  use strict arg principalId
  principal=directory~entryById(principalId)
  if principal==.nil then return .nil
  if principal~kind<>"PRINCIPAL" then return .nil
  if principal~state<>"ACTIVE" then return .nil
  return principal

::method subjectMatches private
  expose directory
  use strict arg principalId, subjectId
  if principalId==subjectId then return .true
  subject=directory~entryById(subjectId)
  if subject==.nil then return .false
  if subject~kind<>"GROUP" then return .false
  if subject~state<>"ACTIVE" then return .false
  if subject~hasMethod("HASMEMBER") then return .false
  return subject~hasMember(principalId)

::method resolve
  expose bindings
  use strict arg session
  if session==.nil then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_AUTHENTICATION_REQUIRED","session missing")
  if session~hasMethod("AUTHENTICATED") | session~hasMethod("PRINCIPALID") then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_SESSION_CONTRACT_REQUIRED")
  if session~authenticated then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_AUTHENTICATION_REQUIRED")
  principalId=session~principalId~string
  if principalId="" then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_PRINCIPAL_REQUIRED")
  principal=self~activePrincipal(principalId)
  if principal==.nil then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_PRINCIPAL_NOT_ACTIVE",principalId)
  do binding over bindings
    if binding==.nil then iterate
    if inding~hasMethod("ACTORROLE") | inding~hasMethod("SUBJECTID") then iterate
    if self~subjectMatches(principalId,binding~subjectId) then do
      sid=""
      if session~hasMethod("SESSIONID") then sid=session~sessionId
      ctx=.OdooRelationshipCRMActorContext~new(principalId,binding~actorRole,principalId,sid)
      return .OdooRelationshipCRMLdapActorResult~success(ctx)
    end
  end
  return .OdooRelationshipCRMLdapActorResult~failure("LDAP_CRM_ROLE_DENIED",principalId)
