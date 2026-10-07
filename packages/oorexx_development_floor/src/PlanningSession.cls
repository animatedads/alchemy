/* PlanningSession.cls
   Luna-only staged planning/orchestration proof for Development Floor.

   Authority boundaries:
   - Luna proposes a tiny ordered plan; Development Floor validates it before work exists.
   - Development Manager creates assignments and binds the one allowed execution provider: Azure Luna.
   - every model phase is WLU-reserved/admitted/accounted independently.
   - IMPLEMENT delegates to DFAutonomousCodingWorker, whose deterministic compile/run evidence
     drives its mandatory second bite.
   - REVIEW can ACCEPT or request REWORK, but cannot directly mutate source.
*/

::class DFPlanningBuild public
::constant API_VERSION "development.floor.planning-session/0.1"
::constant MAX_SPEC_BYTES 65536
::constant MAX_PLAN_BYTES 32768
::constant MAX_REVIEW_BYTES 8192

::class DFPlanWorkItem public
::method init
  expose id kind objective dependencies
  use strict arg idArg, kindArg, objectiveArg, dependenciesArg
  id = idArg~string
  kind = translate(kindArg~string)
  objective = objectiveArg~string
  dependencies = dependenciesArg
::attribute id get
::attribute kind get
::attribute objective get
::attribute dependencies get

::class DFValidatedPlan public
::method init
  expose projectId items rawText
  use strict arg projectIdArg, itemsArg, rawTextArg
  projectId = projectIdArg~string
  items = itemsArg
  rawText = rawTextArg~string
::attribute projectId get
::attribute items get
::attribute rawText get
::method itemByKind
  expose items
  use strict arg kindArg
  wanted = translate(kindArg~string)
  do item over items
    if item~kind = wanted then return item
  end
  return .nil

::class DFProjectRunOutcome public
::method init
  expose ok code detail projectId planPath artifactPath artifactSha reviewDecision inputTokens outputTokens consumedMicroWlu reasoningScore reasoningVerdict
  use strict arg okArg, codeArg, detailArg="", projectIdArg="", planPathArg="", artifactPathArg="", artifactShaArg="", reviewDecisionArg="", inputTokensArg=0, outputTokensArg=0, consumedArg=0, reasoningScoreArg=(-1), reasoningVerdictArg=""
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  projectId = projectIdArg~string
  planPath = planPathArg~string
  artifactPath = artifactPathArg~string
  artifactSha = artifactShaArg~string
  reviewDecision = translate(reviewDecisionArg~string)
  inputTokens = inputTokensArg
  outputTokens = outputTokensArg
  consumedMicroWlu = consumedArg
  reasoningScore = reasoningScoreArg
  reasoningVerdict = reasoningVerdictArg~string~upper
::attribute ok get
::attribute code get
::attribute detail get
::attribute projectId get
::attribute planPath get
::attribute artifactPath get
::attribute artifactSha get
::attribute reviewDecision get
::attribute inputTokens get
::attribute outputTokens get
::attribute consumedMicroWlu get
::attribute reasoningScore get
::attribute reasoningVerdict get

::class DFPlanningDiagnostic
::method redacted class
  use strict arg valueArg
  text = valueArg~string
  if text = "" then return ""
  if text~length > 160 then text = text~left(160) || "..."
  return text

::class DFLunaPlanningSession public
::method init
  expose manager provider journal managementProvider managementModel reasoningThreshold
  use strict arg managerArg, providerArg, journalArg=.nil, managementProviderArg=.nil, managementModelArg="qwen2.5-1.5b-npu", reasoningThresholdArg=0.70
  manager = managerArg
  provider = providerArg
  journal = journalArg
  managementProvider = managementProviderArg
  managementModel = managementModelArg~string
  reasoningThreshold = reasoningThresholdArg

::method runHelloProject
  expose manager provider journal managementProvider managementModel reasoningThreshold
  use strict arg specPath, workspaceRoot, modelId, maxPlanTokens=20000, maxImplementTokens=20000, maxReviewTokens=20000, maxManagementTokens=512
  numeric digits 30
  specRead = self~readFile(specPath, .DFPlanningBuild~MAX_SPEC_BYTES)
  if \specRead[1] then return .DFProjectRunOutcome~new(.false, "SPEC_UNAVAILABLE", specRead[2])
  specParsed = self~parseSpec(specRead[3])
  if \specParsed[1] then return .DFProjectRunOutcome~new(.false, "SPEC_INVALID", specParsed[2])
  spec = specParsed[3]
  projectId = spec["project_id"]~string
  if journal \== .nil then ignore = journal~persist("SESSION", "PROJECT_SPEC", "session/project.spec.json", specRead[3], projectId)
  if \self~ensureDirectory(workspaceRoot) then return .DFProjectRunOutcome~new(.false, "WORKSPACE_UNAVAILABLE", workspaceRoot, projectId)

  totalIn = 0
  totalOut = 0
  totalWlu = 0

  /* Phase 1: Luna planning. */
  planAssignmentId = projectId || "-PLAN"
  planAssignment = .DFAssignment~new(planAssignmentId, projectId, spec["package_id"]~string, spec["language"]~string, "construct an ordered Development Floor plan")
  ignore = planAssignment~assignTo("development-manager")
  ignore = manager~addAssignment(planAssignment)
  ignore = manager~bindAssignmentExecution(planAssignmentId, "development-manager", "azure-gpt-6-luna")
  reserved = manager~reserveAssignmentWork(planAssignmentId, 700000, 1000000, 20, 300, projectId || "-plan")
  if \reserved~ok then return .DFProjectRunOutcome~new(.false, "PLAN_WLU_RESERVE_FAILED", reserved~code, projectId)
  admitted = manager~admitAssignmentWork(planAssignmentId)
  if \admitted~ok then return .DFProjectRunOutcome~new(.false, "PLAN_WLU_ADMIT_FAILED", admitted~code, projectId)

  planPromptText = self~planningPrompt(specRead[3], projectId)
  if journal \== .nil then ignore = journal~persist("PLAN", "MODEL_REQUEST", "plan/prompt.txt", planPromptText, planAssignmentId)
  planReply = provider~complete(.AIProviderRequest~new(modelId, planPromptText, maxPlanTokens))
  if journal \== .nil then ignore = journal~persist("PLAN", "MODEL_RESPONSE", "plan/response.json", planReply~text, "ok=" || planReply~ok || " code=" || planReply~code)
  ignore = manager~consumeAssignmentWork(planAssignmentId, 700000, "luna-project-plan")
  totalWlu += 700000
  totalIn += planReply~usage~inputTokens
  totalOut += planReply~usage~outputTokens
  ignore = self~recordTokens(planAssignmentId, planReply~usage~inputTokens, planReply~usage~outputTokens, "luna-project-plan")
  if \planReply~ok then do
    ignore = manager~settleAssignmentWork(planAssignmentId, 700000)
    return .DFProjectRunOutcome~new(.false, planReply~code, planReply~detail, projectId, "", "", "", "", totalIn, totalOut, totalWlu)
  end
  planParsed = self~parsePlan(planReply~text, projectId)
  if \planParsed[1] then do
    ignore = manager~settleAssignmentWork(planAssignmentId, 700000)
    return .DFProjectRunOutcome~new(.false, "PLAN_INVALID", planParsed[2], projectId, "", "", "", "", totalIn, totalOut, totalWlu)
  end
  plan = planParsed[3]
  if journal \== .nil then ignore = journal~persist("PLAN", "VALIDATED", "plan/validated.json", plan~rawText || "0a"x, projectId)
  planPath = self~joinPath(workspaceRoot, "project.plan.json")
  if \self~writeFile(planPath, plan~rawText || "0a"x) then do
    ignore = manager~settleAssignmentWork(planAssignmentId, 700000)
    return .DFProjectRunOutcome~new(.false, "PLAN_WRITE_FAILED", planPath, projectId, planPath, "", "", "", totalIn, totalOut, totalWlu)
  end
  ignore = manager~settleAssignmentWork(planAssignmentId, 700000)

  /* Phase 2: execute the validated IMPLEMENT item with Luna. */
  implementItem = plan~itemByKind("IMPLEMENT")
  implementAssignmentId = projectId || "-" || implementItem~id
  implementAssignment = .DFAssignment~new(implementAssignmentId, projectId, spec["package_id"]~string, spec["language"]~string, implementItem~objective)
  ignore = implementAssignment~assignTo("hello-specialist")
  ignore = manager~addAssignment(implementAssignment)
  ignore = manager~bindAssignmentExecution(implementAssignmentId, "coding-specialist", "azure-gpt-6-luna")
  reserved = manager~reserveAssignmentWork(implementAssignmentId, 2200000, 3000000, 60, 600, projectId || "-implement")
  if \reserved~ok then return .DFProjectRunOutcome~new(.false, "IMPLEMENT_WLU_RESERVE_FAILED", reserved~code, projectId, planPath, "", "", "", totalIn, totalOut, totalWlu)
  admitted = manager~admitAssignmentWork(implementAssignmentId)
  if \admitted~ok then return .DFProjectRunOutcome~new(.false, "IMPLEMENT_WLU_ADMIT_FAILED", admitted~code, projectId, planPath, "", "", "", totalIn, totalOut, totalWlu)

  instructionPath = self~joinPath(workspaceRoot, "implementation.instructions.txt")
  instructions = self~implementationInstructions(spec)
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "INSTRUCTIONS", "implement/instructions.txt", instructions, implementAssignmentId)
  if \self~writeFile(instructionPath, instructions) then return .DFProjectRunOutcome~new(.false, "IMPLEMENT_INSTRUCTIONS_WRITE_FAILED", instructionPath, projectId, planPath, "", "", "", totalIn, totalOut, totalWlu)
  coder = .DFAutonomousCodingWorker~new(manager, provider, journal)
  coding = coder~runHelloWorld(implementAssignmentId, instructionPath, workspaceRoot, modelId, spec["expected_stdout"]~string, maxImplementTokens, 1000000, 100000, 1000000, 100000)
  totalIn += coding~inputTokens
  totalOut += coding~outputTokens
  totalWlu += coding~consumedMicroWlu
  if \coding~ok then return .DFProjectRunOutcome~new(.false, "IMPLEMENT_FAILED", coding~detail, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)

  /* Phase 3: Qwen management comparison of required vs claimed reasoning. */
  reasoningScore = -1
  reasoningVerdict = "UNAVAILABLE"
  if managementProvider == .nil then return .DFProjectRunOutcome~new(.false, "MANAGEMENT_PROVIDER_UNAVAILABLE", "reasoning alignment provider not configured", projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)
  managementAssignmentId = projectId || "-" || implementItem~id || "-REASONING"
  managementAssignment = .DFAssignment~new(managementAssignmentId, projectId, spec["package_id"]~string, spec["language"]~string, "compare required reasoning obligations with worker claimed reasoning summary")
  ignore = managementAssignment~assignTo("reasoning-manager")
  ignore = manager~addAssignment(managementAssignment)
  ignore = manager~bindAssignmentExecution(managementAssignmentId, "reasoning-manager", "local-qwen-llamacpp")
  reserved = manager~reserveAssignmentWork(managementAssignmentId, 100000, 200000, 10, 120, projectId || "-reasoning-management")
  if \reserved~ok then return .DFProjectRunOutcome~new(.false, "MANAGEMENT_WLU_RESERVE_FAILED", reserved~code, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)
  admitted = manager~admitAssignmentWork(managementAssignmentId)
  if \admitted~ok then return .DFProjectRunOutcome~new(.false, "MANAGEMENT_WLU_ADMIT_FAILED", admitted~code, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)
  requiredReasoning = self~requiredReasoning(spec, implementItem)
  alignmentManager = .DFReasoningAlignmentManager~new(managementProvider, journal, reasoningThreshold)
  alignment = alignmentManager~evaluate(implementItem~id, requiredReasoning, coding~claimedReasoningSummary, managementModel, maxManagementTokens)
  ignore = manager~consumeAssignmentWork(managementAssignmentId, 100000, "qwen-reasoning-alignment")
  ignore = manager~settleAssignmentWork(managementAssignmentId, 100000)
  totalWlu += 100000
  totalIn += alignment~inputTokens
  totalOut += alignment~outputTokens
  ignore = self~recordTokens(managementAssignmentId, alignment~inputTokens, alignment~outputTokens, "qwen-reasoning-alignment")
  if \alignment~ok then return .DFProjectRunOutcome~new(.false, "MANAGEMENT_FAILED", alignment~code || ":" || alignment~detail, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)
  reasoningScore = alignment~score
  reasoningVerdict = alignment~verdict

  /* Phase 4: Luna independent review.  Review may request rework but cannot repair. */
  reviewItem = plan~itemByKind("REVIEW")
  reviewAssignmentId = projectId || "-" || reviewItem~id
  reviewAssignment = .DFAssignment~new(reviewAssignmentId, projectId, spec["package_id"]~string, spec["language"]~string, reviewItem~objective)
  ignore = reviewAssignment~assignTo("luna-reviewer")
  ignore = manager~addAssignment(reviewAssignment)
  ignore = manager~bindAssignmentExecution(reviewAssignmentId, "csm-reviewer", "azure-gpt-6-luna")
  reserved = manager~reserveAssignmentWork(reviewAssignmentId, 500000, 800000, 20, 300, projectId || "-review")
  if \reserved~ok then return .DFProjectRunOutcome~new(.false, "REVIEW_WLU_RESERVE_FAILED", reserved~code, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)
  admitted = manager~admitAssignmentWork(reviewAssignmentId)
  if \admitted~ok then return .DFProjectRunOutcome~new(.false, "REVIEW_WLU_ADMIT_FAILED", admitted~code, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu)

  reviewPromptText = self~reviewPrompt(spec, implementItem, coding)
  if journal \== .nil then ignore = journal~persist("REVIEW", "MODEL_REQUEST", "review/prompt.txt", reviewPromptText, reviewAssignmentId)
  reviewReply = provider~complete(.AIProviderRequest~new(modelId, reviewPromptText, maxReviewTokens))
  if journal \== .nil then ignore = journal~persist("REVIEW", "MODEL_RESPONSE", "review/response.json", reviewReply~text, "ok=" || reviewReply~ok || " code=" || reviewReply~code)
  ignore = manager~consumeAssignmentWork(reviewAssignmentId, 500000, "luna-project-review")
  totalWlu += 500000
  totalIn += reviewReply~usage~inputTokens
  totalOut += reviewReply~usage~outputTokens
  ignore = self~recordTokens(reviewAssignmentId, reviewReply~usage~inputTokens, reviewReply~usage~outputTokens, "luna-project-review")
  if \reviewReply~ok then do
    ignore = manager~settleAssignmentWork(reviewAssignmentId, 500000)
    return .DFProjectRunOutcome~new(.false, reviewReply~code, reviewReply~detail, projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu, reasoningScore, reasoningVerdict)
  end
  reviewed = self~parseReview(reviewReply~text)
  ignore = manager~settleAssignmentWork(reviewAssignmentId, 500000)
  if \reviewed[1] then return .DFProjectRunOutcome~new(.false, "REVIEW_INVALID", reviewed[2], projectId, planPath, coding~filePath, coding~sourceSha256, "", totalIn, totalOut, totalWlu, reasoningScore, reasoningVerdict)
  decision = reviewed[3]
  if journal \== .nil then ignore = journal~persist("REVIEW", "DECISION", "review/decision.txt", decision || "0a"x || reviewed[4] || "0a"x, reviewAssignmentId)
  if decision = "REWORK" then return .DFProjectRunOutcome~new(.false, "REWORK_REQUIRED", reviewed[4], projectId, planPath, coding~filePath, coding~sourceSha256, decision, totalIn, totalOut, totalWlu, reasoningScore, reasoningVerdict)
  return .DFProjectRunOutcome~new(.true, "OK", "Luna plan implemented, deterministically qualified and independently accepted", projectId, planPath, coding~filePath, coding~sourceSha256, decision, totalIn, totalOut, totalWlu, reasoningScore, reasoningVerdict)

::method parseSpec
  use strict arg text
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object", .nil)
  required = .Array~of("schema", "project_id", "goal", "package_id", "language", "expected_stdout", "acceptance")
  do key over required
    if data~at(key) == .nil then return .Array~of(.false, "missing-" || key, .nil)
  end
  if data["schema"]~string \= "development.floor.project/0.1" then return .Array~of(.false, "schema", .nil)
  if data["project_id"]~string~strip = "" then return .Array~of(.false, "project-id", .nil)
  if data["goal"]~string~strip = "" then return .Array~of(.false, "goal", .nil)
  if \data["acceptance"]~isa(.Array) then return .Array~of(.false, "acceptance-not-array", .nil)
  return .Array~of(.true, "", data)
invalid:
  say "Planning session spec JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFPlanningDiagnostic~redacted(condition("D"))
  signal off syntax
  return .Array~of(.false, "invalid-json", .nil)

::method planningPrompt
  use strict arg specText, projectId
  text = "You are Luna acting only as the Development Floor planner." || "0a"x
  text ||= "Construct the smallest safe ordered plan for this project." || "0a"x
  text ||= "Project specification:" || "0a"x || specText || "0a"x
  text ||= 'Return JSON only in exactly this shape:' || "0a"x
  text ||= '{"project_id":"' || projectId || '","items":[' || "0a"x
  text ||= '{"id":"W1","kind":"IMPLEMENT","objective":"<bounded implementation objective>","depends_on":[]},' || "0a"x
  text ||= '{"id":"W2","kind":"REVIEW","objective":"<independent review objective>","depends_on":["W1"]}' || "0a"x
  text ||= ']}' || "0a"x
  text ||= "Exactly two items. Preserve project_id. Kinds and IDs are fixed. No extra fields. No markdown."
  return text

::method parsePlan
  use strict arg text, expectedProjectId
  if text~length > .DFPlanningBuild~MAX_PLAN_BYTES then return .Array~of(.false, "too-large", .nil)
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object", .nil)
  if data~items \= 2 then return .Array~of(.false, "unexpected-top-fields", .nil)
  if data~at("project_id") == .nil then return .Array~of(.false, "required-fields", .nil)
  if data~at("items") == .nil then return .Array~of(.false, "required-fields", .nil)
  if data["project_id"]~string \= expectedProjectId then return .Array~of(.false, "project-id-mismatch", .nil)
  rawItems = data["items"]
  if \rawItems~isa(.Array) then return .Array~of(.false, "items-not-array", .nil)
  if rawItems~items \= 2 then return .Array~of(.false, "item-count", .nil)
  items = .Array~new
  parsedFirst = self~parsePlanItem(rawItems[1])
  if \parsedFirst[1] then return .Array~of(.false, parsedFirst[2], .nil)
  items~append(parsedFirst[3])
  parsedSecond = self~parsePlanItem(rawItems[2])
  if \parsedSecond[1] then return .Array~of(.false, parsedSecond[2], .nil)
  items~append(parsedSecond[3])
  first = items[1]
  second = items[2]
  if first~id \= "W1" then return .Array~of(.false, "implement-shape", .nil)
  if first~kind \= "IMPLEMENT" then return .Array~of(.false, "implement-shape", .nil)
  if first~dependencies~items \= 0 then return .Array~of(.false, "implement-shape", .nil)
  if second~id \= "W2" then return .Array~of(.false, "review-shape", .nil)
  if second~kind \= "REVIEW" then return .Array~of(.false, "review-shape", .nil)
  if second~dependencies~items \= 1 then return .Array~of(.false, "review-dependencies", .nil)
  if second~dependencies[1]~string \= "W1" then return .Array~of(.false, "review-dependency", .nil)
  return .Array~of(.true, "", .DFValidatedPlan~new(expectedProjectId, items, text))
invalid:
  say "Planning session plan JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFPlanningDiagnostic~redacted(condition("D"))
  signal off syntax
  return .Array~of(.false, "invalid-json", .nil)

::method parsePlanItem
  use strict arg row
  if \row~isa(.Directory) then return .Array~of(.false, "item-not-object", .nil)
  if row~items \= 4 then return .Array~of(.false, "item-extra-fields", .nil)
  if row~at("id") == .nil then return .Array~of(.false, "item-required-fields", .nil)
  if row~at("kind") == .nil then return .Array~of(.false, "item-required-fields", .nil)
  if row~at("objective") == .nil then return .Array~of(.false, "item-required-fields", .nil)
  if row~at("depends_on") == .nil then return .Array~of(.false, "item-required-fields", .nil)
  if \row["depends_on"]~isa(.Array) then return .Array~of(.false, "dependencies-not-array", .nil)
  objective = row["objective"]~string~strip
  if objective = "" then return .Array~of(.false, "objective", .nil)
  if objective~length > 512 then return .Array~of(.false, "objective", .nil)
  item = .DFPlanWorkItem~new(row["id"], row["kind"], objective, row["depends_on"])
  return .Array~of(.true, "", item)

::method implementationInstructions
  use strict arg spec
  text = "Implement only the project goal below as one minimal ooRexx file named hello.rex." || "0a"x
  text ||= "Goal: " || spec["goal"]~string || "0a"x
  text ||= "Required stdout: " || spec["expected_stdout"]~string || "0a"x
  text ||= "Acceptance:" || "0a"x
  do item over spec["acceptance"]
    text ||= "- " || item~string || "0a"x
  end
  return text

::method requiredReasoning
  use strict arg spec, implementItem
  text = "WORK ITEM OBJECTIVE:" || "0a"x || implementItem~objective || "0a"x
  text ||= "PROJECT GOAL:" || "0a"x || spec["goal"]~string || "0a"x
  text ||= "REASONING OBLIGATIONS IMPLIED BY ACCEPTANCE:" || "0a"x
  do item over spec["acceptance"]
    text ||= "- " || item~string || "0a"x
  end
  text ||= "The worker's claimed reasoning should materially cover the implementation choices required by these obligations. It need not reveal private chain-of-thought."
  return text

::method reviewPrompt
  use strict arg spec, implementItem, coding
  sourceRead = self~readFile(coding~filePath, .DFPlanningBuild~MAX_SPEC_BYTES * 2)
  if sourceRead[1] then sourceText = sourceRead[3]
  else sourceText = "[SOURCE_UNAVAILABLE " || sourceRead[2] || "]"
  text = "You are Luna acting only as an independent Development Floor reviewer." || "0a"x
  text ||= "Project goal: " || spec["goal"]~string || "0a"x
  text ||= "Implementation objective: " || implementItem~objective || "0a"x
  text ||= "Acceptance criteria:" || "0a"x
  do acceptanceItem over spec["acceptance"]
    text ||= "- " || acceptanceItem~string || "0a"x
  end
  text ||= "Final source under review:" || "0a"x || sourceText || "0a"x
  text ||= "Observed deterministic evidence:" || "0a"x
  text ||= "final_compile_rc=" || coding~finalCompileRc || " final_run_rc=" || coding~finalRunRc || "0a"x
  text ||= "final_stdout=" || coding~finalStdout || "0a"x
  text ||= "source_sha256=" || coding~sourceSha256 || "0a"x
  text ||= 'Return JSON only: {"decision":"ACCEPT"} only if the source AND deterministic evidence satisfy every acceptance criterion.' || "0a"x
  text ||= 'Otherwise return {"decision":"REWORK","reason":"<short bounded reason>"}. No extra fields. No markdown.'
  return text

::method parseReview
  use strict arg text
  if text~length > .DFPlanningBuild~MAX_REVIEW_BYTES then return .Array~of(.false, "too-large", "", "")
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object", "", "")
  decisionValue = data~at("decision")
  if decisionValue == .nil then return .Array~of(.false, "decision-missing", "", "")
  decision = translate(decisionValue~string~strip)
  if decision = "ACCEPT" then do
    if data~items \= 1 then return .Array~of(.false, "accept-extra-fields", "", "")
    return .Array~of(.true, "", decision, "")
  end
  if decision = "REWORK" then do
    if data~items \= 2 then return .Array~of(.false, "rework-fields", "", "")
    reason = data~at("reason")
    if reason == .nil then return .Array~of(.false, "reason-missing", "", "")
    if reason~string~strip = "" then return .Array~of(.false, "reason-empty", "", "")
    return .Array~of(.true, "", decision, reason~string)
  end
  return .Array~of(.false, "decision-unsupported", "", "")
invalid:
  say "Planning session review JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFPlanningDiagnostic~redacted(condition("D"))
  signal off syntax
  return .Array~of(.false, "invalid-json", "", "")

::method recordTokens
  expose manager
  use strict arg assignmentId, inputTokens, outputTokens, externalRef
  if inputTokens > 0 then ignore = manager~recordAssignmentResourceUse(assignmentId, "LLM_INPUT", inputTokens, "INPUT_TOKEN", externalRef, "provider reported input tokens")
  if outputTokens > 0 then ignore = manager~recordAssignmentResourceUse(assignmentId, "LLM_OUTPUT", outputTokens, "OUTPUT_TOKEN", externalRef, "provider reported output tokens")
  return .true

::method ensureDirectory
  use strict arg path
  address command "mkdir -p --" self~shellQuote(path)
  return rc = 0

::method joinPath
  use strict arg root, leaf
  answer = root
  if answer~right(1) \= "/" then answer ||= "/"
  return answer || leaf

::method readFile
  use strict arg path, maxBytes=0
  s = .Stream~new(path)
  if s~query("exists") = "" then return .Array~of(.false, "NOT_FOUND", "")
  opened = s~open("READ")
  if opened \= "READY:" then return .Array~of(.false, opened, "")
  count = s~chars
  if maxBytes > 0 then do
    if count > maxBytes then do
      ignore = s~close
      return .Array~of(.false, "TOO_LARGE", "")
    end
  end
  if count > 0 then text = s~charIn(1, count)
  else text = ""
  ignore = s~close
  return .Array~of(.true, "", text)

::method writeFile
  use strict arg path, text
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if opened \= "READY:" then return .false
  ignore = s~charOut(text)
  ignore = s~close
  return .true

::method shellQuote
  use strict arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "AutonomousCodingWorker.cls"
::requires "DevelopmentFloor.cls"
::requires "AIProviderAccess.cls"
::requires "json.cls"

::requires "ReasoningAlignmentManager.cls"
