/* DevelopmentFloor.cls
   Core deterministic development-floor records and routing rules.

   The Development Manager owns allocation.  Specialists work only within an
   explicit assignment.  Raising a bug records a defect and expressly does not
   grant permission to investigate or repair it.
*/

::class DFRule public
::method init
  expose id scope statement order
  use strict arg id, scope, statement, order=0
  if id~strip = "" then raise syntax 93.900 array("DFRule id must not be empty")
  if scope == .nil then scope = .Directory~new
  self~id = id~strip
  self~scope = scope
  self~statement = statement
  self~order = order
::attribute id
::attribute scope
::attribute statement
::attribute order
::method specificity
  expose scope
  return scope~items
::method matches
  expose scope
  use strict arg context
  do key over scope
    actual = context~at(key)
    if actual == .nil then return .false
    if translate(actual~string) <> translate(scope[key]~string) then return .false
  end
  return .true

::class DFRuleSet public
::method init
  expose rules nextOrder
  rules = .Array~new
  nextOrder = 0
::method add
  expose rules nextOrder
  use strict arg rule
  nextOrder += 1
  rule~order = nextOrder
  rules~append(rule)
  return rule
::method all
  expose rules
  return rules~copy
::method resolve
  expose rules
  use strict arg context
  matches = .Array~new
  maxSpecificity = 0
  do rule over rules
    if rule~matches(context) then do
      matches~append(rule)
      if rule~specificity > maxSpecificity then maxSpecificity = rule~specificity
    end
  end
  ordered = .Array~new
  do s = 0 to maxSpecificity
    do rule over matches
      if rule~specificity = s then ordered~append(rule)
    end
  end
  return ordered

::class DFSpecialistProfile public
::method init
  expose id packageId language domainRules direction metadata
  use strict arg id, packageId="", language=""
  self~id = id
  self~packageId = packageId
  self~language = language
  domainRules = .Array~new
  direction = .Array~new
  metadata = .Directory~new
::attribute id
::attribute packageId
::attribute language
::attribute domainRules get
::attribute direction get
::attribute metadata get
::method addDomainRule
  expose domainRules
  use strict arg ruleText
  domainRules~append(ruleText)
  return self
::method addDirection
  expose direction
  use strict arg item
  direction~append(item)
  return self

::class DFAssignment public
::method init
  expose id project packageId language objective context status specialistId botProfileId executionProviderId wluReservationId wluState
  use strict arg id, project, packageId, language, objective, contextArg=.nil
  if contextArg == .nil then contextArg = .Directory~new
  self~id = id
  self~project = project
  self~packageId = packageId
  self~language = language
  self~objective = objective
  context = contextArg
  status = "ALLOCATED"
  specialistId = ""
  botProfileId = ""
  executionProviderId = ""
  wluReservationId = ""
  wluState = "UNRESERVED"
::attribute id
::attribute project
::attribute packageId
::attribute language
::attribute objective
::attribute context get
::attribute status
::attribute specialistId
::attribute botProfileId
::attribute executionProviderId
::attribute wluReservationId
::attribute wluState
::method assignTo
  use strict arg workerId
  self~specialistId = workerId
  self~status = "ASSIGNED"
  return self
::method bindExecution
  use strict arg botProfileIdArg, executionProviderIdArg
  if self~specialistId = "" then raise syntax 93.900 array("Assignment must have a specialist before execution binding", self~id)
  self~botProfileId = botProfileIdArg
  self~executionProviderId = executionProviderIdArg
  return self
::method bindWLUReservation
  use strict arg reservationId
  if reservationId~string~strip = "" then raise syntax 93.900 array("WLU reservation id must not be empty", self~id)
  self~wluReservationId = reservationId~string
  self~wluState = "RESERVED"
  return self
::method markWLUAdmitted
  if self~wluReservationId = "" then raise syntax 93.900 array("Cannot admit assignment without WLU reservation", self~id)
  self~wluState = "ADMITTED"
  return self
::method clearWLUReservation
  use strict arg finalState="RELEASED"
  self~wluReservationId = ""
  self~wluState = translate(finalState)
  return self

::class DFBugRecord public
::method init
  expose id project packageId assignmentId reporter title observed evidence bugClass status assignedWorker
  use strict arg id, project, packageId, assignmentId, reporter, title, observed, evidence=""
  self~id = id
  self~project = project
  self~packageId = packageId
  self~assignmentId = assignmentId
  self~reporter = reporter
  self~title = title
  self~observed = observed
  self~evidence = evidence
  bugClass = ""
  status = "RAISED"
  assignedWorker = ""
::attribute id
::attribute project
::attribute packageId
::attribute assignmentId
::attribute reporter
::attribute title
::attribute observed
::attribute evidence
::attribute bugClass
::attribute status
::attribute assignedWorker
::method classify
  use strict arg classification
  c = translate(classification~strip)
  select
    when c = "IMPROVEMENT" then nop
    when c = "OPTIMISATION" then nop
    when c = "ERROR CONDITION" then c = "ERROR_CONDITION"
    when c = "ERROR_CONDITION" then nop
    when c = "BLOCKER" then nop
    otherwise raise syntax 93.900 array("Unknown bug class", classification)
  end
  self~bugClass = c
  self~status = "TRIAGED"
  return self
::method assign
  use strict arg workerId
  if self~bugClass = "" then raise syntax 93.900 array("Bug must be classified before assignment", self~id)
  self~assignedWorker = workerId
  self~status = "ASSIGNED"
  return self
::method repairPermitted
  use strict arg workerId
  if self~status <> "ASSIGNED" then return .false
  return self~assignedWorker = workerId

::class DFBugRegister public
::method init
  expose bugs nextId
  bugs = .Directory~new
  nextId = 0
::method raiseBug
  expose bugs nextId
  use strict arg project, packageId, assignmentId, reporter, title, observed, evidence=""
  nextId += 1
  bugId = "BUG-" || nextId~format(5,0)
  bug = .DFBugRecord~new(bugId, project, packageId, assignmentId, reporter, title, observed, evidence)
  bugs[bugId] = bug
  return bug
::method at
  expose bugs
  use strict arg bugId
  return bugs~at(bugId)
::method all
  expose bugs
  return bugs~allItems


::class DFAllocationItem public
::method init
  expose id sourceType sourceId project packageId summary status assignedWorker classification
  use strict arg id, sourceType, sourceId, project, packageId, summary
  self~id = id
  self~sourceType = translate(sourceType)
  self~sourceId = sourceId
  self~project = project
  self~packageId = packageId
  self~summary = summary
  status = "WAITING"
  assignedWorker = ""
  classification = ""
::attribute id
::attribute sourceType
::attribute sourceId
::attribute project
::attribute packageId
::attribute summary
::attribute status
::attribute assignedWorker
::attribute classification
::method assign
  use strict arg workerId, classificationArg=""
  self~assignedWorker = workerId
  self~classification = classificationArg
  self~status = "ASSIGNED"
  return self

::class DFAllocationQueue public
::method init
  expose items nextId
  items = .Array~new
  nextId = 0
::method addBug
  expose items nextId
  use strict arg bug
  nextId += 1
  id = "ALLOC-" || nextId~format(5,0)
  item = .DFAllocationItem~new(id, "BUG", bug~id, bug~project, bug~packageId, bug~title)
  items~append(item)
  return item
::method items
  expose items
  return items~copy
::method waiting
  expose items
  answer = .Array~new
  do item over items
    if item~status = "WAITING" then answer~append(item)
  end
  return answer
::method forSource
  expose items
  use strict arg sourceType, sourceId
  wantedType = translate(sourceType)
  do item over items
    if item~sourceType = wantedType then do
      if item~sourceId = sourceId then return item
    end
  end
  return .nil

::class DFAutoTask public
::method init
  expose id trigger purpose target methodName blocking zeroModelCost
  use strict arg id, trigger, purpose, target=.nil, methodName="", blocking=.true
  self~id = id
  self~trigger = translate(trigger)
  self~purpose = purpose
  self~target = target
  self~methodName = methodName
  self~blocking = blocking
  zeroModelCost = .true
::attribute id
::attribute trigger
::attribute purpose
::attribute target
::attribute methodName
::attribute blocking
::attribute zeroModelCost get
::method run
  expose target methodName
  if target == .nil | methodName = "" then return .DFAutoTaskResult~new(self~id, .true, "NOOP")
  signal on syntax name failed
  taskOutput = target~send(methodName)
  return .DFAutoTaskResult~new(self~id, .true, taskOutput)
failed:
  say "DFAutoTask syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" condition("D")
  return .DFAutoTaskResult~new(self~id, .false, condition("D"))

::class DFAutoTaskResult public
::method init
  expose taskId ok detail
  use strict arg taskId, ok, detail=""
  self~taskId = taskId
  self~ok = ok
  self~detail = detail
::attribute taskId
::attribute ok
::attribute detail

::class DFAutoTaskRegistry public
::method init
  expose tasks
  tasks = .Array~new
::method add
  expose tasks
  use strict arg task
  tasks~append(task)
  return task
::method tasksFor
  expose tasks
  use strict arg trigger
  answer = .Array~new
  wanted = translate(trigger)
  do task over tasks
    if task~trigger = wanted then answer~append(task)
  end
  return answer
::method runTrigger
  use strict arg trigger
  results = .Array~new
  do task over self~tasksFor(trigger)
    results~append(task~run)
  end
  return results

::class DFDocumentationSegment public
::method init
  expose id packageId className methodName sourceRevision state
  use strict arg id, packageId, className, methodName="", sourceRevision=""
  self~id = id
  self~packageId = packageId
  self~className = className
  self~methodName = methodName
  self~sourceRevision = sourceRevision
  state = "PENDING"
::attribute id
::attribute packageId
::attribute className
::attribute methodName
::attribute sourceRevision
::attribute state
::method start
  if self~state <> "PENDING" then raise syntax 93.900 array("Documentation segment is not pending", self~id)
  self~state = "ACTIVE"
  return self
::method complete
  if self~state <> "ACTIVE" then raise syntax 93.900 array("Documentation segment is not active", self~id)
  self~state = "COMPLETE"
  return self

::class DFDevelopmentManager public
::method init
  expose rules bugs assignments specialists autoTasks allocationQueue registrationCatalog workControl
  rules = .DFRuleSet~new
  bugs = .DFBugRegister~new
  assignments = .Directory~new
  specialists = .Directory~new
  autoTasks = .DFAutoTaskRegistry~new
  allocationQueue = .DFAllocationQueue~new
  registrationCatalog = .DFRegistrationCatalog~new
  workControl = .nil
::attribute rules get
::attribute bugs get
::attribute assignments get
::attribute specialists get
::attribute autoTasks get
::attribute allocationQueue get
::attribute registrationCatalog get
::attribute workControl get
::method loadRegistrations
  expose registrationCatalog
  use strict arg path
  registrationCatalog = .DFRegistrationCatalog~fromJsonFile(path)
  return registrationCatalog
::method bindWorkControl
  expose workControl
  use strict arg control
  if control == .nil then raise syntax 93.900 array("Work control must not be nil")
  workControl = control
  return workControl
::method reserveAssignmentWork
  expose assignments workControl
  use strict arg assignmentId, expectedMicroWlu, ceilingMicroWlu, targetSeconds=0, ttlSeconds=30, requestId=""
  if workControl == .nil then raise syntax 93.900 array("WLU work control is not bound")
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  return workControl~reserveAssignment(assignment, expectedMicroWlu, ceilingMicroWlu, targetSeconds, ttlSeconds, requestId)
::method admitAssignmentWork
  expose assignments workControl
  use strict arg assignmentId
  if workControl == .nil then raise syntax 93.900 array("WLU work control is not bound")
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  workReply = workControl~admitAssignment(assignment)
  if workReply~ok then assignment~status = "ACTIVE"
  return workReply
::method requireAssignmentWorkAdmission
  expose assignments workControl
  use strict arg assignmentId
  if workControl == .nil then raise syntax 93.900 array("WLU work control is not bound")
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  return workControl~requireAdmitted(assignment)
::method consumeAssignmentWork
  expose assignments workControl
  use strict arg assignmentId, microWlu, operationId=""
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  return workControl~consumeAssignment(assignment, microWlu, operationId)
::method settleAssignmentWork
  expose assignments workControl
  use strict arg assignmentId, actualMicroWlu=.nil
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  workReply = workControl~settleAssignment(assignment, actualMicroWlu)
  if workReply~ok then assignment~status = "COMPLETE"
  return workReply
::method releaseAssignmentWork
  expose assignments workControl
  use strict arg assignmentId
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  workReply = workControl~releaseAssignment(assignment)
  if workReply~ok then assignment~status = "WAITING"
  return workReply
::method recordAssignmentResourceUse
  expose assignments workControl
  use strict arg assignmentId, resourceKind, quantity, unit, externalRef="", detail=""
  if workControl == .nil then raise syntax 93.900 array("WLU work control is not bound")
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  return workControl~recordResourceUse(assignment, resourceKind, quantity, unit, externalRef, detail)

::method registerSpecialist
  expose specialists
  use strict arg specialist
  specialists[specialist~id] = specialist
  return specialist
::method importQualifiedSpecialists
  expose specialists
  use strict arg registry
  imported = 0
  do specialist over registry~all
    key = specialist~id
    if specialists~at(key) == .nil then do
      specialists[key] = specialist
      imported += 1
    end
  end
  return imported
::method addAssignment
  expose assignments
  use strict arg assignment
  assignments[assignment~id] = assignment
  return assignment
::method bindAssignmentExecution
  expose assignments registrationCatalog
  use strict arg assignmentId, botProfileId, executionProviderId
  assignment = assignments~at(assignmentId)
  if assignment == .nil then raise syntax 93.900 array("Unknown assignment", assignmentId)
  if registrationCatalog~bots~at(botProfileId) == .nil then raise syntax 93.900 array("Unknown bot profile", botProfileId)
  if registrationCatalog~executionProviders~at(executionProviderId) == .nil then raise syntax 93.900 array("Unknown execution provider", executionProviderId)
  assignment~bindExecution(botProfileId, executionProviderId)
  return assignment
::method selectQualificationHost
  expose registrationCatalog
  use strict arg hostId
  host = registrationCatalog~hosts~qualificationTarget(hostId)
  if host == .nil then raise syntax 93.900 array("Host is not eligible for explicit qualification override", hostId)
  return host
::method selectApplianceProfile
  expose registrationCatalog
  use strict arg targetKind, requestedId=""
  if requestedId <> "" then do
    profile = registrationCatalog~applianceProfiles~at(requestedId)
    if profile == .nil then raise syntax 93.900 array("Unknown appliance profile", requestedId)
    if profile~targetKind <> translate(targetKind) then raise syntax 93.900 array("Appliance profile target mismatch", requestedId, targetKind)
    return profile
  end
  profile = registrationCatalog~applianceProfiles~qualifiedDefault(targetKind)
  if profile == .nil then raise syntax 93.900 array("No qualified default appliance profile", targetKind)
  return profile

::method effectiveRules
  expose rules
  use strict arg assignment
  context = .Directory~new
  do key over assignment~context
    context[key] = assignment~context[key]
  end
  context["PROJECT"] = assignment~project
  context["PACKAGE"] = assignment~packageId
  context["LANGUAGE"] = assignment~language
  return rules~resolve(context)
::method raiseBug
  expose bugs allocationQueue
  use strict arg assignment, reporter, title, observed, evidence=""
  bug = bugs~raiseBug(assignment~project, assignment~packageId, assignment~id, reporter, title, observed, evidence)
  ignore = allocationQueue~addBug(bug)
  return bug
::method allocateBug
  expose bugs specialists allocationQueue
  use strict arg bugId, classification, specialistId
  bug = bugs~at(bugId)
  if bug == .nil then raise syntax 93.900 array("Unknown bug", bugId)
  if specialists~at(specialistId) == .nil then raise syntax 93.900 array("Unknown specialist", specialistId)
  bug~classify(classification)
  bug~assign(specialistId)
  item = allocationQueue~forSource("BUG", bugId)
  if item <> .nil then item~assign(specialistId, bug~bugClass)
  return bug

::requires "WorkAccounting.cls"
::requires "Registrations.cls"
