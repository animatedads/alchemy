/* MLRuntime.cls - deliberately small provider-neutral ML model/provenance/tensor substrate v0.16
 *
 * Domain objects (AudioSpeakerEmbedding, pitch observations, transcripts, etc.) remain
 * authoritative for meaning.  These classes describe *how an ML inference was run*.
 */

::class MLModelSpec public
::attribute id
::attribute task
::attribute provider
::attribute family
::attribute source
::attribute revision
::attribute runtime
::attribute inputSchema
::attribute outputSchema
::attribute attributes

::method init
  expose id task provider family source revision runtime inputSchema outputSchema attributes
  use strict arg id, task, provider = '', family = '', source = '', revision = '', runtime = '', inputSchema = '', outputSchema = '', attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  if \attributes~isa(.Directory) then raise syntax 88.900 array('MLModelSpec attributes must be a Directory')
  self~id = id~string
  self~task = task~string
  self~provider = provider~string
  self~family = family~string
  self~source = source~string
  self~revision = revision~string
  self~runtime = runtime~string
  self~inputSchema = inputSchema~string
  self~outputSchema = outputSchema~string
  self~attributes = self~copyDirectory(attributes)

::method copyDirectory private
  use strict arg source
  d = .Directory~new
  do k over source
    d[k] = source[k]
  end
  return d

::method canonicalText
  return 'ML_MODEL=' || self~id || '|task=' || self~task || '|provider=' || self~provider || '|family=' || self~family || '|source=' || self~source || '|revision=' || self~revision || '|runtime=' || self~runtime || '|input=' || self~inputSchema || '|output=' || self~outputSchema


::class MLInferenceProvenance public
::attribute task
::attribute modelId
::attribute runtimeProvider
::attribute runtimeVersion
::attribute providerId
::attribute implementationId
::attribute threadingMode
::attribute inputDescription
::attribute outputDescription
::attribute attributes

::method init
  expose task modelId runtimeProvider runtimeVersion providerId implementationId threadingMode inputDescription outputDescription attributes
  use strict arg task, modelId = '', runtimeProvider = '', runtimeVersion = '', providerId = '', implementationId = '', threadingMode = '', inputDescription = '', outputDescription = '', attributes = .nil
  if attributes == .nil then attributes = .Directory~new
  if \attributes~isa(.Directory) then raise syntax 88.900 array('MLInferenceProvenance attributes must be a Directory')
  self~task = task~string
  self~modelId = modelId~string
  self~runtimeProvider = runtimeProvider~string
  self~runtimeVersion = runtimeVersion~string
  self~providerId = providerId~string
  self~implementationId = implementationId~string
  self~threadingMode = threadingMode~string
  self~inputDescription = inputDescription~string
  self~outputDescription = outputDescription~string
  d = .Directory~new
  do k over attributes
    d[k] = attributes[k]
  end
  self~attributes = d

::method canonicalText
  return 'ML_INFERENCE=' || self~task || '|model=' || self~modelId || '|runtime=' || self~runtimeProvider || ':' || self~runtimeVersion || '|provider=' || self~providerId || '|implementation=' || self~implementationId || '|threading=' || self~threadingMode || '|input=' || self~inputDescription || '|output=' || self~outputDescription

/* Provider-neutral tensor *description*.  This is persistent metadata only;
 * process-local ForeignTensor/native handles remain runtime bindings. */
::class MLTensorDescriptor public
::attribute protocol
::attribute dtype
::attribute shape
::attribute strides
::attribute deviceType
::attribute deviceId
::attribute device
::attribute readonly
::attribute attributes

::method init
  use strict arg protocol, dtype, shape, strides = .nil, deviceType = 0, deviceId = 0, device = '', readonly = '', attributes = .nil
  if shape == .nil then shape = .Array~new
  if strides == .nil then strides = .Array~new
  if attributes == .nil then attributes = .Directory~new
  if \shape~isa(.Array) then raise syntax 88.900 array('MLTensorDescriptor shape must be an Array')
  if \strides~isa(.Array) then raise syntax 88.900 array('MLTensorDescriptor strides must be an Array')
  if \attributes~isa(.Directory) then raise syntax 88.900 array('MLTensorDescriptor attributes must be a Directory')
  self~protocol = protocol~string
  self~dtype = dtype~string
  self~shape = self~copyArray(shape)
  self~strides = self~copyArray(strides)
  self~deviceType = deviceType
  self~deviceId = deviceId
  self~device = device~string
  self~readonly = readonly
  self~attributes = self~copyDirectory(attributes)

::method fromForeignTensor class
  use strict arg tensor, attributes = .nil
  required = .Array~of('protocol','dtype','shape','strides','deviceType','deviceId','device','readonly','nativeHandle')
  do name over required
    if \tensor~hasMethod(name) then raise syntax 88.900 array('tensor object lacks method ' || name)
  end
  return self~new(tensor~protocol, tensor~dtype, tensor~shape, tensor~strides, tensor~deviceType, tensor~deviceId, tensor~device, tensor~readonly, attributes)

::method rank
  return self~shape~items

::method canonicalText
  return 'ML_TENSOR|protocol=' || self~protocol || '|dtype=' || self~dtype || '|shape=' || self~arrayText(self~shape) || '|strides=' || self~arrayText(self~strides) || '|deviceType=' || self~deviceType || '|deviceId=' || self~deviceId || '|device=' || self~device || '|readonly=' || self~readonly

::method copyArray private
  use strict arg source
  a=.Array~new
  do x over source; a~append(x); end
  return a

::method copyDirectory private
  use strict arg source
  d=.Directory~new
  do k over source; d[k]=source[k]; end
  return d

::method arrayText private
  use strict arg source
  s=''
  do i=1 to source~items
    if i>1 then s=s || ','
    s=s || source[i]
  end
  return s

