#!/usr/bin/env rexx
/* ooRexx Semantic Source Control v0.2.3 CLI */
parse arg command rest
command = command~upper
if command = "" | command = "HELP" | command = "--HELP" | command = "-H" then do
  call usage
  exit 0
end

select
  when command = "BASELINE" then call cmdBaseline rest
  when command = "SCAN" then call cmdScan rest
  when command = "INTAKE" then call cmdIntake rest
  when command = "IMPACT" then call cmdIntake rest
  when command = "PROPOSALS" then call cmdProposals rest
  when command = "PROPOSAL" then call cmdProposal rest
  when command = "SURFACE" then call cmdSurface rest
  when command = "SOURCE" then call cmdSource rest
  when command = "EXPORT" then call cmdExport rest
  when command = "CONSUMERS" then call cmdConsumers rest
  otherwise do
    say "unknown command:" command
    call usage
    exit 2
  end
end
exit 0

cmdBaseline: procedure expose packagePath
  use arg rest
  parse var rest sourcePath rest
  repoPath = option(rest, "--repo", "")
  component = option(rest, "--component", "")
  level = option(rest, "--level", "")
  lineage = option(rest, "--lineage", "MAIN")
  if sourcePath = "" | repoPath = "" | component = "" | level = "" then call die "baseline requires PATH --repo REPO --component NAME --level N"
  if \datatype(level, "W") then call die "baseline --level must be a whole-number source level used by AT_LEAST"
  repo = .SemanticRepository~new(repoPath)
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  snap = analyzer~analyzeTree(sourcePath, component, lineage, level, "baseline")
  oldView = repo~latestIdentityView(component)
  repo~reconcileIdentities(snap, oldView)
  out = repo~saveSnapshot(snap)
  say "BASELINE ACCEPTED"
  say "component=" component "lineage=" lineage "sourceLevel=" level
  say "files=" snap~files~items "packages=" snap~packages~items "methods=" snap~methods~items "attributes=" snap~attributes~items "constants=" snap~constants~items "requirements=" snap~requirements~items "externalTracked=" snap~externalOperations~items
  say "snapshot=" out
  pending = 0
  do c over snap~candidates
    if repo~candidateStatus(c, snap) = "PENDING" then pending += 1
  end
  say "trackingProposalsPending=" pending
  return

cmdScan: procedure expose packagePath
  use arg rest
  parse var rest sourcePath rest
  repoPath = option(rest, "--repo", "")
  component = option(rest, "--component", "WORK")
  level = option(rest, "--level", "WORKING")
  if sourcePath = "" | repoPath = "" then call die "scan requires PATH --repo REPO [--component NAME]"
  repo = .SemanticRepository~new(repoPath)
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  snap = analyzer~analyzeTree(sourcePath, component, "WORK", level, "working scan")
  say "SCAN COMPLETE"
  say "files=" snap~files~items "packages=" snap~packages~items "methods=" snap~methods~items "attributes=" snap~attributes~items "constants=" snap~constants~items "requirements=" snap~requirements~items "messageUses=" snap~uses~items "externalCandidates=" snap~candidates~items
  pending = 0
  do c over snap~candidates
    if repo~candidateStatus(c, snap) = "PENDING" then do
      pending += 1
      say "PROPOSE" c~proposalId c~kind c~operation c~methodKey c~path || ":" || c~line
    end
  end
  say "trackingProposalsPending=" pending
  return

cmdProposals: procedure expose packagePath
  use arg rest
  repoPath = option(rest, "--repo", "")
  if repoPath = "" then call die "proposals requires --repo REPO"
  repo = .SemanticRepository~new(repoPath)
  lines = .SSCUtil~readLines(repoPath || "/proposals.osc")
  if lines~items = 0 then do; say "NO PROPOSALS"; return; end
  do row over lines
    f = .SSCUtil~split(row, "|")
    decision = repo~decisionForProposal(f[1])
    status = "PENDING"
    if decision <> .nil then status = decision~decision
    say f[1] status f[5] f[6] .SSCUtil~decode(f[4]) .SSCUtil~decode(f[11]) || ":" || f[12]
  end
  return

cmdProposal: procedure expose packagePath
  use arg rest
  parse var rest action proposalId rest
  repoPath = option(rest, "--repo", "")
  reason = optionText(rest, "--reason", "")
  authority = option(rest, "--authority", "")
  if repoPath = "" | proposalId = "" then call die "proposal accept|reject ID --repo REPO [--reason TEXT]"
  repo = .SemanticRepository~new(repoPath)
  select
    when action~upper = "SHOW" then do
      proposal = repo~proposal(proposalId)
      if proposal == .nil then call die "unknown proposal " || proposalId
      say "TRACKING PROPOSAL" proposal[1]
      say "status=" || proposal[2] "confidence=" || proposal[3]
      say "method=" || .SSCUtil~decode(proposal[4])
      say "kind=" || proposal[5] "operation=" || proposal[6]
      say "statementMD5=" || proposal[7]
      say "beforeContextMD5=" || .SSCUtil~decode(proposal[8])
      say "afterContextMD5=" || .SSCUtil~decode(proposal[9])
      say "semanticContract=" || .SSCUtil~decode(proposal[10])
      say "source=" || .SSCUtil~decode(proposal[11]) || ":" || proposal[12]
      d = repo~decisionForProposal(proposalId)
      if d <> .nil then say "decision=" || d~decision "externalId=" || d~externalId "reason=" || d~reason "authority=" || d~authority
    end
    when action~upper = "ACCEPT" then do
      externalId = repo~recordDecision(proposalId, "ACCEPTED", reason, authority)
      say proposalId "ACCEPTED externalId=" || externalId
    end
    when action~upper = "REJECT" then do
      repo~recordDecision(proposalId, "REJECTED", reason, authority)
      say proposalId "REJECTED"
    end
    otherwise call die "proposal action must be show, accept or reject"
  end
  return

cmdSurface: procedure expose packagePath
  use arg rest
  parse var rest component rest
  repoPath = option(rest, "--repo", "")
  if component = "" | repoPath = "" then call die "surface COMPONENT --repo REPO"
  repo = .SemanticRepository~new(repoPath)
  snap = repo~loadLatest(component)
  if snap == .nil then call die "no accepted snapshot for component " || component
  say "SURFACE" component "AT_LEAST" snap~sourceLevel "lineage=" || snap~lineage
  do p over snap~packages
    say "PACKAGE" p~qualifiedName "entity=" || p~entityId "revision=" || p~revisionId "options={" || p~optionsContract || "}" "requires={" || p~requiresContract || "}"
  end
  do c over snap~classes
    say "CLASS" c~qualifiedName "entity=" || c~entityId "revision=" || c~revisionId "contract={" || c~directiveContract || "}"
  end
  do m over snap~methods
    say m~scope m~visibility m~qualifiedName "entity=" || m~entityId "revision=" || m~revisionId "args={" || m~argSpec || "}"
  end
  do a over snap~attributes
    say "ATTRIBUTE" a~scope a~visibility a~qualifiedName "access=" || a~accessMode "entity=" || a~entityId "revision=" || a~revisionId "contract={" || a~directiveContract || "}"
  end
  do n over snap~constants
    say "CONSTANT" n~qualifiedName "entity=" || n~entityId "revision=" || n~revisionId "value={" || n~valueContract || "}"
  end
  do e over snap~externalOperations
    say "EXTERNAL" e~externalId e~kind e~methodKey e~semanticContract
  end
  return

cmdSource: procedure expose packagePath
  use arg rest
  parse var rest qualified rest
  repoPath = option(rest, "--repo", "")
  level = option(rest, "--level", "")
  if qualified = "" | repoPath = "" then call die "source Component.Class.method --repo REPO [--level N]"
  dot = pos(".", qualified)
  if dot = 0 then call die "source target must start with component name"
  component = qualified~left(dot - 1)
  repo = .SemanticRepository~new(repoPath)
  source = repo~methodSource(component, level, qualified)
  if source == .nil then call die "method source not found for " || qualified
  say source
  return

cmdExport: procedure expose packagePath
  use arg rest
  parse var rest component rest
  repoPath = option(rest, "--repo", "")
  level = option(rest, "--level", "")
  destination = option(rest, "--to", "")
  if component = "" | repoPath = "" | destination = "" then call die "export COMPONENT --repo REPO [--level N] --to DIRECTORY"
  repo = .SemanticRepository~new(repoPath)
  if level = "" then snap = repo~loadLatest(component)
  else snap = repo~loadSnapshot(component, level)
  if snap == .nil then call die "source level not found for component " || component
  count = repo~exportSnapshot(snap, destination)
  say "EXPORTED" component "AT_LEAST" snap~sourceLevel "files=" || count "to=" || destination
  return

cmdConsumers: procedure expose packagePath
  use arg rest
  parse var rest target rest
  against = option(rest, "--against", "")
  repoPath = option(rest, "--repo", "/tmp/osc-consumers-transient")
  if target = "" | against = "" then call die "consumers TARGET --against WORKTREE [--repo REPO]"
  repo = .SemanticRepository~new(repoPath)
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  work = analyzer~analyzeTree(against, "WORK", "WORK", "WORKING")
  say "CONSUMERS" target
  targetBase = target
  wantedScope = "INSTANCE"
  hash = targetBase~lastPos("#")
  if hash > 0 then do
    maybeScope = targetBase~substr(hash + 1)~upper
    if maybeScope = "INSTANCE" | maybeScope = "CLASS" | maybeScope = "OBJECT" then do
      wantedScope = maybeScope
      targetBase = targetBase~left(hash - 1)
    end
  end
  tparts = .SSCUtil~split(targetBase, ".")
  wantedMethod = ""
  if tparts~items > 1 then wantedMethod = tparts[tparts~items]
  do r over work~requirements
    if r~target~upper = target~upper | r~target~upper = targetBase~upper | r~target~upper~left(targetBase~length + 1) = targetBase~upper || "." then say "DECLARED" r~consumer r~path || ":" || r~line "AT_LEAST" r~minimumLevel
  end
  if wantedMethod <> "" then do u over work~uses
    if u~message~upper <> wantedMethod~upper then iterate
    targetClass = ""
    if tparts~items > 2 then targetClass = tparts[tparts~items - 1]
    exact = .false
    if u~useKind = "CONSTRUCTOR" | u~useKind = "LITERAL_CLASS_MESSAGE" | u~useKind = "SELF_MESSAGE" then exact = (targetClass = "" | u~targetClass~upper = targetClass~upper) & (u~targetScope = wantedScope | u~targetScope = "UNKNOWN")
    if u~useKind = "SUPER_MESSAGE" then exact = .false
    if exact then say u~useKind u~consumer u~path || ":" || u~line "targetClass=" || u~targetClass "targetScope=" || u~targetScope
    else if u~useKind = "DYNAMIC_MESSAGE" then say "DYNAMIC_MESSAGE_NAME" u~consumer u~path || ":" || u~line
  end
  return

cmdIntake: procedure expose packagePath
  use arg rest
  parse var rest archive rest
  repoPath = option(rest, "--repo", "")
  against = option(rest, "--against", "")
  if archive = "" | repoPath = "" | against = "" then call die "intake ROLLUP.zip --repo REPO --against WORKTREE"
  repo = .SemanticRepository~new(repoPath)
  analyzer = .OoRexxSourceAnalyzer~new(repo)
  work = analyzer~analyzeTree(against, "WORK", "WORK", "WORKING", "against")
  stage = repoPath || "/.intake/" || .SSCUtil~md5(archive || .SSCUtil~now)
  intake = .RollupIntake~new
  intake~unpack(archive, stage)
  packages = intake~discoverPackages(stage)
  comparator = .ContractComparator~new
  impact = .ImpactEngine~new

  changedComponents = 0; totalDeltas = 0; totalFindings = 0
  say "ROLL-UP IMPACT ASSESSMENT"
  say "archive=" archive
  say "against=" against
  say
  do pkg over packages
    meta = intake~metadata(pkg)
    component = meta["component"]
    if component = "" then component = .SSCUtil~stemWithoutVersion(pkg)
    baseline = repo~loadLatest(component)
    if baseline == .nil then iterate
    level = meta["sourceLevel"]
    lineage = meta["lineage"]
    incoming = analyzer~analyzeTree(pkg, component, lineage, level, "incoming")
    repo~reconcileIdentities(incoming, baseline)
    deltas = comparator~compare(baseline, incoming)
    findings = impact~assess(baseline, incoming, work, deltas)
    if deltas~items = 0 & findings~items = 0 then iterate
    changedComponents += 1; totalDeltas += deltas~items
    say "============================================================"
    say component
    say "acceptedLevel=" baseline~sourceLevel "incomingLevel=" incoming~sourceLevel "lineage=" incoming~lineage
    say "CONTRACT / SEMANTIC CHANGES"
    if deltas~items = 0 then say "  none"
    else do d over deltas
      say " " d~kind "[" || d~risk || "]" d~entity
      if d~detail <> "" then say "     " d~detail
    end
    totalFindings += findings~items
    if findings~items = 0 then say "KNOWN IMPACT: none in analysed work tree"
    else do
      say "KNOWN IMPACT"
      do f over findings
        loc = f~path
        if f~line > 0 then loc ||= ":" || f~line
        say " " f~status f~consumer
        say "     provider=" || f~provider "change=" || f~changeKind
        if loc <> "" then say "     at=" || loc
        say "     why=" || f~reason "evidence=" || f~evidence
      end
    end
    say
  end
  say "SUMMARY"
  say "changedComponents=" changedComponents "semanticDeltas=" totalDeltas "impactFindings=" totalFindings
  if changedComponents = 0 then say "No accepted component in this repository had a detected incoming semantic delta."
  return

option: procedure
  use arg text, wanted, default
  /* Simple CLI tokenizer: values containing spaces can be passed with shell
     quoting, but Rexx receives them as words. --reason is best kept concise in
     v0.2; durable decisions still support arbitrary encoded text internally. */
  do i = 1 to words(text)
    if word(text, i) = wanted then do
      if i < words(text) then return word(text, i + 1)
      return default
    end
  end
  return default

optionText: procedure
  use arg text, wanted, default
  count = words(text)
  do i = 1 to count
    if word(text, i) = wanted then do
      out = ""
      do j = i + 1 to count
        w = word(text, j)
        if w~left(2) = "--" then leave
        if out <> "" then out ||= " "
        out ||= w
      end
      if out = "" then return default
      return out
    end
  end
  return default

die: procedure
  use arg message
  say "ERROR:" message
  exit 2

usage:
  say "ooRexx Semantic Source Control v0.2.3"
  say "  osc baseline PATH --repo REPO --component NAME --level N [--lineage L]"
  say "  osc scan PATH --repo REPO [--component NAME]"
  say "  osc proposals --repo REPO"
  say "  osc proposal show|accept|reject ID --repo REPO [--reason TEXT]"
  say "  osc surface COMPONENT --repo REPO"
  say "  osc source Component.Class.method[#CLASS] --repo REPO [--level N]"
  say "  osc export COMPONENT --repo REPO [--level N] --to DIRECTORY"
  say "  osc consumers TARGET[#CLASS] --against WORKTREE [--repo REPO]"
  say "  osc intake|impact ROLLUP.zip --repo REPO --against WORKTREE"
  return

::requires "src/SemanticSourceControl.cls"
