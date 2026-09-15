/* AudioProcessingToolkit.cls - provider-neutral audio processing object model v0.21
 *
 * Research algorithms are represented as semantic processors, configurations,
 * graphs, measurements, masks, transforms and derived-material results.  Runtime
 * placement (native/Python/GPU/remote) is deliberately separate from meaning.
 */

::class AudioProcessingConstant public
::constant PACKAGE_VERSION '0.21'
::constant FAMILY_TRANSFORM 'TRANSFORM'
::constant FAMILY_MEASUREMENT 'MEASUREMENT'
::constant FAMILY_MASK 'MASK'
::constant FAMILY_ALIGNMENT 'ALIGNMENT'
::constant FAMILY_SPATIAL 'SPATIAL'
::constant FAMILY_CLASSIFIER 'CLASSIFIER'
::constant FAMILY_COMPOSITE 'COMPOSITE'
::constant OUTPUT_AUDIO 'AUDIO_MATERIAL'
::constant OUTPUT_MASK 'MASK'
::constant OUTPUT_MEASUREMENT 'MEASUREMENT'
::constant OUTPUT_TIME_SHIFT 'TIME_SHIFT'
::constant OUTPUT_SPATIAL 'SPATIAL'
::constant OUTPUT_CLASSIFICATION 'CLASSIFICATION'
::constant OUTPUT_FEATURE_MAP 'FEATURE_MAP'
::constant STREAM_STATELESS 'STATELESS'
::constant STREAM_STATEFUL 'STATEFUL'
::constant STREAM_WHOLE_REGION 'WHOLE_REGION'
::constant STATE_TRANSFER_NONE 'NONE'
::constant STATE_TRANSFER_CHECKPOINTABLE 'CHECKPOINTABLE'
::constant STATE_TRANSFER_PROVIDER_AFFINE 'PROVIDER_AFFINE'
::constant GPU_NONE 'NONE'
::constant GPU_OPTIONAL 'OPTIONAL'
::constant GPU_PREFERRED 'PREFERRED'
::constant GPU_REQUIRED 'REQUIRED'

::class AudioProcessingUtil public
::method copyArray class
  use strict arg source=.nil
  a=.Array~new
  if source==.nil then return a
  do x over source; a~append(x); end
  return a

::method copyDirectory class
  use strict arg source=.nil
  d=.Directory~new
  if source==.nil then return d
  do k over source; d[k]=source[k]; end
  return d

::method join class
  use strict arg source, sep=','
  s=''
  do i=1 to source~items
    if i>1 then s=s || sep
    s=s || source[i]
  end
  return s

::method canonicalDirectory class
  use strict arg source
  keys=.Array~new
  do k over source; keys~append(k); end
  keys~sort
  parts=.Array~new
  do k over keys; parts~append(k || '=' || self~canonicalValue(source[k])); end
  return self~join(parts,';')

::method canonicalValue class
  use strict arg value
  if value==.nil then return '<nil>'
  if value~hasMethod('canonicalText') then return value~canonicalText
  if value~isa(.Array) then do
    a=.Array~new
    do x over value; a~append(self~canonicalValue(x)); end
    return '[' || self~join(a,',') || ']'
  end
  return value~string


::class AudioSampleContract public
::attribute sampleRateHz
::attribute minChannels
::attribute maxChannels
::attribute sampleFormats
::attribute planarPolicy
::attribute memoryDomains

::method init
  use strict arg sampleRateHz=0, minChannels=1, maxChannels=0, sampleFormats=.nil, planarPolicy='ANY', memoryDomains=.nil
  if sampleFormats==.nil then sampleFormats=.Array~new
  if memoryDomains==.nil then memoryDomains=.Array~of('HOST')
  self~sampleRateHz=sampleRateHz
  self~minChannels=minChannels
  self~maxChannels=maxChannels
  self~sampleFormats=.AudioProcessingUtil~copyArray(sampleFormats)
  self~planarPolicy=planarPolicy~string~upper
  self~memoryDomains=.AudioProcessingUtil~copyArray(memoryDomains)

::method accepts
  use strict arg sampleRateHz, channels, sampleFormat, planar
  if self~sampleRateHz>0 & sampleRateHz<>self~sampleRateHz then return .false
  if channels<self~minChannels then return .false
  if self~maxChannels>0 & channels>self~maxChannels then return .false
  if self~sampleFormats~items>0 then do
    found=.false
    do x over self~sampleFormats
      if x~string~lower=sampleFormat~string~lower then found=.true
    end
    if \found then return .false
  end
  pp=self~planarPolicy
  if pp='PLANAR' & \planar then return .false
  if pp='PACKED' & planar then return .false
  return .true

::method canonicalText
  return 'AUDIO_SAMPLE_CONTRACT|rate=' || self~sampleRateHz || '|channels=' || self~minChannels || ':' || self~maxChannels || '|formats=' || .AudioProcessingUtil~join(self~sampleFormats) || '|planar=' || self~planarPolicy || '|memory=' || .AudioProcessingUtil~join(self~memoryDomains)


::class AudioStreamingProfile public
::attribute streamingCapable
::attribute stateMode
::attribute preferredBlockSamples
::attribute minimumHistorySamples
::attribute lookAheadSamples
::attribute overlapSamples
::attribute flushRequired
::attribute canParallelizeBlocks
::attribute latencyClass
::attribute stateTransferMode

::method init
  use strict arg streamingCapable=.true, stateMode='STATELESS', preferredBlockSamples=0, minimumHistorySamples=0, lookAheadSamples=0, overlapSamples=0, flushRequired=.false, canParallelizeBlocks=.true, latencyClass='BATCH', stateTransferMode='NONE'
  self~streamingCapable=streamingCapable
  self~stateMode=stateMode~string~upper
  self~preferredBlockSamples=preferredBlockSamples
  self~minimumHistorySamples=minimumHistorySamples
  self~lookAheadSamples=lookAheadSamples
  self~overlapSamples=overlapSamples
  self~flushRequired=flushRequired
  self~canParallelizeBlocks=canParallelizeBlocks
  self~latencyClass=latencyClass~string~upper
  stm=stateTransferMode~string~upper
  if stm<>'NONE' & stm<>'CHECKPOINTABLE' & stm<>'PROVIDER_AFFINE' then raise syntax 88.900 array('invalid audio streaming state transfer mode ' || stateTransferMode)
  self~stateTransferMode=stm

::method canonicalText
  return 'AUDIO_STREAMING|capable=' || self~streamingCapable || '|state=' || self~stateMode || '|block=' || self~preferredBlockSamples || '|history=' || self~minimumHistorySamples || '|lookahead=' || self~lookAheadSamples || '|overlap=' || self~overlapSamples || '|flush=' || self~flushRequired || '|parallel=' || self~canParallelizeBlocks || '|latency=' || self~latencyClass || '|stateTransfer=' || self~stateTransferMode


::class AudioExecutionProfile public
::attribute cpuClass
::attribute gpuMode
::attribute vectorPreferred
::attribute batchable
::attribute minimumVramBytes
::attribute workingSetHint
::attribute capabilityRequirements
::attribute implementationHints

::method init
  use strict arg cpuClass='CPU_VECTOR', gpuMode='OPTIONAL', vectorPreferred=.true, batchable=.true, minimumVramBytes=0, workingSetHint='', capabilityRequirements=.nil, implementationHints=.nil
  if capabilityRequirements==.nil then capabilityRequirements=.Directory~new
  if implementationHints==.nil then implementationHints=.Directory~new
  self~cpuClass=cpuClass~string~upper
  self~gpuMode=gpuMode~string~upper
  self~vectorPreferred=vectorPreferred
  self~batchable=batchable
  self~minimumVramBytes=minimumVramBytes
  self~workingSetHint=workingSetHint~string
  self~capabilityRequirements=.AudioProcessingUtil~copyDirectory(capabilityRequirements)
  self~implementationHints=.AudioProcessingUtil~copyDirectory(implementationHints)

::method canonicalText
  return 'AUDIO_EXECUTION|cpu=' || self~cpuClass || '|gpu=' || self~gpuMode || '|vector=' || self~vectorPreferred || '|batchable=' || self~batchable || '|minVram=' || self~minimumVramBytes || '|workingSet=' || self~workingSetHint || '|requirements=' || .AudioProcessingUtil~canonicalDirectory(self~capabilityRequirements)


::class AudioProcessorSpec public
::attribute id
::attribute version
::attribute family
::attribute description
::attribute inputRoles
::attribute outputKinds
::attribute inputContract
::attribute inputContracts
::attribute streaming
::attribute execution
::attribute parameterSchema
::attribute corpusSources
::attribute implementationStatus

::method init
  use strict arg id, version, family, description='', inputRoles=.nil, outputKinds=.nil, inputContract=.nil, streaming=.nil, execution=.nil, parameterSchema=.nil, corpusSources=.nil, implementationStatus='CATALOGUED'
  if inputRoles==.nil then inputRoles=.Array~new
  if outputKinds==.nil then outputKinds=.Array~new
  if inputContract==.nil then inputContract=.AudioSampleContract~new
  if streaming==.nil then streaming=.AudioStreamingProfile~new
  if execution==.nil then execution=.AudioExecutionProfile~new
  if parameterSchema==.nil then parameterSchema=.Directory~new
  if corpusSources==.nil then corpusSources=.Array~new
  self~id=id~string
  self~version=version~string
  self~family=family~string~upper
  self~description=description~string
  self~inputRoles=.AudioProcessingUtil~copyArray(inputRoles)
  self~outputKinds=.AudioProcessingUtil~copyArray(outputKinds)
  self~inputContract=inputContract
  self~inputContracts=.Directory~new
  do role over self~inputRoles; self~inputContracts[role]=inputContract; end
  self~streaming=streaming
  self~execution=execution
  self~parameterSchema=.AudioProcessingUtil~copyDirectory(parameterSchema)
  self~corpusSources=.AudioProcessingUtil~copyArray(corpusSources)
  self~implementationStatus=implementationStatus~string~upper

::method canonicalText
  return 'AUDIO_PROCESSOR=' || self~id || '@' || self~version || '|family=' || self~family || '|inputs=' || .AudioProcessingUtil~join(self~inputRoles) || '|outputs=' || .AudioProcessingUtil~join(self~outputKinds) || '|status=' || self~implementationStatus || '|' || self~inputContract~canonicalText || '|' || self~streaming~canonicalText || '|' || self~execution~canonicalText

::method setInputContract
  use strict arg role, contract
  if \self~inputContracts~hasIndex(role) then raise syntax 88.900 array('unknown processor input role ' || role)
  self~inputContracts[role]=contract
  return self

::method contractForRole
  use strict arg role
  if self~inputContracts~hasIndex(role) then return self~inputContracts[role]
  return .nil


::class AudioProcessorConfig public
::attribute id
::attribute processorId
::attribute parameters
::attribute label

::method init
  use strict arg id, processorId, parameters=.nil, label=''
  if parameters==.nil then parameters=.Directory~new
  self~id=id~string
  self~processorId=processorId~string
  self~parameters=.AudioProcessingUtil~copyDirectory(parameters)
  self~label=label~string

::method canonicalText
  return 'AUDIO_PROCESSOR_CONFIG=' || self~id || '|processor=' || self~processorId || '|parameters=' || .AudioProcessingUtil~canonicalDirectory(self~parameters) || '|label=' || self~label


::class AudioProcessingInputRef public
::attribute role
::attribute recordingId
::attribute elementId
::attribute channelIndex
::attribute startMs
::attribute endMs
::attribute materialId
::attribute attributes

::method init
  use strict arg role, recordingId='', elementId='', channelIndex=0, startMs=0, endMs=(0-1), materialId='', attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  self~role=role~string
  self~recordingId=recordingId~string
  self~elementId=elementId~string
  self~channelIndex=channelIndex
  self~startMs=startMs
  self~endMs=endMs
  self~materialId=materialId~string
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method canonicalText
  return 'INPUT=' || self~role || '|recording=' || self~recordingId || '|element=' || self~elementId || '|channel=' || self~channelIndex || '|startMs=' || self~startMs || '|endMs=' || self~endMs || '|material=' || self~materialId


::class AudioProcessingNode public
::attribute id
::attribute config
::attribute inputs
::attribute requestedOutputs
::attribute attributes

::method init
  use strict arg id, config, inputs=.nil, requestedOutputs=.nil, attributes=.nil
  if inputs==.nil then inputs=.Directory~new
  if requestedOutputs==.nil then requestedOutputs=.Array~new
  if attributes==.nil then attributes=.Directory~new
  self~id=id~string
  self~config=config
  self~inputs=.AudioProcessingUtil~copyDirectory(inputs)
  self~requestedOutputs=.AudioProcessingUtil~copyArray(requestedOutputs)
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method canonicalText
  return 'AUDIO_NODE=' || self~id || '|' || self~config~canonicalText || '|inputs=' || .AudioProcessingUtil~canonicalDirectory(self~inputs) || '|outputs=' || .AudioProcessingUtil~join(self~requestedOutputs)


::class AudioProcessingGraph public
::attribute id
::attribute nodes
::attribute outputs

::method init
  use strict arg id
  self~id=id~string
  self~nodes=.Directory~new
  self~outputs=.Directory~new

::method addNode
  use strict arg node
  if self~nodes~hasIndex(node~id) then raise syntax 88.900 array('duplicate audio processing node id ' || node~id)
  self~nodes[node~id]=node
  return node

::method bindOutput
  use strict arg name, nodeId, outputRole
  if \self~nodes~hasIndex(nodeId) then raise syntax 88.900 array('unknown audio processing node ' || nodeId)
  self~outputs[name]=nodeId || ':' || outputRole

::method canonicalText
  ids=.Array~new
  do k over self~nodes; ids~append(k); end
  ids~sort
  parts=.Array~new
  do k over ids; parts~append(self~nodes[k]~canonicalText); end
  return 'AUDIO_GRAPH=' || self~id || '|nodes=' || .AudioProcessingUtil~join(parts,'||') || '|outputs=' || .AudioProcessingUtil~canonicalDirectory(self~outputs)


/* Runtime graph edges are typed objects.  They describe where a node obtains an
 * input without turning a process-local ForeignTensor into persistent graph state. */
::class AudioProcessingPortRef public
::attribute kind
::attribute name
::attribute nodeId
::attribute outputRole

::method init
  use strict arg kind, name='', nodeId='', outputRole=''
  k=kind~string~upper
  if k<>'EXTERNAL' & k<>'NODE' then raise syntax 88.900 array('invalid audio processing port ref kind ' || kind)
  self~kind=k
  self~name=name~string
  self~nodeId=nodeId~string
  self~outputRole=outputRole~string

::method external class
  use strict arg name
  return self~new('EXTERNAL',name)

::method node class
  use strict arg nodeId, outputRole
  return self~new('NODE','',nodeId,outputRole)

::method canonicalText
  if self~kind='EXTERNAL' then return 'PORT=EXTERNAL:' || self~name
  return 'PORT=NODE:' || self~nodeId || ':' || self~outputRole


::class AudioProcessingGraphRun public
::attribute graphId
::attribute executionOrder
::attribute nodeResults
::attribute outputs

::method init
  use strict arg graphId, executionOrder, nodeResults, outputs
  self~graphId=graphId~string
  self~executionOrder=.AudioProcessingUtil~copyArray(executionOrder)
  self~nodeResults=.AudioProcessingUtil~copyDirectory(nodeResults)
  self~outputs=.AudioProcessingUtil~copyDirectory(outputs)


::class AudioProcessingGraphExecutor public
::attribute catalog
::attribute provider
::attribute sampleRateHz

::method init
  use strict arg catalog, provider, sampleRateHz
  self~catalog=catalog
  self~provider=provider
  self~sampleRateHz=sampleRateHz

::method execute
  use strict arg graph, externals
  order=self~executionOrder(graph)
  results=.Directory~new
  do nodeId over order
    node=graph~nodes[nodeId]
    spec=self~catalog~at(node~config~processorId)
    if spec==.nil then raise syntax 88.900 array('unknown graph processor ' || node~config~processorId)
    if spec~inputRoles~items=0 then raise syntax 88.900 array('graph executor requires at least one audio input role')
    a=self~resolveInput(node,spec~inputRoles[1],externals,results)
    b=.nil
    if spec~inputRoles~items>=2 then b=self~resolveInput(node,spec~inputRoles[2],externals,results)
    if spec~inputRoles~items>2 then raise syntax 88.900 array('v0.20 graph executor supports at most two runtime audio inputs per node')
    results[nodeId]=self~provider~execute(graph~id || ':' || nodeId,spec,node~config,a,self~sampleRateHz,b)
  end
  outs=.Directory~new
  do name over graph~outputs
    token=graph~outputs[name]
    p=token~pos(':')
    if p=0 then raise syntax 88.900 array('malformed graph output binding ' || token)
    nodeId=token~left(p-1); role=token~substr(p+1)
    if \results~hasIndex(nodeId) then raise syntax 88.900 array('graph output references missing node result ' || nodeId)
    outs[name]=self~findOutput(results[nodeId],role)
  end
  return .AudioProcessingGraphRun~new(graph~id,order,results,outs)

::method executionOrder private
  use strict arg graph
  remaining=.Directory~new
  do k over graph~nodes; remaining[k]=graph~nodes[k]; end
  done=.Directory~new
  order=.Array~new
  do while remaining~items>0
    ids=.Array~new
    do k over remaining; ids~append(k); end
    ids~sort
    progressed=.false
    do id over ids
      node=remaining[id]
      ready=.true
      do role over node~inputs
        ref=node~inputs[role]
        if ref~isa(.AudioProcessingPortRef) then do
          if ref~kind='NODE' & \done~hasIndex(ref~nodeId) then ready=.false
        end
      end
      if ready then do
        order~append(id)
        done[id]=.true
        remaining~remove(id)
        progressed=.true
      end
    end
    if \progressed then raise syntax 88.900 array('audio processing graph has a cycle or unresolved node dependency')
  end
  return order

::method resolveInput private
  use strict arg node, role, externals, results
  if \node~inputs~hasIndex(role) then raise syntax 88.900 array('node ' || node~id || ' missing input role ' || role)
  ref=node~inputs[role]
  if \ref~isa(.AudioProcessingPortRef) then return ref
  if ref~kind='EXTERNAL' then do
    if \externals~hasIndex(ref~name) then raise syntax 88.900 array('missing external graph material ' || ref~name)
    return externals[ref~name]
  end
  if \results~hasIndex(ref~nodeId) then raise syntax 88.900 array('node dependency not executed ' || ref~nodeId)
  out=self~findOutput(results[ref~nodeId],ref~outputRole)
  return out~object

::method findOutput private
  use strict arg result, role
  do out over result~outputs
    if out~role=role then return out
  end
  raise syntax 88.900 array('processing result lacks output role ' || role)


::class AudioTimeShift public
::attribute samples
::attribute seconds
::attribute confidence
::attribute convention
::attribute method
::attribute evidence

::method init
  use strict arg samples, sampleRateHz, confidence=0, convention='', method='', evidence=''
  self~samples=samples
  self~seconds=samples/sampleRateHz
  self~confidence=confidence
  self~convention=convention~string
  self~method=method~string
  self~evidence=evidence

::method milliseconds
  return self~seconds*1000

::method canonicalText
  return 'AUDIO_TIME_SHIFT|samples=' || self~samples || '|seconds=' || self~seconds || '|confidence=' || self~confidence || '|method=' || self~method || '|convention=' || self~convention


::class AudioRoomReflectionProfile public
::attribute delaysMs
::attribute strengths
::attribute confidence
::attribute method
::attribute evidence

::method init
  use strict arg delaysMs=.nil, strengths=.nil, confidence=0, method='room_profile', evidence=''
  if delaysMs==.nil then delaysMs=.Array~new
  if strengths==.nil then strengths=.Array~new
  self~delaysMs=.AudioProcessingUtil~copyArray(delaysMs)
  self~strengths=.AudioProcessingUtil~copyArray(strengths)
  self~confidence=confidence
  self~method=method~string
  self~evidence=evidence

::method canonicalText
  return 'AUDIO_ROOM_PROFILE|delaysMs=' || .AudioProcessingUtil~join(self~delaysMs) || '|strengths=' || .AudioProcessingUtil~join(self~strengths) || '|confidence=' || self~confidence || '|method=' || self~method


::class AudioMeasurement public
::attribute kind
::attribute value
::attribute unit
::attribute confidence
::attribute method
::attribute mathsEvidence
::attribute attributes

::method init
  use strict arg kind, value, unit='', confidence=0, method='', mathsEvidence=.nil, attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  self~kind=kind~string
  self~value=value
  self~unit=unit~string
  self~confidence=confidence
  self~method=method~string
  self~mathsEvidence=mathsEvidence
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method canonicalText
  ev=''
  if self~mathsEvidence \== .nil then do
    if self~mathsEvidence~hasMethod('canonicalText') then ev=self~mathsEvidence~canonicalText
    else ev=self~mathsEvidence~string
  end
  return 'AUDIO_MEASUREMENT=' || self~kind || '|value=' || self~value || '|unit=' || self~unit || '|confidence=' || self~confidence || '|method=' || self~method || '|maths=' || ev


::class AudioMaskDescriptor public
::attribute id
::attribute domain
::attribute timeStartMs
::attribute timeEndMs
::attribute frequencyMinHz
::attribute frequencyMaxHz
::attribute derivation
::attribute confidence
::attribute materialRef
::attribute attributes

::method init
  use strict arg id, domain='TIME_FREQUENCY', timeStartMs=0, timeEndMs=(0-1), frequencyMinHz=0, frequencyMaxHz=0, derivation='', confidence=0, materialRef='', attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  self~id=id~string
  self~domain=domain~string
  self~timeStartMs=timeStartMs
  self~timeEndMs=timeEndMs
  self~frequencyMinHz=frequencyMinHz
  self~frequencyMaxHz=frequencyMaxHz
  self~derivation=derivation~string
  self~confidence=confidence
  self~materialRef=materialRef~string
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)


::class AudioFeatureMapDescriptor public
::attribute id
::attribute domain
::attribute featureKind
::attribute derivation
::attribute confidence
::attribute materialRef
::attribute attributes

::method init
  use strict arg id, domain='TIME_FREQUENCY', featureKind='', derivation='', confidence=0, materialRef='', attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  self~id=id~string
  self~domain=domain~string
  self~featureKind=featureKind~string
  self~derivation=derivation~string
  self~confidence=confidence
  self~materialRef=materialRef~string
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method canonicalText
  return 'AUDIO_FEATURE_MAP=' || self~id || '|domain=' || self~domain || '|kind=' || self~featureKind || '|derivation=' || self~derivation || '|confidence=' || self~confidence || '|material=' || self~materialRef


::class AudioProcessingOutput public
::attribute role
::attribute kind
::attribute materialId
::attribute object
::attribute attributes

::method init
  use strict arg role, kind, materialId='', object=.nil, attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  self~role=role~string
  self~kind=kind~string
  self~materialId=materialId~string
  self~object=object
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)


::class AudioProcessingResult public
::attribute requestId
::attribute processorId
::attribute configId
::attribute status
::attribute outputs
::attribute measurements
::attribute runtimeProvenance
::attribute warnings

::method init
  use strict arg requestId, processorId, configId, status='COMPLETED', outputs=.nil, measurements=.nil, runtimeProvenance=.nil, warnings=.nil
  if outputs==.nil then outputs=.Array~new
  if measurements==.nil then measurements=.Array~new
  if runtimeProvenance==.nil then runtimeProvenance=.Directory~new
  if warnings==.nil then warnings=.Array~new
  self~requestId=requestId~string
  self~processorId=processorId~string
  self~configId=configId~string
  self~status=status~string~upper
  self~outputs=.AudioProcessingUtil~copyArray(outputs)
  self~measurements=.AudioProcessingUtil~copyArray(measurements)
  self~runtimeProvenance=.AudioProcessingUtil~copyDirectory(runtimeProvenance)
  self~warnings=.AudioProcessingUtil~copyArray(warnings)


::class AudioProcessorCatalog public
::attribute specs

::method init
  self~specs=.Directory~new

::method add
  use strict arg spec
  self~specs[spec~id]=spec
  return spec

::method at
  use strict arg id
  if self~specs~hasIndex(id) then return self~specs[id]
  return .nil

::method ids
  a=.Array~new
  do k over self~specs; a~append(k); end
  a~sort
  return a

::method researchCorpus class
  c=self~new
  any=.AudioSampleContract~new
  mono=.AudioSampleContract~new(0,1,1)
  streamFFT=.AudioStreamingProfile~new(.true,'STATEFUL',32768,1536,0,0,.true,.false,'BLOCK','PROVIDER_AFFINE')
  blockFFT=.AudioStreamingProfile~new(.true,'STATELESS',32768,2048,0,1536,.false,.true,'BLOCK')
  whole=.AudioStreamingProfile~new(.false,'WHOLE_REGION',0,0,0,0,.false,.false,'BATCH')
  cpu=.AudioExecutionProfile~new('CPU_VECTOR','OPTIONAL',.true,.true)
  gpu=.AudioExecutionProfile~new('CPU_VECTOR','PREFERRED',.true,.true,0,'O(channels * fft_bins * frames)')

  c~add(.AudioProcessorSpec~new('alignment.gcc_phat','1',.AudioProcessingConstant~FAMILY_ALIGNMENT,'GCC-PHAT phase-whitened TDOA',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_TIME_SHIFT,.AudioProcessingConstant~OUTPUT_MEASUREMENT),mono,blockFFT,cpu,self~params('max_lag_sec=0.2'),.Array~of('fc_dual_feed.py','calibrate_tdoa_event.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('alignment.envelope_lag','1',.AudioProcessingConstant~FAMILY_ALIGNMENT,'Hilbert-envelope lag for tonal/onset events',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_TIME_SHIFT,.AudioProcessingConstant~OUTPUT_MEASUREMENT),mono,blockFFT,cpu,self~params('max_lag_sec=0.2;smoothing_sec=0.015'),.Array~of('calibrate_tdoa_event.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('alignment.cross_ambiguity','1',.AudioProcessingConstant~FAMILY_ALIGNMENT,'Time-domain bounded cross-ambiguity alignment',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_TIME_SHIFT),mono,blockFFT,cpu,self~params('max_delay_sec=0.2'),.Array~of('dual_feed_enhance.py','dual_feed_enhance_v8.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.adaptive_spectral_denoise','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'Noise-floor tracking spectral subtraction',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO),any,streamFFT,gpu,self~params('n_fft=2048;hop=512;noise_percentile=20;floor_scale=1.2;minimum_gain=0.08;state_alpha=0.85'),.Array~of('fc_dual_feed.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('mask.phase_coherence_wiener','1',.AudioProcessingConstant~FAMILY_MASK,'Complex inter-channel coherence Wiener mask',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_MASK,.AudioProcessingConstant~OUTPUT_AUDIO),mono,streamFFT,gpu,self~params('n_fft=2048;hop=512;smoothing_frames=5;floor_gain=0.06;noise_ratio=8'),.Array~of('fc_dual_feed.py','dual_feed_enhance_helper_consistent.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.mvdr.dual','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'Two-element MVDR beamformer',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO),mono,whole,gpu,self~params('n_fft=2048;hop=512;diagonal_loading=1e-4;steering=coherent'),.Array~of('fc_dual_feed.py','dual_feed_enhance.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.clean_spectral_lines','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'CLEAN-style iterative spectral-line suppression',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO),any,blockFFT,gpu,self~params('iterations=8;gain=0.5;beam_width_bins=2.5;minimum_gain=0.05'),.Array~of('fc_dual_feed.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('mask.echo_persistence','1',.AudioProcessingConstant~FAMILY_MASK,'Delayed-energy persistence mask',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_MASK,.AudioProcessingConstant~OUTPUT_AUDIO),any,streamFFT,gpu,self~params('delay_min_ms=10;delay_max_ms=120;delay_step_ms=10;normalization_sec=2.0;threshold=0.4;slope=8'),.Array~of('dual_feed_enhance_v4.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('measurement.room_profile','1',.AudioProcessingConstant~FAMILY_MEASUREMENT,'Blind transient/reflection room profile',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_MEASUREMENT),any,whole,cpu,self~params(''),.Array~of('dual_feed_enhance_v5.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('mask.coherence.multi_domain','1',.AudioProcessingConstant~FAMILY_MASK,'Spatial/echo/wavefront multi-domain fusion',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_MASK,.AudioProcessingConstant~OUTPUT_AUDIO),mono,whole,gpu,self~params('n_fft=2048;hop=512;delay_min_ms=10;delay_max_ms=120;delay_step_ms=10;spatial_weight=0.45;wavefront_weight=0.25;echo_weight=0.30;threshold=0.35;slope=12'),.Array~of('dual_feed_enhance_v5.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('mask.coherence.five_domain','1',.AudioProcessingConstant~FAMILY_MASK,'Spatial, echo, wavefront, syllabic and harmonic fusion',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_MASK,.AudioProcessingConstant~OUTPUT_AUDIO),mono,whole,gpu,self~params('spatial_weight=0.35;echo_weight=0.25;wavefront_weight=0.15;modulation_weight=0.15;harmonic_weight=0.10'),.Array~of('dual_feed_enhance_v6.py'),'CATALOGUED'))
  c~add(.AudioProcessorSpec~new('measurement.harmonic_product','1',.AudioProcessingConstant~FAMILY_MEASUREMENT,'Harmonic Product Spectrum',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_MEASUREMENT,.AudioProcessingConstant~OUTPUT_FEATURE_MAP),any,blockFFT,gpu,self~params('n_fft=2048;hop=512;harmonics=3'),.Array~of('dual_feed_enhance_v7.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('mask.syllabic_modulation','1',.AudioProcessingConstant~FAMILY_MASK,'2-8 Hz speech-envelope modulation weighting',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_MASK),any,streamFFT,gpu,self~params('low_hz=2;high_hz=8'),.Array~of('dual_feed_enhance_v7.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('measurement.spectral_tilt','1',.AudioProcessingConstant~FAMILY_MEASUREMENT,'Speech spectral-tilt estimate',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_MEASUREMENT),any,blockFFT,cpu,self~params('n_fft=2048;hop=512;low_hz=100;high_hz=6000'),.Array~of('dual_feed_enhance_v7.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.log_likelihood_fusion','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'Harmonic/modulation/tilt evidence fusion across two feeds',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO,.AudioProcessingConstant~OUTPUT_MASK),mono,whole,gpu,self~params('n_fft=2048;hop=512;harmonics=3'),.Array~of('dual_feed_enhance_v7.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.eigen_noise_projection','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'Two-channel covariance eigen-noise projection',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO),mono,whole,gpu,self~params('regularization=1e-7'),.Array~of('dual_feed_enhance_v8.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('transform.dynamic_filters','1',.AudioProcessingConstant~FAMILY_TRANSFORM,'Time-scoped notch/high-pass/low-pass rule application with persistent filter state',.Array~of('PRIMARY'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO),any,.AudioStreamingProfile~new(.true,'STATEFUL',4096,0,0,0,.false,.true,'REALTIME','PROVIDER_AFFINE'),cpu,self~params('max_filters_per_block=4'),.Array~of('dual_feed_enhance_v8.py','custom_trial_mix.py'),'REFERENCE'))
  c~add(.AudioProcessorSpec~new('spatial.tdoa.geo','1',.AudioProcessingConstant~FAMILY_SPATIAL,'Geometry-constrained TDOA candidate scoring',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_SPATIAL,.AudioProcessingConstant~OUTPUT_MEASUREMENT),mono,whole,gpu,self~params(''),.Array~of('dual_feed_enhance_v10_2_geo_scene_dual_tdoa.py','dual_feed_enhance_v11_zonal_scene.py'),'CATALOGUED'))
  c~add(.AudioProcessorSpec~new('composite.zonal_scene','1',.AudioProcessingConstant~FAMILY_COMPOSITE,'Zonal scene likelihood and stem rendering',.Array~of('A','B'),.Array~of(.AudioProcessingConstant~OUTPUT_AUDIO,.AudioProcessingConstant~OUTPUT_SPATIAL),mono,whole,gpu,self~params(''),.Array~of('dual_feed_enhance_v11_zonal_scene.py'),'CATALOGUED'))
  return c

::method params class private
  use strict arg text
  d=.Directory~new
  rest=text
  do while rest<>''
    p=rest~pos(';')
    if p=0 then do
      item=rest
      rest=''
    end
    else do
      item=rest~left(p-1)
      rest=rest~substr(p+1)
    end
    eq=item~pos('=')
    if eq>0 then d[item~left(eq-1)]=item~substr(eq+1)
  end
  return d

/* Time-scoped filter semantics are Audio objects.  The first-generation Python
 * scripts used timestamp-keyed JSON maps; v0.21 normalises those rules into
 * sample-domain intervals so streaming and offline execution share one meaning. */
::class AudioFilterRule public
::attribute id
::attribute action
::attribute startSample
::attribute endSample
::attribute frequencyHz
::attribute q
::attribute order
::attribute attributes

::method init
  use strict arg id, action, startSample=0, endSample=(0-1), frequencyHz=0, q=30, order=4, attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  if startSample<0 then raise syntax 88.900 array('audio filter rule start sample must be non-negative')
  if endSample>=0 & endSample<=startSample then raise syntax 88.900 array('audio filter rule end sample must be greater than start sample')
  a=action~string~upper
  if a<>'NOTCH' & a<>'HIGHPASS' & a<>'LOWPASS' then raise syntax 88.900 array('unsupported audio filter rule action ' || action)
  self~id=id~string
  self~action=a
  self~startSample=startSample
  self~endSample=endSample
  self~frequencyHz=frequencyHz
  self~q=q
  self~order=order
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method activeFor
  use strict arg blockStart, blockCount
  blockEnd=blockStart+blockCount
  if blockCount<=0 then return .false
  if self~endSample>=0 & self~endSample<=blockStart then return .false
  if self~startSample>=blockEnd then return .false
  return .true

::method canonicalText
  return 'AUDIO_FILTER_RULE=' || self~id || '|action=' || self~action || '|start=' || self~startSample || '|end=' || self~endSample || '|frequencyHz=' || self~frequencyHz || '|q=' || self~q || '|order=' || self~order || '|attributes=' || .AudioProcessingUtil~canonicalDirectory(self~attributes)


::class AudioDynamicFilterPlan public
::attribute id
::attribute rules
::attribute maxFiltersPerBlock
::attribute attributes

::method init
  use strict arg id, rules=.nil, maxFiltersPerBlock=4, attributes=.nil
  if rules==.nil then rules=.Array~new
  if attributes==.nil then attributes=.Directory~new
  if maxFiltersPerBlock<1 then raise syntax 88.900 array('dynamic filter plan maxFiltersPerBlock must be positive')
  self~id=id~string
  self~rules=.AudioProcessingUtil~copyArray(rules)
  do rule over self~rules
    if \rule~isa(.AudioFilterRule) then raise syntax 88.900 array('dynamic filter plan contains non-AudioFilterRule value')
  end
  self~maxFiltersPerBlock=maxFiltersPerBlock
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method activeRules
  use strict arg blockStart, blockCount
  out=.Array~new
  do rule over self~rules
    if rule~activeFor(blockStart,blockCount) then do
      out~append(rule)
      if out~items>=self~maxFiltersPerBlock then leave
    end
  end
  return out

::method canonicalText
  a=.Array~new
  do rule over self~rules; a~append(rule~canonicalText); end
  return 'AUDIO_DYNAMIC_FILTER_PLAN=' || self~id || '|max=' || self~maxFiltersPerBlock || '|rules=' || .AudioProcessingUtil~join(a,'||') || '|attributes=' || .AudioProcessingUtil~canonicalDirectory(self~attributes)


/* Streaming block semantics are part of the Audio contract, not provider loop mechanics. */
::class AudioProcessingBlock public
::attribute sequence
::attribute startSample
::attribute sampleCount
::attribute overlapBefore
::attribute overlapAfter
::attribute endOfStream
::attribute materialRefs
::attribute attributes

::method init
  use strict arg sequence, startSample, sampleCount, overlapBefore=0, overlapAfter=0, endOfStream=.false, materialRefs=.nil, attributes=.nil
  if materialRefs==.nil then materialRefs=.Array~new
  if attributes==.nil then attributes=.Directory~new
  if sequence<1 | startSample<0 | sampleCount<0 | overlapBefore<0 | overlapAfter<0 then raise syntax 88.900 array('invalid audio processing block geometry')
  self~sequence=sequence
  self~startSample=startSample
  self~sampleCount=sampleCount
  self~overlapBefore=overlapBefore
  self~overlapAfter=overlapAfter
  self~endOfStream=endOfStream
  self~materialRefs=.AudioProcessingUtil~copyArray(materialRefs)
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method endSample
  return self~startSample+self~sampleCount

::method canonicalText
  return 'AUDIO_BLOCK=' || self~sequence || '|start=' || self~startSample || '|count=' || self~sampleCount || '|overlapBefore=' || self~overlapBefore || '|overlapAfter=' || self~overlapAfter || '|eos=' || self~endOfStream || '|materials=' || .AudioProcessingUtil~join(self~materialRefs)


::class AudioProcessingStreamCheckpoint public
::attribute sessionId
::attribute processorId
::attribute configId
::attribute stateVersion
::attribute nextSequence
::attribute processedSamples
::attribute lastEndSample
::attribute endOfStreamSeen
::attribute flushed
::attribute stateKind
::attribute stateSummary

::method init
  use strict arg sessionId, processorId, configId, stateVersion, nextSequence, processedSamples, lastEndSample, endOfStreamSeen=.false, flushed=.false, stateKind='SEMANTIC', stateSummary=.nil
  if stateSummary==.nil then stateSummary=.Directory~new
  self~sessionId=sessionId~string
  self~processorId=processorId~string
  self~configId=configId~string
  self~stateVersion=stateVersion
  self~nextSequence=nextSequence
  self~processedSamples=processedSamples
  self~lastEndSample=lastEndSample
  self~endOfStreamSeen=endOfStreamSeen
  self~flushed=flushed
  self~stateKind=stateKind~string~upper
  self~stateSummary=.AudioProcessingUtil~copyDirectory(stateSummary)

::method toDirectory
  d=.Directory~new
  d['schema']='layered-audio.processing.stream.checkpoint/0.1'
  d['session_id']=self~sessionId
  d['processor_id']=self~processorId
  d['config_id']=self~configId
  d['state_version']=self~stateVersion
  d['next_sequence']=self~nextSequence
  d['processed_samples']=self~processedSamples
  d['last_end_sample']=self~lastEndSample
  d['end_of_stream_seen']=self~endOfStreamSeen
  d['flushed']=self~flushed
  d['state_kind']=self~stateKind
  d['state_summary']=.AudioProcessingUtil~copyDirectory(self~stateSummary)
  return d

::method canonicalText
  return 'AUDIO_STREAM_CHECKPOINT=' || self~sessionId || '|processor=' || self~processorId || '|config=' || self~configId || '|version=' || self~stateVersion || '|next=' || self~nextSequence || '|processed=' || self~processedSamples || '|lastEnd=' || self~lastEndSample || '|eos=' || self~endOfStreamSeen || '|flushed=' || self~flushed || '|stateKind=' || self~stateKind || '|summary=' || .AudioProcessingUtil~canonicalDirectory(self~stateSummary)


::class AudioProcessingStreamBlockResult public
::attribute block get
::attribute checkpoint get

::method init
  expose block checkpoint processingResult
  use strict arg blockArg, resultArg, checkpointArg
  block=blockArg
  processingResult=resultArg
  checkpoint=checkpointArg

::method result
  expose processingResult
  return processingResult


::class AudioProcessingStreamSession public
::attribute id
::attribute config
::attribute profile
::attribute processorId
::attribute acceptedBlocks
::attribute flushed
::attribute endOfStreamSeen
::attribute lastSequence
::attribute lastStartSample
::attribute lastEndSample
::attribute processedSamples
::attribute stateVersion

::method init
  use strict arg id, config, profile, processorId=''
  if \profile~streamingCapable then raise syntax 88.900 array('processor profile is not streaming-capable')
  self~id=id~string
  self~config=config
  self~profile=profile
  if processorId='' then processorId=config~processorId
  self~processorId=processorId~string
  self~acceptedBlocks=.Array~new
  self~flushed=.false
  self~endOfStreamSeen=.false
  self~lastSequence=0
  self~lastStartSample=(0-1)
  self~lastEndSample=(0-1)
  self~processedSamples=0
  self~stateVersion=1

::method acceptBlock
  use strict arg block
  if self~flushed then raise syntax 88.900 array('cannot accept block after stream flush')
  if self~endOfStreamSeen then raise syntax 88.900 array('cannot accept block after end-of-stream block')
  if block~sequence<>self~lastSequence+1 then raise syntax 88.900 array('audio processing block sequence is not contiguous')
  if self~lastStartSample>=0 & block~startSample<self~lastStartSample then raise syntax 88.900 array('audio processing blocks moved backwards in source time')
  self~acceptedBlocks~append(block)
  self~lastSequence=block~sequence
  self~lastStartSample=block~startSample
  self~lastEndSample=block~endSample
  self~processedSamples=self~processedSamples+block~sampleCount
  if block~endOfStream then self~endOfStreamSeen=.true
  self~stateVersion=self~stateVersion+1
  if block~endOfStream & \self~profile~flushRequired then self~flushed=.true
  return self

::method flush
  if self~flushed then return self
  self~flushed=.true
  self~stateVersion=self~stateVersion+1
  return self

::method checkpoint
  use strict arg stateKind='SEMANTIC', stateSummary=.nil
  if stateSummary==.nil then stateSummary=.Directory~new
  return .AudioProcessingStreamCheckpoint~new(self~id,self~processorId,self~config~id,self~stateVersion,self~lastSequence+1,self~processedSamples,self~lastEndSample,self~endOfStreamSeen,self~flushed,stateKind,stateSummary)

::method canonicalText
  return 'AUDIO_STREAM_SESSION=' || self~id || '|processor=' || self~processorId || '|config=' || self~config~id || '|blocks=' || self~acceptedBlocks~items || '|processed=' || self~processedSamples || '|version=' || self~stateVersion || '|eos=' || self~endOfStreamSeen || '|flushed=' || self~flushed


/* Placement requirement seam.  These are requirements/hints only; Audio does not
 * rank nodes or allocate GPU resources.  A Job-to-Node adapter may translate them
 * into the allocator's authoritative requirement vocabulary. */
::class AudioProcessingPlacementRequirements public
::attribute processorId
::attribute gpuMode
::attribute minimumVramBytes
::attribute cpuClass
::attribute batchable
::attribute streamingCapable
::attribute stateMode
::attribute stateTransferMode
::attribute sessionAffinityRequired
::attribute estimatedWorkingSetBytes
::attribute capabilityRequirements
::attribute attributes

::method init
  use strict arg processorSpec, estimatedWorkingSetBytes=0, attributes=.nil
  if attributes==.nil then attributes=.Directory~new
  ex=processorSpec~execution
  self~processorId=processorSpec~id
  self~gpuMode=ex~gpuMode
  self~minimumVramBytes=ex~minimumVramBytes
  self~cpuClass=ex~cpuClass
  self~batchable=ex~batchable
  self~streamingCapable=processorSpec~streaming~streamingCapable
  self~stateMode=processorSpec~streaming~stateMode
  self~stateTransferMode=processorSpec~streaming~stateTransferMode
  self~sessionAffinityRequired=(self~stateMode='STATEFUL' & self~stateTransferMode='PROVIDER_AFFINE')
  self~estimatedWorkingSetBytes=estimatedWorkingSetBytes
  self~capabilityRequirements=.AudioProcessingUtil~copyDirectory(ex~capabilityRequirements)
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method gpuRequired
  return self~gpuMode=.AudioProcessingConstant~GPU_REQUIRED

::method gpuPreferred
  return self~gpuMode=.AudioProcessingConstant~GPU_PREFERRED | self~gpuRequired

::method asDirectory
  d=.Directory~new
  d['processor_id']=self~processorId
  d['gpu_mode']=self~gpuMode
  d['gpu_required']=self~gpuRequired
  d['gpu_preferred']=self~gpuPreferred
  d['minimum_vram_bytes']=self~minimumVramBytes
  d['cpu_class']=self~cpuClass
  d['batchable']=self~batchable
  d['streaming_capable']=self~streamingCapable
  d['state_mode']=self~stateMode
  d['state_transfer_mode']=self~stateTransferMode
  d['session_affinity_required']=self~sessionAffinityRequired
  d['estimated_working_set_bytes']=self~estimatedWorkingSetBytes
  do k over self~capabilityRequirements; d['capability.'||k]=self~capabilityRequirements[k]; end
  return d

::method canonicalText
  return 'AUDIO_PLACEMENT|processor=' || self~processorId || '|gpu=' || self~gpuMode || '|minVram=' || self~minimumVramBytes || '|cpu=' || self~cpuClass || '|batchable=' || self~batchable || '|streaming=' || self~streamingCapable || '|state=' || self~stateMode || '|stateTransfer=' || self~stateTransferMode || '|affinity=' || self~sessionAffinityRequired || '|workingSet=' || self~estimatedWorkingSetBytes

/* Pure/value dispatch envelope for Runtime Reference / queue / managed-node adapters.
 * Live ForeignBuffer/ForeignTensor capabilities are intentionally excluded. */
::class AudioProcessingDispatchEnvelope public
::attribute requestId
::attribute processorId
::attribute configId
::attribute parameters
::attribute inputs
::attribute outputKinds
::attribute placement
::attribute attributes

::method init
  use strict arg requestId, processorSpec, config, inputs=.nil, outputKinds=.nil, placement=.nil, attributes=.nil
  if inputs==.nil then inputs=.Array~new
  if outputKinds==.nil then outputKinds=processorSpec~outputKinds
  if placement==.nil then placement=.AudioProcessingPlacementRequirements~new(processorSpec)
  if attributes==.nil then attributes=.Directory~new
  do x over inputs
    if \x~isa(.AudioProcessingInputRef) then raise syntax 88.900 array('dispatch envelope inputs must be semantic AudioProcessingInputRef values')
  end
  self~requestId=requestId~string
  self~processorId=processorSpec~id
  self~configId=config~id
  self~parameters=.AudioProcessingUtil~copyDirectory(config~parameters)
  self~inputs=.AudioProcessingUtil~copyArray(inputs)
  self~outputKinds=.AudioProcessingUtil~copyArray(outputKinds)
  self~placement=placement
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method toDirectory
  d=.Directory~new
  d['schema']='layered-audio.processing.dispatch/0.1'
  d['request_id']=self~requestId
  d['processor_id']=self~processorId
  d['config_id']=self~configId
  d['parameters']=.AudioProcessingUtil~copyDirectory(self~parameters)
  refs=.Array~new
  do x over self~inputs; refs~append(x~canonicalText); end
  d['input_refs']=refs
  d['output_kinds']=.AudioProcessingUtil~copyArray(self~outputKinds)
  d['placement']=self~placement~asDirectory
  d['attributes']=.AudioProcessingUtil~copyDirectory(self~attributes)
  return d

::method canonicalText
  d=self~toDirectory
  return 'AUDIO_DISPATCH=' || self~requestId || '|processor=' || self~processorId || '|config=' || self~configId || '|inputs=' || .AudioProcessingUtil~join(d['input_refs'],';') || '|outputs=' || .AudioProcessingUtil~join(self~outputKinds) || '|' || self~placement~canonicalText

/* Value-only per-block envelope for remote/queued streaming execution.  A
 * provider-affine implementation carries the same session id to subsequent
 * blocks; no ForeignBuffer/ForeignTensor/Python handle is serialized here. */
::class AudioProcessingStreamDispatchEnvelope public
::attribute requestId
::attribute sessionId
::attribute processorId
::attribute configId
::attribute checkpoint
::attribute block
::attribute inputs
::attribute placement
::attribute attributes

::method init
  use strict arg requestId, sessionId, processorSpec, config, checkpoint, block, inputs=.nil, placement=.nil, attributes=.nil
  if inputs==.nil then inputs=.Array~new
  if placement==.nil then placement=.AudioProcessingPlacementRequirements~new(processorSpec)
  if attributes==.nil then attributes=.Directory~new
  if \checkpoint~isa(.AudioProcessingStreamCheckpoint) then raise syntax 88.900 array('stream dispatch checkpoint must be AudioProcessingStreamCheckpoint')
  if \block~isa(.AudioProcessingBlock) then raise syntax 88.900 array('stream dispatch block must be AudioProcessingBlock')
  do x over inputs
    if \x~isa(.AudioProcessingInputRef) then raise syntax 88.900 array('stream dispatch inputs must be semantic AudioProcessingInputRef values')
  end
  self~requestId=requestId~string
  self~sessionId=sessionId~string
  self~processorId=processorSpec~id
  self~configId=config~id
  self~checkpoint=checkpoint
  self~block=block
  self~inputs=.AudioProcessingUtil~copyArray(inputs)
  self~placement=placement
  self~attributes=.AudioProcessingUtil~copyDirectory(attributes)

::method toDirectory
  d=.Directory~new
  d['schema']='layered-audio.processing.stream.dispatch/0.1'
  d['request_id']=self~requestId
  d['session_id']=self~sessionId
  d['processor_id']=self~processorId
  d['config_id']=self~configId
  d['checkpoint']=self~checkpoint~toDirectory
  d['block']=self~block~canonicalText
  refs=.Array~new
  do x over self~inputs; refs~append(x~canonicalText); end
  d['input_refs']=refs
  d['placement']=self~placement~asDirectory
  d['attributes']=.AudioProcessingUtil~copyDirectory(self~attributes)
  return d

::method canonicalText
  d=self~toDirectory
  return 'AUDIO_STREAM_DISPATCH=' || self~requestId || '|session=' || self~sessionId || '|processor=' || self~processorId || '|config=' || self~configId || '|' || self~checkpoint~canonicalText || '|' || self~block~canonicalText || '|inputs=' || .AudioProcessingUtil~join(d['input_refs'],';') || '|' || self~placement~canonicalText

