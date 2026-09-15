/*
 * AlgorithmInputConsistency.cls
 *
 * Explicit consistency evidence for frozen table-fed algorithm inputs.
 * A frozen observation is immutable after capture, but that alone does not
 * imply that its upstream sources were observed atomically.
 */

::class AlgorithmInputConsistencyConstant public
::constant FROZEN_OBSERVATION   'FROZEN_OBSERVATION'
::constant SOURCE_SNAPSHOT      'SOURCE_SNAPSHOT'
::constant COORDINATED_SNAPSHOT 'COORDINATED_SNAPSHOT'

::class AlgorithmInputConsistencyDescriptor public
::attribute grade get
::attribute sourceCount get
::attribute coordinatorIdentity get
::attribute snapshotToken get
::attribute hash get

::method init
  expose grade sourceCount coordinatorIdentity snapshotToken storedEvidence canonicalTextValue hash
  use arg gradeArg = .nil, sourceCountArg = 1, coordinatorIdentityArg = '', snapshotTokenArg = '', evidenceArg = .nil
  if gradeArg == .nil then gradeArg = .AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION
  grade = gradeArg~string~upper
  sourceCount = sourceCountArg
  coordinatorIdentity = coordinatorIdentityArg~string
  snapshotToken = snapshotTokenArg~string
  if evidenceArg == .nil then evidenceArg = .array~new

  if \self~isKnownGrade(grade) then raise syntax 93.900 additional('Unknown Algorithm Input consistency grade:' grade)
  if \datatype(sourceCount, 'W') then raise syntax 93.900 additional('Consistency sourceCount must be a whole number')
  if sourceCount < 0 then raise syntax 93.900 additional('Consistency sourceCount may not be negative')
  if grade == .AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT then do
    if sourceCount \= 1 then raise syntax 93.900 additional('SOURCE_SNAPSHOT requires exactly one source')
    if snapshotToken == '' then raise syntax 93.900 additional('SOURCE_SNAPSHOT requires a snapshot token')
  end
  if grade == .AlgorithmInputConsistencyConstant~COORDINATED_SNAPSHOT then do
    if sourceCount < 1 then raise syntax 93.900 additional('COORDINATED_SNAPSHOT requires at least one source')
    if snapshotToken == '' then raise syntax 93.900 additional('COORDINATED_SNAPSHOT requires a snapshot token')
    if coordinatorIdentity == '' then raise syntax 93.900 additional('COORDINATED_SNAPSHOT requires a coordinator identity')
  end

  storedEvidence = .array~new
  evidenceKeys = .array~new
  do item over evidenceArg
    evidenceKeys~append(item~string)
  end
  evidenceKeys~sort
  do item over evidenceKeys
    storedEvidence~append(item)
  end

  canonicalTextValue = self~buildCanonicalText
  hash = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method isKnownGrade private
  use arg candidate
  if candidate == .AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION then return .true
  if candidate == .AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT then return .true
  if candidate == .AlgorithmInputConsistencyConstant~COORDINATED_SNAPSHOT then return .true
  return .false

::method rank
  if self~grade == .AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION then return 10
  if self~grade == .AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT then return 20
  if self~grade == .AlgorithmInputConsistencyConstant~COORDINATED_SNAPSHOT then return 30
  return 0

::method satisfies
  use arg requiredGrade
  requiredText = requiredGrade~string~upper
  select
    when requiredText == .AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION then requiredRank = 10
    when requiredText == .AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT then requiredRank = 20
    when requiredText == .AlgorithmInputConsistencyConstant~COORDINATED_SNAPSHOT then requiredRank = 30
    otherwise raise syntax 93.900 additional('Unknown required Algorithm Input consistency grade:' requiredText)
  end
  return self~rank >= requiredRank

::method evidence
  expose storedEvidence
  copied = .array~new
  do item over storedEvidence
    copied~append(item)
  end
  return copied

::method buildCanonicalText private
  expose storedEvidence
  text = 'ALGREL_INPUT_CONSISTENCY_V1' || '0a'x
  text = text || 'GRADE=' || self~grade || '0a'x
  text = text || 'SOURCE_COUNT=' || self~sourceCount || '0a'x
  text = text || 'COORDINATOR=' || self~coordinatorIdentity~length || ':' || self~coordinatorIdentity || '0a'x
  text = text || 'SNAPSHOT_TOKEN=' || self~snapshotToken~length || ':' || self~snapshotToken || '0a'x
  text = text || 'EVIDENCE_COUNT=' || storedEvidence~items || '0a'x
  do item over storedEvidence
    text = text || item~length || ':' || item || '0a'x
  end
  return text

::method canonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method render
  return self~grade || '|sources=' || self~sourceCount || '|coordinator=' || self~coordinatorIdentity || '|snapshot=' || self~snapshotToken || '|hash=' || self~hash

::requires 'AlgorithmIntegrity.cls'
