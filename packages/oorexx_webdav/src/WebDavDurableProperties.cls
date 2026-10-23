/* Durable DAV-only collection dead-property store.
 * File/object dead properties remain StorageEA authority.
 */
::class WebDavDurablePropertyBuild public
::constant VERSION "0.1-dev5"
::constant API "webdav.collection-properties/0.1"

::class WebDavPropertyHex public
::method enc class
  use arg valueArg
  return c2x(valueArg~string)
::method dec class
  use arg valueArg
  v=valueArg~string
  if v="" then return ""
  return x2c(v)

::class WebDavDurableCollectionPropertyStore public
::method init
  expose journalPath byPath
  use arg journalArg
  journalPath=journalArg~string
  if journalPath="" then raise syntax 88.900 array("collection property journal path is mandatory")
  byPath=.directory~new
  self~load

::method set
  expose byPath
  use arg pathArg,nsArg,nameArg,valueArg
  p=.StoragePath~normalize(pathArg)
  key=nsArg~string~lower||"|"||nameArg~string~lower
  d=byPath[p]
  if d==.nil then do; d=.directory~new; byPath[p]=d; end
  d[key]=.WebDavDeadProperty~new(nsArg,nameArg,valueArg)
  self~save
  return .true

::method remove
  expose byPath
  use arg pathArg,nsArg,nameArg
  p=.StoragePath~normalize(pathArg); d=byPath[p]
  if d==.nil then return .false
  key=nsArg~string~lower||"|"||nameArg~string~lower
  if d[key]==.nil then return .false
  d~remove(key)
  self~save
  return .true

::method all
  expose byPath
  use arg pathArg
  p=.StoragePath~normalize(pathArg); d=byPath[p]; a=.array~new
  if d==.nil then return a
  do k over d; a~append(d[k]); end
  return a

::method moveTree
  expose byPath
  use arg sourceArg,destinationArg,copyOnly=.false
  source=.StoragePath~normalize(sourceArg); destination=.StoragePath~normalize(destinationArg)
  paths=.array~new
  do p over byPath
    if .WebDavUtil~startsWithPath(p,source) then paths~append(p)
  end
  do p over paths
    suffix=p~substr(length(source)+1)
    np=.StoragePath~normalize(destination||suffix)
    copied=.directory~new
    do k over byPath[p]
      prop=byPath[p][k]
      copied[k]=.WebDavDeadProperty~new(prop~namespace,prop~name,prop~value)
    end
    byPath[np]=copied
    if \copyOnly then byPath~remove(p)
  end
  self~save
  return self

::method save
  expose journalPath byPath
  ignore=stream(journalPath,"c","open write replace")
  call lineout journalPath,"WEBDAVCOLPROPS1"
  do p over byPath
    d=byPath[p]
    do k over d
      prop=d[k]
      call lineout journalPath,.WebDavPropertyHex~enc(p)||"09"x||.WebDavPropertyHex~enc(prop~namespace)||"09"x||.WebDavPropertyHex~enc(prop~name)||"09"x||.WebDavPropertyHex~enc(prop~value)
    end
  end
  call lineout journalPath
  return self

::method load
  expose journalPath byPath
  if stream(journalPath,"c","query exists")="" then return self
  header=linein(journalPath)
  if header<>"WEBDAVCOLPROPS1" then do
    call stream journalPath,"c","close"
    raise syntax 88.900 array("invalid DAV collection property journal")
  end
  do while lines(journalPath)>0
    line=linein(journalPath)
    if line="" then iterate
    f=.WebDavText~split(line,"09"x)
    if f~items<>4 then do
      call stream journalPath,"c","close"
      raise syntax 88.900 array("malformed DAV collection property record")
    end
    p=.StoragePath~normalize(.WebDavPropertyHex~dec(f[1]))
    ns=.WebDavPropertyHex~dec(f[2]); name=.WebDavPropertyHex~dec(f[3]); value=.WebDavPropertyHex~dec(f[4])
    key=ns~lower||"|"||name~lower
    d=byPath[p]
    if d==.nil then do; d=.directory~new; byPath[p]=d; end
    d[key]=.WebDavDeadProperty~new(ns,name,value)
  end
  call stream journalPath,"c","close"
  return self

::requires "WebDavCore.cls"
