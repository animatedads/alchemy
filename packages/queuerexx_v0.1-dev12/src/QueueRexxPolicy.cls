/* QueueRexxPolicy.cls - QueueBash policy-provider binding, v0.1-dev11.
 *
 * QueueBash remains the compatibility/policy reference. This provider invokes
 * the exact QueueBash worker execution gate against a temporary copy of the job
 * record so policy inspection cannot mutate authoritative queue metadata.
 *
 * The provider owns policy mechanism/evidence only. QueueRexx transition
 * authority decides whether a denied running record moves to pol_blocked.
 */

::class QueueBashPolicyCode public
::constant ALLOWED "QUEUEBASH_EXECUTION_POLICY_ALLOWED"
::constant DENIED "QUEUEBASH_EXECUTION_POLICY_DENIED"
::constant PROVIDER_UNAVAILABLE "QUEUEBASH_POLICY_PROVIDER_UNAVAILABLE"
::constant VERSION_MISMATCH "QUEUEBASH_POLICY_VERSION_MISMATCH"
::constant QUEUE_STATE_AMBIGUOUS "QUEUE_STATE_AMBIGUOUS"
::constant QUEUE_STATE_NOT_RUNNING "QUEUE_STATE_NOT_RUNNING"
::constant SUBMIT_NOT_BOUND "QUEUEBASH_SUBMIT_POLICY_NOT_BOUND"

::class QueuePolicyAssessment public
::constant ALLOW 1
::constant DENY 2
::constant ERROR 3
::attribute decision get
::attribute code get
::attribute detail get
::attribute providerId get
::attribute providerVersion get
::attribute evidence get
::attribute assessedAt get
::method init
  expose decision code detail providerId providerVersion evidence assessedAt
  use strict arg decisionArg, codeArg, detailArg, providerArg, versionArg, evidenceArg = .nil, assessedArg = ""
  decision = decisionArg + 0
  code = codeArg~string
  detail = detailArg~string
  providerId = providerArg~string
  providerVersion = versionArg~string
  if evidenceArg == .nil then evidence = .Directory~new; else evidence = evidenceArg
  if assessedArg == "" then assessedAt = .DateTime~new~string; else assessedAt = assessedArg~string
::method allowed
  expose decision
  return decision == self~ALLOW
::method decisionName
  expose decision
  select
    when decision == self~ALLOW then return "allow"
    when decision == self~DENY then return "deny"
    otherwise return "error"
  end
::method asDirectory
  expose code detail providerId providerVersion evidence assessedAt
  d = .Directory~new
  d["schema"] = .QueueSchema~POLICY_ASSESSMENT
  d["allowed"] = .QueueRexxUtil~jsonBoolean(self~allowed)
  d["decision"] = self~decisionName
  d["code"] = code
  d["detail"] = detail
  d["provider"] = providerId
  d["provider_version"] = providerVersion
  d["assessed_at"] = assessedAt
  d["evidence"] = evidence
  return d

::class QueueBashClassPolicyProvider public subclass QueuePolicyProvider
::constant PROVIDER_ID "queuebash.class-policy"
::constant PROVIDER_VERSION "0.18.144"
::constant CAP_EXECUTION "worker-execution-policy"
::constant CAP_COMMAND_AUTH "command-bound-authorisation"
::constant CAP_POLICY_PRECEDENCE "shared-policy-precedence"
::constant CAP_NONMUTATING "temporary-record-copy-assessment"
::attribute root get
::attribute sourcePath get
::attribute executor get
::method init
  expose root sourcePath executor
  use arg rootArg, sourceArg = "", executorArg = .nil
  root = rootArg~string
  if sourceArg == "" then sourcePath = self~discoverSource
  else sourcePath = sourceArg~string
  if executorArg == .nil then executor = .QueueSystemCommandExecutor~new
  else executor = executorArg
::method id
  return self~PROVIDER_ID
::method version
  return self~PROVIDER_VERSION
::method capabilities
  return .Array~of(self~CAP_EXECUTION, self~CAP_COMMAND_AUTH, self~CAP_POLICY_PRECEDENCE, self~CAP_NONMUTATING)
::method discoverSource private
  path = value("QUEUEREXX_QUEUEBASH_SOURCE",, "ENVIRONMENT")
  if path == "" then path = value("QUEUEBASH_SOURCE",, "ENVIRONMENT")
  return path
::method available
  expose sourcePath
  if sourcePath == "" then return .false
  return SysFileExists(sourcePath)
::method assess
  expose root sourcePath executor
  use strict arg record
  evidence = .Directory~new
  evidence["queue_root"] = root
  evidence["record_path"] = record~path
  evidence["queuebash_source"] = sourcePath
  evidence["assessment_mode"] = "queuebash_worker_execution_gate"
  evidence["authoritative_record_mutated"] = .JSONBoolean~false
  evidence["assessment_copy"] = .JSONBoolean~true
  if \self~available then return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ERROR, .QueueBashPolicyCode~PROVIDER_UNAVAILABLE, "exact QueueBash source is not available; set QUEUEREXX_QUEUEBASH_SOURCE or pass a source path", self~id, self~version, evidence)

  script = 'qrx_tmp=$(mktemp) || exit 96; trap ''rm -f -- "$qrx_tmp"'' EXIT; ' ||,
           'cp -- "$2" "$qrx_tmp" || exit 95; ' ||,
           'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_ROOT="$3"; ' ||,
           'source "$1" >/dev/null || exit 97; ' ||,
           'if [ "${QUEUEBASH_VERSION:-}" != "$4" ]; then printf ''QueueBash version mismatch: expected %s got %s\n'' "$4" "${QUEUEBASH_VERSION:-missing}" >&2; exit 98; fi; ' ||,
           '_queue_job_policy_execution_check "$qrx_tmp"'
  command = "bash -c " || .QueuePosixShell~quote(script) || " qrx-policy " ||,
            .QueuePosixShell~quote(sourcePath) || " " || .QueuePosixShell~quote(record~path) || " " ||,
            .QueuePosixShell~quote(root) || " " || .QueuePosixShell~quote(self~PROVIDER_VERSION)
  commandResult = executor~run(command)
  evidence["provider_rc"] = commandResult~rc
  evidence["stdout"] = commandResult~output
  evidence["stderr"] = commandResult~error

  if commandResult~rc == 0 then return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ALLOW, .QueueBashPolicyCode~ALLOWED, "QueueBash worker execution policy allows this record", self~id, self~version, evidence)
  if commandResult~rc == 98 then return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ERROR, .QueueBashPolicyCode~VERSION_MISMATCH, self~joinLines(commandResult~error), self~id, self~version, evidence)
  if commandResult~rc == 95 | commandResult~rc == 96 | commandResult~rc == 97 | commandResult~rc == 126 | commandResult~rc == 127 then return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ERROR, .QueueBashPolicyCode~PROVIDER_UNAVAILABLE, self~failureDetail(commandResult), self~id, self~version, evidence)
  return .QueuePolicyAssessment~new(.QueuePolicyAssessment~DENY, .QueueBashPolicyCode~DENIED, self~failureDetail(commandResult), self~id, self~version, evidence)

::method explain
  expose sourcePath root
  d = .Directory~new
  d["id"] = self~id
  d["version"] = self~version
  d["capabilities"] = self~capabilities
  d["queue_root"] = root
  d["queuebash_source"] = sourcePath
  d["available"] = .QueueRexxUtil~jsonBoolean(self~available)
  d["authority_note"] = "provider evaluates QueueBash policy against a temporary record copy; it never moves queue state"
  return d

::method failureDetail private
  use strict arg commandResult
  text = self~joinLines(commandResult~output)
  errText = self~joinLines(commandResult~error)
  if text \= "" & errText \= "" then text ||= " | "
  text ||= errText
  if text == "" then text = "QueueBash policy gate returned rc=" || commandResult~rc
  return text

::method joinLines private
  use strict arg lines
  text = ""
  do line over lines
    if text \= "" then text ||= " "
    text ||= line~string~strip
  end
  return text

::class QueueBashExecutionPolicyGate public subclass QueueOperationPolicyGate
::attribute provider get
::attribute root get
::method init
  expose provider root store
  use arg rootArg, providerArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if providerArg == .nil then provider = .QueueBashClassPolicyProvider~new(root)
  else provider = providerArg
::method assessSubmit
  return .QueuePolicyVerdict~deny(.QueueBashPolicyCode~SUBMIT_NOT_BOUND, "dev11 binds QueueBash execution policy only; typed submission remains fail-closed")
::method assessExecution
  expose provider store
  use strict arg record
  matches = store~findAll(record~qid)
  if matches~items \= 1 then return .QueuePolicyVerdict~deny(.QueueBashPolicyCode~QUEUE_STATE_AMBIGUOUS, "execution policy requires exactly one authoritative queue record for QID")
  only = matches[1]
  if only~state \= .QueueState~RUNNING then return .QueuePolicyVerdict~deny(.QueueBashPolicyCode~QUEUE_STATE_NOT_RUNNING, "execution policy is valid only for the one authoritative running record")
  assessment = provider~assess(only)
  if assessment~allowed then return .QueuePolicyVerdict~allow(assessment~code, assessment~detail)
  return .QueuePolicyVerdict~deny(assessment~code, assessment~detail)

::class QueuePolicyInspectionService public
::attribute root get
::attribute provider get
::method init
  expose root provider store
  use arg rootArg, providerArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if providerArg == .nil then provider = .QueueBashClassPolicyProvider~new(root)
  else provider = providerArg
::method inspect
  expose store provider
  use strict arg qidArg
  qid = qidArg~string
  matches = store~findAll(qid)
  if matches~items \= 1 then do
    evidence = .Directory~new
    evidence["record_count"] = matches~items
    states = .Array~new
    do item over matches; states~append(item~stateName); end
    evidence["states_seen"] = states
    return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ERROR, .QueueBashPolicyCode~QUEUE_STATE_AMBIGUOUS, "policy inspection requires exactly one authoritative queue record", provider~id, provider~version, evidence)
  end
  return provider~assess(matches[1])

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxOperations.cls"
