/* Optional catalogue-intention projection for the Storage CLI candidate.
 * Extends storage.fabric.intentions/0.1 without replacing Intention Service,
 * Management Intention Discovery, or resident Storage authority.
 * A capability source must re-evaluate *live* executable capabilities.
 */

::class StorageCatalogueIntentionName public
::constant LIST "STORAGE_CATALOGUE_LIST"
::constant FIND "STORAGE_CATALOGUE_FIND"
::constant LOCATE "STORAGE_CATALOGUE_LOCATE"
::constant ADD "STORAGE_CATALOGUE_ADD"
::constant DESCRIBE "STORAGE_CATALOGUE_ANNOTATE"
::constant REMOVE "STORAGE_CATALOGUE_REMOVE"
::constant MATERIALISE "STORAGE_CATALOGUE_MATERIALISE"
::constant ENSURE "STORAGE_CATALOGUE_ENSURE_AZURE"

::class StorageCatalogueIntentionPort public
::method init
  expose basePort command capabilitySource authority
  use strict arg baseArg,commandArg,authorityArg,capabilityArg
  if baseArg==.nil | commandArg==.nil | authorityArg==.nil | capabilityArg==.nil then -
    raise syntax 88.900 array("base port, command, authority and capability source are required")
  basePort=baseArg; command=commandArg; authority=authorityArg; capabilitySource=capabilityArg

::method discover
  expose basePort authority capabilitySource
  use strict arg context=.nil
  descriptors=basePort~discover(context)
  caps=capabilitySource~capabilities(context)
  if caps==.nil then return descriptors
  if self~enabled(caps,"LIST") then -
    descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~LIST,"list video files","List registered StorageRef objects and virtual paths","READ","catalogue.list",.nil,"CATALOGUE_LIST"))
  if self~enabled(caps,"FIND") then -
    descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~FIND,"find video file","Find by name, description, tag or metadata","READ","catalogue.find",self~slots("QUERY"),"CATALOGUE_FIND"))
  if self~enabled(caps,"LOCATE") then -
    descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~LOCATE,"locate video file","Resolve exact virtual path or StorageRef to recorded locations","READ","catalogue.locate",self~slots("OBJECT"),"CATALOGUE_LOCATE"))
  if authority~canMutate then do
    if self~enabled(caps,"ADD") then -
      descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~ADD,"register video file","Register a host file with its chosen virtual path and metadata","CHANGE","catalogue.add",self~slots("SOURCE","VIRTUAL"),"CATALOGUE_ADD"))
    if self~enabled(caps,"ANNOTATE") then -
      descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~DESCRIBE,"describe video file","Change retained description, tags and searchable metadata","CHANGE","catalogue.annotate",self~slots("OBJECT"),"CATALOGUE_ANNOTATE"))
    if self~enabled(caps,"REMOVE") then -
      descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~REMOVE,"unpublish video path","Remove a logical path; physical copies are retained","DESTRUCTIVE","catalogue.remove",self~slots("VIRTUAL"),"CATALOGUE_REMOVE"))
    if self~enabled(caps,"MATERIALISE") then -
      descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~MATERIALISE,"bring video to this machine","Stage, verify and materialise a video on this node","CHANGE","catalogue.materialise",self~slots("OBJECT","TARGET"),"CATALOGUE_MATERIALISE"))
    if self~enabled(caps,"ENSURE_AZURE") then -
      descriptors~append(.StorageIntentionDescriptor~new(.StorageCatalogueIntentionName~ENSURE,"protect video on Azure Git","Ensure the required second durable copy on Azure Git","CHANGE","catalogue.ensure.azure",self~slots("OBJECT"),"CATALOGUE_ENSURE_AZURE"))
  end
  return descriptors

::method slots
  use strict arg a1,a2=""
  a=.array~of(a1)
  if a2<>"" then a~append(a2)
  return a
::method enabled
  use strict arg caps,name
  if \caps~isA(.Directory) then return .false
  if \caps~hasIndex(name) then return .false
  return caps[name]==.true

::method ownDescriptor
  use strict arg name
  do d over .array~of(.StorageCatalogueIntentionName~LIST,.StorageCatalogueIntentionName~FIND,.StorageCatalogueIntentionName~LOCATE,-
    .StorageCatalogueIntentionName~ADD,.StorageCatalogueIntentionName~DESCRIBE,.StorageCatalogueIntentionName~REMOVE,-
    .StorageCatalogueIntentionName~MATERIALISE,.StorageCatalogueIntentionName~ENSURE)
    if d=name then return .true
  end
  return .false

::method invoke
  expose basePort command authority
  use strict arg nameArg,arguments=.nil,context=.nil,expectedEpoch=.nil
  name=nameArg~string~upper
  if \self~ownDescriptor(name) then return basePort~invoke(name,arguments,context,expectedEpoch)
  descriptor=.nil
  do d over self~discover(context)
    if d~name=name then descriptor=d
  end
  if descriptor==.nil then return self~error("UNAVAILABLE")
  if \arguments~isA(.Directory) then return self~error("ARGUMENTS_REQUIRED")
  if descriptor~risk<>"READ" then do
    if expectedEpoch==.nil then return self~error("EPOCH_REQUIRED")
    guard=authority~guardMutation(expectedEpoch)
    if \guard~allowed then return self~error(guard~code)
    if \arguments~hasIndex("CONFIRMED") then return self~error("CONFIRMATION_REQUIRED")
    if arguments["CONFIRMED"] \== .true then return self~error("CONFIRMATION_REQUIRED")
  end
  select
    when name=.StorageCatalogueIntentionName~LIST then return self~outcome("OK",command~objects)
    when name=.StorageCatalogueIntentionName~FIND then do
      if \arguments~hasIndex("QUERY") then return self~error("QUERY_REQUIRED")
      q=arguments["QUERY"]~string~lower~strip
      if q="" then return self~error("QUERY_REQUIRED")
      matches=.array~new
      do obj over command~objects
        found=(pos(q,obj~displayName~lower)>0 | pos(q,obj~ref~objectId~lower)>0)
        if \found then do
          do ea over obj~eas~all
            if pos(q,ea~name~lower)>0 | pos(q,ea~value~string~lower)>0 then found=.true
          end
        end
        if \found then do
          if command~hasMethod("SNAPSHOT") then do
            do ns over command~snapshot~allNamespaces
              do binding over ns~localBindings
                if binding~ref~objectId=obj~ref~objectId then do
                  if pos(q,binding~path~lower)>0 then found=.true
                end
              end
            end
          end
        end
        if found then matches~append(obj)
      end
      return self~outcome("OK",matches)
    end
    when name=.StorageCatalogueIntentionName~LOCATE then do
      if \arguments~hasIndex("OBJECT") then return self~error("OBJECT_REQUIRED")
      return command~lookup(arguments["OBJECT"])
    end
    when name=.StorageCatalogueIntentionName~ADD then do
      if \arguments~hasIndex("SOURCE") | \arguments~hasIndex("VIRTUAL") then return self~error("SOURCE_AND_VIRTUAL_REQUIRED")
      return command~addFile(arguments["SOURCE"],self~field(arguments,"NAME"),arguments["VIRTUAL"],-
        self~field(arguments,"NAMESPACE","media"),self~field(arguments,"DESCRIPTION"),self~field(arguments,"TAGS"),-
        self~field(arguments,"METADATA"),self~field(arguments,"MEDIA_TYPE","application/octet-stream"))
    end
    when name=.StorageCatalogueIntentionName~DESCRIBE then do
      if \arguments~hasIndex("OBJECT") then return self~error("OBJECT_REQUIRED")
      return command~annotate(arguments["OBJECT"],self~field(arguments,"DESCRIPTION"),self~field(arguments,"TAGS"),-
        self~field(arguments,"METADATA"),self~field(arguments,"UNTAGS"),self~field(arguments,"UNSETS"))
    end
    when name=.StorageCatalogueIntentionName~REMOVE then do
      if \arguments~hasIndex("VIRTUAL") then return self~error("VIRTUAL_REQUIRED")
      return command~removeBinding(arguments["VIRTUAL"],self~field(arguments,"NAMESPACE","media"),.false)
    end
    when name=.StorageCatalogueIntentionName~MATERIALISE then do
      if \arguments~hasIndex("OBJECT") | \arguments~hasIndex("TARGET") then return self~error("OBJECT_AND_TARGET_REQUIRED")
      return command~materialise(arguments["OBJECT"],arguments["TARGET"],self~field(arguments,"PEER"))
    end
    when name=.StorageCatalogueIntentionName~ENSURE then do
      if \arguments~hasIndex("OBJECT") then return self~error("OBJECT_REQUIRED")
      return command~ensureAzure(arguments["OBJECT"])
    end
    otherwise return self~error("UNKNOWN_INTENTION")
  end
::method field
  use strict arg d,k,default=""
  if d~hasIndex(k) then return d[k]
  return default
::method error
  use strict arg code
  d=.directory~new;d["ok"]=.false;d["code"]=code;return d
::method outcome
  use strict arg code,objects
  d=.directory~new;d["ok"]=(code="OK");d["code"]=code;d["objects"]=objects;return d

/* Self-assessing specialist source for Management Intention Discovery dev8.
 * Management does not learn Storage vocabulary; returned descriptors remain
 * original ooRexx objects. Assessment is *not* authority or execution. */
::class StorageCatalogueManagementSource public
::method init
  expose provider
  use strict arg providerArg
  provider=providerArg
::method sourceId
  return "storage.fabric.intentions/0.1"
::method discover
  expose provider
  use strict arg context=.nil
  return provider~discover(context)
::method assessRelevance
  use strict arg request,surface,context=.nil
  query=request~string~lower
  matched=.false
  do word over .array~of("storage","file","files","video","recording","backup","replica","materialis","materializ","azure git","virtual path","archive","catalogue")
    if pos(word,query)>0 then matched=.true
  end
  /* A service with no current intentions cannot be relevant. */
  if surface==.nil then matched=.false
  else if surface~items=0 then matched=.false
  if matched then return .StorageCatalogueRelevance~new(.true,85,"storage.fabric","DOMAIN_MATCH",surface)
  return .StorageCatalogueRelevance~new(.false,0,"storage.fabric","NO_DOMAIN_MATCH",surface)

::class StorageCatalogueRelevance public
::attribute relevant get
::attribute score get
::attribute authority get
::attribute reason get
::attribute evidence get
::method init
  expose relevant score authority reason evidence
  use strict arg r,s,a,why,ev
  relevant=r;score=s;authority=a;reason=why;evidence=ev

::requires "StorageIntentions.cls"
