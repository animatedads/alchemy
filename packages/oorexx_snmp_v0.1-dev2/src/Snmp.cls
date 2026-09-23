/*----------------------------------------------------------------------------*/
/* ooRexx SNMP v0.1-dev2                                                      */
/* Object projection and implementation-map core.                             */
/*                                                                            */
/* The wire protocol owns OIDs. Applications own objects and behaviour.       */
/* Dynamic MIB / implementation-map properties are projected through UNKNOWN. */
/*----------------------------------------------------------------------------*/

::class SnmpBuild public
::constant RELEASE "0.1-dev2"
::constant API_VERSION "snmp/0.1"
::constant MAP_SCHEMA "snmp.implementation.map/0.2"
::constant MAP_SCHEMA_V1 "snmp.implementation.map/0.1"

/*----------------------------------------------------------------------------*/
/* Identity                                                                    */
/*----------------------------------------------------------------------------*/

::class SnmpIndex public
::attribute components get

::method init
  expose components
  use strict arg componentsArg=.nil
  components=.array~new
  if componentsArg==.nil then return
  if componentsArg~isA(.array) then do c over componentsArg; components~append(c); end
  else components~append(componentsArg)

::method oidSuffix
  expose components
  out=""
  do c over components
    part=c~string
    if out=="" then out=part
    else out=out||"."||part
  end
  return out

::method string
  return self~oidSuffix

::method key
  return self~oidSuffix

/*----------------------------------------------------------------------------*/
/* Definition model                                                            */
/*----------------------------------------------------------------------------*/

::class SnmpObjectDefinition public
::attribute name get
::attribute oid get
::attribute kind get
::attribute syntax get
::attribute access get
::attribute tableName get
::attribute enumByWire get
::attribute enumByName get
::attribute eventRules get
::attribute metadata get

::method init
  expose name oid kind syntax access tableName enumByWire enumByName eventRules metadata
  use strict arg nameArg, oidArg, kindArg="SCALAR", syntaxArg="OCTET STRING", accessArg="READ-ONLY", -
                 tableArg="", enumArg=.nil, eventsArg=.nil, metadataArg=.nil
  name=nameArg~string
  oid=oidArg~string
  kind=kindArg~string~upper
  syntax=syntaxArg~string~upper
  access=accessArg~string~upper
  tableName=tableArg~string
  enumByWire=.directory~new
  enumByName=.directory~new
  if enumArg<>.nil then do key over enumArg
    symbolic=enumArg[key]~string
    enumByWire[key~string]=symbolic
    enumByName[symbolic~upper]=key~string
  end
  eventRules=.directory~new
  if eventsArg<>.nil then do key over eventsArg
    eventRules[key~string~lower]=eventsArg[key]~string~upper
  end
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::method writable
  expose access
  return access=="READ-WRITE" | access=="WRITE-ONLY" | access=="READ-CREATE"

::method readable
  expose access
  return access<>"WRITE-ONLY" & access<>"NOT-ACCESSIBLE"

::method instanceOid
  expose oid kind
  use strict arg index=.nil
  if kind=="SCALAR" then return oid
  if kind=="COLUMN" then do
    if index==.nil then raise syntax 93.900 array('SNMP column requires an index',self~name)
    if index~isA(.SnmpIndex) then suffix=index~oidSuffix
    else suffix=index~string
    if suffix=="" then raise syntax 93.900 array('SNMP column requires a non-empty index',self~name)
    return oid||"."||suffix
  end
  return oid

::method decode
  expose enumByWire syntax
  use strict arg raw
  if raw==.nil then return .nil
  key=raw~string
  if enumByWire~hasIndex(key) then return enumByWire[key]
  return raw

::method encode
  expose enumByName syntax
  use strict arg value
  if value==.nil then return value
  key=value~string~upper
  if enumByName~hasIndex(key) then return enumByName[key]
  return value

::method transitionEvent
  expose eventRules
  use strict arg oldValue, newValue
  if eventRules~items==0 then return ""
  old=oldValue~string~lower
  new=newValue~string~lower
  keys=.array~of(old||"->"||new, "*->"||new, old||"->*", "*->*")
  do key over keys
    if eventRules~hasIndex(key) then return eventRules[key]
  end
  return ""

::class SnmpTableDefinition public
::attribute name get
::attribute oid get
::attribute indexNames get
::attribute metadata get

::method init
  expose name oid indexNames metadata
  use strict arg nameArg, oidArg, indexArg=.nil, metadataArg=.nil
  name=nameArg~string
  oid=oidArg~string
  indexNames=.array~new
  if indexArg<>.nil then do
    if indexArg~isA(.array) then do i over indexArg; indexNames~append(i~string); end
    else indexNames~append(indexArg~string)
  end
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::class SnmpNotificationDefinition public
::attribute name get
::attribute oid get
::attribute eventType get
::attribute targetTable get
::attribute indexVarbind get
::attribute metadata get

::method init
  expose name oid eventType targetTable indexVarbind metadata
  use strict arg nameArg, oidArg, eventArg, targetTableArg="", indexVarbindArg="", metadataArg=.nil
  name=nameArg~string
  oid=oidArg~string
  eventType=eventArg~string~upper
  targetTable=targetTableArg~string
  indexVarbind=indexVarbindArg~string
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

/*----------------------------------------------------------------------------*/
/* Semantic projection                                                        */
/*----------------------------------------------------------------------------*/

::class SnmpAliasDefinition public
::attribute name get
::attribute target get
::attribute kind get
::attribute scope get
::attribute metadata get

::method init
  expose name target kind scope metadata
  use strict arg nameArg,targetArg,kindArg="AUTO",scopeArg="*",metadataArg=.nil
  name=nameArg~string
  target=targetArg~string
  kind=kindArg~string~upper
  scope=scopeArg~string~upper
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::method appliesTo
  expose scope
  use strict arg objectKindArg="OBJECT",tableNameArg=""
  objectKind=objectKindArg~string~upper
  tableName=tableNameArg~string~upper
  if scope=="*" then return .true
  if scope==objectKind then return .true
  if scope~left(6)=="TABLE:" then return tableName<>"" & scope~substr(7)==tableName
  return .false

::class SnmpSemanticRule public
::attribute name get
::attribute propertyName get
::attribute eventType get
::attribute operator get
::attribute compareValue get
::attribute edge get
::attribute scope get
::attribute metadata get

::method init
  expose name propertyName eventType operator compareValue edge scope metadata
  use strict arg nameArg,propertyArg,eventArg,operatorArg="EQ",compareArg=.nil,edgeArg="ENTER",scopeArg="*",metadataArg=.nil
  name=nameArg~string
  propertyName=propertyArg~string
  eventType=eventArg~string~upper
  operator=operatorArg~string~upper
  compareValue=compareArg
  edge=edgeArg~string~upper
  scope=scopeArg~string~upper
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::method appliesTo
  expose scope
  use strict arg objectKindArg="OBJECT",tableNameArg=""
  objectKind=objectKindArg~string~upper
  tableName=tableNameArg~string~upper
  if scope=="*" then return .true
  if scope==objectKind then return .true
  if scope~left(6)=="TABLE:" then return tableName<>"" & scope~substr(7)==tableName
  return .false

::method accepts
  expose operator compareValue
  use strict arg value
  select
    when operator=="ALWAYS" then return .true
    when operator=="EQ" then return value~string==compareValue~string
    when operator=="NE" then return value~string<>compareValue~string
    when operator=="GT" then return self~numericCompare(value,compareValue,"> ")
    when operator=="GE" then return self~numericCompare(value,compareValue,">=")
    when operator=="LT" then return self~numericCompare(value,compareValue,"< ")
    when operator=="LE" then return self~numericCompare(value,compareValue,"<=")
    otherwise raise syntax 93.900 array('Unsupported SNMP semantic rule operator',operator)
  end

::method numericCompare private
  use strict arg left,right,op
  if \datatype(left~string,"N") | \datatype(right~string,"N") then return .false
  l=left+0
  r=right+0
  select
    when op=="> " then return l>r
    when op==">=" then return l>=r
    when op=="< " then return l<r
    when op=="<=" then return l<=r
    otherwise return .false
  end

::method fires
  expose edge
  use strict arg oldValue,newValue
  oldMatch=self~accepts(oldValue)
  newMatch=self~accepts(newValue)
  select
    when edge=="ENTER" then return \oldMatch & newMatch
    when edge=="EXIT" then return oldMatch & \newMatch
    when edge=="CHANGE" then return oldValue~string<>newValue~string & newMatch
    when edge=="ALWAYS" then return newMatch
    otherwise raise syntax 93.900 array('Unsupported SNMP semantic rule edge',edge)
  end

/*----------------------------------------------------------------------------*/
/* Implementation map                                                         */
/*----------------------------------------------------------------------------*/

::class SnmpImplementationMap public
::attribute name get
::attribute layers get

::method init
  expose name layers objectsByName objectsByOid tablesByName notificationsByOid notificationsByName aliasesByKey rulesByKey rulesByProperty
  use strict arg nameArg="anonymous"
  name=nameArg~string
  layers=.array~new
  layers~append(name)
  objectsByName=.directory~new
  objectsByOid=.directory~new
  tablesByName=.directory~new
  notificationsByOid=.directory~new
  notificationsByName=.directory~new
  aliasesByKey=.directory~new
  rulesByKey=.directory~new
  rulesByProperty=.directory~new

::method addObject guarded
  expose objectsByName objectsByOid
  use strict arg definition
  nameKey=definition~name~upper
  oidKey=definition~oid

  /* A later adoption layer may deliberately re-project a symbolic property
     onto a different vendor OID. Remove stale reverse mappings so both
     symbolic and OID resolution have one current authority. */
  if objectsByName~hasIndex(nameKey) then do
    previous=objectsByName[nameKey]
    if previous~oid<>oidKey then objectsByOid~remove(previous~oid)
  end
  if objectsByOid~hasIndex(oidKey) then do
    previous=objectsByOid[oidKey]
    if previous~name~upper<>nameKey then objectsByName~remove(previous~name~upper)
  end

  objectsByName[nameKey]=definition
  objectsByOid[oidKey]=definition
  return self

::method addTable guarded
  expose tablesByName
  use strict arg definition
  tablesByName[definition~name~upper]=definition
  return self

::method addNotification guarded
  expose notificationsByOid notificationsByName
  use strict arg definition
  nameKey=definition~name~upper
  oidKey=definition~oid
  if notificationsByName~hasIndex(nameKey) then do
    previous=notificationsByName[nameKey]
    if previous~oid<>oidKey then notificationsByOid~remove(previous~oid)
  end
  if notificationsByOid~hasIndex(oidKey) then do
    previous=notificationsByOid[oidKey]
    if previous~name~upper<>nameKey then notificationsByName~remove(previous~name~upper)
  end
  notificationsByOid[oidKey]=definition
  notificationsByName[nameKey]=definition
  return self

::method addAlias guarded
  expose aliasesByKey
  use strict arg definition
  key=definition~name~upper||"|"||definition~scope
  aliasesByKey[key]=definition
  return self

::method addRule guarded
  expose rulesByKey rulesByProperty
  use strict arg definition
  key=definition~name~upper||"|"||definition~scope
  if rulesByKey~hasIndex(key) then do
    previous=rulesByKey[key]
    previousProperty=previous~propertyName~upper
    if rulesByProperty~hasIndex(previousProperty) then do
      cleaned=.array~new
      do existing over rulesByProperty[previousProperty]
        existingKey=existing~name~upper||"|"||existing~scope
        if existingKey<>key then cleaned~append(existing)
      end
      rulesByProperty[previousProperty]=cleaned
    end
  end
  rulesByKey[key]=definition
  propertyKey=definition~propertyName~upper
  if \rulesByProperty~hasIndex(propertyKey) then rulesByProperty[propertyKey]=.array~new
  rulesByProperty[propertyKey]~append(definition)
  return self

::method alias guarded
  expose aliasesByKey
  use strict arg nameArg,objectKindArg="OBJECT",tableNameArg=""
  name=nameArg~string~upper
  objectKind=objectKindArg~string~upper
  tableName=tableNameArg~string~upper
  candidates=.array~new
  if tableName<>"" then candidates~append(name||"|TABLE:"||tableName)
  candidates~append(name||"|"||objectKind)
  candidates~append(name||"|*")
  do key over candidates
    if aliasesByKey~hasIndex(key) then return aliasesByKey[key]
  end
  return .nil

::method rule guarded
  expose rulesByKey
  use strict arg nameArg,objectKindArg="OBJECT",tableNameArg=""
  name=nameArg~string~upper
  objectKind=objectKindArg~string~upper
  tableName=tableNameArg~string~upper
  candidates=.array~new
  if tableName<>"" then candidates~append(name||"|TABLE:"||tableName)
  candidates~append(name||"|"||objectKind)
  candidates~append(name||"|*")
  do key over candidates
    if rulesByKey~hasIndex(key) then return rulesByKey[key]
  end
  return .nil

::method rulesFor guarded
  expose rulesByProperty
  use strict arg propertyNameArg,objectKindArg="OBJECT",tableNameArg=""
  key=propertyNameArg~string~upper
  out=.array~new
  if \rulesByProperty~hasIndex(key) then return out
  do rule over rulesByProperty[key]
    if rule~appliesTo(objectKindArg,tableNameArg) then out~append(rule)
  end
  return out

::method semanticEvent guarded
  expose notificationsByName
  use strict arg nameArg,objectKindArg="OBJECT",tableNameArg=""
  name=nameArg~string
  rule=self~rule(name,objectKindArg,tableNameArg)
  if rule<>.nil then return rule~eventType
  key=name~upper
  if notificationsByName~hasIndex(key) then return notificationsByName[key]~eventType
  return key

::method object guarded
  expose objectsByName
  use strict arg nameArg
  key=nameArg~string~upper
  if objectsByName~hasIndex(key) then return objectsByName[key]
  return .nil

::method table guarded
  expose tablesByName
  use strict arg nameArg
  key=nameArg~string~upper
  if tablesByName~hasIndex(key) then return tablesByName[key]
  return .nil

::method notification guarded
  expose notificationsByOid notificationsByName
  use strict arg nameOrOid
  key=nameOrOid~string
  if notificationsByOid~hasIndex(key) then return notificationsByOid[key]
  key=key~upper
  if notificationsByName~hasIndex(key) then return notificationsByName[key]
  return .nil

::method resolveOid guarded
  expose objectsByOid
  use strict arg oidArg
  oid=oidArg~string
  if objectsByOid~hasIndex(oid) then return .array~of(objectsByOid[oid], .nil)

  /* Longest matching column base wins. */
  best=.nil
  bestLen=0
  bestSuffix=""
  do base over objectsByOid
    def=objectsByOid[base]
    if def~kind<>"COLUMN" then iterate
    prefix=base||"."
    if oid~left(prefix~length)==prefix then do
      if base~length>bestLen then do
        best=def
        bestLen=base~length
        bestSuffix=oid~substr(prefix~length+1)
      end
    end
  end
  if best==.nil then return .nil
  return .array~of(best,.SnmpIndex~new(self~splitOid(bestSuffix)))

::method splitOid private
  use strict arg suffix
  out=.array~new
  rest=suffix
  do while rest<>""
    parse var rest part "." rest
    out~append(part)
  end
  return out

::method adopt guarded
  expose layers tablesByName
  use strict arg other
  do layer over other~layers; layers~append(layer); end

  /* Release our guard while using the public guarded installers.  They own
     collision cleanup and keep the name/OID indexes consistent. */
  incomingObjects=other~objects
  incomingTables=other~tables
  incomingNotifications=other~notifications
  incomingAliases=other~aliases
  incomingRules=other~rules
  guard off
  do def over incomingObjects; self~addObject(def); end
  do def over incomingTables; self~addTable(def); end
  do def over incomingNotifications; self~addNotification(def); end
  do def over incomingAliases; self~addAlias(def); end
  do def over incomingRules; self~addRule(def); end
  return self

::method objects guarded
  expose objectsByName
  out=.array~new
  do key over objectsByName; out~append(objectsByName[key]); end
  return out

::method tables guarded
  expose tablesByName
  out=.array~new
  do key over tablesByName; out~append(tablesByName[key]); end
  return out

::method notifications guarded
  expose notificationsByOid
  out=.array~new
  do key over notificationsByOid; out~append(notificationsByOid[key]); end
  return out

::method aliases guarded
  expose aliasesByKey
  out=.array~new
  do key over aliasesByKey; out~append(aliasesByKey[key]); end
  return out

::method rules guarded
  expose rulesByKey
  out=.array~new
  do key over rulesByKey; out~append(rulesByKey[key]); end
  return out

/*----------------------------------------------------------------------------*/
/* Map loader                                                                  */
/*----------------------------------------------------------------------------*/

::class SnmpImplementationMapLoader public

::method loadFile
  use strict arg path
  stream=.stream~new(path)
  status=stream~open("read")
  if status~left(6)<>"READY:" then raise syntax 93.900 array('Cannot open SNMP implementation map',path,status)
  text=stream~charin(1,stream~chars)
  stream~close
  return self~loadText(text)

::method loadText
  use strict arg text
  doc=.json~fromJSON(text)
  if \fragmentHas(doc,"schema") then raise syntax 93.900 array('SNMP implementation map lacks schema')
  schema=doc["schema"]
  if schema<>.SnmpBuild~MAP_SCHEMA & schema<>.SnmpBuild~MAP_SCHEMA_V1 then raise syntax 93.900 array('Unsupported SNMP implementation map schema',schema)
  name="anonymous"
  if fragmentHas(doc,"name") then name=doc["name"]
  map=.SnmpImplementationMap~new(name)

  if fragmentHas(doc,"objects") then do defDoc over doc["objects"]
    enum=.nil
    events=.nil
    table=""
    metadata=.nil
    kind="SCALAR"
    syntax="OCTET STRING"
    access="READ-ONLY"
    if fragmentHas(defDoc,"enum") then enum=defDoc["enum"]
    if fragmentHas(defDoc,"events") then events=defDoc["events"]
    if fragmentHas(defDoc,"table") then table=defDoc["table"]
    if fragmentHas(defDoc,"metadata") then metadata=defDoc["metadata"]
    if fragmentHas(defDoc,"kind") then kind=defDoc["kind"]
    if fragmentHas(defDoc,"syntax") then syntax=defDoc["syntax"]
    if fragmentHas(defDoc,"access") then access=defDoc["access"]
    map~addObject(.SnmpObjectDefinition~new(defDoc["name"],defDoc["oid"],kind,syntax,access,table,enum,events,metadata))
  end

  if fragmentHas(doc,"tables") then do tableDoc over doc["tables"]
    indexes=.nil
    metadata=.nil
    if fragmentHas(tableDoc,"index") then indexes=tableDoc["index"]
    if fragmentHas(tableDoc,"metadata") then metadata=tableDoc["metadata"]
    map~addTable(.SnmpTableDefinition~new(tableDoc["name"],tableDoc["oid"],indexes,metadata))
  end

  if fragmentHas(doc,"notifications") then do nDoc over doc["notifications"]
    targetTable=""
    indexVarbind=""
    metadata=.nil
    if fragmentHas(nDoc,"targetTable") then targetTable=nDoc["targetTable"]
    if fragmentHas(nDoc,"indexVarbind") then indexVarbind=nDoc["indexVarbind"]
    if fragmentHas(nDoc,"metadata") then metadata=nDoc["metadata"]
    map~addNotification(.SnmpNotificationDefinition~new(nDoc["name"],nDoc["oid"],nDoc["eventType"],targetTable,indexVarbind,metadata))
  end

  if fragmentHas(doc,"aliases") then do aDoc over doc["aliases"]
    kind="AUTO"
    scope="*"
    metadata=.nil
    if fragmentHas(aDoc,"kind") then kind=aDoc["kind"]
    if fragmentHas(aDoc,"scope") then scope=aDoc["scope"]
    if fragmentHas(aDoc,"metadata") then metadata=aDoc["metadata"]
    map~addAlias(.SnmpAliasDefinition~new(aDoc["name"],aDoc["target"],kind,scope,metadata))
  end

  if fragmentHas(doc,"eventRules") then do rDoc over doc["eventRules"]
    operator="EQ"
    compare=.nil
    edge="ENTER"
    scope="*"
    metadata=.nil
    if fragmentHas(rDoc,"operator") then operator=rDoc["operator"]
    if fragmentHas(rDoc,"value") then compare=rDoc["value"]
    if fragmentHas(rDoc,"edge") then edge=rDoc["edge"]
    if fragmentHas(rDoc,"scope") then scope=rDoc["scope"]
    if fragmentHas(rDoc,"metadata") then metadata=rDoc["metadata"]
    map~addRule(.SnmpSemanticRule~new(rDoc["name"],rDoc["property"],rDoc["eventType"],operator,compare,edge,scope,metadata))
  end
  return map

/*----------------------------------------------------------------------------*/
/* Varbind evidence                                                            */
/*----------------------------------------------------------------------------*/

::class SnmpVarBind public
::attribute oid get
::attribute name get
::attribute index get
::attribute rawValue get
::attribute value get
::attribute definition get

::method init
  expose oid name index rawValue value definition
  use strict arg oidArg, rawArg, definitionArg=.nil, indexArg=.nil
  oid=oidArg~string
  rawValue=rawArg
  definition=definitionArg
  index=indexArg
  if definition==.nil then do; name=""; value=rawArg; end
  else do; name=definition~name; value=definition~decode(rawArg); end

::class SnmpVarBindSet public
::method init
  expose items byName byOid
  items=.array~new
  byName=.directory~new
  byOid=.directory~new

::method add
  expose items byName byOid
  use strict arg varbind
  items~append(varbind)
  byOid[varbind~oid]=varbind
  if varbind~name<>"" then byName[varbind~name~upper]=varbind
  return self

::method addRaw
  use strict arg oid,raw,map
  resolved=map~resolveOid(oid)
  if resolved==.nil then vb=.SnmpVarBind~new(oid,raw)
  else vb=.SnmpVarBind~new(oid,raw,resolved[1],resolved[2])
  return self~add(vb)

::method byName
  expose byName
  use strict arg name
  key=name~string~upper
  if byName~hasIndex(key) then return byName[key]
  return .nil

::method byOid
  expose byOid
  use strict arg oid
  key=oid~string
  if byOid~hasIndex(key) then return byOid[key]
  return .nil

::method items
  expose items
  return items~copy

/*----------------------------------------------------------------------------*/
/* Transport/session                                                           */
/*----------------------------------------------------------------------------*/

::class SnmpTransport public
::method get abstract
::method set abstract
::method walk abstract

::class SnmpMemoryTransport subclass SnmpTransport public
::method init
  expose values gets sets
  use strict arg initial=.nil
  values=.directory~new
  gets=0
  sets=0
  if initial<>.nil then do key over initial; values[key~string]=initial[key]; end

::method get
  expose values gets
  use strict arg oid
  gets+=1
  key=oid~string
  if \values~hasIndex(key) then return .nil
  return values[key]

::method set
  expose values sets
  use strict arg oid,value
  sets+=1
  values[oid~string]=value
  return value

::method walk
  expose values
  use strict arg baseOid
  out=.SnmpVarBindSet~new
  prefix=baseOid~string||"."
  do oid over values
    if oid~left(prefix~length)==prefix then out~add(.SnmpVarBind~new(oid,values[oid]))
  end
  return out

::method inject
  expose values
  use strict arg oid,value
  values[oid~string]=value
  return self

::method getCount
  expose gets
  return gets

::method setCount
  expose sets
  return sets

::class SnmpSession public
::attribute transport get
::attribute implementationMap get

::method init
  expose transport implementationMap
  use strict arg transportArg,mapArg
  transport=transportArg
  implementationMap=mapArg

::method getDefinition
  expose transport
  use strict arg definition,index=.nil
  if \definition~readable then raise syntax 93.900 array('SNMP object is not readable',definition~name)
  raw=transport~get(definition~instanceOid(index))
  return definition~decode(raw)

::method setDefinition
  expose transport
  use strict arg definition,index=.nil,value
  if \definition~writable then raise syntax 93.900 array('SNMP object is not writable',definition~name)
  wire=definition~encode(value)
  raw=transport~set(definition~instanceOid(index),wire)
  return definition~decode(raw)

/*----------------------------------------------------------------------------*/
/* Managed object projection                                                   */
/*----------------------------------------------------------------------------*/

::class SnmpValueChange public
::attribute propertyName get
::attribute index get
::attribute oldValue get
::attribute newValue get
::attribute definition get
::attribute evidence get

::method init
  expose propertyName index oldValue newValue definition evidence
  use strict arg nameArg,indexArg,oldArg,newArg,definitionArg,evidenceArg=.nil
  propertyName=nameArg~string
  index=indexArg
  oldValue=oldArg
  newValue=newArg
  definition=definitionArg
  evidence=evidenceArg

::class SnmpNotificationEvidence public
::attribute notification get
::attribute varbinds get

::method init
  expose notification varbinds
  use strict arg notificationArg,varbindsArg
  notification=notificationArg
  varbinds=varbindsArg

::class SnmpObservationSnapshot public
::attribute generation get
::attribute terminalType get
::attribute visibleText get
::attribute contentDigest get
::attribute values get
::attribute sourceId get

::method init
  expose generation terminalType visibleText contentDigest values sourceId
  use strict arg generationArg,sourceIdArg,valuesArg
  generation=generationArg+0
  sourceId=sourceIdArg~string
  terminalType="SNMP"
  values=valuesArg~copy
  keys=.array~new
  do key over values; keys~append(key~string); end
  if keys~items>1 then keys~sort
  visibleText=""
  do key over keys
    if visibleText<>"" then visibleText=visibleText||"0A"x
    visibleText=visibleText||key||"="||values[key]~string
  end
  /* Observation only requires a stable content identity.  Crypto-backed
     evidence can wrap this snapshot at the evidence boundary. */
  contentDigest=visibleText

::method copyDetached
  expose generation sourceId values
  return .SnmpObservationSnapshot~new(generation,sourceId,values)

::class SnmpObservationView public
::method init
  expose source
  use strict arg sourceArg
  source=sourceArg

::method sessionId
  expose source
  return source~sourceId

::method terminalType
  return "SNMP"

::method deviceName
  expose source
  return source~sourceId

::method snapshot
  expose source
  return source~snapshot

::method current
  return self~snapshot

::method back
  expose source
  use strict arg count=1
  return source~historySnapshot(count)

::method history
  expose source
  return source~history

::method knownStateStatus
  expose source
  if source~generation>0 then return "KNOWN"
  return "UNKNOWN"

::method knownStateId
  expose source
  if source~generation==0 then return ""
  return source~sourceId||":"||source~generation

::method knownStateGeneration
  expose source
  return source~generation

::method knownStateHistory
  return self~history

::class SnmpManagedObject subclass EventSource public
::attribute session get
::attribute implementationMap get
::attribute index get
::attribute objectKind get
::attribute generation get

::method init
  expose session implementationMap index objectKind valueCache tables generation observationHistory observationView
  use strict arg sourceIdArg,sessionArg,mapArg,indexArg=.nil,kindArg="OBJECT"
  self~init:super(sourceIdArg)
  session=sessionArg
  implementationMap=mapArg
  index=indexArg
  objectKind=kindArg~string~upper
  valueCache=.directory~new
  tables=.directory~new
  generation=0
  observationHistory=.array~new
  observationView=.nil

::method scopeTable
  return ""

::method resolvePropertyName private
  expose implementationMap objectKind
  use strict arg propertyName
  alias=implementationMap~alias(propertyName,objectKind,self~scopeTable)
  if alias<>.nil then do
    if alias~kind=="TABLE" then return propertyName~string
    if implementationMap~object(alias~target)<>.nil then return alias~target
  end
  return propertyName~string

::method resolveTableName private
  expose implementationMap objectKind
  use strict arg tableName
  alias=implementationMap~alias(tableName,objectKind,self~scopeTable)
  if alias<>.nil then do
    if alias~kind=="PROPERTY" then return tableName~string
    if implementationMap~table(alias~target)<>.nil then return alias~target
  end
  return tableName~string

::method propertyDefinition unguarded
  expose implementationMap
  use strict arg propertyName
  resolved=self~resolvePropertyName(propertyName)
  return implementationMap~object(resolved)

::method getProperty unguarded
  expose session implementationMap index
  use strict arg propertyName
  definition=self~propertyDefinition(propertyName)
  if definition==.nil then raise syntax 97.1 array(propertyName)
  return session~getDefinition(definition,index)

::method setProperty unguarded
  expose session implementationMap index
  use strict arg propertyName,value
  definition=self~propertyDefinition(propertyName)
  if definition==.nil then raise syntax 97.1 array(propertyName)
  return session~setDefinition(definition,index,value)

::method managedTable unguarded
  expose implementationMap
  use strict arg tableName
  resolved=self~resolveTableName(tableName)
  definition=implementationMap~table(resolved)
  if definition==.nil then raise syntax 97.1 array(tableName)
  return self~tableObject(definition)

::method unknown unguarded
  expose session implementationMap index objectKind
  use strict arg name,args
  message=name~string

  if message~right(1)=="=" then do
    if args~items<>1 then raise syntax 93.900 array('SNMP dynamic setter requires exactly one value',message)
    property=message~left(message~length-1)
    definition=self~propertyDefinition(property)
    if definition==.nil then raise syntax 97.1 array(name)
    return session~setDefinition(definition,index,args[1])
  end

  if args~items<>0 then raise syntax 97.1 array(name)

  definition=implementationMap~object(message)
  if definition<>.nil then return session~getDefinition(definition,index)

  tableDefinition=implementationMap~table(message)
  if tableDefinition<>.nil then return self~tableObject(tableDefinition)

  alias=implementationMap~alias(message,objectKind,self~scopeTable)
  if alias<>.nil then do
    if alias~kind<>"TABLE" then do
      definition=implementationMap~object(alias~target)
      if definition<>.nil then return session~getDefinition(definition,index)
    end
    if alias~kind<>"PROPERTY" then do
      tableDefinition=implementationMap~table(alias~target)
      if tableDefinition<>.nil then return self~tableObject(tableDefinition)
    end
  end

  raise syntax 97.1 array(name)

::method when unguarded
  expose implementationMap objectKind
  use strict arg filterOrName
  if filterOrName~isA(.EventFilter) then return self~when:super(filterOrName)
  eventType=implementationMap~semanticEvent(filterOrName,objectKind,self~scopeTable)
  filter=.EventFilter~new(eventType,self~sourceId)
  return self~when:super(filter)

::method on unguarded
  expose implementationMap objectKind
  use strict arg eventName,target,messageName,delivery='SYNC'
  eventType=implementationMap~semanticEvent(eventName,objectKind,self~scopeTable)
  return self~on:super(eventType,target,messageName,delivery)

::method tableObject
  expose session implementationMap tables
  use strict arg tableDefinition
  key=tableDefinition~name~upper
  if tables~hasIndex(key) then return tables[key]
  table=.SnmpManagedTable~new(self,session,implementationMap,tableDefinition)
  tables[key]=table
  return table

::method refresh
  expose session implementationMap index valueCache objectKind
  use strict arg propertyName
  definition=self~propertyDefinition(propertyName)
  if definition==.nil then raise syntax 97.1 array(propertyName)
  value=session~getDefinition(definition,index)
  key=definition~name~upper
  if \valueCache~hasIndex(key) then do
    valueCache[key]=value
    self~recordObservation
    return value
  end
  old=valueCache[key]
  if old==value then return value
  valueCache[key]=value
  self~recordObservation
  change=.SnmpValueChange~new(definition~name,index,old,value,definition)
  self~emit("SNMP.VALUE.CHANGED",change)
  semantic=definition~transitionEvent(old,value)
  if semantic<>"" then self~emit(semantic,change)
  do rule over implementationMap~rulesFor(definition~name,objectKind,self~scopeTable)
    if rule~fires(old,value) then self~emit(rule~eventType,change)
  end
  return value

::method refreshAll
  expose implementationMap objectKind
  do definition over implementationMap~objects
    if \definition~readable then iterate
    if objectKind=="ROW" then do
      if definition~kind<>"COLUMN" then iterate
      if definition~tableName~upper<>self~scopeTable~upper then iterate
    end
    else do
      if definition~kind<>"SCALAR" then iterate
    end
    self~refresh(definition~name)
  end
  return self~snapshot

::method seed
  expose implementationMap valueCache
  use strict arg propertyName,value
  definition=self~propertyDefinition(propertyName)
  if definition==.nil then raise syntax 97.1 array(propertyName)
  key=definition~name~upper
  changed=\valueCache~hasIndex(key)
  if \changed then changed=valueCache[key]<>value
  valueCache[key]=value
  if changed then self~recordObservation
  return self

::method cached
  expose valueCache
  use strict arg propertyName,default=.nil
  definition=self~propertyDefinition(propertyName)
  if definition==.nil then return default
  key=definition~name~upper
  if valueCache~hasIndex(key) then return valueCache[key]
  return default

::method snapshot
  expose generation valueCache
  return .SnmpObservationSnapshot~new(generation,self~sourceId,valueCache)

::method observation
  expose observationView
  if observationView==.nil then observationView=.SnmpObservationView~new(self)
  return observationView

::method history
  expose observationHistory
  out=.array~new
  do snapshot over observationHistory; out~append(snapshot~copyDetached); end
  return out

::method historySnapshot
  expose observationHistory
  use strict arg backCount=1
  position=observationHistory~items-(backCount+0)
  if position<1 then return .nil
  return observationHistory[position]~copyDetached

::method recordObservation private
  expose generation observationHistory
  generation+=1
  observationHistory~append(self~snapshot)
  do while observationHistory~items>32; observationHistory~remove(1); end
  return generation

::class SnmpManagedTable public
::attribute owner get
::attribute definition get

::method init
  expose owner session implementationMap definition rows
  use strict arg ownerArg,sessionArg,mapArg,definitionArg
  owner=ownerArg
  session=sessionArg
  implementationMap=mapArg
  definition=definitionArg
  rows=.directory~new

::method row guarded
  expose owner session implementationMap definition rows
  use strict arg indexArg
  if indexArg~isA(.SnmpIndex) then idx=indexArg
  else idx=.SnmpIndex~new(indexArg)
  key=idx~key
  if rows~hasIndex(key) then return rows[key]
  sourceId=owner~sourceId||":"||definition~name||":"||key
  row=.SnmpManagedRow~new(sourceId,session,implementationMap,idx,definition~name)
  rows[key]=row
  return row

::method "[]"
  use strict arg indexArg
  return self~row(indexArg)

::method indexes
  expose session implementationMap definition
  out=.array~new
  if definition~indexNames~items==0 then return out
  indexName=definition~indexNames[1]
  indexDefinition=implementationMap~object(indexName)
  if indexDefinition==.nil then return out
  walked=session~transport~walk(indexDefinition~oid)
  found=.directory~new
  do vb over walked~items
    resolved=implementationMap~resolveOid(vb~oid)
    if resolved==.nil then iterate
    if resolved[1]~name~upper<>indexName~upper then iterate
    if resolved[2]==.nil then iterate
    found[resolved[2]~key]=resolved[2]
  end
  keys=.array~new
  do key over found; keys~append(key); end
  if keys~items>1 then keys~sort
  do key over keys; out~append(found[key]); end
  return out

::method rows
  out=.array~new
  do index over self~indexes; out~append(self~row(index)); end
  return out

::method items
  return self~rows~items

::method supplier
  return self~rows~supplier

::method makeArray
  return self~rows

::method refreshAll
  out=.array~new
  do row over self~rows; out~append(row~refreshAll); end
  return out

::class SnmpManagedRow subclass SnmpManagedObject public
::attribute tableName get

::method init
  expose tableName
  use strict arg sourceIdArg,sessionArg,mapArg,indexArg,tableArg
  self~init:super(sourceIdArg,sessionArg,mapArg,indexArg,"ROW")
  tableName=tableArg~string

::method scopeTable
  expose tableName
  return tableName

::class SnmpAgent subclass SnmpManagedObject public
::attribute agentId get

::method init
  expose agentId
  use strict arg agentIdArg,sessionArg,mapArg
  agentId=agentIdArg~string
  self~init:super("snmp:"||agentId,sessionArg,mapArg,.nil,"AGENT")

::method adopt
  use strict arg map
  self~implementationMap~adopt(map)
  return self

::method acceptNotification
  use strict arg notificationOid,varbinds
  implementationMap=self~implementationMap
  definition=implementationMap~notification(notificationOid)
  if definition==.nil then do
    evidence=.SnmpNotificationEvidence~new(.nil,varbinds)
    return self~emit("SNMP.NOTIFICATION.UNKNOWN",evidence)
  end

  target=self
  if definition~targetTable<>"" & definition~indexVarbind<>"" then do
    idxVb=varbinds~byName(definition~indexVarbind)
    if idxVb<>.nil then do
      tableDefinition=implementationMap~table(definition~targetTable)
      if tableDefinition<>.nil then target=self~tableObject(tableDefinition)~row(idxVb~value)
    end
  end
  /* Notifications are observations.  Adopt any resolved varbind state into
     the targeted managed object before publishing the semantic event, but do
     not manufacture transition events from the seeding operation itself. */
  do vb over varbinds~items
    if vb~definition==.nil then iterate
    if target~objectKind=="ROW" then do
      if vb~definition~kind<>"COLUMN" then iterate
      if vb~index==.nil then iterate
      if vb~index~key<>target~index~key then iterate
    end
    else do
      if vb~definition~kind<>"SCALAR" then iterate
    end
    target~seed(vb~definition~name,vb~value)
  end
  evidence=.SnmpNotificationEvidence~new(definition,varbinds)
  return target~emit(definition~eventType,evidence)

::requires "EventRuntime.cls"
::requires "json.cls"

::routine fragmentHas
  use strict arg obj,key
  return obj~hasIndex(key~string)
