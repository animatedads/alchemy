/* AudioMLMaterial.cls - canonical ML-ready audio material, buffer and tensor runtime bindings v0.16 */

::class AudioMLMaterialSpec public
::attribute id
::attribute sourceRecordingId
::attribute sourceElementId
::attribute startMs
::attribute endMs
::attribute sampleRateHz
::attribute channels
::attribute sampleFormat
::attribute channelLayout
::attribute byteOrder
::attribute processingLineage
::attribute attributes

::method init
  use strict arg id, sourceRecordingId, sourceElementId, startMs, endMs, sampleRateHz, channels, sampleFormat, channelLayout = 'MONO', byteOrder = 'LITTLE', processingLineage = .nil, attributes = .nil
  if processingLineage == .nil then processingLineage = .Array~new
  if attributes == .nil then attributes = .Directory~new
  if endMs < startMs then raise syntax 88.900 array('AudioMLMaterialSpec end precedes start')
  if sampleRateHz < 1 | channels < 1 then raise syntax 88.900 array('AudioMLMaterialSpec sample rate/channels must be positive')
  self~id=id~string
  self~sourceRecordingId=sourceRecordingId~string
  self~sourceElementId=sourceElementId~string
  self~startMs=startMs
  self~endMs=endMs
  self~sampleRateHz=sampleRateHz
  self~channels=channels
  self~sampleFormat=sampleFormat~string
  self~channelLayout=channelLayout~string
  self~byteOrder=byteOrder~string
  self~processingLineage=.AudioUtil~copyArray(processingLineage)
  self~attributes=.AudioUtil~copyDirectory(attributes)

::method durationMs
  return self~endMs-self~startMs

::method canonicalText
  return 'AUDIO_ML_MATERIAL=' || self~id || '|recording=' || self~sourceRecordingId || '|element=' || self~sourceElementId || '|time=' || self~startMs || '-' || self~endMs || '|rate=' || self~sampleRateHz || '|channels=' || self~channels || '|format=' || self~sampleFormat || '|layout=' || self~channelLayout || '|byteOrder=' || self~byteOrder || '|lineage=' || .AudioUtil~idsText(self~processingLineage) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioMLMaterialBinding public
::attribute spec
::attribute storageProvider
::attribute storageObject
::attribute byteOffset
::attribute byteLength
::attribute zeroCopyCapable
::attribute attributes

::method init
  use strict arg spec, storageProvider, storageObject, byteOffset = 0, byteLength = 0, zeroCopyCapable = .false, attributes = .nil
  if \spec~isa(.AudioMLMaterialSpec) then raise syntax 88.900 array('AudioMLMaterialBinding requires AudioMLMaterialSpec')
  if attributes == .nil then attributes=.Directory~new
  if arg(5,'O') then do
    if storageObject~hasMethod('size') then byteLength=storageObject~size-byteOffset
    else byteLength=0
  end
  if byteOffset < 0 | byteLength < 0 then raise syntax 88.900 array('AudioMLMaterialBinding byte bounds must be non-negative')
  self~spec=spec
  self~storageProvider=storageProvider~string
  self~storageObject=storageObject
  self~byteOffset=byteOffset
  self~byteLength=byteLength
  self~zeroCopyCapable=zeroCopyCapable
  self~attributes=.AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'AUDIO_ML_BINDING=' || self~spec~id || '|provider=' || self~storageProvider || '|offset=' || self~byteOffset || '|length=' || self~byteLength || '|zeroCopyCapable=' || self~zeroCopyCapable || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)

::requires 'AudioCore.cls'

/* Runtime tensor binding for an AudioMLMaterialBinding.  It deliberately
 * separates persistent tensor metadata from transient process-local handles. */
::class AudioMLTensorBinding public
::attribute materialBinding
::attribute descriptor
::attribute tensorProvider
::attribute tensorObject
::attribute nativeDescriptorCapable
::attribute ownsTensor
::attribute attributes

::method init
  use strict arg materialBinding, descriptor, tensorProvider, tensorObject, nativeDescriptorCapable = .false, ownsTensor = .false, attributes = .nil
  if \materialBinding~isa(.AudioMLMaterialBinding) then raise syntax 88.900 array('AudioMLTensorBinding requires AudioMLMaterialBinding')
  if \descriptor~isa(.MLTensorDescriptor) then raise syntax 88.900 array('AudioMLTensorBinding requires MLTensorDescriptor')
  if tensorObject == .nil then raise syntax 88.900 array('AudioMLTensorBinding requires runtime tensor object')
  if attributes == .nil then attributes=.Directory~new
  if \attributes~isa(.Directory) then raise syntax 88.900 array('AudioMLTensorBinding attributes must be a Directory')
  self~materialBinding=materialBinding
  self~descriptor=descriptor
  self~tensorProvider=tensorProvider~string
  self~tensorObject=tensorObject
  self~nativeDescriptorCapable=nativeDescriptorCapable
  self~ownsTensor=ownsTensor
  self~attributes=.AudioUtil~copyDirectory(attributes)

::method fromForeignTensor class
  use strict arg materialBinding, tensorObject, ownsTensor = .false, attributes = .nil
  descriptor=.MLTensorDescriptor~fromForeignTensor(tensorObject)
  provider='foreign-tensor'
  if tensorObject~hasMethod('provider') then provider=tensorObject~provider
  capable=.false
  if tensorObject~hasMethod('nativeHandle') then capable=(tensorObject~nativeHandle>0)
  return self~new(materialBinding,descriptor,provider,tensorObject,capable,ownsTensor,attributes)

::method nativeHandle
  if \self~nativeDescriptorCapable then return 0
  return self~tensorObject~nativeHandle

::method canonicalText
  return 'AUDIO_ML_TENSOR=' || self~materialBinding~spec~id || '|provider=' || self~tensorProvider || '|nativeDescriptorCapable=' || self~nativeDescriptorCapable || '|tensor=' || self~descriptor~canonicalText || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)

::method close
  if self~ownsTensor then do
    if self~tensorObject \== .nil then if self~tensorObject~hasMethod('close') then self~tensorObject~close
  end
  return .true


::requires 'MLRuntime.cls'

