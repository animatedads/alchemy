/* Odoo Relationship CRM projection -> Relationship CRM Service envelopes. */

::class OdooRelationshipCRMServiceAdapter public
::attribute defaultActorId get
::attribute defaultActorRole get
::method init
  expose defaultActorId defaultActorRole
  use arg actorIdArg="ODOO-CRM-BRIDGE", actorRoleArg="SERVICE"
  defaultActorId=actorIdArg~string
  defaultActorRole=actorRoleArg~string~upper
  if defaultActorId="" then defaultActorId="ODOO-CRM-BRIDGE"
  if defaultActorRole="" then defaultActorRole="SERVICE"

::method canonicalToken private
  use strict arg value
  text=value~string~upper
  out=""
  do i=1 to text~length
    c=text~substr(i,1)
    if (c>="A" & c<="Z") | (c>="0" & c<="9") | c="." | c="-" | c="_" | c=":" then out||=c
    else out||="_"
  end
  return out

::method commandId private
  use strict arg commandType, objectId, actorId, actorRole
  return "ODOOCRM:"||self~canonicalToken(commandType)||":"||self~canonicalToken(objectId)||":"||self~canonicalToken(actorId)||":"||self~canonicalToken(actorRole)

::method relationshipOpenEnvelope
  expose defaultActorId defaultActorRole
  use arg relationship, actorId="", actorRole="", correlationId="", causationId="", requestedAt=.nil, replyTo=""
  if relationship==.nil then raise syntax 88.930 array("RelationshipRecord required")
  if actorId="" then actorId=defaultActorId
  if actorRole="" then actorRole=defaultActorRole
  payload=.directory~new
  payload["relationship"]=relationship
  cid=self~commandId("CRM.RELATIONSHIP.OPEN",relationship~relationshipId,actorId,actorRole)
  if correlationId="" then correlationId=relationship~relationshipId
  return .RelationshipCRMServiceEnvelope~new(cid,"CRM.RELATIONSHIP.OPEN",actorId,actorRole,payload,correlationId,causationId,requestedAt,replyTo)

::method interactionRecordEnvelope
  expose defaultActorId defaultActorRole
  use arg interaction, actorId="", actorRole="", correlationId="", causationId="", requestedAt=.nil, replyTo=""
  if interaction==.nil then raise syntax 88.931 array("RelationshipInteractionRef required")
  if actorId="" then actorId=defaultActorId
  if actorRole="" then actorRole=defaultActorRole
  payload=.directory~new
  payload["interaction"]=interaction
  cid=self~commandId("CRM.INTERACTION.RECORD",interaction~interactionId,actorId,actorRole)
  if correlationId="" then correlationId=interaction~sourceRef
  if correlationId="" then correlationId=interaction~interactionId
  if causationId="" then causationId=interaction~sourceRef
  return .RelationshipCRMServiceEnvelope~new(cid,"CRM.INTERACTION.RECORD",actorId,actorRole,payload,correlationId,causationId,requestedAt,replyTo)

::method envelopesForCallProjection
  use arg projection, actorId="", actorRole="", correlationId="", causationId="", requestedAt=.nil, replyTo=""
  if projection==.nil then raise syntax 88.932 array("OdooRelationshipCRMCallProjection required")
  relationship=projection~relationship
  interaction=projection~interaction
  if relationship==.nil then raise syntax 88.933 array("Projection relationship required")
  if interaction==.nil then raise syntax 88.934 array("Projection interaction required")
  if correlationId="" then correlationId=interaction~sourceRef
  if correlationId="" then correlationId=interaction~interactionId
  if causationId="" then causationId=interaction~sourceRef
  out=.array~new
  out~append(self~relationshipOpenEnvelope(relationship,actorId,actorRole,correlationId,causationId,requestedAt,replyTo))
  out~append(self~interactionRecordEnvelope(interaction,actorId,actorRole,correlationId,causationId,requestedAt,replyTo))
  return out

::method envelopesForLdapCallProjection
  use arg projection, actorResolver, ldapSession, correlationId="", causationId="", requestedAt=.nil, replyTo=""
  if actorResolver==.nil then return .OdooRelationshipCRMLdapActorResult~failure("LDAP_ACTOR_RESOLVER_REQUIRED")
  auth=actorResolver~resolve(ldapSession)
  if auth~ok then return auth
  actor=auth~value
  envelopes=self~envelopesForCallProjection(projection,actor~actorId,actor~actorRole,correlationId,causationId,requestedAt,replyTo)
  return .OdooRelationshipCRMLdapActorResult~success(envelopes)

::requires "OdooRelationshipCRMAdapter.cls"
::requires "OdooRelationshipCRMLdapActor.cls"
::requires "RelationshipCRMService.cls"
