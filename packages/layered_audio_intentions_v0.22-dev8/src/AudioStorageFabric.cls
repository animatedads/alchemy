/* Layered Audio Storage Fabric integration v0.22-dev2
 *
 * This is the provider-neutral storage boundary for the underlying Layered Audio
 * object model.  It deliberately does not teach Audio about machine paths.
 * Durable Audio identity is a pinned StorageRef.  Pathnames exist only inside
 * execution-time StorageMaterialisationLease objects.
 *
 * The file does not ::requires AudioCore.cls so the storage contract can be
 * qualified independently.  AudioStorageRecordingBridge accepts an ordinary
 * AudioRecording-like object by protocol (addRawFeed/addTrack/addDerived).
 */

::class AudioStorageBuild public
::constant VERSION "0.22-dev2"
::constant API "audio.storage/0.1"
::constant STORAGE_BINDING_API "storage.fabric.binding/0.1"
::constant STORAGE_STREAMING_API "storage.fabric.streaming/0.1"

::class AudioStorageAccess public
::constant READ_ONLY "READ_ONLY"
::constant READ_WRITE "READ_WRITE"

::class AudioStorageIdentity public
::attribute pinnedRef get
::attribute role get
::attribute mediaType get
::method init
  expose pinnedRef role mediaType
  use arg pinnedRefArg, roleArg="source", mediaTypeArg="audio/*"
  if pinnedRefArg==.nil | pinnedRefArg~hasMethod("IDENTITYKEY") then
    raise syntax 88.900 array("Audio Storage identity requires a StoragePinnedRef-like object")
  pinnedRef=pinnedRefArg
  role=roleArg~string~strip
  mediaType=mediaTypeArg~string~strip
  if role="" then raise syntax 88.900 array("Audio Storage role must not be empty")
::method identityKey
  expose pinnedRef
  return pinnedRef~identityKey
::method durableUri
  expose pinnedRef
  return "storage-ref:"||pinnedRef~identityKey
::method canonicalText
  expose role mediaType
  return "AUDIO_STORAGE_IDENTITY|role="||role||"|media="||mediaType||"|"||self~identityKey

::class AudioStorageElementBinding public
::attribute elementId get
::attribute identity get
::attribute accessMode get
::method init
  expose elementId identity accessMode
  use arg elementIdArg, identityArg, accessArg="READ_ONLY"
  elementId=elementIdArg~string~strip
  identity=identityArg
  accessMode=accessArg~string~strip~upper
  if elementId="" | identity==.nil then raise syntax 88.900 array("Audio element id and Storage identity are mandatory")
  if accessMode<>.AudioStorageAccess~READ_ONLY then if accessMode<>.AudioStorageAccess~READ_WRITE then
    raise syntax 88.900 array("invalid Audio Storage access mode")
::method identityKey
  expose identity
  return identity~identityKey
::method canonicalText
  expose elementId identity accessMode
  return "AUDIO_STORAGE_BINDING|element="||elementId||"|access="||accessMode||"|"||identity~canonicalText

::class AudioStorageRecordingBindings public
::attribute recordingId get
::method init
  expose recordingId bindings order sealed
  use arg recordingIdArg
  recordingId=recordingIdArg~string~strip
  if recordingId="" then raise syntax 88.900 array("recording id is mandatory")
  bindings=.directory~new
  order=.array~new
  sealed=.false
::method bind
  expose bindings order sealed
  use arg elementIdArg, pinnedRefArg, roleArg="source", mediaTypeArg="audio/*", accessArg="READ_ONLY"
  if sealed then raise syntax 88.900 array("Audio Storage recording bindings are sealed")
  id=elementIdArg~string~strip
  if id="" then raise syntax 88.900 array("Audio element id is mandatory")
  if bindings[id]<>.nil then raise syntax 88.900 array("Audio element already has a Storage binding:" id)
  identity=.AudioStorageIdentity~new(pinnedRefArg,roleArg,mediaTypeArg)
  binding=.AudioStorageElementBinding~new(id,identity,accessArg)
  bindings[id]=binding
  order~append(id)
  return binding
::method binding
  expose bindings
  use arg elementIdArg
  return bindings[elementIdArg~string]
::method ids
  expose order
  a=.array~new
  do id over order; a~append(id); end
  return a
::method count
  expose order
  return order~items
::method seal
  expose sealed
  sealed=.true
  return self
::method sealed
  expose sealed
  return sealed
::method canonicalText
  expose recordingId bindings order
  s="AUDIO_STORAGE_RECORDING|recording="||recordingId
  do id over order
    s=s||";"||bindings[id]~canonicalText
  end
  return s

::class AudioStorageRecordingBridge public
::attribute recording get
::attribute bindings get
::method init
  expose recording bindings
  use arg recordingArg, recordingIdArg=""
  if recordingArg==.nil then raise syntax 88.900 array("AudioRecording-like object is mandatory")
  required=.array~of("ADDRAWFEED","ADDTRACK","ADDDERIVED")
  do m over required
    if ecordingArg~hasMethod(m) then raise syntax 88.900 array("AudioRecording method is missing:" m)
  end
  recording=recordingArg
  rid=recordingIdArg~string~strip
  if rid="" then do
    if recordingArg~hasMethod("ID") then rid=recordingArg~id~string
    else raise syntax 88.900 array("recording id is mandatory when AudioRecording has no ID method")
  end
  bindings=.AudioStorageRecordingBindings~new(rid)
::method addRawFeed
  expose recording bindings
  use arg id, durationMs, pinnedRef, description="", metadata=.nil, role="source", mediaType="audio/*"
  identity=.AudioStorageIdentity~new(pinnedRef,role,mediaType)
  if metadata==.nil then metadata=.directory~new
  binding=bindings~bind(id,pinnedRef,role,mediaType,.AudioStorageAccess~READ_ONLY)
  element=recording~addRawFeed(id,durationMs,identity~durableUri,description,metadata)
  return element
::method addTrack
  expose recording bindings
  use arg id, durationMs, pinnedRef, description="", parentIds=.nil, metadata=.nil, role="track", mediaType="audio/*"
  identity=.AudioStorageIdentity~new(pinnedRef,role,mediaType)
  if parentIds==.nil then parentIds=.array~new
  if metadata==.nil then metadata=.directory~new
  binding=bindings~bind(id,pinnedRef,role,mediaType,.AudioStorageAccess~READ_ONLY)
  element=recording~addTrack(id,durationMs,identity~durableUri,description,parentIds,metadata)
  return element
::method addDerived
  expose recording bindings
  use arg id, durationMs, pinnedRef, description, parentIds, metadata, stepId, technique, family, parameters, confidence, assessor, notes, startMs, endMs, role="derived", mediaType="audio/*"
  identity=.AudioStorageIdentity~new(pinnedRef,role,mediaType)
  binding=bindings~bind(id,pinnedRef,role,mediaType,.AudioStorageAccess~READ_ONLY)
  element=recording~addDerived(id,durationMs,identity~durableUri,description,parentIds,metadata,stepId,technique,family,parameters,confidence,assessor,notes,startMs,endMs)
  return element

::class AudioStorageExecutionBinding public
::attribute elementBinding get
::attribute nodeId get
::attribute lease get
::method init
  expose elementBinding nodeId lease
  use arg elementBindingArg, authorityArg, nodeArg, leaseIdArg=""
  if elementBindingArg==.nil | authorityArg==.nil then raise syntax 88.900 array("Audio Storage element binding and authority are mandatory")
  elementBinding=elementBindingArg
  nodeId=nodeArg~string~strip
  if nodeId="" then raise syntax 88.900 array("Audio execution node is mandatory")
  leaseId=leaseIdArg~string
  if leaseId="" then leaseId="audio:"||elementBinding~elementId
  lease=authorityArg~materialise(elementBinding~identity~pinnedRef,nodeId,elementBinding~accessMode,leaseId)
  if lease~identityKey<>elementBinding~identityKey then
    raise syntax 88.900 array("Audio execution materialisation changed Storage identity")
::method localPath
  expose lease
  if lease~active then raise syntax 88.900 array("Audio Storage materialisation lease is not active")
  return lease~localPath
::method identityKey
  expose elementBinding
  return elementBinding~identityKey
::method canonicalText
  expose elementBinding nodeId lease
  return "AUDIO_STORAGE_EXECUTION|element="||elementBinding~elementId||"|node="||nodeId||"|identity="||self~identityKey||"|lease="||lease~leaseId
::method release
  expose lease
  return lease~release

::class AudioStorageRuntimeRequest public
::method withPath class
  use arg requestArg, executionArg, keyArg="path"
  if requestArg==.nil | executionArg==.nil then raise syntax 88.900 array("runtime request and Audio execution binding are mandatory")
  d=.directory~new
  supplier=requestArg~supplier
  do while supplier~available
    d[supplier~index]=supplier~item
    supplier~next
  end
  d[keyArg~string]=executionArg~localPath
  d["storage_identity"]=executionArg~identityKey
  return d

::class AudioStorageRandomAccess public
::attribute identity get
::attribute byteView get
::method init
  expose identity byteView
  use arg identityArg, byteSourceArg, maximumReadArg=1048576
  if identityArg==.nil | byteSourceArg==.nil then raise syntax 88.900 array("Audio Storage identity and byte source are mandatory")
  identity=identityArg
  byteView=.StorageRandomAccessByteView~new(byteSourceArg,identityArg~pinnedRef~ref,maximumReadArg)
::method sizeBytes
  expose byteView
  return byteView~sizeBytes
::method readAt
  expose byteView
  use arg offsetArg, lengthArg
  return byteView~readAt(offsetArg,lengthArg)
::method identityKey
  expose identity
  return identity~identityKey
::method close
  expose byteView
  byteView~close
  return self

::class AudioStorageOutputBinding public
::attribute elementId get
::attribute outputLease get
::attribute publishedIdentity get
::method init
  expose elementId outputLease publishedIdentity
  use arg elementIdArg, outputLeaseArg
  elementId=elementIdArg~string~strip
  outputLease=outputLeaseArg
  publishedIdentity=.nil
  if elementId="" | outputLease==.nil then raise syntax 88.900 array("Audio output element id and Storage output lease are mandatory")
::method localPath
  expose outputLease
  return outputLease~localPath
::method markWriting
  expose outputLease
  return outputLease~markWriting
::method publish
  expose outputLease publishedIdentity
  use arg storageRefArg, safeReplicaCountArg, generationArg, digestArg="", roleArg="derived", mediaTypeArg="audio/*"
  ref=outputLease~commit(storageRefArg,safeReplicaCountArg)
  pin=.StoragePinnedRef~new(ref,generationArg,digestArg)
  publishedIdentity=.AudioStorageIdentity~new(pin,roleArg,mediaTypeArg)
  return publishedIdentity
::method durable
  expose publishedIdentity
  return publishedIdentity<>.nil
::method canonicalText
  expose elementId publishedIdentity
  if publishedIdentity==.nil then return "AUDIO_STORAGE_OUTPUT|element="||elementId||"|state=UNPUBLISHED"
  return "AUDIO_STORAGE_OUTPUT|element="||elementId||"|state=PUBLISHED|"||publishedIdentity~canonicalText

::requires "src/StorageBinding.cls"
::requires "src/StorageVirtualMedia.cls"
