/* Source-code evidence catalogue used by the Builder's self-hosting acceptance. */
::class WireUISourceFile subclass AlchemyObject public
::attribute sourceId get
::attribute path get
::attribute contentAddress get
::attribute lineCount get
::method init
  expose sourceId path contentAddress lineCount classes methods attributes constants requires packageOptions
  use arg sourceId, path, text, classes=.nil, methods=.nil, attributes=.nil, constants=.nil, requires=.nil, packageOptions=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Source file evidence inspected by Wire UI Builder"))
  sourceId=sourceId~string~strip; path=path~string
  classes=.WireUIDesignUtil~copyArray(classes); methods=.WireUIDesignUtil~copyArray(methods); attributes=.WireUIDesignUtil~copyArray(attributes); constants=.WireUIDesignUtil~copyArray(constants); requires=.WireUIDesignUtil~copyArray(requires); packageOptions=.WireUIDesignUtil~copyArray(packageOptions)
  lineCount=text~countStr(.endOfLine)+1
  contentAddress="source-hc-" || text~hashCode~c2x
::method classes; expose classes; return .WireUIDesignUtil~copyArray(classes)
::method methods; expose methods; return .WireUIDesignUtil~copyArray(methods)
::method attributes; expose attributes; return .WireUIDesignUtil~copyArray(attributes)
::method constants; expose constants; return .WireUIDesignUtil~copyArray(constants)
::method requires; expose requires; return .WireUIDesignUtil~copyArray(requires)
::method packageOptions; expose packageOptions; return .WireUIDesignUtil~copyArray(packageOptions)
::method canonicalText
  expose sourceId path contentAddress lineCount classes methods attributes constants requires packageOptions
  return sourceId"|"path"|"contentAddress"|"lineCount"|".WireUIDesignUtil~canonicalArray(classes)"|".WireUIDesignUtil~canonicalArray(methods)"|".WireUIDesignUtil~canonicalArray(attributes)"|".WireUIDesignUtil~canonicalArray(constants)"|".WireUIDesignUtil~canonicalArray(requires)"|".WireUIDesignUtil~canonicalArray(packageOptions)
::method asWire
  expose sourceId path contentAddress lineCount classes methods attributes constants requires packageOptions
  d=.directory~new; d["id"]=path; d["sourceId"]=sourceId; d["path"]=path; d["contentAddress"]=contentAddress; d["lineCount"]=lineCount
  d["classes"]=.WireUIDesignUtil~copyArray(classes); d["methods"]=.WireUIDesignUtil~copyArray(methods); d["attributes"]=.WireUIDesignUtil~copyArray(attributes); d["constants"]=.WireUIDesignUtil~copyArray(constants); d["requires"]=.WireUIDesignUtil~copyArray(requires); d["packageOptions"]=.WireUIDesignUtil~copyArray(packageOptions)
  return d

::class WireUISourceCatalogue subclass AlchemyObject public
::attribute catalogueId get
::attribute contentAddress get
::method init
  expose catalogueId files contentAddress
  use arg catalogueId="WIRE_UI_BUILDER_SOURCE"
  self~init:super(.WireUIDesignAlchemy~metadata("Source catalogue for Builder source-aware authoring"))
  catalogueId=catalogueId~string~strip; files=.table~new; contentAddress=""
::method addFile
  expose files contentAddress
  use arg path, logicalPath=""
  path=path~string; logicalPath=logicalPath~string~strip
  stream=.stream~new(path); r=stream~open("READ"); if r<>"READY:" & r<>"READY" then return .WireUIDesignResult~failure("SOURCE_OPEN_FAILED",path)
  text=""; classes=.array~new; methods=.array~new; attrs=.array~new; consts=.array~new; reqs=.array~new; opts=.array~new; lineNo=0
  do while stream~lines>0
    line=stream~lineIn; lineNo += 1; text ||= line || .endOfLine
    stripped=line~strip
    if stripped="" then iterate
    directive=word(stripped,1)~translate
    select
      when directive="::CLASS" then classes~append(self~symbol(word(stripped,2),lineNo,stripped))
      when directive="::METHOD" then methods~append(self~symbol(word(stripped,2),lineNo,stripped))
      when directive="::ATTRIBUTE" then attrs~append(self~symbol(word(stripped,2),lineNo,stripped))
      when directive="::CONSTANT" then consts~append(self~symbol(word(stripped,2),lineNo,stripped))
      when directive="::REQUIRES" then reqs~append(stripped~substr(11)~strip)
      when directive="::OPTIONS" then opts~append(stripped~substr(10)~strip)
      otherwise nop
    end
  end
  stream~close
  if logicalPath="" then logicalPath=path
  sourceId=filespec("N",logicalPath); if sourceId="" then sourceId=logicalPath
  f=.WireUISourceFile~new(sourceId,logicalPath,text,classes,methods,attrs,consts,reqs,opts)
  files[logicalPath]=f; contentAddress=""
  return .WireUIDesignResult~success(f,"SOURCE_ADDED")
::method addFiles
  use arg paths
  do p over paths; r=self~addFile(p); if \r~ok then return r; end
  return .WireUIDesignResult~success(self,"SOURCES_ADDED")
::method addTree
  use arg root, pattern="*.cls", recursive=.true, logicalRoot=""
  root=root~string~strip; pattern=pattern~string~strip; logicalRoot=logicalRoot~string~strip
  if root="" then return .WireUIDesignResult~failure("SOURCE_TREE_ROOT_REQUIRED")
  call SysFileTree root, "rootMatch.", "DO"
  if rootMatch.0=1 then root=rootMatch.1
  do while root~length>1 & root~right(1)="/"; root=root~left(root~length-1); end
  if pattern="" then pattern="*.cls"
  if logicalRoot="" then logicalRoot=filespec("N",root)
  if logicalRoot="" then logicalRoot="source"
  options="FO"; if recursive then options="FOS"
  call SysFileTree root"/"pattern, "matches.", options
  paths=.array~new
  do i=1 to matches.0; paths~append(matches.i); end
  if paths~items=0 then return .WireUIDesignResult~failure("SOURCE_TREE_EMPTY",root"/"pattern)
  paths~sort
  do path over paths
    relative=path
    prefix=root"/"
    if relative~left(prefix~length)=prefix then relative=relative~substr(prefix~length+1)
    logical=logicalRoot; if relative<>"" then logical ||= "/"relative
    r=self~addFile(path,logical); if \r~ok then return r
  end
  return .WireUIDesignResult~success(self,"SOURCE_TREE_ADDED")
::method files
  expose files
  out=.array~new; keys=files~allIndexes; keys~sort; do k over keys; out~append(files[k]); end; return out
::method file
  expose files
  use arg key
  key=key~string
  if files~hasIndex(key) then return files[key]
  do path over files~allIndexes
    f=files[path]
    if f~sourceId=key | f~path=key then return f
  end
  return .nil
::method fileCount; expose files; return files~items
::method classCount
  n=0; do f over self~files; n+=f~classes~items; end; return n
::method methodCount
  n=0; do f over self~files; n+=f~methods~items; end; return n
::method attributeCount
  n=0; do f over self~files; n+=f~attributes~items; end; return n
::method constantCount
  n=0; do f over self~files; n+=f~constants~items; end; return n
::method packageOptionCount
  n=0; do f over self~files; n+=f~packageOptions~items; end; return n
::method seal
  expose contentAddress catalogueId
  text=catalogueId; do f over self~files; text ||= "|"f~canonicalText; end
  contentAddress="sourcecat-" || .WireUIDesignUtil~token(text)
  return .WireUIDesignResult~success(self,"SOURCE_CATALOGUE_SEALED")
::method asWire
  expose catalogueId contentAddress
  d=.directory~new; d["catalogueId"]=catalogueId; d["contentAddress"]=contentAddress
  aa=.array~new; do f over self~files; aa~append(f~asWire); end; d["files"]=aa; d["fileCount"]=aa~items; d["classCount"]=self~classCount; d["methodCount"]=self~methodCount; d["attributeCount"]=self~attributeCount; d["constantCount"]=self~constantCount; d["packageOptionCount"]=self~packageOptionCount
  return d
::method symbol private
  use arg name,lineNo,signature
  d=.directory~new; d["name"]=name; d["line"]=lineNo; d["signature"]=signature; return d
::requires "WireUIDesignSupport.cls"
