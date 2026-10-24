/* Architecture Domain Model — scope.identity/0.1
 * Business statements, participants, subjects and existing estates are
 * different facts. No subject is promoted to a security principal by name.
 * Every entity/relation is an explicitly attributed *design fact/proposal*;
 * no entry proves a deployed mechanism or successful authentication.
 */
::requires 'json.cls'

::class ArchitectureDomainModel public
::attribute entities get
::attribute relationships get
::attribute statements get
::attribute facts get

::method init
  expose entities relationships statements facts
  entities = .Directory~new
  relationships = .Array~new
  statements = .Array~new
  facts = .Directory~new

/* Keep original stakeholder language intact; never silently turn nouns
 * in a statement into users, database tables, or authentication mechanisms.
 */
::method statement
  use strict arg words, authority, evidence = ''
  if words~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_SCOPE_STATEMENT_INCOMPLETE')
  record = .Directory~new
  record['text'] = words
  record['authority'] = authority
  record['evidence'] = evidence
  record['status'] = 'UNINTERPRETED'
  self~statements~append(record)
  return record

/* These are scope *observations*, not platform selections. UNKNOWN is an
 * acceptable explicit answer only as a retained unresolved question. */
::method clarify
  use strict arg dimension, answer, authority, evidence = ''
  permitted = '|BUSINESS_OUTCOME|EXISTING_ESTATE|ACTORS_AND_PRINCIPALS|RECORD_OF_TRUTH|SCALE|INTEGRATION_BOUNDARIES|OPERATIONS|'
  if pos('|'dimension'|',permitted) == 0 then -
    raise syntax 93.900 array('ARCH_DOMAIN_DIMENSION_UNKNOWN',dimension)
  if answer~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_DOMAIN_CLARIFICATION_INCOMPLETE',dimension)
  row = .Directory~new
  row['dimension'] = dimension
  row['answer'] = answer
  row['authority'] = authority
  row['evidence'] = evidence
  row['status'] = 'STAKEHOLDER_DECLARED_NOT_VERIFIED'
  self~facts[dimension] = row
  return row

/* SUBJECT is a thing the business is about; PERSON/DEVICE/SERVICE are
 * possible actors; PRINCIPAL is an actual security identity/role boundary.
 * SYSTEM and DATASET describe an existing or proposed data estate.
 */
::method entity
  use strict arg identity, kind, label, authority, evidence = '', lifecycle = 'PROPOSED'
  if identity~strip == '' | label~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_SCOPE_ENTITY_INCOMPLETE')
  if pos('|'kind'|', '|SUBJECT|PERSON|DEVICE|SERVICE|PRINCIPAL|SYSTEM|DATASET|PROCESS|') == 0 then -
    raise syntax 93.900 array('ARCH_SCOPE_ENTITY_KIND_UNKNOWN', kind)
  if pos('|'lifecycle'|', '|PROPOSED|EXISTING|RETIRED|') == 0 then -
    raise syntax 93.900 array('ARCH_SCOPE_LIFECYCLE_UNKNOWN', lifecycle)
  if self~entities~hasIndex(identity) then -
    raise syntax 93.900 array('ARCH_SCOPE_ENTITY_DUPLICATE', identity)
  record = .Directory~new
  record['id'] = identity
  record['kind'] = kind
  record['label'] = label
  record['authority'] = authority
  record['evidence'] = evidence
  record['lifecycle'] = lifecycle
  record['status'] = 'DECLARED'
  self~entities[identity] = record
  return record

/* Relations describe *proposed meaning*, never grant privileges. Reject
 * the classic error of letting a subject authenticate merely by being known.
 */
::method relate
  use strict arg source, target, kind, rationale, authority, evidence = ''
  if self~entities~hasIndex(source) == .false | self~entities~hasIndex(target) == .false then -
    raise syntax 93.900 array('ARCH_SCOPE_RELATION_ENDPOINT_UNKNOWN', source, target)
  if rationale~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_SCOPE_RELATION_RATIONALE_REQUIRED')
  permitted = '|AUTHENTICATES_AS|REPRESENTS|IDENTIFIES|OWNS|READS|WRITES|EXPOSES|INTEGRATES_WITH|MIGRATES_FROM|'
  if pos('|'kind'|', permitted) == 0 then -
    raise syntax 93.900 array('ARCH_SCOPE_RELATION_KIND_UNKNOWN', kind)
  leftKind = self~entities[source]['kind']
  rightKind = self~entities[target]['kind']
  if kind == 'AUTHENTICATES_AS' then do
    if pos('|'leftKind'|', '|PERSON|DEVICE|SERVICE|') == 0 | rightKind \== 'PRINCIPAL' then -
      raise syntax 93.900 array('ARCH_SCOPE_IDENTITY_BOUNDARY', source, target)
  end
  if kind == 'REPRESENTS' then do
    if leftKind \== 'PRINCIPAL' | rightKind \== 'SUBJECT' then -
      raise syntax 93.900 array('ARCH_SCOPE_REPRESENTATION_BOUNDARY', source, target)
  end
  if kind == 'IDENTIFIES' then do
    if leftKind \== 'DEVICE' | rightKind \== 'SUBJECT' then -
      raise syntax 93.900 array('ARCH_SCOPE_IDENTIFICATION_BOUNDARY', source, target)
  end
  row = .Directory~new
  row['source'] = source
  row['target'] = target
  row['kind'] = kind
  row['rationale'] = rationale
  row['authority'] = authority
  row['evidence'] = evidence
  row['status'] = 'PROPOSED_NOT_VERIFIED'
  self~relationships~append(row)
  return row

::method hasRelation private
  use strict arg identity, kind, position
  do relation over self~relationships
    if relation['kind'] == kind & relation[position] == identity then return .true
  end
  return .false

/* Evidence questions are not answerable by a dropdown alone. Website clients
 * must offer actor/data-relationship editing instead of inventing a choice.
 */
::method openQuestions
  out = .Array~new
  /* A bare business statement starts discovery. Do not ask for every
   * platform subsystem or assume a database, authentication or cluster. */
  if self~statements~items > 0 then do
    dimensions = .Array~of('BUSINESS_OUTCOME','EXISTING_ESTATE', -
      'ACTORS_AND_PRINCIPALS','RECORD_OF_TRUTH','SCALE', -
      'INTEGRATION_BOUNDARIES','OPERATIONS')
    do dimension over dimensions
      unknown = .true
      if self~facts~hasIndex(dimension) then do
        value = self~facts[dimension]['answer']~strip~upper
        if value \== 'UNKNOWN' & value \== 'NOT_ASSESSED' then unknown = .false
      end
      if unknown then self~addQuestion(out, 'scope_'dimension, -
         'What is known about 'dimension' for this business?', -
         'Record actual requirements, existing estate, authority and evidence before picking runtime layers')
    end
  end
  do identity over self~entities~allIndexes
    row = self~entities[identity]
    kind = row['kind']
    if kind == 'SUBJECT' then do
      represented = self~hasRelation(identity, 'REPRESENTS', 'target')
      identified = self~hasRelation(identity, 'IDENTIFIES', 'target')
      if \represented & \identified then -
        self~addQuestion(out, 'subject_'identity, -
          'Is 'row['label']' a record, an authenticated party, a device-identified entity, or represented by somebody else?', -
          'Specify who acts, what is identified and what constitutes authorization; do not presume the subject logs in')
    end
    if kind == 'PRINCIPAL' then do
      if \self~hasRelation(identity, 'AUTHENTICATES_AS', 'target') then -
        self~addQuestion(out, 'principal_'identity, -
          'Who or what controls 'row['label']' and how will that identity be authenticated?', -
          'Record actor-to-principal proposal and a separate credential/identity policy decision')
    end
    if kind == 'SYSTEM' & row['lifecycle'] == 'EXISTING' & row['evidence'] == '' then -
      self~addQuestion(out, 'legacy_'identity, -
        'What verified interfaces, schema and operational constraints exist for 'row['label']'?', -
        'Obtain the system inventory and migration/coexistence evidence before replacement')
    if kind == 'DATASET' & row['lifecycle'] == 'EXISTING' & row['evidence'] == '' then -
      self~addQuestion(out, 'dataset_'identity, -
        'Which real schema/format, ownership and retention apply to 'row['label']'?', -
        'Obtain a schema sample and provenance; do not assume a database backend')
  end
  return out

::method addQuestion private
  use strict arg output, identity, wording, guidance
  question = .Directory~new
  question['id'] = 'domain_'identity
  question['section'] = '00-discovery'
  question['question'] = wording
  question['purpose'] = guidance
  question['answerMechanism'] = 'DOMAIN_RELATION_OR_EVIDENCE'
  question['options'] = .Array~new
  output~append(question)

::method snapshot
  outline = .Directory~new
  outline['schema'] = 'alchemy.architecture.domain/0.1'
  outline['statements'] = self~statements
  outline['facts'] = self~facts
  values = .Array~new
  do identity over self~entities~allIndexes
    values~append(self~entities[identity])
  end
  outline['entities'] = values
  outline['relationships'] = self~relationships
  outline['openQuestions'] = self~openQuestions
  outline['authority'] = 'Stakeholder-attributed design proposals; no identity or runtime evidence implied'
  return outline
