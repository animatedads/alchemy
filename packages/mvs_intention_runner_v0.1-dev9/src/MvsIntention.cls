/* MvsIntention.cls
 * Discovery-first MVS intention runner core.
 * dev2 composes independent MVS Alchemy, Terminal Machine and Hercules evidence.
 *
 * The caller supplies plain English.  The runner refreshes safe, read-only
 * evidence before IntentionService is asked to resolve meaning.  The model is
 * never expected to manufacture MVS command syntax or retain operational IDs.
 */

::class MvsProbeRecord public
::method init
  expose sequence name safe detail
  use arg sequence, name, safe = .true, detail = ""
::attribute sequence get
::attribute name get
::attribute safe get
::attribute detail get

::class MvsJobObservation public
::method init
  expose jobId name owner kind state completion endedAt spool sourceDataset
  use arg jobId, name, owner, kind, state, completion, endedAt, spool = .true, sourceDataset = ""
  jobId = translate(strip(jobId))
  name = translate(strip(name))
  owner = translate(strip(owner))
  kind = translate(strip(kind))
  state = translate(strip(state))
  completion = translate(strip(completion))
  endedAt = strip(endedAt)
  sourceDataset = translate(strip(sourceDataset))
::attribute jobId get
::attribute name get
::attribute owner get
::attribute kind get
::attribute state get
::attribute completion get
::attribute endedAt get
::attribute spool get
::attribute sourceDataset get

::class MvsDatasetObservation public
::method init
  expose name kind writable
  use arg name, kind = "UNKNOWN", writable = .false
  name = translate(strip(name))
  kind = translate(strip(kind))
::attribute name get
::attribute kind get
::attribute writable get

::class MvsDiscoverySnapshot public
::method init
  expose target systemName osName tsoUser jesState terminalState subsystemState jobs datasets capabilities probeTrace sourceFacts
  use arg target = ""
  target = translate(strip(target))
  systemName = ""
  osName = ""
  tsoUser = ""
  jesState = "UNKNOWN"
  terminalState = "UNKNOWN"
  subsystemState = .Directory~new
  jobs = .Array~new
  datasets = .Array~new
  capabilities = .Directory~new
  probeTrace = .Array~new
  sourceFacts = .Array~new
::attribute target get
::attribute systemName
::attribute osName
::attribute tsoUser
::attribute jesState
::attribute terminalState
::method subsystem
  expose subsystemState
  use arg name, value
  key = translate(strip(name))
  if arg(2, "O") = 0 then do
    subsystemState~put(translate(strip(value)), key)
    return self
  end
  if subsystemState~hasIndex(key) = 0 then return "UNKNOWN"
  return subsystemState~at(key)
::method addJob
  expose jobs
  use arg job
  jobs~append(job)
  return self
::method jobs
  expose jobs
  return jobs~copy
::method addDataset
  expose datasets
  use arg dataset
  datasets~append(dataset)
  return self
::method datasets
  expose datasets
  return datasets~copy
::method capability
  expose capabilities
  use arg name, value
  key = translate(strip(name))
  if arg(2, "O") = 0 then do
    capabilities~put(translate(strip(value)), key)
    return self
  end
  if capabilities~hasIndex(key) = 0 then return "UNKNOWN"
  return capabilities~at(key)
::method addProbe
  expose probeTrace
  use arg record
  probeTrace~append(record)
  return self
::method probeTrace
  expose probeTrace
  return probeTrace~copy
::method probeCount
  expose probeTrace
  return probeTrace~items
::method addSourceFact
  expose sourceFacts
  use arg fact
  sourceFacts~append(fact)
  return self
::method sourceFacts
  expose sourceFacts
  return sourceFacts~copy
::method factsBySource
  expose sourceFacts
  use arg source
  wanted = translate(strip(source))
  out = .Array~new
  do fact over sourceFacts
    if fact~source == wanted then out~append(fact)
  end
  return out



/* A source fact is deliberately more general than the projected snapshot.  It
 * retains independent authority/provenance so contradictory observations are
 * evidence, not values to be silently collapsed. */
::class MvsSourceFact public
::method init
  expose source subject predicate value quality evidence
  use arg source, subject, predicate, value, quality = 100, evidence = ""
  source = translate(strip(source))
  subject = translate(strip(subject))
  predicate = translate(strip(predicate))
  value = strip(value)
  evidence = strip(evidence)
::attribute source get
::attribute subject get
::attribute predicate get
::attribute value get
::attribute quality get
::attribute evidence get

::class MvsSourceResult public
::method init
  expose source facts probes available detail
  use arg source
  source = translate(strip(source))
  facts = .Array~new
  probes = .Array~new
  available = .true
  detail = ""
::attribute source get
::attribute available
::attribute detail
::method addFact
  expose facts
  use arg fact
  facts~append(fact)
  return self
::method facts
  expose facts
  return facts~copy
::method addProbe
  expose probes
  use arg record
  probes~append(record)
  return self
::method probes
  expose probes
  return probes~copy

/* Controller-owned adapter over an actual discovery source.  The delegate is
 * expected to implement discover(target) and return MvsSourceResult. */
::class MvsDiscoverySource public
::method init
  expose source delegate
  use arg source, delegate
  source = translate(strip(source))
::attribute source get
::method discover
  expose source delegate
  use arg target
  if delegate == .nil then do
    r = .MvsSourceResult~new(source)
    r~available = .false
    r~detail = "NO_DELEGATE"
    r~addProbe(.MvsProbeRecord~new(1, source || "_UNAVAILABLE", .true, "No discovery delegate configured"))
    return r
  end
  return delegate~discover(target)

/* The composer performs all safe source discovery before the intention service
 * sees the utterance.  Projection rules are authority-specific: MVS Alchemy
 * owns guest/JES/dataset semantics, Terminal Machine owns 3270 observations,
 * and Hercules owns emulator/control-plane observations. */
::class MvsDiscoveryComposer public
::method init
  expose sources
  sources = .Array~new
::method addSource
  expose sources
  use arg source
  sources~append(source)
  return self
::method discover
  expose sources
  use arg target
  snapshot = .MvsDiscoverySnapshot~new(target)
  sequence = 0
  do source over sources
    sourceResult = source~discover(target)
    do probe over sourceResult~probes
      sequence += 1
      snapshot~addProbe(.MvsProbeRecord~new(sequence, probe~name, probe~safe, source~source || ": " || probe~detail))
    end
    if sourceResult~available then do fact over sourceResult~facts
      snapshot~addSourceFact(fact)
      self~project(snapshot, fact)
    end
    else do
      snapshot~addSourceFact(.MvsSourceFact~new(source~source, "SOURCE", "AVAILABLE", "FALSE", 100, sourceResult~detail))
    end
  end
  return snapshot
::method project
  use arg snapshot, fact
  source = fact~source
  subject = fact~subject
  predicate = fact~predicate
  value = fact~value

  if source == "MVS_ALCHEMY" then do
    if subject == "SYSTEM" then do
      if predicate == "NAME" then snapshot~systemName = translate(value)
      else if predicate == "OS" then snapshot~osName = value
    end
    else if subject == "TSO" then do
      if predicate == "USER" then snapshot~tsoUser = translate(value)
    end
    else if subject == "JES" then do
      if predicate == "STATE" then snapshot~jesState = translate(value)
    end
    else if left(subject, 4) == "JOB." then do
      if predicate == "ROW" then self~projectJob(snapshot, value)
    end
    else if left(subject, 8) == "DATASET." then do
      if predicate == "ROW" then self~projectDataset(snapshot, value)
    end
  end
  else if source == "TERMINAL_MACHINE" then do
    if subject == "SESSION" then do
      if predicate == "STATE" then snapshot~terminalState = translate(value)
      else if predicate == "AUTHENTICATED" then snapshot~capability("TERMINAL_MACHINE_AUTHENTICATED", value)
      else if predicate == "TARGET" then snapshot~capability("TERMINAL_MACHINE_TARGET", value)
      else if predicate == "HOST" then snapshot~capability("TERMINAL_MACHINE_HOST", value)
      else if predicate == "REQUESTED_LU" then snapshot~capability("TERMINAL_MACHINE_LU", value)
      else if predicate == "DEVICE_NAME" then snapshot~capability("TERMINAL_MACHINE_DEVICE_NAME", value)
      else if predicate == "MODE" then snapshot~capability("TERMINAL_MACHINE_MODE", value)
    end
    else if subject == "SCREEN" then do
      if predicate == "CLASS" then snapshot~capability("TERMINAL_MACHINE_SCREEN", value)
      else if predicate == "ROWS" then snapshot~capability("TERMINAL_MACHINE_ROWS", value)
      else if predicate == "COLUMNS" then snapshot~capability("TERMINAL_MACHINE_COLUMNS", value)
      else if predicate == "GENERATION" then snapshot~capability("TERMINAL_MACHINE_GENERATION", value)
    end
    else if subject == "CURSOR" then do
      if predicate == "ROW" then snapshot~capability("TERMINAL_MACHINE_CURSOR_ROW", value)
      else if predicate == "COLUMN" then snapshot~capability("TERMINAL_MACHINE_CURSOR_COLUMN", value)
    end
    else if subject == "KEYBOARD" then do
      if predicate == "STATE" then snapshot~capability("TERMINAL_MACHINE_KEYBOARD", value)
    end
    else if subject == "TSO" then do
      if predicate == "USER" then do
        if snapshot~tsoUser == "" then snapshot~tsoUser = translate(value)
      end
    end
  end
  else if source == "HERCULES_SERVICES" then do
    if subject == "GUEST" then do
      if predicate == "STATE" then snapshot~capability("HERCULES_GUEST_STATE", value)
    end
    else if subject == "CONTROL" then do
      if predicate == "STATE" then snapshot~capability("HERCULES_CONTROL_STATE", value)
    end
  end
  else if source == "REFERENCE_TSO_X3270" then do
    /* Authenticated qualification oracle. It may project only facts directly
     * observed from the guest TSO session. It never becomes MVS_ALCHEMY or
     * TERMINAL_MACHINE authority. */
    if subject == "TSO" then do
      if predicate == "USER" then do
        if snapshot~tsoUser == "" then snapshot~tsoUser = translate(value)
      end
      else if predicate == "READY" then snapshot~capability("REFERENCE_TSO_READY", value)
    end
    else if subject == "SESSION" then do
      if predicate == "AUTHENTICATED" then snapshot~capability("REFERENCE_TSO_AUTHENTICATED", value)
      else if predicate == "TARGET" then snapshot~capability("REFERENCE_TSO_TARGET", value)
      else if predicate == "HOST" then snapshot~capability("REFERENCE_TSO_HOST", value)
      else if predicate == "LU" then snapshot~capability("REFERENCE_TSO_LU", value)
    end
    else if left(subject, 8) == "DATASET." then do
      if predicate == "ROW" then self~projectDataset(snapshot, value)
    end
  end
  else if source == "REFERENCE_X3270" then do
    /* Qualification oracle only.  Never relabel this evidence as
     * TERMINAL_MACHINE.  It may fill otherwise-unknown terminal scope while
     * the real Terminal Machine provider is absent. */
    if subject == "SESSION" then do
      if predicate == "STATE" then do
        snapshot~capability("REFERENCE_X3270_SESSION", value)
        if snapshot~terminalState == "UNKNOWN" then snapshot~terminalState = translate(value)
      end
      else if predicate == "MODEL" then snapshot~capability("REFERENCE_X3270_MODEL", value)
      else if predicate == "NATIVE_STATUS" then snapshot~capability("REFERENCE_X3270_NATIVE_STATUS", value)
    end
    else if subject == "SCREEN" then do
      if predicate == "CLASS" then do
        snapshot~capability("REFERENCE_X3270_SCREEN", value)
        if snapshot~terminalState == "UNKNOWN" then snapshot~terminalState = translate(value)
        else if translate(value) == "TSO_LOGON" then snapshot~terminalState = "TSO_LOGON"
      end
      else if predicate == "ROWS" then snapshot~capability("REFERENCE_X3270_ROWS", value)
      else if predicate == "COLUMNS" then snapshot~capability("REFERENCE_X3270_COLUMNS", value)
    end
    else if subject == "CURSOR" then do
      if predicate == "ROW" then snapshot~capability("REFERENCE_X3270_CURSOR_ROW", value)
      else if predicate == "COLUMN" then snapshot~capability("REFERENCE_X3270_CURSOR_COLUMN", value)
    end
  end
  return self
::method projectJob
  use arg snapshot, row
  /* JOB_ID|NAME|OWNER|KIND|STATE|COMPLETION|ENDED_AT|SOURCE_DATASET */
  parse var row jobId "|" name "|" owner "|" kind "|" state "|" completion "|" endedAt "|" sourceDataset
  if strip(jobId) == "" then return self
  snapshot~addJob(.MvsJobObservation~new(jobId, name, owner, kind, state, completion, endedAt, .true, sourceDataset))
  return self
::method projectDataset
  use arg snapshot, row
  /* NAME|KIND|WRITABLE */
  parse var row name "|" kind "|" writable
  if strip(name) == "" then return self
  canWrite = .false
  if translate(strip(writable)) == "TRUE" then canWrite = .true
  snapshot~addDataset(.MvsDatasetObservation~new(name, kind, canWrite))
  return self


/* Qualification backend.  A real adapter can implement the same discover()
 * contract using Terminal Machine, MVS Alchemy and Hercules Services. */
::class MvsFixtureDiscoveryBackend public
::method init
  expose generation
  use arg generation = 1
::attribute generation
::method discover
  expose generation
  use arg target
  snapshot = .MvsDiscoverySnapshot~new(target)
  call probe snapshot, "SYSTEM_IDENTITY", "Read guest/system identity"
  snapshot~systemName = translate(strip(target))
  snapshot~osName = "MVS 3.8J TK5"
  call probe snapshot, "TERMINAL_STATE", "Observe current 3270 terminal state"
  snapshot~terminalState = "TSO_READY"
  call probe snapshot, "TSO_IDENTITY", "Observe logged-on TSO identity"
  snapshot~tsoUser = "HERC01"
  call probe snapshot, "JES_STATE", "Observe JES availability"
  snapshot~jesState = "READY"
  call probe snapshot, "JOB_CATALOG", "Read bounded JES job catalogue"
  call probe snapshot, "JOB_OWNERS", "Read owners for discovered jobs"
  call probe snapshot, "JOB_COMPLETION", "Read completion state for discovered jobs"
  call probe snapshot, "JOB_TIMES", "Read end/submission ordering evidence"
  call probe snapshot, "JOB_TYPES", "Classify compile/run jobs from observed evidence"
  call probe snapshot, "SPOOL_INDEX", "Read spool DD inventory only"
  call probe snapshot, "DATASET_CATALOG", "Read bounded dataset catalogue"
  call probe snapshot, "DATASET_METADATA", "Read DSORG/shape metadata"
  call probe snapshot, "PDS_MEMBER_INDEX", "Read bounded member names"
  call probe snapshot, "SUBSYSTEM_STATE", "Observe VTAM/TCAS/JES state"
  call probe snapshot, "CONSOLE_STATE", "Observe console reachability"
  call probe snapshot, "CAPABILITY_CATALOG", "Discover read-only semantic capabilities"
  call probe snapshot, "SESSION_SELECTION", "Observe current selected/referent objects"

  snapshot~subsystem("VTAM", "ACTIVE")
  snapshot~subsystem("TCAS", "ACCEPTING_LOGONS")
  snapshot~capability("SYSTEM_IDENTITY", "TRUE")
  snapshot~capability("JES_LIST", "TRUE")
  snapshot~capability("JES_SPOOL_READ", "TRUE")
  snapshot~capability("DATASET_LIST", "TRUE")
  snapshot~capability("DATASET_READ", "TRUE")

  snapshot~addJob(.MvsJobObservation~new("JOB00137", "COBTEST", "FRED", "COMPILE", "ENDED", "CC 0008", "2026-10-06T07:51:00", .true, "FRED.COBOL(TEST1)"))
  snapshot~addJob(.MvsJobObservation~new("JOB00140", "PAYCOMP", "FRED", "COMPILE", "ENDED", "CC 0012", "2026-10-06T08:12:00", .true, "FRED.COBOL(PAYROLL)"))
  snapshot~addJob(.MvsJobObservation~new("JOB00141", "PAYRUN", "FRED", "RUN", "ENDED", "ABEND S0C7", "2026-10-06T08:18:00", .true, "FRED.CNTL(PAYRUN)"))
  snapshot~addJob(.MvsJobObservation~new("JOB00139", "ACCTCMP", "ALICE", "COMPILE", "ENDED", "CC 0000", "2026-10-06T08:02:00", .true, "ALICE.COBOL(ACCT)"))
  if generation >= 2 then snapshot~addJob(.MvsJobObservation~new("JOB00144", "NEWWORK", "FRED", "COMPILE", "ENDED", "CC 0016", "2026-10-06T09:04:00", .true, "FRED.COBOL(NEWWORK)"))

  snapshot~addDataset(.MvsDatasetObservation~new("FRED.COBOL", "PDS", .true))
  snapshot~addDataset(.MvsDatasetObservation~new("FRED.CNTL", "PDS", .true))
  snapshot~addDataset(.MvsDatasetObservation~new("SYS1.PARMLIB", "PDS", .false))
  return snapshot
probe: procedure
  use arg snapshot, name, detail
  snapshot~addProbe(.MvsProbeRecord~new(snapshot~probeCount + 1, name, .true, detail))
return

::class MvsDiscoveryPublisher public
::method publish
  use arg service, snapshot
  service~clearEvidenceFacts
  service~addEvidenceFact(.IntentionEvidenceFact~new("MVS", "TARGET", snapshot~target, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:target"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("MVS", "SYSTEM_NAME", snapshot~systemName, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:system"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("MVS", "OS", snapshot~osName, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:os"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("MVS", "TSO_USER", snapshot~tsoUser, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:tso"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("JES", "STATE", snapshot~jesState, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:jes"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("TERMINAL", "STATE", snapshot~terminalState, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:terminal"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("VTAM", "STATE", snapshot~subsystem("VTAM"), 100, "MVS_DISCOVERY", "OBSERVED", "mvs:vtam"))
  service~addEvidenceFact(.IntentionEvidenceFact~new("TCAS", "STATE", snapshot~subsystem("TCAS"), 100, "MVS_DISCOVERY", "OBSERVED", "mvs:tcas"))
  do job over snapshot~jobs
    subject = "JOB." || job~jobId
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "EXISTS", "TRUE", 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "NAME", job~name, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "OWNER", job~owner, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "KIND", job~kind, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "STATE", job~state, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "COMPLETION", job~completion, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "ENDED_AT", job~endedAt, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "SOURCE_DATASET", job~sourceDataset, 100, "JES_DISCOVERY", "OBSERVED", "jes:" || job~jobId))
  end
  do ds over snapshot~datasets
    subject = "DATASET." || ds~name
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "EXISTS", "TRUE", 100, "DATASET_DISCOVERY", "OBSERVED", "dataset:" || ds~name))
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "KIND", ds~kind, 100, "DATASET_DISCOVERY", "OBSERVED", "dataset:" || ds~name))
    writable = "FALSE"
    if ds~writable then writable = "TRUE"
    service~addEvidenceFact(.IntentionEvidenceFact~new(subject, "WRITABLE", writable, 100, "DATASET_DISCOVERY", "OBSERVED", "dataset:" || ds~name))
  end
  do fact over snapshot~sourceFacts
    service~addEvidenceFact(.IntentionEvidenceFact~new(fact~subject, fact~predicate, fact~value, fact~quality, fact~source, "OBSERVED", fact~evidence))
  end
  service~addEvidenceFact(.IntentionEvidenceFact~new("MVS_DISCOVERY", "SAFE_PROBE_COUNT", snapshot~probeCount, 100, "MVS_DISCOVERY", "OBSERVED", "mvs:probe-trace"))
  return service

::class MvsPurposeInterrogator public
::method init
  expose snapshot
  use arg snapshot = .nil
::method snapshot
  expose snapshot
  use arg value
  if arg(1, "O") = 0 then do; snapshot = value; return self; end
  return snapshot
::method name
  return "MVS_INTERROGATOR"
::method propose
  expose snapshot
  use arg service, text
  out = .Array~new
  if snapshot == .nil then return out
  t = translate(strip(text))
  if t == "" then return out

  if self~hasAny(t, "WHAT CAN I DO|WHAT IS HERE|DISCOVER MVS|SHOW SCOPE|WHAT CAN I SEE") then do
    out~append(.IntentionProposal~new("DISCOVER_SCOPE", 98, self~name, .true, "live MVS discovery catalogue"))
    return out
  end
  if self~hasAny(t, "WHAT SYSTEM|WHICH SYSTEM|WHO AM I|SYSTEM AM I ON|IDENTIFY SYSTEM") then do
    if strip(snapshot~systemName) == "" then return out
    if strip(snapshot~osName) == "" then return out
    out~append(.IntentionProposal~new("SYSTEM_IDENTITY", 98, self~name, .true, "observed system identity"))
    return out
  end
  if self~hasAny(t, "LIST JOBS|SHOW JOBS|WHAT JOBS|JES JOBS") then do
    if translate(strip(snapshot~jesState)) == "UNKNOWN" then return out
    out~append(.IntentionProposal~new("LIST_JOBS", 96, self~name, .true, "observed JES catalogue"))
    return out
  end
  if self~hasAny(t, "LIST DATASETS|SHOW DATASETS|MY DATASETS|WHAT DATASETS") then do
    if snapshot~datasets~items == 0 then return out
    out~append(.IntentionProposal~new("LIST_DATASETS", 96, self~name, .true, "observed dataset catalogue"))
    return out
  end
  if self~hasAny(t, "FAILED|FAIL|COMPILE") then do
    job = self~latestFailedCompile(t)
    if job \== .nil then do
      p = .IntentionProposal~new("FIND_LAST_FAILED_COMPILE", 99, self~name, .true, "selected from live JES observations")
      p~putSlot("JOB_ID", job~jobId, .false)
      p~putSlot("JOB_NAME", job~name, .false)
      p~putSlot("OWNER", job~owner, .false)
      p~putSlot("COMPLETION", job~completion, .false)
      p~putSlot("SOURCE_DATASET", job~sourceDataset, .false)
      out~append(p)
      return out
    end
  end
  return out
::method latestFailedCompile
  expose snapshot
  use arg text
  wantedOwner = ""
  do job over snapshot~jobs
    if pos(job~owner, text) > 0 then do; wantedOwner = job~owner; leave; end
  end
  best = .nil
  do job over snapshot~jobs
    if job~kind \== "COMPILE" then iterate
    if wantedOwner \== "" then if job~owner \== wantedOwner then iterate
    if job~completion == "CC 0000" then iterate
    if best == .nil then best = job
    else if job~endedAt > best~endedAt then best = job
  end
  return best
::method hasAny
  use arg text, terms
  /* Deliberately tiny phrase recognizer for the first qualified slice. */
  if pos("WHAT CAN I DO", text) > 0 then if pos("WHAT CAN I DO", terms) > 0 then return .true
  if pos("WHAT IS HERE", text) > 0 then if pos("WHAT IS HERE", terms) > 0 then return .true
  if pos("DISCOVER MVS", text) > 0 then if pos("DISCOVER MVS", terms) > 0 then return .true
  if pos("SHOW SCOPE", text) > 0 then if pos("SHOW SCOPE", terms) > 0 then return .true
  if pos("WHAT CAN I SEE", text) > 0 then if pos("WHAT CAN I SEE", terms) > 0 then return .true
  if pos("WHAT SYSTEM", text) > 0 then if pos("WHAT SYSTEM", terms) > 0 then return .true
  if pos("WHICH SYSTEM", text) > 0 then if pos("WHICH SYSTEM", terms) > 0 then return .true
  if pos("WHO AM I", text) > 0 then if pos("WHO AM I", terms) > 0 then return .true
  if pos("SYSTEM AM I ON", text) > 0 then if pos("SYSTEM AM I ON", terms) > 0 then return .true
  if pos("IDENTIFY SYSTEM", text) > 0 then if pos("IDENTIFY SYSTEM", terms) > 0 then return .true
  if pos("LIST JOBS", text) > 0 then if pos("LIST JOBS", terms) > 0 then return .true
  if pos("SHOW JOBS", text) > 0 then if pos("SHOW JOBS", terms) > 0 then return .true
  if pos("WHAT JOBS", text) > 0 then if pos("WHAT JOBS", terms) > 0 then return .true
  if pos("JES JOBS", text) > 0 then if pos("JES JOBS", terms) > 0 then return .true
  if pos("LIST DATASETS", text) > 0 then if pos("LIST DATASETS", terms) > 0 then return .true
  if pos("SHOW DATASETS", text) > 0 then if pos("SHOW DATASETS", terms) > 0 then return .true
  if pos("MY DATASETS", text) > 0 then if pos("MY DATASETS", terms) > 0 then return .true
  if pos("WHAT DATASETS", text) > 0 then if pos("WHAT DATASETS", terms) > 0 then return .true
  if pos("FAILED", text) > 0 then if pos("FAILED", terms) > 0 then return .true
  if pos("FAIL", text) > 0 then if pos("FAIL", terms) > 0 then return .true
  if pos("COMPILE", text) > 0 then if pos("COMPILE", terms) > 0 then return .true
  return .false

::class MvsPlanBuilder public
::method build
  use arg service, registration, proposal
  id = registration~id
  plan = .IntentionPlan~new(id, "Resolve from current read-only MVS observations")
  plan~sideEffectClass = "READ_ONLY"
  select
    when id == "SYSTEM_IDENTITY" then plan~addStep("OBSERVE", "Return current system identity", "MVS")
    when id == "LIST_JOBS" then plan~addStep("OBSERVE", "Return current JES job catalogue", "JES")
    when id == "LIST_DATASETS" then plan~addStep("OBSERVE", "Return current dataset catalogue", "DATASETS")
    when id == "DISCOVER_SCOPE" then plan~addStep("OBSERVE", "Return discovered MVS scope", "MVS")
    when id == "FIND_LAST_FAILED_COMPILE" then do
      plan~addStep("FILTER", "Filter observed compile jobs by owner/failure", "JES")
      plan~addStep("ORDER", "Choose latest observed matching job", "ENDED_AT")
      plan~addStep("OBSERVE", "Return job and source evidence", "JES")
    end
    otherwise nop
  end
  return plan

::class MvsIntentionRunner public
::method init
  expose target backend service discovery publisher interrogator snapshot planBuilder
  use arg target = "ED209Z", backend = .nil
  target = translate(strip(target))
  if backend == .nil then backend = .MvsFixtureDiscoveryBackend~new
  service = .IntentionService~new
  service~registerBucket("MVS_READ", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
  planBuilder = .MvsPlanBuilder~new
  self~registerRead(service, planBuilder, "DISCOVER_SCOPE")
  self~registerRead(service, planBuilder, "SYSTEM_IDENTITY")
  self~registerRead(service, planBuilder, "LIST_JOBS")
  self~registerRead(service, planBuilder, "LIST_DATASETS")
  self~registerRead(service, planBuilder, "FIND_LAST_FAILED_COMPILE")
  interrogator = .MvsPurposeInterrogator~new
  service~registerProvider(interrogator)
  discovery = backend
  publisher = .MvsDiscoveryPublisher~new
  snapshot = .nil
::method refresh
  expose target discovery publisher interrogator snapshot service
  snapshot = discovery~discover(target)
  publisher~publish(service, snapshot)
  interrogator~snapshot(snapshot)
  return snapshot
::method input
  expose service
  use arg text
  self~refresh
  return service~input(text)
::method snapshot
  expose snapshot
  return snapshot
::method service
  expose service
  return service
::method backend
  expose discovery
  return discovery
::method render
  expose snapshot
  use arg decision
  if decision~status \== "READY" then return decision~question
  id = decision~registration~id
  select
    when id == "SYSTEM_IDENTITY" then return snapshot~systemName || " | " || snapshot~osName || " | TSO=" || snapshot~tsoUser
    when id == "DISCOVER_SCOPE" then do
      text = "jobs=" || snapshot~jobs~items || " datasets=" || snapshot~datasets~items || " JES=" || snapshot~jesState || " terminal=" || snapshot~terminalState
      model = snapshot~capability("REFERENCE_X3270_MODEL")
      rows = snapshot~capability("REFERENCE_X3270_ROWS")
      cols = snapshot~capability("REFERENCE_X3270_COLUMNS")
      if model \== "UNKNOWN" then text ||= " model=" || model
      if rows \== "UNKNOWN" then do
        if cols \== "UNKNOWN" then text ||= " screen=" || rows || "x" || cols
      end
      return text
    end
    when id == "LIST_JOBS" then do
      text = ""
      do job over snapshot~jobs
        if text \== "" then text = text || .endOfLine
        text = text || job~jobId || " | " || job~name || " | " || job~owner || " | " || job~completion
      end
      return text
    end
    when id == "LIST_DATASETS" then do
      text = ""
      do ds over snapshot~datasets
        if text \== "" then text = text || .endOfLine
        text = text || ds~name || " | " || ds~kind
      end
      return text
    end
    when id == "FIND_LAST_FAILED_COMPILE" then do
      jobId = decision~proposal~slot("JOB_ID")~value
      do job over snapshot~jobs
        if job~jobId == jobId then return job~jobId || " | " || job~name || " | " || job~owner || " | " || job~completion || " | " || job~sourceDataset
      end
      return "discovered job no longer present"
    end
    otherwise return ""
  end
::method registerRead
  use arg service, planBuilder, id
  r = service~register(id, .nil, "MVS_READ")
  r~planBuilder(planBuilder)
  return self

::requires "IntentionService.cls"

/* Canonical controller feed.  Real provider adapters may write this tiny TSV
 * protocol without exposing their native commands to the LLM:
 *   PROBE<TAB>name<TAB>detail
 *   FACT<TAB>subject<TAB>predicate<TAB>value<TAB>quality<TAB>evidence
 */
::class MvsTsvDiscoveryDelegate public
::method init
  expose source path
  use arg source, path
  source = translate(strip(source))
  path = strip(path)
::method discover
  expose source path
  use arg target
  sourceResult = .MvsSourceResult~new(source)
  if stream(path, "c", "query exists") == "" then do
    sourceResult~available = .false
    sourceResult~detail = "FEED_NOT_FOUND:" || path
    sourceResult~addProbe(.MvsProbeRecord~new(1, "FEED_NOT_FOUND", .true, path))
    return sourceResult
  end
  seq = 0
  do while lines(path) > 0
    line = linein(path)
    if strip(line) == "" then iterate
    parse var line kind "09"x rest
    kind = translate(strip(kind))
    if kind == "PROBE" then do
      parse var rest name "09"x detail
      seq += 1
      sourceResult~addProbe(.MvsProbeRecord~new(seq, strip(name), .true, strip(detail)))
    end
    else if kind == "FACT" then do
      parse var rest subject "09"x predicate "09"x value "09"x quality "09"x evidence
      q = 100
      if datatype(strip(quality), "N") then q = strip(quality)
      sourceResult~addFact(.MvsSourceFact~new(source, subject, predicate, value, q, evidence))
    end
  end
  call stream path, "c", "close"
  if sourceResult~probes~items = 0 then sourceResult~addProbe(.MvsProbeRecord~new(1, "FEED_READ", .true, path))
  return sourceResult

::class MvsDiscoveryDirectoryBackend public
::method init
  expose directory composer
  use arg directory
  directory = strip(directory)
  composer = .MvsDiscoveryComposer~new
  composer~addSource(.MvsDiscoverySource~new("MVS_ALCHEMY", .MvsTsvDiscoveryDelegate~new("MVS_ALCHEMY", directory || "/mvs_alchemy.tsv")))
  composer~addSource(.MvsDiscoverySource~new("TERMINAL_MACHINE", .MvsTsvDiscoveryDelegate~new("TERMINAL_MACHINE", directory || "/terminal_machine.tsv")))
  referencePath = directory || "/reference_x3270.tsv"
  if stream(referencePath, "c", "query exists") \== "" then do
    composer~addSource(.MvsDiscoverySource~new("REFERENCE_X3270", .MvsTsvDiscoveryDelegate~new("REFERENCE_X3270", referencePath)))
  end
  tsoReferencePath = directory || "/reference_tso_x3270.tsv"
  if stream(tsoReferencePath, "c", "query exists") \== "" then do
    composer~addSource(.MvsDiscoverySource~new("REFERENCE_TSO_X3270", .MvsTsvDiscoveryDelegate~new("REFERENCE_TSO_X3270", tsoReferencePath)))
  end
  composer~addSource(.MvsDiscoverySource~new("HERCULES_SERVICES", .MvsTsvDiscoveryDelegate~new("HERCULES_SERVICES", directory || "/hercules_services.tsv")))
::method discover
  expose composer
  use arg target
  return composer~discover(target)

/* Three source fixtures model the independent authorities and are useful for
 * qualification without claiming that a fixture is a live MVS observation. */
::class MvsAlchemyFixtureSource public
::method init
  expose generation
  use arg generation = 1
::attribute generation
::method discover
  expose generation
  use arg target
  r = .MvsSourceResult~new("MVS_ALCHEMY")
  r~addProbe(.MvsProbeRecord~new(1, "SYSTEM_IDENTITY", .true, "mvs.alchemy system identity"))
  r~addProbe(.MvsProbeRecord~new(2, "JES_STATE", .true, "mvs.alchemy JES observation"))
  r~addProbe(.MvsProbeRecord~new(3, "JES_JOB_CATALOG", .true, "bounded job catalogue"))
  r~addProbe(.MvsProbeRecord~new(4, "JES_JOB_METADATA", .true, "owners/completion/times"))
  r~addProbe(.MvsProbeRecord~new(5, "DATASET_CATALOG", .true, "bounded dataset catalogue"))
  r~addProbe(.MvsProbeRecord~new(6, "DATASET_METADATA", .true, "dataset shape/access"))
  r~addProbe(.MvsProbeRecord~new(7, "TSO_IDENTITY", .true, "guest-side session identity"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "SYSTEM", "NAME", target, 100, "fixture:mvs:system"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "SYSTEM", "OS", "MVS 3.8J TK5", 100, "fixture:mvs:os"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "JES", "STATE", "READY", 100, "fixture:mvs:jes"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "TSO", "USER", "HERC01", 100, "fixture:mvs:tso"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "JOB.JOB00137", "ROW", "JOB00137|COBTEST|FRED|COMPILE|ENDED|CC 0008|2026-10-06T07:51:00|FRED.COBOL(TEST1)", 100, "fixture:jes:137"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "JOB.JOB00140", "ROW", "JOB00140|PAYCOMP|FRED|COMPILE|ENDED|CC 0012|2026-10-06T08:12:00|FRED.COBOL(PAYROLL)", 100, "fixture:jes:140"))
  if generation >= 2 then r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "JOB.JOB00144", "ROW", "JOB00144|NEWWORK|FRED|COMPILE|ENDED|CC 0016|2026-10-06T09:04:00|FRED.COBOL(NEWWORK)", 100, "fixture:jes:144"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "DATASET.FRED.COBOL", "ROW", "FRED.COBOL|PDS|TRUE", 100, "fixture:ds:fred.cobol"))
  r~addFact(.MvsSourceFact~new("MVS_ALCHEMY", "DATASET.SYS1.PARMLIB", "ROW", "SYS1.PARMLIB|PDS|FALSE", 100, "fixture:ds:sys1.parmlib"))
  return r

::class TerminalMachineFixtureSource public
::method init
  expose state
  use arg state = "TSO_READY"
::attribute state
::method discover
  expose state
  use arg target
  r = .MvsSourceResult~new("TERMINAL_MACHINE")
  r~addProbe(.MvsProbeRecord~new(1, "SESSION_ATTACH", .true, "observe existing 3270 session"))
  r~addProbe(.MvsProbeRecord~new(2, "SCREEN_STATE", .true, "observe presentation state"))
  r~addProbe(.MvsProbeRecord~new(3, "CURSOR_FIELD_STATE", .true, "observe cursor/field/keyboard state"))
  r~addProbe(.MvsProbeRecord~new(4, "TSO_PANEL_IDENTITY", .true, "observe TSO-visible identity"))
  r~addFact(.MvsSourceFact~new("TERMINAL_MACHINE", "SESSION", "STATE", state, 100, "fixture:3270:session"))
  r~addFact(.MvsSourceFact~new("TERMINAL_MACHINE", "TSO", "USER", "HERC01", 95, "fixture:3270:tso"))
  return r

::class HerculesFixtureSource public
::method init
  expose guestState controlState
  use arg guestState = "RUNNING", controlState = "REACHABLE"
::attribute guestState
::attribute controlState
::method discover
  expose guestState controlState
  use arg target
  r = .MvsSourceResult~new("HERCULES_SERVICES")
  r~addProbe(.MvsProbeRecord~new(1, "PROCESS_STATE", .true, "host supervisor observation"))
  r~addProbe(.MvsProbeRecord~new(2, "COMMAND_STATE", .true, "integrated Rexx/control observation"))
  r~addProbe(.MvsProbeRecord~new(3, "GUEST_STATE", .true, "emulator guest projection"))
  r~addProbe(.MvsProbeRecord~new(4, "CONSOLE_ENDPOINT", .true, "console endpoint observation"))
  r~addProbe(.MvsProbeRecord~new(5, "HTTP_ENDPOINT", .true, "management endpoint observation"))
  r~addProbe(.MvsProbeRecord~new(6, "DEVICE_INVENTORY", .true, "read-only device inventory"))
  r~addFact(.MvsSourceFact~new("HERCULES_SERVICES", "GUEST", "STATE", guestState, 100, "fixture:hercules:guest"))
  r~addFact(.MvsSourceFact~new("HERCULES_SERVICES", "CONTROL", "STATE", controlState, 100, "fixture:hercules:control"))
  return r

::class MvsThreePlaneFixtureBackend public
::method init
  expose mvs terminal hercules composer
  use arg generation = 1
  mvs = .MvsAlchemyFixtureSource~new(generation)
  terminal = .TerminalMachineFixtureSource~new
  hercules = .HerculesFixtureSource~new
  composer = .MvsDiscoveryComposer~new
  composer~addSource(.MvsDiscoverySource~new("MVS_ALCHEMY", mvs))
  composer~addSource(.MvsDiscoverySource~new("TERMINAL_MACHINE", terminal))
  composer~addSource(.MvsDiscoverySource~new("HERCULES_SERVICES", hercules))
::method discover
  expose composer
  use arg target
  return composer~discover(target)
::method mvs
  expose mvs
  return mvs
::method terminal
  expose terminal
  return terminal
::method hercules
  expose hercules
  return hercules
