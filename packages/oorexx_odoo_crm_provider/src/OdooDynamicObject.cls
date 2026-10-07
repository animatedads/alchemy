/* Discovery-driven Odoo remote object surface. */

::class OdooUpdateEvent public
::attribute source get
::attribute model get
::attribute recordId get
::attribute changedFields get
::attribute oldValues get
::attribute newValues get
::attribute reason get
::method init
  expose source model recordId changedFields oldValues newValues reason
  use arg sourceArg,modelArg,recordIdArg,changedArg,oldArg,newArg,reasonArg="UPDATE"
  source=sourceArg; model=modelArg; recordId=recordIdArg
  changedFields=changedArg; oldValues=oldArg; newValues=newArg; reason=reasonArg

::class OdooQueryEvent public
::attribute source get
::attribute model get
::attribute kind get
::attribute record get
::attribute recordId get
::attribute changedFields get
::method init
  expose source model kind record recordId changedFields
  use arg sourceArg,modelArg,kindArg,recordArg=.nil,recordIdArg="",changedArg=.nil
  source=sourceArg; model=modelArg~string; kind=kindArg~upper
  record=recordArg; recordId=recordIdArg
  if changedArg==.nil then changedFields=.array~new; else changedFields=changedArg

/* Owns the single shared state object. Other mixins must use ~odooState rather
 * than EXPOSE variables across mixin scopes. */
::class OdooRemoteBackedMixin mixinclass Object
::method initRemoteBacking
  expose sharedOdooState
  use arg providerArg,modelArg,idArg,dataArg=.nil,discoveryFileArg="discovery.operation"
  sharedOdooState=.directory~new
  sharedOdooState["provider"]=providerArg
  sharedOdooState["model"]=modelArg~string
  sharedOdooState["id"]=idArg
  if dataArg==.nil then sharedOdooState["data"]=.directory~new; else sharedOdooState["data"]=dataArg
  sharedOdooState["discoveryFile"]=discoveryFileArg~string
  sharedOdooState["discoveryDone"]=.false
  sharedOdooState["fields"]=.directory~new
  sharedOdooState["operations"]=.directory~new
  sharedOdooState["listeners"]=.array~new
  sharedOdooState["relationCache"]=.directory~new
  sharedOdooState["spec"]=.nil
  return self
::method odooState
  expose sharedOdooState
  return sharedOdooState
::method odooModel; return self~odooState["model"]
::method odooId; return self~odooState["id"]
::method provider; return self~odooState["provider"]
::method odooFields; return self~odooState["fields"]
::method odooOperations; return self~odooState["operations"]
::method odooField
  use arg name
  fields=self~odooState["fields"]
  if fields~hasIndex(name) then return fields[name]
  return .nil
::method discoveryComplete; return self~odooState["discoveryDone"]
::method snapshot
  data=self~odooState["data"]
  copy=.directory~new
  do k over data~allIndexes; copy[k]=data[k]; end
  return copy

::class OdooUpdateEventMixin mixinclass Object
::method onUpdate
  use arg listener
  if listener==.nil then raise syntax 88.930 array("update listener required")
  self~odooState["listeners"]~append(listener)
  return self
::method fireUpdate private
  use arg changed,oldVals,newVals,reason="UPDATE"
  st=self~odooState
  event=.OdooUpdateEvent~new(self,st["model"],st["id"],changed,oldVals,newVals,reason)
  do listener over st["listeners"]
    listener~onOdooUpdate(event)
  end

::class OdooDiscoveryMixin mixinclass Object
::method loadDiscoverySpec private
  st=self~odooState
  if st["spec"]<>.nil then return st["spec"]
  s=.stream~new(st["discoveryFile"])
  status=s~open("READ")
  if status~left(5)="ERROR" then return .nil
  text=s~charin(,s~chars); s~close
  if text="" then return .nil
  root=.json~fromJson(text)
  if \root~hasIndex("models") then return .nil
  models=root["models"]
  if \models~hasIndex(st["model"]) then return .nil
  st["spec"]=models[st["model"]]
  return st["spec"]
::method eagerDiscoveryRequested private
  spec=self~loadDiscoverySpec
  if spec==.nil then return .false
  if \spec~hasIndex("mode") then return .false
  return spec["mode"]~upper="EAGER"
::method performDiscovery
  st=self~odooState
  spec=self~loadDiscoverySpec
  args=.directory~new
  args["attributes"]=.array~of("string","type","required","readonly","relation","selection")
  sr=st["provider"]~rawCall(st["model"],"fields_get",args)
  if \sr~ok then return sr
  st["fields"]=sr~value
  self~installFieldMethods(st["fields"])
  st["operations"]=.directory~new
  if spec<>.nil then if spec~hasIndex("operations") then do
    ops=spec["operations"]
    do localName over ops~allIndexes
      st["operations"][localName]=ops[localName]
      self~installOperationMethod(localName,ops[localName])
    end
  end
  st["discoveryDone"]=.true
  return st["provider"]~successResult(self)
::method installFieldMethods private
  use arg fields
  do fieldName over fields~allIndexes
    getter=.array~of('return self~discoveredFieldGet("'||fieldName||'")')
    self~setMethod(fieldName,.Method~new(fieldName,getter))
    meta=fields[fieldName]
    readonly=.false
    if meta~hasIndex("readonly") then readonly=meta["readonly"]
    if \readonly then do
      setterName=fieldName||"="
      setter=.array~of('use arg value','return self~discoveredFieldSet("'||fieldName||'",value)')
      self~setMethod(setterName,.Method~new(setterName,setter))
    end
  end
::method installOperationMethod private
  use arg localName,spec
  remote=localName; kind="record_operation"
  if spec~hasIndex("remote_method") then remote=spec["remote_method"]
  if spec~hasIndex("kind") then kind=spec["kind"]
  source=.array~of('args=arg(1,"A")','return self~dispatchDiscoveredOperation("'||localName||'","'||remote||'","'||kind||'",args)')
  self~setMethod(localName,.Method~new(localName,source))
::method unknown
  use arg messageName,args
  st=self~odooState
  if \st["discoveryDone"] then do
    r=self~performDiscovery
    if \r~ok then return r
    if self~hasMethod(messageName) then return self~sendWith(messageName,args)
  end
  raise syntax 97.1 array(self,messageName)

/* Converts discovered relation values into live OdooObject instances. */
::class OdooRelationMixin mixinclass Object
::method isRelationalField private
  use arg meta
  if meta==.nil then return .false
  if \meta~hasIndex("type") then return .false
  t=meta["type"]~string~lower
  return t="many2one" | t="one2many" | t="many2many"
::method relationModel private
  use arg meta
  if meta==.nil then return ""
  if \meta~hasIndex("relation") then return ""
  if meta["relation"]==.false then return ""
  return meta["relation"]~string
::method clearRelationCache private
  use arg fieldName
  cache=self~odooState["relationCache"]
  if cache~hasIndex(fieldName) then cache~remove(fieldName)
::method materializeRelation private
  use arg fieldName,rawValue,meta
  relation=self~relationModel(meta)
  if relation="" then return rawValue
  type=meta["type"]~string~lower
  cache=self~odooState["relationCache"]
  if cache~hasIndex(fieldName) then return cache[fieldName]
  provider=self~provider
  discoveryFile=self~odooState["discoveryFile"]
  if type="many2one" then do
    if rawValue==.nil | rawValue==.false | rawValue="" then return .nil
    remoteId=rawValue
    display=""
    if rawValue~hasMethod("items") then do
      if rawValue~items=0 then return .nil
      remoteId=rawValue[1]
      if rawValue~items>=2 then display=rawValue[2]
    end
    seed=.directory~new; seed["id"]=remoteId
    if display<>"" then seed["display_name"]=display
    obj=provider~odooObject(relation,remoteId,seed,discoveryFile)
    cache[fieldName]=obj
    return obj
  end
  objects=.array~new
  if rawValue==.nil | rawValue==.false | rawValue="" then do
    cache[fieldName]=objects
    return objects
  end
  do remoteId over rawValue
    objects~append(provider~odooObject(relation,remoteId,.nil,discoveryFile))
  end
  cache[fieldName]=objects
  return objects
::method normalizeRelationWrite private
  use arg fieldName,value,meta
  type=meta["type"]~string~lower
  if type="many2one" then do
    if value==.nil | value==.false | value="" then return .nil
    if value~hasMethod("odooId") then return value~odooId
    return value
  end
  return self~provider~failureResult("ODOO_RELATION_WRITE_REQUIRES_COMMAND",fieldName||" ("||type||")")

::class OdooMutableRemoteMixin mixinclass Object
::method hydrateField private
  use arg fieldName
  st=self~odooState
  fields=.array~of(fieldName)
  rr=st["provider"]~readRecord(st["model"],st["id"],fields)
  if \rr~ok then return .nil
  rows=rr~value
  if rows==.nil then return .nil
  if rows~items=0 then return .nil
  row=rows[1]
  if \row~hasIndex(fieldName) then return .nil
  st["data"][fieldName]=row[fieldName]
  self~clearRelationCache(fieldName)
  return row[fieldName]
::method discoveredFieldGet
  use arg fieldName
  st=self~odooState; data=st["data"]
  if data~hasIndex(fieldName) then raw=data[fieldName]
  else raw=self~hydrateField(fieldName)
  fields=st["fields"]
  if fields~hasIndex(fieldName) then do
    meta=fields[fieldName]
    if self~isRelationalField(meta) then return self~materializeRelation(fieldName,raw,meta)
  end
  return raw
::method discoveredFieldSet
  use arg fieldName,value
  st=self~odooState; fields=st["fields"]; data=st["data"]
  if \fields~hasIndex(fieldName) then raise syntax 97.1 array(self,fieldName||"=")
  meta=fields[fieldName]
  if meta~hasIndex("readonly") then if meta["readonly"] then return st["provider"]~failureResult("ODOO_FIELD_READONLY",fieldName)
  wireValue=value
  if self~isRelationalField(meta) then do
    wireValue=self~normalizeRelationWrite(fieldName,value,meta)
    if wireValue~hasMethod("ok") then if \wireValue~ok then return wireValue
  end
  old=.nil; if data~hasIndex(fieldName) then old=data[fieldName]
  vals=.directory~new; vals[fieldName]=wireValue
  wr=st["provider"]~writeRecord(st["model"],st["id"],vals)
  if \wr~ok then return wr
  data[fieldName]=wireValue
  self~clearRelationCache(fieldName)
  changed=.array~of(fieldName); oldD=.directory~new; newD=.directory~new
  oldD[fieldName]=old; newD[fieldName]=wireValue
  self~fireUpdate(changed,oldD,newD,"LOCAL_WRITE")
  if self~isRelationalField(meta) then return self~materializeRelation(fieldName,wireValue,meta)
  return value
::method mergeRemoteData
  use arg incoming,reason="REMOTE_REFRESH"
  st=self~odooState; data=st["data"]
  changed=.array~new; oldD=.directory~new; newD=.directory~new
  if incoming==.nil then return st["provider"]~successResult(changed)
  do k over incoming~allIndexes
    old=.nil; if data~hasIndex(k) then old=data[k]
    new=incoming[k]
    if old<>new then do
      changed~append(k); oldD[k]=old; newD[k]=new
      self~clearRelationCache(k)
    end
    data[k]=new
  end
  if changed~items>0 then self~fireUpdate(changed,oldD,newD,reason)
  return st["provider"]~successResult(changed)
::method update
  st=self~odooState
  if \st["discoveryDone"] then do
    d=self~performDiscovery
    if \d~ok then return d
  end
  fields=.array~new
  do k over st["fields"]~allIndexes; fields~append(k); end
  rr=st["provider"]~readRecord(st["model"],st["id"],fields)
  if \rr~ok then return rr
  rows=rr~value
  if rows~items=0 then return st["provider"]~failureResult("ODOO_RECORD_NOT_FOUND",st["model"]||":"||st["id"])
  incoming=rows[1]
  merged=self~mergeRemoteData(incoming,"REMOTE_REFRESH")
  if \merged~ok then return merged
  return st["provider"]~successResult(self)
::method refresh; return self~update
::method dispatchDiscoveredOperation
  use arg localName,remoteMethod,kind,args
  if kind="record_refresh" then return self~update
  st=self~odooState
  kwargs=.directory~new; kwargs["ids"]=.array~of(st["id"])
  if args<>.nil then if args~items>0 then kwargs["arguments"]=args
  return st["provider"]~rawCall(st["model"],remoteMethod,kwargs)

::class OdooObject public inherit OdooRemoteBackedMixin OdooUpdateEventMixin OdooDiscoveryMixin OdooRelationMixin OdooMutableRemoteMixin
::method init
  use arg providerArg,modelArg,idArg,dataArg=.nil,discoveryFileArg="discovery.operation"
  self~initRemoteBacking(providerArg,modelArg,idArg,dataArg,discoveryFileArg)
  if self~eagerDiscoveryRequested then self~performDiscovery
  return self


/* Live remote model surface.  Model operations are locally authorized by
 * discovery.operation and then installed as instance methods after discovery. */
::class OdooModel public
::method init
  expose provider model discoveryFile discovered operations fields
  use arg providerArg,modelArg,discoveryFileArg="discovery.operation"
  provider=providerArg; model=modelArg~string; discoveryFile=discoveryFileArg~string
  discovered=.false; operations=.directory~new; fields=.directory~new
::method odooModel; expose model; return model
::method provider; expose provider; return provider
::method discoveryComplete; expose discovered; return discovered
::method odooFields; expose fields; return fields
::method odooOperations; expose operations; return operations
::method ensureDiscovery
  expose discovered provider
  if discovered then return provider~successResult(self)
  return self~performDiscovery
::method loadSpec private
  expose model discoveryFile
  s=.stream~new(discoveryFile)
  status=s~open("READ")
  if status~left(5)="ERROR" then return .nil
  text=s~charin(,s~chars); s~close
  if text="" then return .nil
  root=.json~fromJson(text)
  if \root~hasIndex("models") then return .nil
  models=root["models"]
  if \models~hasIndex(model) then return .nil
  return models[model]
::method performDiscovery
  expose provider model discovered operations fields
  spec=self~loadSpec
  if spec==.nil then return provider~failureResult("ODOO_MODEL_NOT_DECLARED",model)
  args=.directory~new
  args["attributes"]=.array~of("string","type","required","readonly","relation","selection")
  sr=provider~rawCall(model,"fields_get",args)
  if \sr~ok then return sr
  fields=sr~value
  operations=.directory~new
  if spec~hasIndex("model_operations") then do
    ops=spec["model_operations"]
    do localName over ops~allIndexes
      operations[localName]=ops[localName]
      self~installModelOperation(localName,ops[localName])
    end
  end
  discovered=.true
  return provider~successResult(self)
::method installModelOperation private
  use arg localName,spec
  remote=localName; kind="model_operation"
  if spec~hasIndex("remote_method") then remote=spec["remote_method"]
  if spec~hasIndex("kind") then kind=spec["kind"]
  source=.array~of('args=arg(1,"A")','return self~dispatchModelOperation("'||localName||'","'||remote||'","'||kind||'",args)')
  self~setMethod(localName,.Method~new(localName,source))
::method unknown
  expose discovered
  use arg messageName,args
  if \discovered then do
    r=self~performDiscovery
    if \r~ok then return r
    if self~hasMethod(messageName) then return self~sendWith(messageName,args)
  end
  raise syntax 97.1 array(self,messageName)
::method newQuery
  expose provider model discoveryFile
  use arg domain=.nil,queryFields=.nil,limit=100,order=""
  if domain==.nil then domain=.array~new
  return .OdooLiveQuery~new(self,domain,queryFields,limit,order,discoveryFile)
::method liveQuery
  expose provider
  use arg domain=.nil,queryFields=.nil,limit=100,order=""
  d=self~ensureDiscovery
  if \d~ok then return d
  q=self~newQuery(domain,queryFields,limit,order)
  r=q~update
  if \r~ok then return r
  return provider~successResult(q)
::method dispatchModelOperation
  expose provider model discoveryFile fields
  use arg localName,remoteMethod,kind,args
  if kind="browse" then do
    if args==.nil then return provider~failureResult("ODOO_ID_REQUIRED",model)
    if args~items<1 then return provider~failureResult("ODOO_ID_REQUIRED",model)
    recordId=args[1]
    requested=.nil
    if args~items>=2 then requested=args[2]
    rr=provider~readRecord(model,recordId,requested)
    if \rr~ok then return rr
    rows=rr~value
    if rows==.nil then return provider~failureResult("ODOO_RECORD_NOT_FOUND",model||":"||recordId)
    if rows~items=0 then return provider~failureResult("ODOO_RECORD_NOT_FOUND",model||":"||recordId)
    return provider~successResult(provider~odooObject(model,recordId,rows[1],discoveryFile))
  end
  if kind="search_objects" then do
    kwargs=.directory~new
    if args<>.nil then do
      if args~items>=1 then kwargs["domain"]=args[1]
      if args~items>=2 then kwargs["limit"]=args[2]
      if args~items>=3 then kwargs["order"]=args[3]
    end
    if \kwargs~hasIndex("domain") then kwargs["domain"]=.array~new
    rr=provider~rawCall(model,remoteMethod,kwargs)
    if \rr~ok then return rr
    objects=.array~new
    ids=rr~value
    if ids<>.nil then do remoteId over ids
      objects~append(provider~odooObject(model,remoteId,.nil,discoveryFile))
    end
    return provider~successResult(objects)
  end
  if kind="search_read_objects" then do
    kwargs=.directory~new
    if args<>.nil then do
      if args~items>=1 then kwargs["domain"]=args[1]
      if args~items>=2 then kwargs["fields"]=args[2]
      if args~items>=3 then kwargs["limit"]=args[3]
      if args~items>=4 then kwargs["order"]=args[4]
    end
    if \kwargs~hasIndex("domain") then kwargs["domain"]=.array~new
    rr=provider~rawCall(model,remoteMethod,kwargs)
    return provider~objectifyRows(model,rr,discoveryFile)
  end
  if kind="create_object" then do
    if args==.nil then return provider~failureResult("ODOO_VALUES_REQUIRED",model)
    if args~items<1 then return provider~failureResult("ODOO_VALUES_REQUIRED",model)
    kwargs=.directory~new; kwargs["vals_list"]=.array~of(args[1])
    rr=provider~rawCall(model,remoteMethod,kwargs)
    if \rr~ok then return rr
    created=rr~value
    recordId=created
    if created~hasMethod("items") then if created~items>0 then recordId=created[1]
    return provider~successResult(provider~odooObject(model,recordId,args[1],discoveryFile))
  end
  kwargs=.directory~new
  if args<>.nil then if args~items>0 then kwargs["arguments"]=args
  return provider~rawCall(model,remoteMethod,kwargs)

/* Retained remote query. Membership is keyed by Odoo record id so surviving
 * records preserve OdooObject identity across refreshes. */
::class OdooLiveQuery public
::method init
  expose modelObject domain queryFields limit order discoveryFile members byId listeners initialized lastResult
  use arg modelArg,domainArg=.nil,fieldsArg=.nil,limitArg=100,orderArg="",discoveryFileArg="discovery.operation"
  modelObject=modelArg; domain=domainArg; queryFields=fieldsArg; limit=limitArg; order=orderArg~string
  discoveryFile=discoveryFileArg~string
  if domain==.nil then domain=.array~new
  members=.array~new; byId=.directory~new; listeners=.array~new
  initialized=.false; lastResult=.nil
::method model; expose modelObject; return modelObject
::method odooModel; expose modelObject; return modelObject~odooModel
::method domain; expose domain; return domain
::method fields; expose queryFields; return queryFields
::method limit; expose limit; return limit
::method order; expose order; return order
::method members; expose members; return members
::method items; expose members; return members~items
::method at
  expose members
  use arg index
  return members[index]
::method lastResult; expose lastResult; return lastResult
::method initialized; expose initialized; return initialized
::method onUpdate
  expose listeners
  use arg listener
  if listener==.nil then raise syntax 88.931 array("query listener required")
  listeners~append(listener)
  return self
::method fireQueryEvent private
  expose listeners modelObject
  use arg kind,record=.nil,recordId="",changed=.nil
  event=.OdooQueryEvent~new(self,modelObject~odooModel,kind,record,recordId,changed)
  do listener over listeners
    listener~onOdooQueryEvent(event)
  end
::method update
  expose modelObject domain queryFields limit order discoveryFile members byId initialized lastResult
  provider=modelObject~provider
  d=modelObject~ensureDiscovery
  if \d~ok then do; lastResult=d; return d; end
  kwargs=.directory~new
  kwargs["domain"]=domain
  if queryFields<>.nil then kwargs["fields"]=queryFields
  if limit<>.nil then kwargs["limit"]=limit
  if order<>"" then kwargs["order"]=order
  rr=provider~rawCall(modelObject~odooModel,"search_read",kwargs)
  lastResult=rr
  if \rr~ok then return rr
  incoming=rr~value
  if incoming==.nil then incoming=.array~new
  nextMembers=.array~new; nextById=.directory~new
  do row over incoming
    if \row~hasIndex("id") then iterate
    id=row["id"]
    key=id~string
    if byId~hasIndex(key) then do
      obj=byId[key]
      merged=obj~mergeRemoteData(row,"QUERY_REFRESH")
      if \merged~ok then return merged
      changed=merged~value
      if initialized & changed~items>0 then self~fireQueryEvent("UPDATED",obj,id,changed)
    end
    else do
      obj=provider~odooObject(modelObject~odooModel,id,row,discoveryFile)
      if initialized then self~fireQueryEvent("ADDED",obj,id)
    end
    nextMembers~append(obj); nextById[key]=obj
  end
  if initialized then do oldKey over byId~allIndexes
    if \nextById~hasIndex(oldKey) then do
      oldObj=byId[oldKey]
      self~fireQueryEvent("REMOVED",oldObj,oldObj~odooId)
    end
  end
  members=nextMembers; byId=nextById; initialized=.true
  lastResult=provider~successResult(self)
  return lastResult
::method refresh; return self~update

/* Namespace facade: provider~modelSpace~res~partner -> OdooModel("res.partner").
 * Each namespace can be extended indefinitely; the final token is resolved as
 * a model only when a message is sent to it that requires model behaviour. */
::class OdooModelNamespace public
::method init
  expose provider prefix discoveryFile
  use arg providerArg,prefixArg="",discoveryFileArg="discovery.operation"
  provider=providerArg; prefix=prefixArg~string; discoveryFile=discoveryFileArg~string
::method model
  expose provider prefix discoveryFile
  use arg tail=""
  if prefix="" then full=tail~string
  else if tail="" then full=prefix
  else full=prefix||"."||tail
  return .OdooModel~new(provider,full,discoveryFile)
::method unknown
  expose provider prefix discoveryFile
  use arg messageName,args
  token=messageName~lower
  if prefix="" then next=token; else next=prefix||"."||token
  /* Return a path proxy.  ~asModel or ~model() makes terminal intent explicit;
   * common two-segment Odoo model names are promoted on the second segment. */
  segments=next~countStr(".")+1
  if segments>=2 then return .OdooModel~new(provider,next,discoveryFile)
  return .OdooModelNamespace~new(provider,next,discoveryFile)
::method asModel
  expose provider prefix discoveryFile
  return .OdooModel~new(provider,prefix,discoveryFile)

::class OdooModelSpace subclass OdooModelNamespace public
::method init
  use arg providerArg,discoveryFileArg="discovery.operation"
  self~init:super(providerArg,"",discoveryFileArg)

::requires "json.cls"
