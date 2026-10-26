/* WorldEnsemble/0.2 -- pure ooRexx finite countermodel checker.
 * Synthetic teaching/qualification fixture only.
 * No claim that enumerated worlds exhaust reality. No numerical probabilities.
 * Separates observations of statements from the truth of their content.
 * Original ChatGPT GPT-6; missing-field open-world correction Claude Opus 4.8.
 */
::class WorldEnsemble public

::method init
  expose worlds observations
  worlds = .directory~new
  observations = .array~new

::method addWorld
  expose worlds
  use strict arg id, properties
  if worlds~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_WORLD:' || id)
  if \properties~isA(.Directory) then raise syntax 93.900 array('PROPERTIES_NOT_DIRECTORY')
  worlds[id] = properties
  return self

::method admit
  expose observations
  /* Observation is about a field, not a free-form allegation of what that field implies.
   * REPORTED is retained but does not constrain worlds; ADMITTED constrains fixture worlds.
   * sourceRoot is the upstream provenance root, not the document/copy id. */
  use strict arg id, field, value, sourceRoot, status = 'REPORTED'
  if status \= 'REPORTED' & status \= 'ADMITTED' then -
    raise syntax 93.900 array('INVALID_ADMISSION_STATUS:' || status)
  do o over observations
    if o['id'] = id then raise syntax 93.900 array('DUPLICATE_OBSERVATION:' || id)
  end
  o = .directory~new
  o['id'] = id; o['field'] = field; o['value'] = value
  o['sourceRoot'] = sourceRoot; o['status'] = status
  observations~append(o)
  return self

::method admittedCount
  expose observations
  c = 0
  do o over observations
    if o['status'] = 'ADMITTED' then c += 1
  end
  return c

::method distinctRoots
  expose observations
  use strict arg field = ''
  seen = .set~new
  do o over observations
    if o['status'] \= 'ADMITTED' then iterate
    if field \= '' & o['field'] \= field then iterate
    seen~put(o['sourceRoot'])
  end
  return seen~items

::method survivors
  expose worlds observations
  survivors = .array~new
  ids = worlds~allIndexes
  ids~sort
  do id over ids
    w = worlds[id]
    consistent = .true
    do o over observations
      if o['status'] \= 'ADMITTED' then iterate
      field = o['field']
      if \w~hasIndex(field) then iterate  /* open-world: silence != contradiction */
      if w[field] \== o['value'] then do
        consistent = .false
        leave
      end
    end
    if consistent then survivors~append(id)
  end
  return survivors

::method assess
  expose worlds
  use strict arg field, expected
  ids = self~survivors
  r = .directory~new
  r['field'] = field
  r['expected'] = expected
  r['worldCount'] = ids~items
  r['completeness'] = 'OPEN_WORLD_ENUMERATION_NOT_EXHAUSTIVE'
  r['actualTruthProven'] = .false
  matches = .array~new; counter = .array~new; missing = .array~new
  do id over ids
    w = worlds[id]
    if \w~hasIndex(field) then missing~append(id)
    else if w[field] == expected then matches~append(id)
    else counter~append(id)
  end
  r['supports'] = matches; r['counterexamples'] = counter; r['unknownField'] = missing
  select
    when ids~items = 0 then r['status'] = 'MODEL_OR_EVIDENCE_CONFLICT'
    when missing~items > 0 then r['status'] = 'UNKNOWN_IN_MODEL'
    when counter~items = 0 then r['status'] = 'HOLDS_IN_LISTED_WORLDS_ONLY'
    when matches~items = 0 then r['status'] = 'REFUTED_IN_LISTED_WORLDS_ONLY'
    otherwise r['status'] = 'UNDERDETERMINED'
  end
  return r

::method indistinguishablePair
  /* Return two current worlds differing about a nominated proposition.
   * This is an explicit counterexample to any alleged inference from current observations. */
  expose worlds
  use strict arg field
  ids = self~survivors
  do i = 1 to ids~items
    wi = worlds[ids[i]]
    if \wi~hasIndex(field) then iterate
    do j = i + 1 to ids~items
      wj = worlds[ids[j]]
      if \wj~hasIndex(field) then iterate
      if wi[field] \== wj[field] then return .array~of(ids[i],ids[j])
    end
  end
  return .array~new

::method partition
  expose worlds
  use strict arg field
  r = .directory~new
  do id over self~survivors
    w = worlds[id]
    if w~hasIndex(field) then value = w[field]
    else value = '<UNKNOWN>'
    if \r~hasIndex(value) then r[value] = .array~new
    r[value]~append(id)
  end
  return r

::method observationReport
  expose observations
  r = .array~new
  do o over observations
    r~append(o['id'] || ' ' || o['status'] || ' ' || o['field'] || '=' || o['value'] || ' [' || o['sourceRoot'] || ']')
  end
  return r

/* NegativeSearch / 0.1
 * A no-match search is only negative evidence for an exact proposition when
 * source universe, event phase, date basis, date window, coverage, and source
 * integrity all match. It NEVER proves intentional evasion.
 * This is a syntactic scope gate, not source authentication or actual proof.
 */
::class NegativeSearch public
::method init
  expose id universe phase basis window coverage integrity searchOutcome
  use strict arg id, universe, phase, basis, window, coverage, integrity, searchOutcome = 'NO_MATCH'
  if coverage \= 'COMPLETE' & coverage \= 'INCOMPLETE' & coverage \= 'UNKNOWN' then -
    raise syntax 93.900 array('INVALID_COVERAGE')
  if integrity \= 'VERIFIED' & integrity \= 'UNVERIFIED' then -
    raise syntax 93.900 array('INVALID_INTEGRITY')
  if searchOutcome \= 'NO_MATCH' & searchOutcome \= 'MATCH_FOUND' then -
    raise syntax 93.900 array('INVALID_RESULT')
::attribute id get
::method result
  expose searchOutcome
  return searchOutcome
::method evaluate
  expose universe phase basis window coverage integrity searchOutcome
  use strict arg targetUniverse, targetPhase, targetBasis, targetWindow
  r = .directory~new
  errors = .array~new
  if universe \== targetUniverse then errors~append('UNIVERSE_MISMATCH')
  if phase \== targetPhase then errors~append('TRANSACTION_PHASE_MISMATCH')
  if basis \== targetBasis then errors~append('DATE_BASIS_MISMATCH')
  if window \== targetWindow then errors~append('WINDOW_NOT_PROVEN_COVERING')
  if coverage \= 'COMPLETE' then errors~append('COVERAGE_NOT_COMPLETE')
  if integrity \= 'VERIFIED' then errors~append('SOURCE_NOT_VERIFIED')
  if searchOutcome \= 'NO_MATCH' then errors~append('NOT_A_NEGATIVE_RESULT')
  r['errors'] = errors
  r['truthProven'] = .false
  if errors~items > 0 then r['assessment'] = 'NO_VALID_ABSENCE_INFERENCE'
  else r['assessment'] = 'SCOPED_NEGATIVE_SUPPORT_ONLY'
  return r
