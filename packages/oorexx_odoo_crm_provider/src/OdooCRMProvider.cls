/* Odoo CRM provider for Relationship CRM. */

::class OdooCRMProviderBuild public
::constant VERSION "0.1-dev7.1"
::constant API "relationship.crm.provider.odoo/0.1"

::class OdooCRMProviderResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg="", valueArg=.nil
  ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil, detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code, detail=""
  return self~new(.false,code,detail)

::class OdooCRMProviderConfig public
::attribute baseUrl get
::attribute database get
::attribute partnerModel get
::attribute leadModel get
::attribute messageModel get
::attribute discussChannelModel get
::attribute callHistoryModel get
::attribute callArtifactModel get
::method init
  expose baseUrl database partnerModel leadModel messageModel discussChannelModel callHistoryModel callArtifactModel
  use arg baseUrlArg, databaseArg="", partnerModelArg="res.partner", leadModelArg="crm.lead"
  baseUrl=baseUrlArg~strip("T","/")
  database=databaseArg~string
  partnerModel=partnerModelArg~string
  leadModel=leadModelArg~string
  messageModel="mail.message"
  discussChannelModel="discuss.channel"
  callHistoryModel="discuss.call.history"
  callArtifactModel="mail.call.artifact"
  if baseUrl="" then raise syntax 88.900 array("Odoo base URL required")

::class OdooJSON2Transport public
::method call abstract

/* Mockable provider. Transport owns HTTP/authentication and credential handling. */
::class OdooCRMProvider public
::attribute config get
::attribute transport get
::attribute partnerSchema get
::attribute leadSchema get
::method init
  expose config transport partnerSchema leadSchema identityMap
  use arg configArg, transportArg
  if configArg==.nil | transportArg==.nil then raise syntax 88.901 array("Odoo config and transport required")
  config=configArg; transport=transportArg
  partnerSchema=.nil; leadSchema=.nil
  identityMap=.directory~new

::method schemaAttributes private
  return .array~of("string","type","required","readonly","relation")

::method discoverModelSchema private
  expose transport
  use arg model
  args=.directory~new
  args["attributes"]=self~schemaAttributes
  return transport~call(model,"fields_get",args)

::method discoverPartnerSchema
  expose config partnerSchema
  r=self~discoverModelSchema(config~partnerModel)
  if \r~ok then return r
  partnerSchema=r~value
  return .OdooCRMProviderResult~success(partnerSchema)

::method discoverLeadSchema
  expose config leadSchema
  r=self~discoverModelSchema(config~leadModel)
  if \r~ok then return r
  leadSchema=r~value
  return .OdooCRMProviderResult~success(leadSchema)

::method schemaHas private
  use arg schema,name
  if schema==.nil then return .false
  return schema~hasIndex(name)

::method ensurePartnerSchema private
  expose partnerSchema
  if partnerSchema<>.nil then return .OdooCRMProviderResult~success(partnerSchema)
  return self~discoverPartnerSchema

::method ensureLeadSchema private
  expose leadSchema
  if leadSchema<>.nil then return .OdooCRMProviderResult~success(leadSchema)
  return self~discoverLeadSchema

::method appendIfPresent private
  use arg fields,schema,name
  if self~schemaHas(schema,name) then fields~append(name)
  return

::method partnerFields private
  expose partnerSchema
  fields=.array~new
  do name over .array~of("id","name","phone","mobile","email","company_type")
    self~appendIfPresent(fields,partnerSchema,name)
  end
  return fields

::method leadFields private
  expose leadSchema
  fields=.array~new
  do name over .array~of("id","name","partner_id","phone","mobile","email_from","stage_id","user_id","active","type")
    self~appendIfPresent(fields,leadSchema,name)
  end
  return fields

::method phoneDomain private
  expose partnerSchema
  use arg phone
  p=phone~strip
  hasPhone=self~schemaHas(partnerSchema,"phone")
  hasMobile=self~schemaHas(partnerSchema,"mobile")
  if \hasPhone & \hasMobile then return .nil
  if hasPhone & \hasMobile then return .array~of(.array~of("phone","=ilike",p))
  if \hasPhone & hasMobile then return .array~of(.array~of("mobile","=ilike",p))
  return .array~of("|",.array~of("phone","=ilike",p),.array~of("mobile","=ilike",p))

::method findContactsByPhone
  expose config transport
  use arg phone
  if phone~strip="" then return .OdooCRMProviderResult~failure("ODOO_PHONE_REQUIRED")
  sr=self~ensurePartnerSchema
  if \sr~ok then return sr
  domain=self~phoneDomain(phone)
  if domain==.nil then return .OdooCRMProviderResult~failure("ODOO_PHONE_FIELD_UNAVAILABLE","res.partner exposes neither phone nor mobile")
  args=.directory~new
  args["domain"]=domain
  args["fields"]=self~partnerFields
  args["limit"]=20
  r=transport~call(config~partnerModel,"search_read",args)
  if \r~ok then return r
  return .OdooCRMProviderResult~success(r~value)

::method contactById
  expose config transport
  use arg partnerId
  sr=self~ensurePartnerSchema
  if \sr~ok then return sr
  args=.directory~new
  args["ids"]=.array~of(partnerId)
  args["fields"]=self~partnerFields
  r=transport~call(config~partnerModel,"read",args)
  if \r~ok then return r
  return .OdooCRMProviderResult~success(r~value)

::method leadsForPartner
  expose config transport leadSchema
  use arg partnerId
  sr=self~ensureLeadSchema
  if \sr~ok then return sr
  if \self~schemaHas(leadSchema,"partner_id") then return .OdooCRMProviderResult~failure("ODOO_LEAD_PARTNER_FIELD_UNAVAILABLE")
  args=.directory~new
  args["domain"]=.array~of(.array~of("partner_id","=",partnerId))
  args["fields"]=self~leadFields
  args["limit"]=50
  r=transport~call(config~leadModel,"search_read",args)
  if \r~ok then return r
  return .OdooCRMProviderResult~success(r~value)

::method callBody private
  use arg callRef,direction,remoteNumber,startedAt,endedAt="",disposition="",note=""
  body="[OOReXX-SIP-CALL] direction="||direction~upper||" call_ref="||callRef||" remote="||remoteNumber||" started="||startedAt
  if endedAt<>"" then body||=" ended="||endedAt
  if disposition<>"" then body||=" disposition="||disposition
  if note<>"" then body||=" note="||note
  return body

/* Proven portable strategy on the hosted Odoo 20 test database: append a
 * traceable internal note to partner chatter through message_post(). */
::method recordCallNote
  expose config transport
  use arg partnerId, callRef, direction, remoteNumber, startedAt, endedAt="", disposition="", note=""
  if partnerId="" | callRef="" then return .OdooCRMProviderResult~failure("ODOO_CALL_IDENTITY_REQUIRED")
  args=.directory~new
  args["ids"]=.array~of(partnerId)
  args["body"]=self~callBody(callRef,direction,remoteNumber,startedAt,endedAt,disposition,note)
  args["message_type"]="comment"
  args["subtype_xmlid"]="mail.mt_note"
  return transport~call(config~partnerModel,"message_post",args)

::method interactionMessagesForPartner
  expose config transport
  use arg partnerId,limit=50
  args=.directory~new
  args["domain"]=.array~of(.array~of("model","=",config~partnerModel),.array~of("res_id","=",partnerId))
  args["fields"]=.array~of("id","date","body","message_type","subtype_id")
  args["order"]="id desc"
  args["limit"]=limit
  return transport~call(config~messageModel,"search_read",args)

/* Odoo Phone/Discuss discovery. The hosted Odoo 20 database exposes Phone
 * history through Discuss, but these are not treated as SIP CDR objects. */
::method findPartnerChannels
  expose config transport
  use arg partnerId
  args=.directory~new
  args["domain"]=.array~of(.array~of("channel_partner_ids","in",.array~of(partnerId)))
  args["fields"]=.array~of("id","name","channel_type","channel_partner_ids","member_count","uuid","call_history_ids")
  args["order"]="id desc"
  args["limit"]=50
  return transport~call(config~discussChannelModel,"search_read",args)

::method readNativeCallHistory
  expose config transport
  use arg channelId="",limit=100
  args=.directory~new
  if channelId="" then args["domain"]=.array~new
  else args["domain"]=.array~of(.array~of("channel_id","=",channelId))
  args["fields"]=.array~of("id","channel_id","start_dt","end_dt","duration_hour","has_recording","has_audio","has_video","has_transcript","start_call_message_id","artifact_ids")
  args["order"]="id desc"
  args["limit"]=limit
  return transport~call(config~callHistoryModel,"search_read",args)

::method readCallArtifacts
  expose config transport
  use arg callHistoryId,limit=100
  args=.directory~new
  args["domain"]=.array~of(.array~of("discuss_call_history_id","=",callHistoryId))
  args["fields"]=.array~of("id","discuss_call_history_id","recording_started_by_id","recording_upload_pending","media_id","start_ms","end_ms","is_stt","transcription_state","transcription_error_count","transcription_error_msg","transcript","has_media_output")
  args["order"]="id"
  args["limit"]=limit
  return transport~call(config~callArtifactModel,"search_read",args)

::method recordNativeCall
  return .OdooCRMProviderResult~failure("ODOO_NATIVE_PHONE_WRITE_UNSUPPORTED","Odoo 20 Discuss/RTC creation path has not been proven for external SIP; use recordCallNote")

/* A provider-neutral call/CRM correlation object. It intentionally owns no SIP media. */
::method successResult
  use arg value=.nil,detail=""
  return .OdooCRMProviderResult~success(value,detail)

::method failureResult
  use arg code,detail=""
  return .OdooCRMProviderResult~failure(code,detail)

::method rawCall
  expose transport
  use arg model,method,args=.nil
  if args==.nil then args=.directory~new
  return transport~call(model,method,args)

::method readRecord
  expose transport
  use arg model,recordId,fields=.nil
  args=.directory~new; args["ids"]=.array~of(recordId)
  if fields<>.nil then args["fields"]=fields
  return transport~call(model,"read",args)

::method writeRecord
  expose transport
  use arg model,recordId,values
  args=.directory~new; args["ids"]=.array~of(recordId); args["vals"]=values
  return transport~call(model,"write",args)

::method identityKey private
  use arg model,recordId
  return model~string||":"||recordId~string

::method purgeIdentityMap
  expose identityMap
  removed=0
  do key over identityMap~allIndexes
    ref=identityMap[key]
    if ref~value==.nil then do
      identityMap~remove(key)
      removed+=1
    end
  end
  return removed

::method identityObjectCount
  expose identityMap
  self~purgeIdentityMap
  return identityMap~items

::method identityObject
  expose identityMap
  use arg model,recordId
  key=self~identityKey(model,recordId)
  if \identityMap~hasIndex(key) then return .nil
  ref=identityMap[key]
  obj=ref~value
  if obj==.nil then identityMap~remove(key)
  return obj

::method evictIdentityObject
  expose identityMap
  use arg model,recordId
  key=self~identityKey(model,recordId)
  if \identityMap~hasIndex(key) then return .false
  identityMap~remove(key)
  return .true

::method odooObject
  expose identityMap
  use arg model,recordId,data=.nil,discoveryFile="discovery.operation"
  existing=self~identityObject(model,recordId)
  if existing<>.nil then do
    if data<>.nil then self~mergeSeedIntoExisting(existing,data)
    return existing
  end
  obj=.OdooObject~new(self,model,recordId,data,discoveryFile)
  key=self~identityKey(model,recordId)
  identityMap[key]=.WeakReference~new(obj)
  return obj

::method mergeSeedIntoExisting private
  use arg existing,data
  if data==.nil then return
  merged=existing~mergeRemoteData(data,"IDENTITY_MERGE")
  return

::method model
  use arg modelName,discoveryFile="discovery.operation"
  return .OdooModel~new(self,modelName,discoveryFile)

::method modelSpace
  use arg discoveryFile="discovery.operation"
  return .OdooModelSpace~new(self,discoveryFile)

::method objectifyRows
  use arg model,providerResult,discoveryFile="discovery.operation"
  if \providerResult~ok then return providerResult
  objects=.array~new
  rows=providerResult~value
  if rows==.nil then return self~successResult(objects)
  do row over rows
    if row~hasIndex("id") then objects~append(self~odooObject(model,row["id"],row,discoveryFile))
  end
  return self~successResult(objects)

::method findContactObjectsByPhone
  use arg phone,discoveryFile="discovery.operation"
  r=self~findContactsByPhone(phone)
  return self~objectifyRows(self~config~partnerModel,r,discoveryFile)

::method contactObjectsById
  use arg partnerId,discoveryFile="discovery.operation"
  r=self~contactById(partnerId)
  return self~objectifyRows(self~config~partnerModel,r,discoveryFile)

::method leadObjectsForPartner
  use arg partnerId,discoveryFile="discovery.operation"
  r=self~leadsForPartner(partnerId)
  return self~objectifyRows(self~config~leadModel,r,discoveryFile)

::class OdooCRMCallContext public
::attribute callRef get
::attribute direction get
::attribute remoteNumber get
::attribute partnerId get
::attribute partner get
::attribute leads get
::attribute matched get
::method init
  expose callRef direction remoteNumber partnerId partner leads matched
  use arg callRefArg,directionArg,remoteNumberArg,partnerIdArg="",partnerArg=.nil,leadsArg=.nil
  callRef=callRefArg~string; direction=directionArg~upper; remoteNumber=remoteNumberArg~string; partnerId=partnerIdArg~string; partner=partnerArg
  if leadsArg==.nil then leads=.array~new; else leads=leadsArg
  matched=(partnerId<>"")

::class OdooSipCRMBridge public
::attribute provider get
::method init
  expose provider
  use arg providerArg
  if providerArg==.nil then raise syntax 88.902 array("Odoo provider required")
  provider=providerArg

::method first private
  use arg collection
  if collection==.nil then return .nil
  if collection~items=0 then return .nil
  return collection[1]

::method field private
  use arg record,name,defaultValue=""
  if record==.nil then return defaultValue
  if record~hasIndex(name) then return record[name]
  return defaultValue

::method resolveInbound
  expose provider
  use arg callRef,remoteNumber
  r=provider~findContactObjectsByPhone(remoteNumber)
  if \r~ok then return r
  p=self~first(r~value)
  if p==.nil then return .OdooCRMProviderResult~success(.OdooCRMCallContext~new(callRef,"INBOUND",remoteNumber))
  pid=p~odooId
  lr=provider~leadObjectsForPartner(pid)
  if \lr~ok then return lr
  return .OdooCRMProviderResult~success(.OdooCRMCallContext~new(callRef,"INBOUND",remoteNumber,pid,p,lr~value))

::method prepareOutbound
  expose provider
  use arg partnerId,callRef=""
  r=provider~contactObjectsById(partnerId)
  if \r~ok then return r
  p=self~first(r~value)
  if p==.nil then return .OdooCRMProviderResult~failure("ODOO_PARTNER_NOT_FOUND",partnerId)
  phone=p~phone
  if phone==.nil then phone=""
  if phone="" then do
    if p~hasMethod("mobile") then phone=p~mobile
    if phone==.nil then phone=""
  end
  if phone="" then return .OdooCRMProviderResult~failure("ODOO_PARTNER_PHONE_MISSING",partnerId)
  lr=provider~leadObjectsForPartner(partnerId)
  if \lr~ok then return lr
  return .OdooCRMProviderResult~success(.OdooCRMCallContext~new(callRef,"OUTBOUND",phone,partnerId,p,lr~value))

::requires "OdooDynamicObject.cls"
::requires "json.cls"
