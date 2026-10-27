/* JudgmentReasoningLedger/0.1 - public-source judicial reasoning trace.
 * Architecture: Tom Dyer. Code: ChatGPT GPT-6.
 * Generic, domain-neutral; does not judge whether witness events are true.
 * Source-anchored actors must remain distinct: prior tribunal vs appellate court.
 */
::class JudgmentReasoningLedger public
::method init
  expose nodes edges
  nodes = .directory~new
  edges = .array~new

::method record
  expose nodes
  use strict arg id, actor, kind, cite, statement
  if id = '' | actor = '' | cite = '' | statement = '' then -
    raise syntax 93.900 array('SOURCE_ID_ACTOR_CITATION_AND_TEXT_REQUIRED')
  if nodes~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_RECORD:' || id)
  if \.array~of('UT_AS_REPORTED','CA_JUDICIAL_FINDING','CA_LEGAL_RULE','CA_REPORTED_EVIDENCE','CA_OUTCOME')~hasItem(actor) then -
    raise syntax 93.900 array('UNKNOWN_ACTOR:' || actor)
  n = .directory~new
  n['id'] = id; n['actor'] = actor; n['kind'] = kind
  n['cite'] = cite; n['statement'] = statement
  n['underlyingTruthCertified'] = .false
  nodes[id] = n
  return self

::method relate
  expose nodes edges
  use strict arg sourceId, targetId, relation
  if \nodes~hasIndex(sourceId) | \nodes~hasIndex(targetId) then -
    raise syntax 93.900 array('UNRESOLVED_PROVENANCE_NODE')
  if \.array~of('CORRECTS_STANDARD','QUALIFIES_NO_DUTY','CHALLENGES_CORROBORATION',- 
        'REJECTS_CONFLATION','IDENTIFIES_OMISSION','REMAKES_PRIOR','DISTINGUISHES_ISSUES')~hasItem(relation) then -
    raise syntax 93.900 array('UNKNOWN_RELATION:' || relation)
  e = .directory~new
  e['from'] = sourceId; e['to'] = targetId; e['relation'] = relation
  edges~append(e)
  return self

::method node
  expose nodes
  use strict arg id
  if \nodes~hasIndex(id) then raise syntax 93.900 array('UNKNOWN_RECORD:' || id)
  return nodes[id]

::method trace
  expose nodes edges
  a = .array~new
  do e over edges
    f = nodes[e['from']]; t = nodes[e['to']]
    a~append(e['relation'] || ' [' || f['actor'] || ' ' || f['cite'] || '] ' || -
       f['id'] || ' -> [' || t['actor'] || ' ' || t['cite'] || '] ' || t['id'])
  end
  return a

::method audit
  expose nodes edges
  out = .directory~new
  out['validatedTruth'] = .false
  out['outcomeIndependentlyDetermined'] = .false
  out['sourceCount'] = nodes~items
  out['relationCount'] = edges~items
  findings = .array~new
  out['findings'] = findings
  do e over edges
    from = nodes[e['from']]; to = nodes[e['to']]
    typ = e['relation']
    /* A source record is not a judicial decision; fail closed instead of
     * having a litigant's reported contention become the court's own finding. */
    if typ = 'QUALIFIES_NO_DUTY' then do
      if from['actor'] \= 'CA_LEGAL_RULE' | to['actor'] \= 'CA_LEGAL_RULE' then iterate
    end
    else if typ = 'REMAKES_PRIOR' then do
      if from['actor'] \= 'CA_OUTCOME' | to['actor'] \= 'UT_AS_REPORTED' then iterate
    end
    else do
      if from['actor'] \= 'CA_JUDICIAL_FINDING' | to['actor'] \= 'UT_AS_REPORTED' then iterate
    end
    d = .directory~new
    d['type'] = typ; d['sourceId'] = from['id']; d['targetId'] = to['id']
    d['sourceCite'] = from['cite']; d['targetCite'] = to['cite']
    d['authority'] = 'JUDGMENT_REPORT_ONLY'
    d['validatedTruth'] = .false
    findings~append(d)
  end
  return out

::method hasFinding
  use strict arg type
  rep = self~audit
  do f over rep['findings']
    if f['type'] = type then return .true
  end
  return .false
