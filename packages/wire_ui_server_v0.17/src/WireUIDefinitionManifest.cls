/* Exact immutable definition manifest for one access point/render-profile state. */
::class WireUIDefinitionManifest subclass AlchemyObject public
::attribute siteId get
::attribute profileId get
::attribute manifestId get

::method init
  expose siteId profileId manifestId entries byKey
  use arg siteId, profileId, definitions
  self~init:super(.WireUIAlchemy~metadata("Exact authorised Wire UI definition manifest"))
  siteId=siteId~string~strip
  profileId=profileId~string~strip
  if siteId="" then siteId="*"
  if profileId="" then profileId="generic"
  entries=.array~new
  byKey=.table~new

  defs=.array~new
  do d over definitions
    defs~append(d)
  end
  /* Definition keys are exact and version-qualified, so lexical order is stable. */
  keys=.array~new
  do d over defs; keys~append(d~definitionKey); end
  keys~sort

  canonical=siteId"|"profileId
  do key over keys
    selected=.nil
    do d over defs
      if d~definitionKey=key then do; selected=d; leave; end
    end
    if selected==.nil then iterate
    e=.table~new
    e["id"]=selected~definitionId
    e["version"]=self~numericVersion(selected~version)
    e["contentAddress"]=selected~contentAddress
    entries~append(e)
    byKey[selected~definitionKey]=e
    canonical ||= "|"selected~definitionKey"="selected~contentAddress
  end
  manifestId="wui-manifest-"self~token(canonical)
  self~registerStateVariable("manifestId","PUBLIC","deterministic exact definition-manifest identity")

::method definitions
  expose entries
  a=.array~new
  do e over entries
    c=.table~new; do k over e~allIndexes; c[k]=e[k]; end
    a~append(c)
  end
  return a

::method contains
  expose byKey
  use arg definitionId, version, contentAddress=""
  key=definitionId~string"@"version~string
  if \byKey~hasIndex(key) then return .false
  if contentAddress<>"" & byKey[key]["contentAddress"]<>contentAddress then return .false
  return .true

::method asWire
  expose siteId profileId manifestId
  f=.table~new
  f["siteId"]=siteId
  f["profileId"]=profileId
  f["manifestId"]=manifestId
  f["definitions"]=self~definitions
  return f

::method numericVersion private
  use arg version
  if datatype(version,"W") then return version+0
  return version

::method token private
  use arg text
  numeric digits 20
  h=2166136261
  text=text~string
  do i=1 to text~length
    h=(h*16777619 + text~substr(i,1)~c2d) // 2147483647
  end
  return d2x(h~format(,0),8)

::requires "WireUIAlchemy.cls"
