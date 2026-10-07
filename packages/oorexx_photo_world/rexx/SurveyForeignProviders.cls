/* Photo Survey World foreign-compute provider contracts.
 *
 * Authority boundary:
 *   - Photo Survey World owns survey semantics, observations and SurveyWorld.
 *   - ooRexx Maths owns reusable numerical values and higher mathematics.
 *   - Foreign providers may propose derived evidence, but never mutate SurveyWorld.
 */
::class SurveyDerivedEvidence public
::attribute kind get
::attribute provider get
::attribute providerVersion get
::attribute sourceDigest get
::attribute payload get
::attribute confidence get
::attribute coordinateConvention get
::method init
  expose kind provider providerVersion sourceDigest payload confidence coordinateConvention
  use strict arg kind, provider, providerVersion, sourceDigest, payload, confidence = .nil, coordinateConvention = ''

/* Named collection of Maths-owned numerical values.  Photo World may attach
 * semantic names, but numerical storage/precision/provider semantics remain
 * the responsibility of Maths.
 */
::class SurveyMathPayload public
::method init
  expose _values
  _values=.directory~new
::method put
  expose _values
  use strict arg name,value
  if value==.nil then raise syntax 88.900 array('MathValue payload', '.nil')
  if \value~isA(.MathValue) then raise syntax 88.900 array('MathValue payload', value~class~id)
  _values[name~upper]=value
  return value
::method at
  expose _values
  use strict arg name
  return _values[name~upper]
::method has
  expose _values
  use strict arg name
  return _values~hasIndex(name~upper)
::method names
  expose _values
  out=.array~new
  do k over _values; out~append(k); end
  return out
::method count
  expose _values
  return _values~items

/* Dense image depth carried by Maths rather than by a Photo World array type.
 * DEPTH_KIND is deliberately semantic: RELATIVE, INVERSE_RELATIVE, or METRIC.
 * Units are required only when the provider makes a metric claim.
 */
::class SurveyDepthField public
::attribute depthKind get
::attribute units get
::attribute matrix get
::attribute confidenceMatrix get
::method init
  expose depthKind units matrix confidenceMatrix
  use strict arg matrix, depthKind='RELATIVE', units='', confidenceMatrix=.nil
  if \matrix~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix depth field',matrix~class~id)
  if confidenceMatrix \== .nil then do
    if \confidenceMatrix~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix confidence field',confidenceMatrix~class~id)
    if confidenceMatrix~rows<>matrix~rows | confidenceMatrix~cols<>matrix~cols then -
      raise syntax 88.900 array('depth/confidence matrices with equal shape',matrix~rows'x'matrix~cols'/'confidenceMatrix~rows'x'confidenceMatrix~cols)
  end
  depthKind=depthKind~upper
  select
    when depthKind='RELATIVE' then nop
    when depthKind='INVERSE_RELATIVE' then nop
    when depthKind='METRIC' then nop
    otherwise raise syntax 88.900 array('RELATIVE, INVERSE_RELATIVE or METRIC depth kind',depthKind)
  end
  if depthKind='METRIC' then do
    if units='' then raise syntax 88.900 array('units for metric depth field','empty')
  end
::method rows; expose matrix; return matrix~rows
::method cols; expose matrix; return matrix~cols
::method context; expose matrix; return matrix~context

/* A mesh candidate is numerical material, not SurveyWorld geometry.  Vertices,
 * triangle indices and optional normals are Maths matrices.  Promotion into
 * world objects is a separate, explicit survey decision.
 */
::class SurveyMeshCandidate public
::attribute vertices get
::attribute faces get
::attribute normals get
::attribute coordinateConvention get
::method init
  expose vertices faces normals coordinateConvention
  use strict arg vertices,faces,normals=.nil,coordinateConvention='SURVEY_LOCAL_METRES'
  if \vertices~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix vertices',vertices~class~id)
  if \faces~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix faces',faces~class~id)
  if vertices~cols<>3 then raise syntax 88.900 array('Nx3 vertex matrix',vertices~rows'x'vertices~cols)
  if faces~cols<>3 then raise syntax 88.900 array('Mx3 triangle-index matrix',faces~rows'x'faces~cols)
  if normals \== .nil then do
    if \normals~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix normals',normals~class~id)
    if normals~rows<>vertices~rows | normals~cols<>3 then -
      raise syntax 88.900 array('Nx3 normal matrix matching vertices',normals~rows'x'normals~cols)
  end

::class SurveyDepthEvidence public subclass SurveyDerivedEvidence
::method init
  use strict arg provider,providerVersion,sourceDigest,depthField,confidence=.nil,coordinateConvention='IMAGE_DEPTH'
  if \depthField~isA(.SurveyDepthField) then raise syntax 88.900 array('SurveyDepthField',depthField~class~id)
  self~init:super('DEPTH',provider,providerVersion,sourceDigest,depthField,confidence,coordinateConvention)

::class SurveyMeshEvidence public subclass SurveyDerivedEvidence
::method init
  use strict arg provider,providerVersion,sourceDigest,meshCandidate,confidence=.nil
  if \meshCandidate~isA(.SurveyMeshCandidate) then raise syntax 88.900 array('SurveyMeshCandidate',meshCandidate~class~id)
  self~init:super('MESH_CANDIDATE',provider,providerVersion,sourceDigest,meshCandidate,confidence,meshCandidate~coordinateConvention)

::class SurveyDepthProvider public
::method providerName abstract
::method providerVersion abstract
::method infer abstract

::class SurveyGeoCandidateProvider public
::method providerName abstract
::method providerVersion abstract
::method locate abstract

::class SurveyMeshProvider public
::method providerName abstract
::method providerVersion abstract
::method reconstruct abstract

/* Adapter for an already-projected Alchemy Python object.  This class knows
 * nothing about Python startup, class loading or argument framing; Macrospace
 * owns that boundary.  Its raw result remains DERIVED material until a caller
 * promotes numerical output through the Maths-backed evidence classes above.
 */
::class SurveyPythonDepthProvider public subclass SurveyDepthProvider
::attribute foreignObject get
::attribute modelName get
::method init
  expose foreignObject modelName
  use strict arg foreignObject, modelName = 'Depth Anything V2'
::method providerName
  expose modelName
  return modelName
::method providerVersion
  expose foreignObject
  return foreignObject~providerVersion
::method infer
  expose foreignObject modelName
  use strict arg sourceRef, sourceDigest
  foreignOutput = foreignObject~infer(sourceRef)
  return .SurveyDerivedEvidence~new('DEPTH_RAW', modelName, self~providerVersion, sourceDigest, foreignOutput, .nil, 'FOREIGN_DERIVED')

::class SurveyPythonGeoProvider public subclass SurveyGeoCandidateProvider
::attribute foreignObject get
::method init
  expose foreignObject
  use strict arg foreignObject
::method providerName
  return 'GeoCLIP'
::method providerVersion
  expose foreignObject
  return foreignObject~providerVersion
::method locate
  expose foreignObject
  use strict arg sourceRef, sourceDigest
  foreignOutput = foreignObject~locate(sourceRef)
  return .SurveyDerivedEvidence~new('GEO_CANDIDATES_RAW', self~providerName, self~providerVersion, sourceDigest, foreignOutput, .nil, 'FOREIGN_DERIVED')

::class SurveyPythonMeshProvider public subclass SurveyMeshProvider
::attribute foreignObject get
::method init
  expose foreignObject
  use strict arg foreignObject
::method providerName
  return 'PyMeshLab'
::method providerVersion
  expose foreignObject
  return foreignObject~providerVersion
::method reconstruct
  expose foreignObject
  use strict arg geometryRef, sourceDigest
  foreignOutput = foreignObject~reconstruct(geometryRef)
  return .SurveyDerivedEvidence~new('MESH_CANDIDATE_RAW', self~providerName, self~providerVersion, sourceDigest, foreignOutput, .nil, 'FOREIGN_DERIVED')

::requires 'MathsBootstrap.cls'

/* Explicit promotion record.  A foreign/model result remains derived evidence;
 * this object records the deliberate conversion of supported raw foreign
 * evidence into a Maths-backed survey evidence object.  It never mutates a
 * SurveyWorld and therefore cannot itself mint world authority.
 */
::class SurveyEvidencePromotion public
::attribute rawEvidence get
::attribute promotedEvidence get
::attribute basis get
::method init
  expose rawEvidence promotedEvidence basis
  use strict arg rawEvidence,promotedEvidence,basis
  if \rawEvidence~isA(.SurveyDerivedEvidence) then raise syntax 88.900 array('SurveyDerivedEvidence raw evidence',rawEvidence~class~id)
  if \promotedEvidence~isA(.SurveyDerivedEvidence) then raise syntax 88.900 array('SurveyDerivedEvidence promoted evidence',promotedEvidence~class~id)
  if basis='' then raise syntax 88.900 array('non-empty explicit promotion basis','empty')
  if rawEvidence~sourceDigest \== promotedEvidence~sourceDigest then -
    raise syntax 88.900 array('matching source digest',rawEvidence~sourceDigest'/'promotedEvidence~sourceDigest)
  if rawEvidence~provider \== promotedEvidence~provider then -
    raise syntax 88.900 array('matching provider',rawEvidence~provider'/'promotedEvidence~provider)
  if rawEvidence~providerVersion \== promotedEvidence~providerVersion then -
    raise syntax 88.900 array('matching provider version',rawEvidence~providerVersion'/'promotedEvidence~providerVersion)
  select
    when rawEvidence~kind='DEPTH_RAW' then do
      if \promotedEvidence~isA(.SurveyDepthEvidence) then raise syntax 88.900 array('SurveyDepthEvidence promotion target',promotedEvidence~class~id)
    end
    when rawEvidence~kind='MESH_CANDIDATE_RAW' then do
      if \promotedEvidence~isA(.SurveyMeshEvidence) then raise syntax 88.900 array('SurveyMeshEvidence promotion target',promotedEvidence~class~id)
    end
    otherwise raise syntax 88.900 array('supported raw evidence kind DEPTH_RAW or MESH_CANDIDATE_RAW',rawEvidence~kind)
  end
::method authority
  return 'PROMOTION_RECORD_ONLY'
::method mutatesWorld
  return .false

/* Structural-image evidence is intentionally a raw provider lane.  It may
 * detect line/edge evidence, but it does not mint SurveyWorld geometry. */
::class SurveyStructureProvider public
::method providerName abstract
::method providerVersion abstract
::method analyze abstract

::class SurveyPythonStructureProvider public subclass SurveyStructureProvider
::attribute foreignObject get
::attribute modelName get
::method init
  expose foreignObject modelName
  use strict arg foreignObject,modelName='OpenCV LSD structure'
::method providerName
  expose modelName
  return modelName
::method providerVersion
  expose foreignObject
  return foreignObject~providerVersion
::method analyze
  expose foreignObject modelName
  use strict arg sourceRef,sourceDigest
  foreignOutput=foreignObject~analyze(sourceRef)
  return .SurveyDerivedEvidence~new('STRUCTURE_RAW',modelName,self~providerVersion,sourceDigest,foreignOutput,.nil,'IMAGE_2D_DERIVED')
