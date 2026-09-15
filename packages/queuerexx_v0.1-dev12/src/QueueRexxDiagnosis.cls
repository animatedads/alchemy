/* QueueRexxDiagnosis.cls - bounded non-mutating damaged-queue diagnosis, v0.1-dev6 */

::class QueueDiagnosisKind public
::constant NOT_FOUND 0
::constant SINGLE_STATE 1
::constant RUNNING_INTERRUPTED 2
::constant RUNNING_POL_BLOCKED 3
::constant INTERRUPTED_POL_BLOCKED 4
::constant MULTIPLE_OTHER 5
::constant NAME_NOT_FOUND "not_found"
::constant NAME_SINGLE_STATE "single_state"
::constant NAME_RUNNING_INTERRUPTED "running_interrupted"
::constant NAME_RUNNING_POL_BLOCKED "running_pol_blocked"
::constant NAME_INTERRUPTED_POL_BLOCKED "interrupted_pol_blocked"
::constant NAME_MULTIPLE_OTHER "multiple_other"
::method name class
  use arg value
  select
    when value == self~NOT_FOUND then return self~NAME_NOT_FOUND
    when value == self~SINGLE_STATE then return self~NAME_SINGLE_STATE
    when value == self~RUNNING_INTERRUPTED then return self~NAME_RUNNING_INTERRUPTED
    when value == self~RUNNING_POL_BLOCKED then return self~NAME_RUNNING_POL_BLOCKED
    when value == self~INTERRUPTED_POL_BLOCKED then return self~NAME_INTERRUPTED_POL_BLOCKED
    when value == self~MULTIPLE_OTHER then return self~NAME_MULTIPLE_OTHER
    otherwise return "unknown"
  end

::class QueueDiagnosisRecommendation public
::constant NONE 0
::constant KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE 1
::constant MANUAL_REVIEW 2
::constant REPAIR_LOCK_TREE_OWNERSHIP 3
::constant NAME_NONE "none"
::constant NAME_KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE "keep_running_archive_stale_duplicate"
::constant NAME_MANUAL_REVIEW "manual_review"
::constant NAME_REPAIR_LOCK_TREE_OWNERSHIP "repair_lock_tree_ownership"
::method name class
  use arg value
  select
    when value == self~NONE then return self~NAME_NONE
    when value == self~KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE then return self~NAME_KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE
    when value == self~MANUAL_REVIEW then return self~NAME_MANUAL_REVIEW
    when value == self~REPAIR_LOCK_TREE_OWNERSHIP then return self~NAME_REPAIR_LOCK_TREE_OWNERSHIP
    otherwise return "unknown"
  end

::class QueueDiagnosisService public
::attribute store get
::attribute observer get
::method init
  expose store observer
  use arg storeArg, observerArg = .nil
  store = storeArg
  if observerArg == .nil then observer = .QueueJobObserver~new
  else observer = observerArg

::method diagnose
  expose store observer
  use arg qidArg
  qid = qidArg~string
  matches = store~findAll(qid)
  d = .Directory~new
  d["schema"] = .QueueSchema~DIAGNOSIS
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["qid"] = qid
  d["record_count"] = matches~items
  states = .Array~new
  records = .Array~new
  running = .nil
  interrupted = .nil
  blocked = .nil
  do record over matches
    states~append(record~stateName)
    x = record~explainSummary
    if record~state == .QueueState~INTERRUPTED then x["interrupted_reason"] = record~field(.QueueRecord~FIELD_INTERRUPTED_REASON, "")
    if record~state == .QueueState~POL_BLOCKED | record~state == .QueueState~POLICY_BLOCKED then x["policy_blocked_reason"] = record~field(.QueueRecord~FIELD_POLICY_BLOCKED_REASON, "")
    records~append(x)
    if record~state == .QueueState~RUNNING then running = record
    if record~state == .QueueState~INTERRUPTED then interrupted = record
    if record~state == .QueueState~POL_BLOCKED | record~state == .QueueState~POLICY_BLOCKED then blocked = record
  end
  d["states_seen"] = states
  d["records"] = records

  kind = self~classify(matches, running, interrupted, blocked)
  recommendation = .QueueDiagnosisRecommendation~NONE
  reason = ""
  if matches~items == 0 then reason = "no authoritative job record found"
  else if matches~items == 1 then reason = "exactly one authoritative job record found"
  else do
    recommendation = .QueueDiagnosisRecommendation~MANUAL_REVIEW
    reason = "multiple authoritative state records exist; normal transition code must not choose one"
    if running \= .nil then do
      observation = observer~observe(running)
      d["running_observation"] = observation~asDirectory
      if observation~status == .QueueJobObservation~LIVE then do
        staleDuplicate = self~knownStaleDuplicate(interrupted, blocked)
        if staleDuplicate then do
          recommendation = .QueueDiagnosisRecommendation~KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE
          reason = "running record has live payload and duplicate reason matches QueueBash stale health/sentinel/policy-not-found repair rules"
        end
      end
    end
  end

  lock = self~lockTreeDiagnosis(store~root)
  d["lock_tree"] = lock
  if lock["present"] == .JSONBoolean~true & lock["writable"] == .JSONBoolean~false then do
    recommendation = .QueueDiagnosisRecommendation~REPAIR_LOCK_TREE_OWNERSHIP
    reason = "locks/state exists but is not writable by the current queue actor"
  end

  d["diagnosis"] = .QueueDiagnosisKind~name(kind)
  d["diagnosis_code"] = kind
  d["recommendation"] = .QueueDiagnosisRecommendation~name(recommendation)
  d["recommendation_code"] = recommendation
  d["reason"] = reason
  d["mutated"] = .JSONBoolean~false
  return d

::method classify private
  use arg matches, running, interrupted, blocked
  if matches~items == 0 then return .QueueDiagnosisKind~NOT_FOUND
  if matches~items == 1 then return .QueueDiagnosisKind~SINGLE_STATE
  if running \= .nil & interrupted \= .nil then return .QueueDiagnosisKind~RUNNING_INTERRUPTED
  if running \= .nil & blocked \= .nil then return .QueueDiagnosisKind~RUNNING_POL_BLOCKED
  if interrupted \= .nil & blocked \= .nil then return .QueueDiagnosisKind~INTERRUPTED_POL_BLOCKED
  return .QueueDiagnosisKind~MULTIPLE_OTHER

::method knownStaleDuplicate private
  use arg interrupted, blocked
  if interrupted \= .nil then do
    reason = interrupted~field(.QueueRecord~FIELD_INTERRUPTED_REASON, "")
    if reason == "stale-running-detected-by-health" | reason == "stale-running-detected-by-sentinel" | reason == "stale_running_pid" then return .true
  end
  if blocked \= .nil then do
    reason = blocked~field(.QueueRecord~FIELD_POLICY_BLOCKED_REASON, "")~lower
    if reason~pos("job file not found") > 0 | reason~pos("not found") > 0 | reason~pos("stale") > 0 then return .true
  end
  return .false

::method lockTreeDiagnosis private
  use arg root
  d = .Directory~new
  path = root || "/" || .QueueMutationPath~LOCKS || "/" || .QueueMutationPath~STATE_LOCKS
  present = SysFileExists(path) == 1
  writable = .false
  if present then do
    text = .QueueRexxUtil~shellOutput("test -w " || .QueuePosixShell~quote(path) || " && printf yes")
    writable = text == "yes"
  end
  d["path"] = path
  d["present"] = .QueueRexxUtil~jsonBoolean(present)
  d["writable"] = .QueueRexxUtil~jsonBoolean(writable)
  d["owner"] = .QueueRexxUtil~shellOutput("stat -c %U -- " || .QueuePosixShell~quote(path) || " 2>/dev/null")
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxHealth.cls"
::requires "QueueRexxMutation.cls"
