#!/usr/bin/env rexx
parse arg argv
cmd = argv~word(1)~lower
if cmd == "" | cmd == "help" | cmd == "--help" | cmd == "-h" then do
  call usage
  exit 0
end

root = value("QUEUEBASH_ROOT",, "ENVIRONMENT")
if root == "" then root = value("HOME",, "ENVIRONMENT") || "/.queuebash"
store = .QueueStateStore~new(root)
jsonMode = argv~wordpos(.QueueOption~JSON) > 0 | argv~wordpos(.QueueOption~JSON_SHORT) > 0

select
  when cmd == .QueueCommandName~VERSION then do
    if jsonMode then do
      d = .Directory~new
      d["schema"] = .QueueSchema~VERSION
      d["queuerexx_version"] = .QueueRexxVersion~version
      d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
      say .QueueSerialization~toJson(d)
    end
    else say "QueueRexx" .QueueRexxVersion~version "(QueueBash compatibility baseline" .QueueRexxVersion~queueBashCompatibility || ")"
  end

  when cmd == .QueueCommandName~LIST | cmd == .QueueCommandName~LIST_SHORT then do
    requestedState = .QueueState~ALL
    p = argv~wordpos(.QueueOption~STATE)
    if p == 0 then p = argv~wordpos(.QueueOption~STATE_SHORT)
    if p > 0 & p < argv~words then requestedState = .QueueState~fromName(argv~word(p + 1))
    records = store~records(requestedState)
    if jsonMode then do
      jobs = .Array~new
      do r over records; jobs~append(r~summary); end
      d = .Directory~new
      d["queue_root"] = root
      d["selected_user"] = .QueueRexxUtil~currentUser
      d["jobs"] = jobs
      say .QueueSerialization~toJson(d)
    end
    else do
      do r over records
        say r~qid r~stateName r~priority r~name
      end
    end
  end

  when cmd == .QueueCommandName~EXPLAIN then do
    qid = firstPositional(argv)
    if qid == "" then do
      say "queuerexx explain: missing QID"; exit 2
    end
    matches = store~findAll(qid)
    if matches~items == 0 then do
      if jsonMode then do
        d = .Directory~new; d["schema"] = .QueueSchema~EXPLAIN_READONLY; d["found"] = .JSONBoolean~false; d["qid"] = qid
        say .QueueSerialization~toJson(d)
      end
      else say "not found:" qid
      exit 1
    end
    r = matches[1]
    d = r~explainSummary
    d["schema"] = .QueueSchema~EXPLAIN_READONLY
    d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
    d["duplicate_state_count"] = matches~items
    duplicateStates = .Array~new
    do m over matches; duplicateStates~append(m~stateName); end
    d["states_seen"] = duplicateStates
    if jsonMode then say .QueueSerialization~toJson(d)
    else do
      say "qid:" r~qid
      say "name:" r~name
      say "state:" r~stateName
      say "class:" r~jobClass
      say "runner requested:" r~field(.QueueRecord~FIELD_RUNNER, .QueueRunnerKind~AUTO)
      say "runner used:" r~field(.QueueRecord~FIELD_RUNNER_USED, "")
      say "command:" r~commandLine
      if matches~items > 1 then say "WARNING: duplicate QID present in" matches~items "states"
    end
  end


  when cmd == .QueueCommandName~DIAGNOSE then do
    qid = firstPositional(argv)
    if qid == "" then do; say "queuerexx diagnose: missing QID"; exit 2; end
    diagnosis = .QueueDiagnosisService~new(store)~diagnose(qid)
    if jsonMode then say .QueueSerialization~toJson(diagnosis)
    else do
      say "qid:" diagnosis["qid"]
      say "diagnosis:" diagnosis["diagnosis"]
      stateText = ""
      do stateItem over diagnosis["states_seen"]
        if stateText \= "" then stateText ||= " "
        stateText ||= stateItem
      end
      say "states:" stateText
      say "recommendation:" diagnosis["recommendation"]
      say "reason:" diagnosis["reason"]
    end
    if diagnosis["record_count"] == 0 then exit 1
  end

  when cmd == .QueueCommandName~PROVIDERS then do
    reg = .QueueProviderRegistry~builtins
    arr = .Array~new
    facts = .QueuePlatformFacts~probeLocal
    do pvd over reg~all(.QueueProviderCategory~RUNNER)
      x = .Directory~new
      x["category"] = .QueueProviderCategory~RUNNER
      x["id"] = pvd~id
      x["version"] = pvd~version
      x["capabilities"] = pvd~capabilities
      arr~append(x)
    end
    d = .Directory~new
    d["schema"] = .QueueSchema~PROVIDER_REGISTRY
    d["providers"] = arr
    d["platform_facts"] = facts~asDirectory
    if jsonMode then say .QueueSerialization~toJson(d)
    else do pvd over arr; say pvd["category"] || ":" || pvd["id"] pvd["version"]; end
  end


  when cmd == .QueueCommandName~POLICY_CHECK then do
    qid = firstPositional(argv)
    if qid == "" then do; say "queuerexx policy-check: missing QID"; exit 2; end
    assessment = .QueuePolicyInspectionService~new(root)~inspect(qid)
    if jsonMode then say .QueueSerialization~toJson(assessment~asDirectory)
    else do
      say "qid:" qid
      say "decision:" assessment~decisionName
      say "code:" assessment~code
      say "provider:" assessment~providerId assessment~providerVersion
      say "detail:" assessment~detail
    end
    if \assessment~allowed then exit 1
  end

  when cmd == .QueueCommandName~PROVIDER_HEALTH then do
    snapshot = .QueueProviderTelemetryCollector~new~collect(.QueueProviderCategory~RUNNER)~asDirectory
    if jsonMode then say .QueueSerialization~toJson(snapshot)
    else do
      say "provider health:" snapshot["overall_state"]
      do item over snapshot["providers"]
        say item["category"] || ":" || item["provider"] item["state"] item["code"]
      end
    end
    if snapshot["overall_state"] == .QueueProviderHealthState~NAME_UNAVAILABLE then exit 1
  end

  when cmd == .QueueCommandName~PROVIDER_PLAN then do
    qid = firstPositional(argv)
    if qid == "" then do
      say "queuerexx provider-plan: missing QID"; exit 2
    end
    r = store~findOne(qid)
    if r == .nil then do; say "not found:" qid; exit 1; end
    req = .QueueJobRequirement~fromRecord(r)
    facts = .QueuePlatformFacts~probeLocal
    reg = .QueueProviderRegistry~builtins
    decision = .QueueRunnerSelector~new(reg)~select(facts, req)
    d = .Directory~new
    d["schema"] = .QueueSchema~PROVIDER_DECISION
    d["qid"] = qid
    d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
    d["job_requirement"] = req~asDirectory
    d["platform_facts"] = facts~asDirectory
    d["runner"] = decision~asDirectory
    if jsonMode then say .QueueSerialization~toJson(d)
    else do
      if decision~selected then say "runner:" decision~provider~id "(" || decision~code || ")"
      else say "runner unavailable:" decision~code
      if decision~warning \= "" then say "warning:" decision~warning
    end
  end

  when cmd == .QueueCommandName~OBSERVE then do
    qid = firstPositional(argv)
    if qid == "" then do; say "queuerexx observe: missing QID"; exit 2; end
    r = store~findOne(qid)
    if r == .nil then do; say "not found:" qid; exit 1; end
    observer = .QueueJobObserver~new
    observation = observer~observe(r)
    if jsonMode then say .QueueSerialization~toJson(observer~asDirectory(r))
    else say r~qid r~stateName observation~statusName observation~providerId observation~code
    if observation~status == .QueueJobObservation~DEAD then exit 1
  end


  when cmd == .QueueCommandName~RUNTIME_STATUS then do
    qid = firstPositional(argv)
    if qid == "" then do; say "queuerexx runtime-status: missing QID"; exit 2; end
    status = .QueueRuntimeMonitor~new(root)~project(qid)
    if jsonMode then say .QueueSerialization~toJson(status~asDirectory)
    else do
      d = status~asDirectory
      say "qid:" d["qid"]
      say "relation:" d["relation"]
      say "recommended action:" d["recommended_action"]
      say "detail:" d["detail"]
    end
    if status~ambiguous then exit 1
  end

  when cmd == .QueueCommandName~RUNTIME_SCAN then do
    scan = .QueueRuntimeMonitor~new(root)~scan(100)
    if jsonMode then say .QueueSerialization~toJson(scan)
    else do
      say "runtime records:" scan["count"]
      do item over scan["items"]
        say item["qid"] item["relation"] item["recommended_action"]
      end
    end
  end

  when cmd == .QueueCommandName~HEALTH then do
    if argv~wordpos(.QueueOption~FIX) > 0 then do
      report = .QueueHealthReport~new(root)
      report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "QueueRexx v0.1-dev12 public repair is disabled; --fix is not enabled"))
      if jsonMode then say .QueueSerialization~toJson(report~asDirectory)
      else say "BAD QueueRexx v0.1-dev12 public repair is disabled; --fix is not enabled"
      exit 2
    end
    deepMode = argv~wordpos(.QueueOption~DEEP) > 0
    report = .QueueHealthScanner~new(store)~scan(deepMode)
    if jsonMode then say .QueueSerialization~toJson(report~asDirectory)
    else do
      do finding over report~findings
        say .QueueHealthFinding~levelName(finding~level)~upper finding~message
      end
      say "Health summary: errors=" || report~errors "warnings=" || report~warnings "fix=0 deep=" || (deepMode == .true)
    end
    if \report~ok then exit 1
  end

  otherwise do
    say "queuerexx: unknown command:" cmd
    call usage
    exit 2
  end
end
exit 0

firstPositional:
  use arg line
  do i = 2 to line~words
    word = line~word(i)
    if word == .QueueOption~JSON | word == .QueueOption~JSON_SHORT | word == .QueueOption~DEEP | word == .QueueOption~FIX then iterate
    if word == .QueueOption~STATE | word == .QueueOption~STATE_SHORT then do; i += 1; iterate; end
    if word~left(1) == "-" then iterate
    return word
  end
  return ""

usage:
  say "Usage: queuerexx version [--json]"
  say "       queuerexx list [--state STATE] [--json]"
  say "       queuerexx explain QID [--json]"
  say "       queuerexx diagnose QID [--json]"
  say "       queuerexx providers [--json]"
  say "       queuerexx provider-plan QID [--json]"
  say "       queuerexx provider-health [--json]"
  say "       queuerexx policy-check QID [--json]"
  say "       queuerexx observe QID [--json]"
  say "       queuerexx runtime-status QID [--json]"
  say "       queuerexx runtime-scan [--json]"
  say "       queuerexx health [--deep] [--json]"
  return

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxSerialization.cls"
::requires "QueueRexxHealth.cls"
::requires "QueueRexxDiagnosis.cls"

::requires "QueueRexxRuntimeRecovery.cls"
::requires "QueueRexxTelemetry.cls"
::requires "QueueRexxPolicy.cls"
