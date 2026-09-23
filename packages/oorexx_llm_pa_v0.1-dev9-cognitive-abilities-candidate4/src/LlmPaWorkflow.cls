/* Native workflow substrate for bounded recurring PA tasks.
 * Gemma may propose a directory, but these classes validate and execute no
 * model prose. Scheduling and tool authority are supplied by the host. */

::class LlmPaWorkflowSpec public
::attribute workflowId get
::attribute actionName get
::attribute actionArgs get
::attribute intervalSeconds get
::attribute metric get
::attribute operator get
::attribute threshold get
::attribute notifyMode get

::method init
  expose workflowId actionName actionArgs intervalSeconds metric operator threshold notifyMode
  use arg workflowIdArg, actionNameArg, actionArgsArg, intervalArg, metricArg, operatorArg, thresholdArg, notifyArg = "on_match"
  workflowId = workflowIdArg~string~strip
  actionName = actionNameArg~string~strip
  actionArgs = actionArgsArg
  intervalSeconds = intervalArg + 0
  metric = metricArg~string~strip~lower
  operator = operatorArg~string~strip
  threshold = thresholdArg + 0
  notifyMode = notifyArg~string~strip~lower

::method fromDirectory class
  use arg proposal
  if proposal == .nil | \proposal~isa(.Directory) then return .LlmPaResult~failure("WORKFLOW_PROPOSAL_INVALID")
  required = .array~of("workflow_id", "action", "args", "interval_seconds", "predicate_metric", "predicate_operator", "predicate_threshold")
  do field over required
    if \proposal~hasIndex(field) then return .LlmPaResult~failure("WORKFLOW_FIELD_REQUIRED", field)
  end
  args = proposal["args"]
  if \args~isa(.Array) then return .LlmPaResult~failure("WORKFLOW_ARGS_INVALID")
  spec = self~new(proposal["workflow_id"], proposal["action"], args, proposal["interval_seconds"], proposal["predicate_metric"], proposal["predicate_operator"], proposal["predicate_threshold"], self~field(proposal, "notify_mode", "on_match"))
  checked = spec~validate
  if \checked~ok then return checked
  return .LlmPaResult~success(spec)

::method validate
  expose workflowId actionName actionArgs intervalSeconds metric operator threshold notifyMode
  if workflowId = "" | workflowId~length > 128 then return .LlmPaResult~failure("WORKFLOW_ID_INVALID")
  if actionName = "" | actionName~length > 128 then return .LlmPaResult~failure("WORKFLOW_ACTION_INVALID")
  if \actionArgs~isa(.Array) then return .LlmPaResult~failure("WORKFLOW_ARGS_INVALID")
  if datatype(intervalSeconds, "W") = 0 | intervalSeconds < 60 | intervalSeconds > 31536000 then return .LlmPaResult~failure("WORKFLOW_INTERVAL_INVALID", intervalSeconds)
  if metric \= "working_space_free_percent" then return .LlmPaResult~failure("WORKFLOW_METRIC_UNSUPPORTED", metric)
  if operator \= "<" then return .LlmPaResult~failure("WORKFLOW_OPERATOR_UNSUPPORTED", operator)
  if datatype(threshold, "N") = 0 | threshold < 0 | threshold > 100 then return .LlmPaResult~failure("WORKFLOW_THRESHOLD_INVALID", threshold)
  if notifyMode \= "on_match" & notifyMode \= "on_transition" & notifyMode \= "on_failure" then return .LlmPaResult~failure("WORKFLOW_NOTIFY_MODE_INVALID", notifyMode)
  return .LlmPaResult~success(self)

::method field private class
  use arg source, name, default
  if source~hasIndex(name) then return source[name]
  return default

::class LlmPaWorkflowPredicate public
::method evaluate class
  use arg metricArg, operatorArg = "<", thresholdArg = 50
  metricText = metricArg~string~strip
  if datatype(metricText, "N") = 0 then return .LlmPaResult~failure("WORKFLOW_METRIC_VALUE_INVALID", metricText)
  operator = operatorArg~string~strip
  threshold = thresholdArg + 0
  matched = .false
  select
    when operator = "<" then matched = (metricText + 0) < threshold
    when operator = "<=" then matched = (metricText + 0) <= threshold
    when operator = ">" then matched = (metricText + 0) > threshold
    when operator = ">=" then matched = (metricText + 0) >= threshold
    otherwise return .LlmPaResult~failure("WORKFLOW_OPERATOR_UNSUPPORTED", operator)
  end
  outcome = .directory~new
  outcome["metric"] = metricText + 0
  outcome["operator"] = operator
  outcome["threshold"] = threshold
  outcome["matched"] = matched
  return .LlmPaResult~success(outcome)

::class LlmPaWorkflowAudit public
::attribute path get
::method init
  expose path
  use arg pathArg
  path = pathArg~string~strip
  if path = "" then raise syntax 88.900 array("workflow audit path is required")

::method append
  expose path
  use arg eventArg
  if eventArg == .nil | \eventArg~isa(.Directory) then return .LlmPaResult~failure("WORKFLOW_AUDIT_EVENT_INVALID")
  required = .array~of("event_type", "workflow_id")
  do field over required
    if \eventArg~hasIndex(field) then return .LlmPaResult~failure("WORKFLOW_AUDIT_FIELD_REQUIRED", field)
  end
  line = .LlmPaUtil~timestamp || "09"x || self~pack(eventArg["event_type"]) || "09"x || self~pack(eventArg["workflow_id"])
  optional = .array~of("execution_id", "outcome", "predicate_matched", "notification", "detail")
  do field over optional
    value = ""
    if eventArg~hasIndex(field) then value = eventArg[field]
    line = line || "09"x || self~pack(value)
  end
  call lineout path, line
  call lineout path
  return .LlmPaResult~success(.true)

::method pack private
  use arg valueArg
  if valueArg == .nil then return ""
  return c2x(valueArg~string)

::requires "LlmPaCore.cls"

/* Runtime for an activated fixed workflow. The executor and notifier are
 * injected authority seams; this class never shells out or invents commands. */
::class LlmPaWorkflowService public
::method init
  expose reminders executor notifier audit workflows
  use arg remindersArg, executorArg, notifierArg = .nil, auditArg = .nil
  reminders = remindersArg
  executor = executorArg
  notifier = notifierArg
  audit = auditArg
  workflows = .table~new

::method activate
  expose reminders audit workflows
  use arg spec
  checked = spec~validate
  if \checked~ok then return checked
  id = spec~workflowId
  if workflows~hasIndex(id) then return .LlmPaResult~failure("WORKFLOW_ALREADY_ACTIVE", id)
  workflows[id] = spec
  ignore = self~writeAudit(self~event("ACTIVATED", id))
  armed = self~armInitial(spec)
  if \armed~ok then do
    workflows[id] = .nil
    return armed
  end
  return .LlmPaResult~success(self~state(spec, "ARMED", armed~value))

::method run
  expose executor notifier workflows
  use arg workflowIdArg
  id = workflowIdArg~string~strip
  if \workflows~hasIndex(id) then return .LlmPaResult~failure("WORKFLOW_NOT_FOUND", id)
  spec = workflows[id]
  executionId = "exec-" || random(100000,999999)
  started = self~event("EXECUTION_STARTED", id)
  started["execution_id"] = executionId
  ignore = self~writeAudit(started)
  if executor == .nil then return self~executionFailure(spec, executionId, "EXECUTOR_NOT_CONFIGURED", "fixed executor is not configured")
  invocation = executor~runFixed(spec~actionName, spec~actionArgs)
  if \invocation~ok then return self~executionFailure(spec, executionId, invocation~code, invocation~detail)
  measured = .LlmPaDfParser~workingSpaceFreePercent(invocation~value)
  if \measured~ok then return self~executionFailure(spec, executionId, measured~code, measured~detail)
  checked = .LlmPaWorkflowPredicate~evaluate(measured~value, spec~operator, spec~threshold)
  if \checked~ok then return self~executionFailure(spec, executionId, checked~code, checked~detail)
  matched = checked~value["matched"]
  notification = "SUPPRESSED"
  if matched then do
    notification = "EMITTED"
    if notifier \== .nil then do
      sent = notifier~notify(spec~workflowId, spec~actionName, measured~value, invocation~value)
      if \sent~ok then notification = "FAILED"
    end
  end
  completed = self~event("EXECUTION_COMPLETED", id)
  completed["execution_id"] = executionId
  completed["outcome"] = "SUCCESS"
  completed["predicate_matched"] = matched
  completed["notification"] = notification
  completed["detail"] = "working_space_free_percent=" || measured~value
  ignore = self~writeAudit(completed)
  /* A fired Alarm is one-shot and is now over. Recurrence is an LLM
   * decision, not a service side effect. The caller receives the evidence
   * and may explicitly arm a new Alarm after Gemma has assessed it. */
  return .LlmPaResult~success(self~state(spec, "CHECKED", checked~value))

::method armInitial private
  expose reminders
  use arg spec
  if reminders == .nil then return .LlmPaResult~failure("WORKFLOW_REMINDERS_NOT_CONFIGURED")
  armed = reminders~scheduleDecision(spec~intervalSeconds, "WORKFLOW_FIRE|" || spec~workflowId, spec~workflowId, spec~workflowId, "workflow")
  if \armed~ok then return armed
  ignore = self~writeAudit(self~event("ALARM_ARMED", spec~workflowId))
  return armed

::method executionFailure private
  use arg spec, executionId, code, detail
  event = self~event("EXECUTION_FAILED", spec~workflowId)
  event["execution_id"] = executionId
  event["outcome"] = code
  event["notification"] = "FAILURE_POLICY"
  event["detail"] = detail
  ignore = self~writeAudit(event)
  return .LlmPaResult~failure(code, detail)

::method state private
  use arg spec, status, alarm
  d = .directory~new
  d["workflow_id"] = spec~workflowId
  d["status"] = status
  d["alarm"] = alarm
  return d

::method event private
  use arg eventType, workflowId
  d = .directory~new
  d["event_type"] = eventType
  d["workflow_id"] = workflowId
  return d

::method writeAudit private
  expose audit
  use arg event
  if audit == .nil then return .LlmPaResult~success(.true)
  return audit~append(event)

::class LlmPaDfParser public
::method workingSpaceFreePercent class
  use arg outputArg
  text = outputArg~string
  do i = 1 to words(text)
    token = word(text, i)
    if token~right(1) = "%" then do
      usedText = token~left(token~length - 1)
      if datatype(usedText, "N") then do
        free = 100 - (usedText + 0)
        if free < 0 | free > 100 then iterate
        return .LlmPaResult~success(free)
      end
    end
  end
  return .LlmPaResult~failure("WORKFLOW_DF_METRIC_MISSING", "df capacity percentage not found")
