#!/usr/bin/env rexx
/* Semantic Source Control machine protocol v0.1-dev1.
 * Read-only projection over the exact vendored SSC v0.2.3 semantic engine.
 */
parse arg command rest
command = command~upper
select
  when command = "STATUS" then call cmdStatus rest
  when command = "IDENTIFY" then call cmdIdentify rest
  when command = "COMPARE" then call cmdCompare rest
  when command = "IMPACT" then call cmdImpact rest
  when command = "SOURCE" then call cmdSource rest
  when command = "PROPOSALS" then call cmdProposals rest
  when command = "HELP" | command = "--HELP" | command = "-H" | command = "" then call usage
  otherwise call fail "INVALID_REQUEST", "UNKNOWN", "unknown command: " || command, 2
end
exit 0

cmdStatus: procedure
  use arg rest
  parse var rest component rest
  repoPath = option(rest, "--repo", "")
  if component = "" | repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "status requires COMPONENT --repo REPO", 2
  repo = .SemanticRepository~new(repoPath)
  snap = repo~loadLatest(component)
  if snap == .nil then do
    call emit "OK", "NOT_FOUND", "status", '{"component":' || q(component) || '}'
    return
  end
  pending = 0; tracked = 0; rejected = 0
  do c over snap~candidates
    s = repo~candidateStatus(c, snap)
    select
      when s = "PENDING" then pending += 1
      when s = "TRACKED" then tracked += 1
      when s = "REJECTED" then rejected += 1
      otherwise nop
    end
  end
  result = '{"component":' || q(snap~component) || ',"lineage":' || q(snap~lineage) || ',"source_level":' || q(snap~sourceLevel) || ',' ||,
           '"schema_version":' || snap~schemaVersion || ',"counts":{' ||,
           '"files":' || snap~files~items || ',"packages":' || snap~packages~items || ',"classes":' || snap~classes~items || ',' ||,
           '"methods":' || snap~methods~items || ',"attributes":' || snap~attributes~items || ',"constants":' || snap~constants~items || ',' ||,
           '"requirements":' || snap~requirements~items || ',"external_candidates":' || snap~candidates~items || ',"external_tracked":' || snap~externalOperations~items || '},' ||,
           '"tracking":{"pending":' || pending || ',"tracked":' || tracked || ',"rejected":' || rejected || '}}'
  call emit "OK", "FOUND", "status", result
  return

cmdIdentify: procedure
  use arg rest
  parse var rest component target rest
  repoPath = option(rest, "--repo", "")
  level = option(rest, "--level", "")
  if component = "" | target = "" | repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "identify requires COMPONENT TARGET --repo REPO [--level N]", 2
  repo = .SemanticRepository~new(repoPath)
  if level = "" then snap = repo~loadLatest(component)
  else snap = repo~loadSnapshot(component, level)
  if snap == .nil then do
    call emit "OK", "NOT_FOUND", "identify", '{"component":' || q(component) || ',"target":' || q(target) || '}'
    return
  end
  matches = .array~new
  do p over snap~packages
    if entityMatches(target, p~qualifiedName, p~entityId, p~revisionId) then matches~append(entityPackage(p))
  end
  do c over snap~classes
    if entityMatches(target, c~qualifiedName, c~entityId, c~revisionId) then matches~append(entityClass(c))
  end
  do m over snap~methods
    selector = m~displaySelector
    if entityMatches(target, selector, m~entityId, m~revisionId) | target~upper = m~qualifiedName~upper then matches~append(entityMethod(m))
  end
  do a over snap~attributes
    if entityMatches(target, a~identityKey, a~entityId, a~revisionId) | target~upper = a~qualifiedName~upper then matches~append(entityAttribute(a))
  end
  do n over snap~constants
    if entityMatches(target, n~identityKey, n~entityId, n~revisionId) | target~upper = n~qualifiedName~upper then matches~append(entityConstant(n))
  end
  do e over snap~externalOperations
    if target~upper = e~externalId~upper then matches~append(entityExternal(e))
  end
  if matches~items = 0 then status = "NOT_FOUND"
  else if matches~items = 1 then status = "FOUND"
  else status = "AMBIGUOUS"
  result = '{"component":' || q(component) || ',"lineage":' || q(snap~lineage) || ',"source_level":' || q(snap~sourceLevel) || ',"target":' || q(target) || ',"matches":' || jsonArray(matches) || '}'
  call emit "OK", status, "identify", result
  return

cmdCompare: procedure
  use arg rest
  parse var rest component sourcePath rest
  repoPath = option(rest, "--repo", "")
  if component = "" | sourcePath = "" | repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "compare requires COMPONENT PATH --repo REPO", 2
  repo = .SemanticRepository~new(repoPath)
  baseline = repo~loadLatest(component)
  if baseline == .nil then do
    call emit "OK", "NOT_FOUND", "compare", '{"component":' || q(component) || '}'
    return
  end
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  incoming = analyzer~analyzeTree(sourcePath, component, baseline~lineage, "WORKING", "machine compare")
  repo~reconcileIdentities(incoming, baseline)
  repo~reconcileTrackingSet(incoming, baseline, .false)
  comparator = .ContractComparator~new
  deltas = comparator~compare(baseline, incoming)
  rows = .array~new
  do d over deltas
    rows~append('{"kind":' || q(d~kind) || ',"risk":' || q(d~risk) || ',"entity":' || q(d~entity) || ',"old":' || q(d~oldValue) || ',"new":' || q(d~newValue) || ',"detail":' || q(d~detail) || '}')
  end
  pending = 0
  do c over incoming~candidates
    if repo~candidateStatus(c, incoming) = "PENDING" then pending += 1
  end
  if deltas~items = 0 & pending = 0 then status = "UNCHANGED"
  else if pending > 0 then status = "REVIEW_REQUIRED"
  else status = "CHANGED"
  result = '{"component":' || q(component) || ',"accepted_source_level":' || q(baseline~sourceLevel) || ',"candidate_source_level":"WORKING","semantic_deltas":' || jsonArray(rows) || ',"semantic_delta_count":' || deltas~items || ',"tracking_proposals_pending":' || pending || '}'
  call emit "OK", status, "compare", result
  return

cmdImpact: procedure
  use arg rest
  parse var rest component sourcePath rest
  repoPath = option(rest, "--repo", "")
  against = option(rest, "--against", sourcePath)
  if component = "" | sourcePath = "" | repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "impact requires COMPONENT PATH --repo REPO [--against WORKTREE]", 2
  repo = .SemanticRepository~new(repoPath)
  baseline = repo~loadLatest(component)
  if baseline == .nil then do
    call emit "OK", "NOT_FOUND", "impact", '{"component":' || q(component) || '}'
    return
  end
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  incoming = analyzer~analyzeTree(sourcePath, component, baseline~lineage, "WORKING", "machine impact candidate")
  repo~reconcileIdentities(incoming, baseline)
  repo~reconcileTrackingSet(incoming, baseline, .false)
  work = analyzer~analyzeTree(against, "WORK", "WORK", "WORKING", "machine impact consumers")
  comparator = .ContractComparator~new
  deltas = comparator~compare(baseline, incoming)
  impact = .ImpactEngine~new
  findings = impact~assess(baseline, incoming, work, deltas)
  rows = .array~new
  do f over findings
    rows~append('{"status":' || q(f~status) || ',"provider":' || q(f~provider) || ',"change_kind":' || q(f~changeKind) || ',"consumer":' || q(f~consumer) || ',"path":' || q(f~path) || ',"line":' || f~line || ',"reason":' || q(f~reason) || ',"evidence":' || q(f~evidence) || '}')
  end
  result = '{"component":' || q(component) || ',"accepted_source_level":' || q(baseline~sourceLevel) || ',"semantic_delta_count":' || deltas~items || ',"impact_findings":' || jsonArray(rows) || ',"impact_finding_count":' || findings~items || '}'
  if deltas~items = 0 & findings~items = 0 then status = "UNCHANGED"
  else status = "FOUND"
  call emit "OK", status, "impact", result
  return

cmdSource: procedure
  use arg rest
  parse var rest component target rest
  repoPath = option(rest, "--repo", "")
  level = option(rest, "--level", "")
  if component = "" | target = "" | repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "source requires COMPONENT TARGET --repo REPO [--level N]", 2
  repo = .SemanticRepository~new(repoPath)
  source = repo~methodSource(component, level, target)
  if source == .nil then do
    call emit "OK", "NOT_FOUND", "source", '{"component":' || q(component) || ',"target":' || q(target) || '}'
    return
  end
  result = '{"component":' || q(component) || ',"target":' || q(target) || ',"source":' || q(source) || ',"sha256":' || q(.SSCUtil~contentHash(source)) || '}'
  call emit "OK", "FOUND", "source", result
  return

cmdProposals: procedure
  use arg rest
  repoPath = option(rest, "--repo", "")
  if repoPath = "" then call fail "INVALID_REQUEST", "UNKNOWN", "proposals requires --repo REPO", 2
  repo = .SemanticRepository~new(repoPath)
  lines = .SSCUtil~readLines(repoPath || "/proposals.osc")
  rows = .array~new
  do row over lines
    f = .SSCUtil~split(row, "|")
    if f~items < 12 then iterate
    decision = repo~decisionForProposal(f[1])
    status = "PENDING"; externalId = ""; reason = ""; authority = ""
    if decision <> .nil then do
      status = decision~decision; externalId = decision~externalId; reason = decision~reason; authority = decision~authority
    end
    rows~append('{"proposal_id":' || q(f[1]) || ',"status":' || q(status) || ',"classification":' || q(f[2]) || ',"confidence":' || q(f[3]) || ',"method":' || q(.SSCUtil~decode(f[4])) || ',"kind":' || q(f[5]) || ',"operation":' || q(f[6]) || ',"statement_md5":' || q(f[7]) || ',"semantic_contract":' || q(.SSCUtil~decode(f[10])) || ',"path":' || q(.SSCUtil~decode(f[11])) || ',"line":' || f[12] || ',"external_id":' || q(externalId) || ',"reason":' || q(reason) || ',"authority":' || q(authority) || '}')
  end
  result = '{"proposals":' || jsonArray(rows) || ',"count":' || rows~items || '}'
  call emit "OK", "FOUND", "proposals", result
  return

entityMatches: procedure
  use arg target, name, entityId, revisionId
  u = target~upper
  return u = name~upper | u = entityId~upper | u = revisionId~upper

entityPackage: procedure
  use arg p
  return '{"kind":"PACKAGE","qualified_name":' || q(p~qualifiedName) || ',"entity_id":' || q(p~entityId) || ',"revision_id":' || q(p~revisionId) || ',"options":' || q(p~optionsContract) || ',"requires":' || q(p~requiresContract) || ',"path":' || q(p~path) || ',"line":' || p~line || '}'
entityClass: procedure
  use arg c
  return '{"kind":"CLASS","qualified_name":' || q(c~qualifiedName) || ',"entity_id":' || q(c~entityId) || ',"revision_id":' || q(c~revisionId) || ',"contract":' || q(c~directiveContract) || ',"path":' || q(c~path) || ',"line":' || c~line || '}'
entityMethod: procedure
  use arg m
  return '{"kind":"METHOD","qualified_name":' || q(m~qualifiedName) || ',"selector":' || q(m~displaySelector) || ',"scope":' || q(m~scope) || ',"visibility":' || q(m~visibility) || ',"entity_id":' || q(m~entityId) || ',"revision_id":' || q(m~revisionId) || ',"arguments":' || q(m~argSpec) || ',"path":' || q(m~path) || ',"line_start":' || m~lineStart || ',"line_end":' || m~lineEnd || '}'
entityAttribute: procedure
  use arg a
  return '{"kind":"ATTRIBUTE","qualified_name":' || q(a~qualifiedName) || ',"selector":' || q(a~identityKey) || ',"scope":' || q(a~scope) || ',"visibility":' || q(a~visibility) || ',"access":' || q(a~accessMode) || ',"entity_id":' || q(a~entityId) || ',"revision_id":' || q(a~revisionId) || ',"path":' || q(a~path) || ',"line":' || a~line || '}'
entityConstant: procedure
  use arg n
  return '{"kind":"CONSTANT","qualified_name":' || q(n~qualifiedName) || ',"selector":' || q(n~identityKey) || ',"entity_id":' || q(n~entityId) || ',"revision_id":' || q(n~revisionId) || ',"value":' || q(n~valueContract) || ',"path":' || q(n~path) || ',"line":' || n~line || '}'
entityExternal: procedure
  use arg e
  return '{"kind":"EXTERNAL_OPERATION","external_id":' || q(e~externalId) || ',"method":' || q(e~methodKey) || ',"external_kind":' || q(e~kind) || ',"operation":' || q(e~operation) || ',"semantic_contract":' || q(e~semanticContract) || ',"path":' || q(e~path) || ',"line":' || e~line || '}'

jsonArray: procedure
  use arg values
  out = "["
  do i = 1 to values~items
    if i > 1 then out ||= ","
    out ||= values[i]
  end
  return out || "]"

q: procedure
  use arg value
  if value == .nil then value = ""
  s = value~string
  s = s~changestr("\\", "\\\\")
  s = s~changestr('"', '\\"')
  s = s~changestr("08"x, "\\b")
  s = s~changestr("09"x, "\\t")
  s = s~changestr("0a"x, "\\n")
  s = s~changestr("0c"x, "\\f")
  s = s~changestr("0d"x, "\\r")
  return '"' || s || '"'

emit: procedure
  use arg toolStatus, operationStatus, operation, resultJson
  say '{"schema":"semantic.source.control.machine/0.1","tool_status":' || q(toolStatus) || ',"operation_status":' || q(operationStatus) || ',"operation":' || q(operation) || ',"result":' || resultJson || ',"diagnostics":[]}'
  return

fail: procedure
  use arg toolStatus, operationStatus, message, code = 2
  say '{"schema":"semantic.source.control.machine/0.1","tool_status":' || q(toolStatus) || ',"operation_status":' || q(operationStatus) || ',"operation":"error","result":null,"diagnostics":[' || q(message) || ']}'
  exit code

option: procedure
  use arg text, wanted, default
  do i = 1 to words(text)
    if word(text, i) = wanted then do
      if i < words(text) then return word(text, i + 1)
      return default
    end
  end
  return default

usage:
  call emit "OK", "DESCRIBED", "help", '{"commands":["status COMPONENT --repo REPO","identify COMPONENT TARGET --repo REPO [--level N]","compare COMPONENT PATH --repo REPO","impact COMPONENT PATH --repo REPO [--against WORKTREE]","source COMPONENT TARGET --repo REPO [--level N]","proposals --repo REPO"],"mutations":false}'
  return

::requires "src/SemanticSourceControl.cls"
