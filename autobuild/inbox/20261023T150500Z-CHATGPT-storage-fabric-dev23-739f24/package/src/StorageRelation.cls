/* ooRexx Storage Fabric relation/query projection.
 *
 * Read-only executable implementation for provider-neutral structured data.
 * Mutation contracts are deliberately designed here but not executable yet.
 * FUSE :? syntax is a client projection; providers never receive raw query
 * strings and therefore cannot accidentally treat path text as SQL.
 */

::class StorageRelationBuild public
::constant VERSION "0.1-dev14"
::constant API "storage.fabric.relation/0.1"

::class StorageRelationCapability public
::constant QUERY "QUERY"
::constant GET "GET"
::constant SNAPSHOT "SNAPSHOT"
::constant PROJECT_FIELDS "PROJECT_FIELDS"
::constant MUTATE "MUTATE"            /* reserved: design contract only */
::constant COMPARE_AND_SWAP "COMPARE_AND_SWAP" /* reserved */
::constant TRANSACTION "TRANSACTION"  /* reserved */

::class StorageRelationOperator public
::constant EQ "EQ"
::constant NE "NE"
::constant GT "GT"
::constant GE "GE"
::constant LT "LT"
::constant LE "LE"
::constant CONTAINS "CONTAINS"
::constant PREFIX "PREFIX"
::constant EXISTS "EXISTS"

::class StorageRelationClause public
::attribute field get
::attribute operator get
::attribute expected get
::method init
  expose field operator expected
  use arg fieldArg,operatorArg="EQ",expectedArg=""
  field=fieldArg~string~strip
  operator=operatorArg~string~strip~upper
  expected=expectedArg
  if field="" then raise syntax 88.900 array("relation query field is mandatory")
::method matches
  use arg row
  if row==.nil then return .false
  actual=row~field(self~field)
  if self~operator=.StorageRelationOperator~EXISTS then return actual<>.nil
  if actual==.nil then return .false
  a=actual~string; e=self~expected~string
  select
    when self~operator=.StorageRelationOperator~EQ then return a=e
    when self~operator=.StorageRelationOperator~NE then return a<>e
    when self~operator=.StorageRelationOperator~CONTAINS then return pos(e~lower,a~lower)>0
    when self~operator=.StorageRelationOperator~PREFIX then return left(a~lower,length(e))=e~lower
    when self~operator=.StorageRelationOperator~GT then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0>e+0; end
    when self~operator=.StorageRelationOperator~GE then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0>=e+0; end
    when self~operator=.StorageRelationOperator~LT then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0<e+0; end
    when self~operator=.StorageRelationOperator~LE then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0<=e+0; end
    otherwise raise syntax 88.900 array("unsupported relation query operator: "||self~operator)
  end

::class StorageRelationQuery public
::attribute sourceText get
::method init
  expose clauses sourceText
  use arg sourceArg=""
  clauses=.array~new
  sourceText=sourceArg~string
::method add
  expose clauses
  use arg clause
  if clause==.nil then raise syntax 88.900 array("relation query clause is mandatory")
  clauses~append(clause)
  return self
::method clauses
  expose clauses
  return clauses
::method count
  expose clauses
  return clauses~items
::method matches
  expose clauses
  use arg row
  do c over clauses
    if \c~matches(row) then return .false
  end
  return .true

/* Bounded query grammar used by :? paths.
 *   field=value   EQ
 *   field!=value  NE
 *   field>=value  GE
 *   field<=value  LE
 *   field>value   GT
 *   field<value   LT
 *   field~value   CONTAINS
 *   field^value   PREFIX
 *   field?        EXISTS
 * Clauses are ANDed with '&'. Percent escapes are decoded. Raw SQL is never
 * accepted or passed to a provider. */
::class StorageRelationQueryParser public
::method parse class
  use arg textArg
  text=textArg~string
  q=.StorageRelationQuery~new(text)
  if text="" then return q
  rest=text
  do while rest<>""
    amp=pos("&",rest)
    if amp=0 then do; term=rest; rest=""; end
    else do; term=left(rest,amp-1); rest=substr(rest,amp+1); end
    if term="" then iterate
    q~add(self~parseTerm(term))
  end
  return q
::method parseTerm class private
  use arg termArg
  t=termArg~string
  if right(t,1)="?" & pos("=",t)=0 & pos(">",t)=0 & pos("<",t)=0 then return .StorageRelationClause~new(self~decode(left(t,length(t)-1)),.StorageRelationOperator~EXISTS,"")
  ops=.array~of("!=",">=","<=","=",">","<","~","^")
  names=.array~of(.StorageRelationOperator~NE,.StorageRelationOperator~GE,.StorageRelationOperator~LE,.StorageRelationOperator~EQ,.StorageRelationOperator~GT,.StorageRelationOperator~LT,.StorageRelationOperator~CONTAINS,.StorageRelationOperator~PREFIX)
  do i=1 to ops~items
    p=pos(ops[i],t)
    if p>0 then do
      f=self~decode(left(t,p-1))
      v=self~decode(substr(t,p+length(ops[i])))
      return .StorageRelationClause~new(f,names[i],v)
    end
  end
  raise syntax 88.900 array("invalid relation query term: "||t)
::method decode class private
  use arg textArg
  s=textArg~string
  out=""; i=1
  do while i<=length(s)
    ch=substr(s,i,1)
    if ch="%" & i+2<=length(s) then do
      hx=substr(s,i+1,2)
      if datatype(hx,"X") then do; out=out||x2c(hx); i+=3; iterate; end
    end
    if ch="+" then out=out||" "; else out=out||ch
    i+=1
  end
  return out

::class StorageRelationRow public
::attribute rowId get
::attribute versionToken get
::method init
  expose rowId versionToken fields
  use arg idArg,fieldMapArg=.nil,versionArg=""
  rowId=idArg~string
  versionToken=versionArg~string
  if rowId="" then raise syntax 88.900 array("relation row id is mandatory")
  if fieldMapArg==.nil then fields=.directory~new; else fields=fieldMapArg
::method field
  expose fields
  use arg nameArg
  return fields[nameArg~string]
::method fieldNames
  expose fields
  a=.array~new
  do n over fields; a~append(n); end
  return a
::method canonical
  expose fields rowId versionToken
  out="id"||"09"x||rowId||d2c(10)
  if versionToken<>"" then out=out||"version"||"09"x||versionToken||d2c(10)
  do n over fields
    v=fields[n]
    if v<>.nil then out=out||n||"09"x||v~string||d2c(10)
  end
  return out

/* A query result is an immutable membership binding. snapshotToken is supplied
 * by the provider/Storage snapshot authority; rows are the exact membership
 * observed for that binding. */
::class StorageRelationResult public
::attribute relationName get
::attribute snapshotToken get
::attribute providerId get
::method init
  expose relationName snapshotToken providerId rows byId
  use arg relationArg,providerArg,snapshotArg="",rowsArg=.nil
  relationName=relationArg~string
  providerId=providerArg~string
  snapshotToken=snapshotArg~string
  if rowsArg==.nil then rows=.array~new; else rows=rowsArg
  byId=.directory~new
  do r over rows; byId[r~rowId]=r; end
::method rows
  expose rows
  return rows
::method row
  expose byId
  use arg idArg
  return byId[idArg~string]
::method count
  expose rows
  return rows~items

/* Provider contract. Subclasses implement query/get. The mutation methods are
 * intentionally absent in dev14; see RELATION_QUERY.md for the designed R/W
 * contract and conflict/authority requirements. */
::class StorageRelationProvider public
::attribute providerId get
::method init
  expose providerId capabilities
  use arg idArg
  providerId=idArg~string~strip
  capabilities=.directory~new
  if providerId="" then raise syntax 88.900 array("relation provider id is mandatory")
::method declareCapability
  expose capabilities
  use arg capArg
  capabilities[capArg~string~upper]=.true
  return self
::method hasCapability
  expose capabilities
  use arg capArg
  return capabilities[capArg~string~upper]<>.nil
::method query
  raise syntax 88.900 array("relation provider must implement query")
::method get
  raise syntax 88.900 array("relation provider must implement get")

/* Executable reference provider used for qualification and for ooRexx object
 * collections. It demonstrates the provider boundary without SQL coupling. */
::class StorageObjectRelationProvider subclass StorageRelationProvider public
::method init
  expose relations snapshots nextSnapshot
  use arg idArg="object-relation"
  self~init:super(idArg)
  self~declareCapability(.StorageRelationCapability~QUERY)
  self~declareCapability(.StorageRelationCapability~GET)
  self~declareCapability(.StorageRelationCapability~SNAPSHOT)
  self~declareCapability(.StorageRelationCapability~PROJECT_FIELDS)
  relations=.directory~new
  snapshots=.directory~new
  nextSnapshot=1
::method addRow
  expose relations
  use arg relationArg,row
  rn=relationArg~string
  a=relations[rn]
  if a==.nil then do; a=.array~new; relations[rn]=a; end
  a~append(row)
  return self
::method query
  expose relations snapshots nextSnapshot
  use arg relationArg,queryArg=.nil,snapshotArg=""
  rn=relationArg~string
  a=relations[rn]
  if a==.nil then a=.array~new
  if queryArg==.nil then queryArg=.StorageRelationQuery~new("")
  token=snapshotArg~string
  if token<>"" then do
    prior=snapshots[token]
    if prior==.nil then return .nil
    return prior
  end
  rows=.array~new
  do row over a
    if queryArg~matches(row) then rows~append(row)
  end
  token="REL:"||self~providerId||":"||nextSnapshot
  nextSnapshot+=1
  answer=.StorageRelationResult~new(rn,self~providerId,token,rows)
  snapshots[token]=answer
  return answer
::method get
  expose relations
  use arg relationArg,rowIdArg
  a=relations[relationArg~string]
  if a==.nil then return .nil
  do row over a
    if row~rowId=rowIdArg~string then return row
  end
  return .nil

::class StorageRelationMount public
::attribute path get
::attribute provider get
::attribute relationName get
::attribute writePolicy get
::method init
  expose path provider relationName writePolicy
  use arg pathArg,providerArg,relationArg,policyArg="READ_ONLY"
  path=.StoragePath~normalize(pathArg)
  provider=providerArg
  relationName=relationArg~string
  writePolicy=policyArg~string~upper
  if provider==.nil | relationName="" then raise syntax 88.900 array("relation mount provider/relation are mandatory")

::class StorageRelationResolved public
::attribute mount get
::attribute relationResult get
::method init
  expose mount relationResult
  use arg mountArg,resultArg
  mount=mountArg; relationResult=resultArg

::class StorageRelationRegistry public
::method init
  expose mounts
  mounts=.directory~new
::method mount
  expose mounts
  use arg pathArg,providerArg,relationArg,policyArg="READ_ONLY"
  m=.StorageRelationMount~new(pathArg,providerArg,relationArg,policyArg)
  mounts[m~path]=m
  return m
::method at
  expose mounts
  use arg pathArg
  return mounts[.StoragePath~normalize(pathArg)]

/* Parse /customers:?country=GB[/row[/field]]. The query selector is a
 * directory component, not a named stream. */
::class StorageRelationVirtualPath public
::attribute original get
::attribute relationPath get
::attribute queryText get
::attribute rowId get
::attribute fieldName get
::attribute valid get
::method init
  expose original relationPath queryText rowId fieldName valid
  use arg pathArg
  original=.StoragePath~normalize(pathArg)
  relationPath=""; queryText=""; rowId=""; fieldName=""; valid=.false
  parts=self~split(original)
  qi=0
  do i=1 to parts~items
    c=parts[i]
    p=pos(":?",c)
    if p>0 then do
      qi=i
      stem=left(c,p-1)
      queryText=substr(c,p+2)
      base=.array~new
      do j=1 to i-1; base~append(parts[j]); end
      if stem<>"" then base~append(stem)
      relationPath=self~join(base)
      leave
    end
  end
  if qi=0 then return
  if parts~items>=qi+1 then rowId=parts[qi+1]
  if parts~items>=qi+2 then fieldName=parts[qi+2]
  if parts~items>qi+2 then return
  valid=.true
::method split private
  use arg pathArg
  p=.StoragePath~normalize(pathArg); a=.array~new
  if p="/" then return a
  rest=substr(p,2)
  do while rest<>""
    slash=pos("/",rest)
    if slash=0 then do; a~append(rest); leave; end
    a~append(left(rest,slash-1)); rest=substr(rest,slash+1)
  end
  return a
::method join private
  use arg a
  if a~items=0 then return "/"
  out=""; do x over a; out=out||"/"||x; end
  return .StoragePath~normalize(out)

/* Read-only operation core suitable for delegation from FUSE RPC semantics.
 * Result membership is cached by the exact query path, giving stable traversal
 * during a single daemon lifetime. Storage-native generation/snapshot binding
 * can supply/reopen the provider snapshotToken without changing this API. */
::class StorageRelationFuseReadOnlyCore public
::attribute registry get
::method init
  expose registry results handles nextHandle
  use arg registryArg=.nil
  if registryArg==.nil then registry=.StorageRelationRegistry~new; else registry=registryArg
  results=.directory~new; handles=.directory~new; nextHandle=1
::method handlesPath
  use arg pathArg
  vp=.StorageRelationVirtualPath~new(pathArg)
  return vp~valid
::method resolve private
  expose registry results
  use arg vp
  m=registry~at(vp~relationPath)
  if m==.nil then return .nil
  key=vp~relationPath||":?"||vp~queryText
  answer=results[key]
  if answer==.nil then do
    q=.StorageRelationQueryParser~parse(vp~queryText)
    answer=m~provider~query(m~relationName,q)
    if answer<>.nil then results[key]=answer
  end
  if answer==.nil then return .nil
  return .StorageRelationResolved~new(m,answer)
::method getattr
  use arg pathArg
  vp=.StorageRelationVirtualPath~new(pathArg)
  if \vp~valid then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"not a relation query path")
  rr=self~resolve(vp); if rr==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"relation/query absent")
  rel=rr~relationResult
  if vp~rowId="" then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"QUERY:"||rel~snapshotToken,0),"")
  row=rel~row(vp~rowId); if row==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"row absent from query snapshot")
  if vp~fieldName="" then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"QUERY:"||rel~snapshotToken,0),"")
  value=row~field(vp~fieldName); if value==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"field absent")
  return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~FILE,pathArg,length(value~string),"QUERY:"||rel~snapshotToken,0),"")
::method readdir
  use arg pathArg
  vp=.StorageRelationVirtualPath~new(pathArg)
  if \vp~valid then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"not a relation query path")
  rr=self~resolve(vp); if rr==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"relation/query absent")
  rel=rr~relationResult; out=.array~new
  if vp~rowId="" then do r over rel~rows; out~append(r~rowId); end
  else do
    row=rel~row(vp~rowId); if row==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"row absent from query snapshot")
    if vp~fieldName<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTDIR,.nil,"field is not a directory")
    do n over row~fieldNames; out~append(n); end
  end
  return .StorageFuseResult~new(0,out,"snapshot="||rel~snapshotToken)
::method open
  expose handles nextHandle
  use arg pathArg,modeArg="READ"
  mode=modeArg~string~upper
  if pos("W",mode)>0 | pos("WRITE",mode)>0 | mode="RW" then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  vp=.StorageRelationVirtualPath~new(pathArg)
  if \vp~valid | vp~rowId="" then return .StorageFuseResult~new(.StorageFuseErrno~EISDIR,.nil,"query/row directory is not openable")
  rr=self~resolve(vp); if rr==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"relation/query absent")
  row=rr~relationResult~row(vp~rowId); if row==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"row absent")
  if vp~fieldName="" then data=row~canonical
  else do; v=row~field(vp~fieldName); if v==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"field absent"); data=v~string; end
  h=.StorageRelationReadHandle~new("rq"||nextHandle,pathArg,data,rr~relationResult~snapshotToken); nextHandle+=1; handles[h~handleId]=h
  return .StorageFuseResult~new(0,h,"snapshot="||rr~relationResult~snapshotToken)
::method read
  expose handles
  use arg handleArg,offsetArg,countArg
  if handleArg~hasMethod("HANDLEID") then h=handleArg; else h=handles[handleArg~string]
  if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"relation read handle absent")
  return .StorageFuseResult~new(0,h~readAt(offsetArg,countArg),"")
::method release
  expose handles
  use arg handleArg
  if handleArg~hasMethod("HANDLEID") then id=handleArg~handleId; else id=handleArg~string
  h=handles[id]; if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"relation read handle absent")
  handles~remove(id); return .StorageFuseResult~new(0,.true,"")

::class StorageRelationReadHandle public
::attribute handleId get
::attribute path get
::attribute snapshotToken get
::method init
  expose handleId path data snapshotToken
  use arg idArg,pathArg,dataArg,snapshotArg=""
  handleId=idArg~string; path=pathArg~string; data=dataArg~string; snapshotToken=snapshotArg~string
::method readAt
  expose data
  use arg offsetArg,countArg
  off=offsetArg+0; n=countArg+0
  if off<0 | n<=0 | off>=length(data) then return ""
  return substr(data,off+1,n)

::requires "src/StorageFuse.cls"

/* Composite FUSE core: query paths are routed to the read-only relation core,
 * everything else remains owned by the existing StorageFuseOperationCore.
 * This is intentionally above libfuse/RPC so the native protocol stays
 * storage-neutral. */
::class StorageFuseCompositeCore public
::attribute storageCore get
::attribute relationCore get
::method init
  expose storageCore relationCore
  use arg storageArg=.nil,relationArg=.nil
  if storageArg==.nil then storageCore=.StorageFuseOperationCore~new; else storageCore=storageArg
  if relationArg==.nil then relationCore=.StorageRelationFuseReadOnlyCore~new; else relationCore=relationArg
::method isRelation private
  expose relationCore
  use arg pathArg
  return relationCore~handlesPath(pathArg)
::method getattr
  expose storageCore relationCore
  use arg pathArg
  if self~isRelation(pathArg) then return relationCore~getattr(pathArg)
  return storageCore~getattr(pathArg)
::method readdir
  expose storageCore relationCore
  use arg pathArg
  if self~isRelation(pathArg) then return relationCore~readdir(pathArg)
  return storageCore~readdir(pathArg)
::method open
  expose storageCore relationCore
  use arg pathArg,modeArg="READ"
  if self~isRelation(pathArg) then return relationCore~open(pathArg,modeArg)
  return storageCore~open(pathArg,modeArg)
::method read
  expose storageCore relationCore
  use arg handleArg,offsetArg,countArg
  id=handleArg~string
  if left(id,2)="rq" then return relationCore~read(handleArg,offsetArg,countArg)
  return storageCore~read(handleArg,offsetArg,countArg)
::method release
  expose storageCore relationCore
  use arg handleArg
  id=handleArg~string
  if left(id,2)="rq" then return relationCore~release(handleArg)
  return storageCore~release(handleArg)
::method create
  expose storageCore
  use arg pathArg,modeArg="RW"
  if self~isRelation(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~create(pathArg,modeArg)
::method mkdir
  expose storageCore
  use arg pathArg
  if self~isRelation(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~mkdir(pathArg)
::method write
  expose storageCore
  use arg handleArg,offsetArg,dataArg
  if left(handleArg~string,2)="rq" then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~write(handleArg,offsetArg,dataArg)
::method truncate
  expose storageCore
  use arg handleArg,sizeArg
  if left(handleArg~string,2)="rq" then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~truncate(handleArg,sizeArg)
::method truncatePath
  expose storageCore
  use arg pathArg,sizeArg
  if self~isRelation(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~truncatePath(pathArg,sizeArg)
::method unlink
  expose storageCore
  use arg pathArg
  if self~isRelation(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~unlink(pathArg)
::method rename
  expose storageCore
  use arg oldArg,newArg
  if self~isRelation(oldArg) | self~isRelation(newArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~rename(oldArg,newArg)
::method rmdir
  expose storageCore
  use arg pathArg
  if self~isRelation(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"relation projection is read-only in dev14")
  return storageCore~rmdir(pathArg)
::method readVirtual
  expose storageCore
  use arg pathArg
  return storageCore~readVirtual(pathArg)
