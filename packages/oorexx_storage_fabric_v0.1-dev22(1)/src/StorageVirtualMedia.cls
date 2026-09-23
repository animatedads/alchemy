/* Generic virtual-media compatibility contract for emulators and other
 * random-access virtual devices.  Storage Fabric owns object identity,
 * transfer and persistence; the presenting system owns device semantics and
 * the quiesce boundary required for application/guest consistency. */

::class StorageVirtualMediaBuild public
::constant VERSION "0.1-dev12"
::constant API "storage.fabric.virtual-media/0.1"

::class StorageVirtualMediaState public
::constant LIVE "LIVE"
::constant QUIESCING "QUIESCING"
::constant FROZEN "FROZEN"
::constant PUBLISHED "PUBLISHED"
::constant OFFLINE "OFFLINE"

::class StorageVirtualMediaConsistency public
::constant HOST_BYTES_ATOMIC "HOST_BYTES_ATOMIC"
::constant GUEST_CONSISTENT "GUEST_CONSISTENT"
::constant APPLICATION_CONSISTENT "APPLICATION_CONSISTENT"

::class StorageVirtualMediaDescriptor public
::attribute mediaId get
::attribute architecture get
::attribute mediaType get
::attribute geometry get
::attribute pinnedRef get
::attribute sizeBytes get
::attribute state get
::method init
  expose mediaId architecture mediaType geometry pinnedRef sizeBytes state
  use arg mediaIdArg, architectureArg, mediaTypeArg, pinnedRefArg, sizeArg, geometryArg="", stateArg="LIVE"
  mediaId=mediaIdArg~string~strip
  architecture=architectureArg~string~strip
  mediaType=mediaTypeArg~string~strip
  pinnedRef=pinnedRefArg
  sizeBytes=sizeArg+0
  geometry=geometryArg~string
  state=stateArg~string~strip~upper
  if mediaId="" | architecture="" | mediaType="" | pinnedRef==.nil | sizeBytes<0 then
    raise syntax 88.900 array("virtual media id/architecture/type/ref/size are mandatory")
::method setState
  expose state
  use arg stateArg
  s=stateArg~string~strip~upper
  if s<>.StorageVirtualMediaState~LIVE & s<>.StorageVirtualMediaState~QUIESCING & s<>.StorageVirtualMediaState~FROZEN & s<>.StorageVirtualMediaState~PUBLISHED & s<>.StorageVirtualMediaState~OFFLINE then
    raise syntax 88.900 array("invalid virtual media state")
  state=s
  return self

/* Turn StorageByteSource into bounded random-access bytes without importing
 * emulator-specific disk semantics into Storage Fabric. */
::class StorageRandomAccessByteView public
::attribute storageRef get
::attribute sizeBytes get
::attribute maximumReadBytes get
::method init
  expose source storageRef sizeBytes maximumReadBytes
  use arg sourceArg, storageRefArg, maximumReadArg=1048576
  source=sourceArg; storageRef=storageRefArg
  if source==.nil | storageRef==.nil then raise syntax 88.900 array("byte source and StorageRef are mandatory")
  required=.array~of("SIZEBYTES","OPENAT","READCHUNK","CLOSE")
  do m over required
    if \source~hasMethod(m) then raise syntax 88.900 array("StorageByteSource method is missing:" m)
  end
  sizeBytes=source~sizeBytes
  maximumReadBytes=maximumReadArg+0
  if sizeBytes<0 | maximumReadBytes<1 then raise syntax 88.900 array("invalid random access size/read bound")
::method readAt
  expose source sizeBytes maximumReadBytes
  use arg offsetArg, lengthArg
  offset=offsetArg+0; need=lengthArg+0
  if offset<0 | need<0 | need>maximumReadBytes | offset+need>sizeBytes then
    raise syntax 88.900 array("random access request out of bounds")
  if need=0 then return ""
  source~openAt(offset)
  answer=""; expected=offset; remaining=need
  do while remaining>0
    chunk=source~readChunk(remaining)
    if chunk==.nil then do; source~close; raise syntax 88.900 array("StorageByteSource returned no chunk"); end
    if \chunk~hasMethod("OFFSET") | \chunk~hasMethod("DATA") | \chunk~hasMethod("EOF") then do
      source~close; raise syntax 88.900 array("StorageByteSource returned invalid chunk")
    end
    if chunk~offset<>expected then do; source~close; raise syntax 88.900 array("StorageByteSource returned unexpected offset"); end
    data=chunk~data; got=data~length
    if got<1 | got>remaining then do; source~close; raise syntax 88.900 array("StorageByteSource returned invalid bounded length"); end
    answer=answer||data; expected+=got; remaining-=got
    if chunk~eof & remaining>0 then do; source~close; raise syntax 88.900 array("StorageByteSource ended before requested range"); end
  end
  source~close
  return answer
::method close
  expose source
  source~close
  return self

::class StorageVirtualMediaSnapshot public
::attribute mediaId get
::attribute generation get
::attribute frozenRef get
::attribute consistency get
::attribute evidenceRef get
::attribute state get
::method init
  expose mediaId generation frozenRef consistency evidenceRef state
  use arg mediaIdArg, generationArg, frozenRefArg, consistencyArg, evidenceArg="", stateArg="FROZEN"
  mediaId=mediaIdArg~string~strip
  generation=generationArg~string~strip
  frozenRef=frozenRefArg
  consistency=consistencyArg~string~strip~upper
  evidenceRef=evidenceArg~string
  state=stateArg~string~strip~upper
  if mediaId="" | generation="" | frozenRef==.nil then raise syntax 88.900 array("virtual media snapshot id/generation/ref are mandatory")
::method guestConsistent
  expose consistency
  return consistency=.StorageVirtualMediaConsistency~GUEST_CONSISTENT | consistency=.StorageVirtualMediaConsistency~APPLICATION_CONSISTENT
::method publish
  expose state
  if state<>.StorageVirtualMediaState~FROZEN then return .false
  state=.StorageVirtualMediaState~PUBLISHED
  return .true

/* Admission policy: Storage may preserve a host-byte atomic image, but a
 * caller requiring guest/application consistency must demand evidence from the
 * presenting authority. */
::class StorageVirtualMediaSnapshotPolicy public
::method admissible class
  use arg snapshotArg, requireGuestConsistencyArg=.true
  if snapshotArg==.nil then return .false
  s=snapshotArg~state
  if s<>.StorageVirtualMediaState~FROZEN & s<>.StorageVirtualMediaState~PUBLISHED then return .false
  if requireGuestConsistencyArg==.true & \snapshotArg~guestConsistent then return .false
  return .true
