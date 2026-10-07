/* ooRexx WebDAV v0.1-dev4 state, sync and bounded byte plane. */

::class WebDavStateBuild public
::constant VERSION "0.1-dev4"
::constant API "webdav.state/0.1"


::class WebDavStateUtil public
::method trimQuotes class
  use arg value
  s=value~string~strip
  if length(s)>=2 & left(s,1)='"' & right(s,1)='"' then return substr(s,2,length(s)-2)
  return s
::method startsWithPath class
  use arg candidateArg,ancestorArg
  c=.StoragePath~normalize(candidateArg); a=.StoragePath~normalize(ancestorArg)
  if c=a then return .true
  if a='/' then return .true
  return left(c,length(a)+1)=a||'/'
::method split class
  use arg textArg,sepArg
  s=textArg~string; sep=sepArg~string; a=.array~new
  do forever
    p=s~pos(sep)
    if p=0 then do; a~append(s); leave; end
    a~append(s~substr(1,p-1)); s=s~substr(p+sep~length)
  end
  return a

::class WebDavIfEvaluator public
/* Evaluate the useful RFC 4918 If-header core:
 * - OR across state lists
 * - AND within one list
 * - Not state-token / Not entity-tag
 * - tagged-resource lists, applied only to the request resource
 *
 * This parser deliberately fails closed on malformed input.
 */
::method evaluate class
  use arg headerArg, requestPathArg, currentEtagArg="", tokenArrayArg=.nil
  h=headerArg~string~strip
  if h="" then return .false
  if tokenArrayArg==.nil then tokenArray=.array~new
  else tokenArray=tokenArrayArg
  requestPath=.StoragePath~normalize(requestPathArg)
  currentTag=.WebDavStateUtil~trimQuotes(currentEtagArg)

  lists=self~listsForRequest(h,requestPath)
  if lists==.nil | lists~items=0 then return .false
  do list over lists
    if self~evaluateList(list,currentTag,tokenArray) then return .true
  end
  return .false

::method listsForRequest class private
  use arg headerArg,requestPath
  h=headerArg~string
  out=.array~new
  pos=1; active=.true
  do while pos<=h~length
    pos=self~skipSpaces(h,pos)
    if pos>h~length then leave
    ch=h~substr(pos,1)
    if ch="<" then do
      q=h~pos(">",pos+1)
      if q=0 then return .nil
      tag=h~substr(pos+1,q-pos-1)
      active=self~tagMatches(tag,requestPath)
      pos=q+1
      iterate
    end
    if ch="(" then do
      q=self~matchingParen(h,pos)
      if q=0 then return .nil
      if active then out~append(h~substr(pos+1,q-pos-1))
      pos=q+1
      iterate
    end
    return .nil
  end
  return out

::method tagMatches class private
  use arg tagArg,requestPath
  t=tagArg~string
  p=t~pos("://")
  if p>0 then do
    tail=t~substr(p+3)
    slash=tail~pos("/")
    if slash=0 then t="/"
    else t=tail~substr(slash)
  end
  tagged=.StoragePath~normalize(t)
  if tagged=requestPath then return .true
  if requestPath='/' then return .false
  return right(tagged,length(requestPath))=requestPath

::method matchingParen class private
  use arg h,start
  depth=0
  do i=start to h~length
    ch=h~substr(i,1)
    if ch="(" then depth+=1
    else if ch=")" then do
      depth-=1
      if depth=0 then return i
      if depth<0 then return 0
    end
  end
  return 0

::method evaluateList class private
  use arg listArg,currentTag,tokenArray
  s=listArg~string; pos=1; any=.false
  do while pos<=s~length
    pos=self~skipSpaces(s,pos)
    if pos>s~length then leave
    negate=.false
    if s~substr(pos,3)~upper="NOT" then do
      after=pos+3
      if after>s~length | s~substr(after,1)=" " | s~substr(after,1)="09"x then do
        negate=.true; pos=after; pos=self~skipSpaces(s,pos)
      end
    end
    if pos>s~length then return .false
    ch=s~substr(pos,1)
    if ch="<" then do
      q=s~pos(">",pos+1); if q=0 then return .false
      token=s~substr(pos+1,q-pos-1); matched=self~hasToken(tokenArray,token); pos=q+1
    end
    else if ch="[" then do
      q=s~pos("]",pos+1); if q=0 then return .false
      tag=.WebDavStateUtil~trimQuotes(s~substr(pos+1,q-pos-1)); matched=(tag=currentTag); pos=q+1
    end
    else return .false
    any=.true
    if negate then matched=\matched
    if \matched then return .false
  end
  return any

::method hasToken class private
  use arg tokenArray,token
  do t over tokenArray
    if t~string=token then return .true
  end
  return .false

::method skipSpaces class private
  use arg s,pos
  do while pos<=s~length
    ch=s~substr(pos,1)
    if ch<>" " & ch<>"09"x & ch<>"0A"x & ch<>"0D"x then leave
    pos+=1
  end
  return pos


::class WebDavSyncChange public
::attribute sequence get
::attribute path get
::attribute status get
::attribute operation get
::attribute generation get
::method init
  expose sequence path status operation generation
  use arg sequenceArg,pathArg,statusArg,operationArg,generationArg=0
  sequence=sequenceArg+0; path=.StoragePath~normalize(pathArg); status=statusArg+0
  operation=operationArg~string~upper; generation=generationArg+0

::class WebDavSyncResult public
::attribute ok get
::attribute code get
::attribute token get
::attribute changes get
::method init
  expose ok code token changes
  use arg okArg,codeArg,tokenArg,changesArg
  ok=(okArg==.true); code=codeArg~string; token=tokenArg~string; changes=changesArg

::class WebDavSyncJournal public
::attribute maximumEntries get
::method init
  expose entries sequence floorSequence maximumEntries journalPath
  use arg maxEntriesArg=10000,journalArg=""
  maximumEntries=maxEntriesArg+0
  if maximumEntries<100 then maximumEntries=100
  entries=.array~new; sequence=0; floorSequence=0; journalPath=journalArg~string
  if journalPath<>"" then self~load

::method record
  expose entries sequence floorSequence maximumEntries
  use arg pathArg,statusArg=200,operationArg="CHANGE",generationArg=0
  sequence+=1
  entries~append(.WebDavSyncChange~new(sequence,pathArg,statusArg,operationArg,generationArg))
  if entries~items>maximumEntries then do
    dropCount=entries~items-maximumEntries
    new=.array~new
    do i=dropCount+1 to entries~items; new~append(entries[i]); end
    entries=new
    floorSequence=sequence-entries~items
  end
  self~save
  return sequence

::method currentToken
  expose sequence
  return "urn:oorexx:webdav:sync:"||sequence

::method changesSince
  expose entries sequence floorSequence
  use arg tokenArg,rootArg="/",limitArg=4096
  root=.StoragePath~normalize(rootArg); limit=limitArg+0
  if limit<1 then limit=1
  if tokenArg=="" then since=0
  else do
    prefix="urn:oorexx:webdav:sync:"
    t=tokenArg~string~strip
    if left(t,length(prefix))<>prefix then return .WebDavSyncResult~new(.false,"INVALID_TOKEN",self~currentToken,.array~new)
    n=t~substr(length(prefix)+1)
    if \datatype(n,"W") then return .WebDavSyncResult~new(.false,"INVALID_TOKEN",self~currentToken,.array~new)
    since=n+0
    if since<floorSequence then return .WebDavSyncResult~new(.false,"TOKEN_EXPIRED",self~currentToken,.array~new)
    if since>sequence then return .WebDavSyncResult~new(.false,"INVALID_TOKEN",self~currentToken,.array~new)
  end
  out=.array~new
  do c over entries
    if c~sequence<=since then iterate
    if \.WebDavStateUtil~startsWithPath(c~path,root) then iterate
    out~append(c)
    if out~items>=limit then leave
  end
  return .WebDavSyncResult~new(.true,"OK",self~currentToken,out)

::method save
  expose entries journalPath sequence floorSequence maximumEntries
  if journalPath="" then return self
  ignore=stream(journalPath,"c","open write replace")
  call lineout journalPath,"WEBDAVSYNC1"||"09"x||sequence||"09"x||floorSequence||"09"x||maximumEntries
  do c over entries
    call lineout journalPath,c~sequence||"09"x||c~status||"09"x||c~generation||"09"x||c~operation||"09"x||c~path
  end
  call lineout journalPath
  return self

::method load
  expose entries journalPath sequence floorSequence maximumEntries
  if journalPath="" | stream(journalPath,"c","query exists")="" then return self
  h=linein(journalPath); f=.WebDavStateUtil~split(h,"09"x)
  if f~items<4 | f[1]<>"WEBDAVSYNC1" then do; call stream journalPath,"c","close"; return self; end
  sequence=f[2]+0; floorSequence=f[3]+0; maximumEntries=f[4]+0
  do while lines(journalPath)>0
    line=linein(journalPath); if line="" then iterate
    x=.WebDavStateUtil~split(line,"09"x); if x~items<5 then iterate
    entries~append(.WebDavSyncChange~new(x[1]+0,x[5],x[2]+0,x[4],x[3]+0))
  end
  call stream journalPath,"c","close"; return self


/* Map StorageRefs to provider-neutral StorageByteSource objects/factories.
 * The source object is opened at the requested offset for each bounded read.
 */
::class WebDavByteSourceRegistry public
::method init
  expose sources
  sources=.directory~new
::method register
  expose sources
  use arg refArg,sourceArg
  if refArg==.nil | sourceArg==.nil then raise syntax 88.900 array("StorageRef and byte source are mandatory")
  sources[refArg~objectId]=sourceArg; return self
::method sourceFor
  expose sources
  use arg refArg
  if refArg==.nil then return .nil
  return sources[refArg~objectId]
::method has
  expose sources
  use arg refArg
  if refArg==.nil then return .false
  return sources~hasIndex(refArg~objectId)
::method readAt
  expose sources
  use arg refArg,offsetArg,lengthArg,maximumArg=8388608
  source=self~sourceFor(refArg)
  if source==.nil then return .nil
  offset=offsetArg+0; need=lengthArg+0; maximum=maximumArg+0
  if offset<0 | need<0 | need>maximum then raise syntax 88.900 array("invalid bounded DAV read")
  if offset+need>source~sizeBytes then raise syntax 88.900 array("DAV read beyond Storage object")
  if need=0 then return ""
  source~openAt(offset)
  out=""; expected=offset; remaining=need
  do while remaining>0
    chunk=source~readChunk(remaining)
    if chunk==.nil | chunk~offset<>expected then do; source~close; raise syntax 88.900 array("invalid StorageByteSource chunk"); end
    data=chunk~data; got=data~length
    if got<1 | got>remaining then do; source~close; raise syntax 88.900 array("invalid StorageByteSource bounded length"); end
    out=out||data; expected+=got; remaining-=got
    if chunk~eof & remaining>0 then do; source~close; raise syntax 88.900 array("unexpected StorageByteSource EOF"); end
  end
  source~close
  return out


/* A bounded copy helper for a WebDAV caller that already has a
 * StorageByteSource.  The returned sink remains storage-provider authority.
 */
::class WebDavBoundedTransfer public
::method copy class
  use arg sourceArg,sinkArg,totalArg,chunkArg=8388608
  total=totalArg+0; chunkSize=chunkArg+0
  if sourceArg==.nil | sinkArg==.nil | total<0 | chunkSize<1 then raise syntax 88.900 array("invalid bounded transfer")
  sourceArg~openAt(0); sinkArg~openAt(0,total)
  offset=0
  do while offset<total
    want=total-offset; if want>chunkSize then want=chunkSize
    c=sourceArg~readChunk(want)
    if c==.nil | c~offset<>offset then do; sourceArg~close; sinkArg~close; raise syntax 88.900 array("invalid source chunk"); end
    data=c~data
    if data~length<1 | data~length>want then do; sourceArg~close; sinkArg~close; raise syntax 88.900 array("invalid source chunk length"); end
    written=sinkArg~writeChunk(data)
    if written<>data~length then do; sourceArg~close; sinkArg~close; raise syntax 88.900 array("short sink write"); end
    sinkArg~flush
    offset+=written
  end
  sourceArg~close; sinkArg~close
  return offset

::requires "StorageFabric.cls"
::requires "StorageStreaming.cls"
