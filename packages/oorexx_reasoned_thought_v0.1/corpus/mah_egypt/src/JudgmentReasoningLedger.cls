/* JudgmentReasoningLedger/0.3 - public-source judicial reasoning trace.
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
  /* The caller receives a detached snapshot, never the admitted source. */
  n = nodes[id]; copy = .directory~new
  do key over n~allIndexes
    copy[key] = n[key]
  end
  return copy

::method trace
  expose nodes edges
  a = .array~new
  do e over edges
    f = nodes[e['from']]; t = nodes[e['to']]
    a~append(e['relation'] || ' [' || f['actor'] || ' ' || f['cite'] || '] ' || -
       f['id'] || ' -> [' || t['actor'] || ' ' || t['cite'] || '] ' || t['id'])
  end
  return a

/* Relationship qualification is structural, not semantic authentication.
 * The same judicial ACTOR may make several very different kinds of finding.
 * A valid actor alone cannot warrant arbitrary inferential edges. */
::method classifyEdge private
  use strict arg f, t, relation
  select
    when relation = 'QUALIFIES_NO_DUTY' then do
      if f['actor'] \= 'CA_LEGAL_RULE' | t['actor'] \= 'CA_LEGAL_RULE' then -
        return 'RELATION_ACTOR_MISMATCH'
      if f['kind'] \= 'CORROBORATION' | t['kind'] \= 'CORROBORATION' then -
        return 'RELATION_KIND_MISMATCH'
    end
    when relation = 'REMAKES_PRIOR' then do
      if f['actor'] \= 'CA_OUTCOME' | t['actor'] \= 'UT_AS_REPORTED' then -
        return 'RELATION_ACTOR_MISMATCH'
      if f['kind'] \= 'DISPOSITION' | t['kind'] \= 'DISPOSITION' then -
        return 'RELATION_KIND_MISMATCH'
    end
    otherwise do
      if f['actor'] \= 'CA_JUDICIAL_FINDING' | t['actor'] \= 'UT_AS_REPORTED' then -
        return 'RELATION_ACTOR_MISMATCH'
      select
        when relation = 'CORRECTS_STANDARD' then -
          valid = (f['kind'] = 'APPLIED_STANDARD' & t['kind'] = 'STATED_STANDARD')
        when relation = 'CHALLENGES_CORROBORATION' then -
          valid = (f['kind'] = 'WARRANT' & t['kind'] = 'CREDIBILITY_INFERENCE')
        when relation = 'REJECTS_CONFLATION' then -
          valid = (f['kind'] = 'PROPOSITION_IDENTITY' & t['kind'] = 'CREDIBILITY')
        when relation = 'IDENTIFIES_OMISSION' then -
          valid = (f['kind'] = 'OMITTED_EVIDENCE' & t['kind'] = 'REASONS')
        /* No defined proposition-kind schema for this catch-all edge yet. */
        otherwise valid = .false
      end
      if \valid then return 'RELATION_KIND_MISMATCH'
    end
  end
  return ''

::method audit
  expose nodes edges
  out = .directory~new
  out['validatedTruth'] = .false
  out['outcomeIndependentlyDetermined'] = .false
  out['citationValidated'] = .false
  out['sourceCount'] = nodes~items
  out['relationCount'] = edges~items
  findings = .array~new
  rejected = .array~new
  out['findings'] = findings
  out['rejectedEdges'] = rejected
  seen = .set~new
  do e over edges
    from = nodes[e['from']]; to = nodes[e['to']]
    typ = e['relation']
    if from['id'] = to['id'] then defect = 'SELF_RELATION'
    else defect = self~classifyEdge(from, to, typ)
    /* Repeated citations to one inferential edge are not fresh evidence.
     * Length-prefixed key prevents delimiter ambiguities in arbitrary IDs. */
    if defect = '' then do
      key = length(from['id']) || ':' || from['id'] || -
            length(to['id']) || ':' || to['id'] || -
            length(typ) || ':' || typ
      if seen~hasItem(key) then defect = 'DUPLICATE_RELATION'
      else seen~put(key)
    end
    d = .directory~new
    d['type'] = typ; d['sourceId'] = from['id']; d['targetId'] = to['id']
    d['sourceCite'] = from['cite']; d['targetCite'] = to['cite']
    d['authority'] = 'JUDGMENT_REPORT_ONLY'
    d['validatedTruth'] = .false
    d['citationValidated'] = .false
    if defect \= '' then do
      d['reason'] = defect
      rejected~append(d)
      iterate
    end
    findings~append(d)
  end
  out['unqualifiedCount'] = rejected~items
  return out

::method hasFinding
  use strict arg type
  rep = self~audit
  do f over rep['findings']
    if f['type'] = type then return .true
  end
  return .false
