/* Controlled, read-only machine observation abilities for the LLM PA.
 *
 * The PA/model never receives a shell command surface.  It may request one
 * named ability and a bounded argument (node, optional expected version or
 * metadata-only path).  This module owns the fixed sshnode.sh command
 * templates.  Every host command executes from a Method with an attached
 * ooRexx SecurityManager, so ADDRESS SYSTEM is interpreter-gated as well as
 * application-gated.
 *
 * There is deliberately no transfer, rm, redirection, pipe, sudo, kill,
 * chmod/chown, mv/cp, service restart, queue mutation, or arbitrary command
 * ability here.
 */

::class LlmPaMachineAbilityDescriptor public
::attribute name get
::attribute accessMode get
::attribute eventable get
::attribute mutating get
::attribute description get
::attribute argumentKind get

::method init
  expose name accessMode eventable mutating description argumentKind
  use arg nameArg, descriptionArg, argumentKindArg = "none"
  name = nameArg~string~strip~lower
  description = descriptionArg~string~strip
  argumentKind = argumentKindArg~string~strip~lower
  accessMode = "READ_ONLY"
  eventable = .true
  mutating = .false

::method asDirectory
  expose name accessMode eventable mutating description argumentKind
  d = .directory~new
  d["name"] = name
  d["access_mode"] = accessMode
  d["eventable"] = eventable
  d["mutating"] = mutating
  d["description"] = description
  d["argument_kind"] = argumentKind
  return d

/* Security manager attached to the tiny floating method that owns ADDRESS
 * SYSTEM.  Exact-command allowlisting is the primary control; forbidden-token
 * checks are defense in depth against a future unsafe catalogue entry. */
::class LlmPaMachineCheckSecurityManager public
::attribute audit get

::method init
  expose allowed audit label helperPath
  use arg allowedCommands, labelArg = "machine-observation", helperArg
  allowed = .directory~new
  audit = .array~new
  label = labelArg~string
  helperPath = helperArg~string~strip
  if helperPath = "" then raise syntax 88.900 array("machine SecurityManager requires sshnode helper path")
  if allowedCommands == .nil | \allowedCommands~isa(.Array) then raise syntax 88.900 array("machine SecurityManager requires command allowlist")
  do command over allowedCommands
    text = command~string
    if text = "" then iterate
    allowed[text] = .true
  end

::method command
  expose allowed audit label helperPath
  use arg info
  if info == .nil | \info~isa(.Directory) then raise syntax 98.948 array("LLM PA machine SecurityManager: invalid COMMAND checkpoint")
  commandText = ""
  addressName = ""
  if info~hasIndex("COMMAND") then commandText = info["COMMAND"]~string
  if info~hasIndex("ADDRESS") then addressName = info["ADDRESS"]~string~upper
  if addressName \= "SYSTEM" then do
    audit~append(.LlmPaUtil~timestamp || " DENY " || label || " address=" || addressName)
    raise syntax 98.948 array("LLM PA machine SecurityManager: only ADDRESS SYSTEM is permitted")
  end
  if \allowed~hasIndex(commandText) then do
    audit~append(.LlmPaUtil~timestamp || " DENY " || label || " command-not-allowlisted")
    raise syntax 98.948 array("LLM PA machine SecurityManager: command not delegated")
  end
  if \self~validDelegatedCommand(commandText, helperPath) then do
    audit~append(.LlmPaUtil~timestamp || " DENY " || label || " outside-machine-probe-contract")
    raise syntax 98.948 array("LLM PA machine SecurityManager: command outside delegated machine probe contract")
  end
  if self~containsForbidden(commandText) then do
    audit~append(.LlmPaUtil~timestamp || " DENY " || label || " forbidden-primitive")
    raise syntax 98.948 array("LLM PA machine SecurityManager: mutating/redirection primitive blocked")
  end
  audit~append(.LlmPaUtil~timestamp || " ALLOW " || label)
  return 0

::method unknown
  expose audit label
  use arg checkpoint, args
  audit~append(.LlmPaUtil~timestamp || " DENY " || label || " checkpoint=" || checkpoint~string)
  raise syntax 98.948 array("LLM PA machine SecurityManager: checkpoint blocked: " || checkpoint~string)

::method validDelegatedCommand private
  use arg commandText, helperPath
  prefix = "timeout 20 " || helperPath || " "
  if commandText~left(prefix~length) \= prefix then return .false
  rest = commandText~substr(prefix~length + 1)
  firstSpace = rest~pos(" ")
  if firstSpace <= 1 then return .false
  node = rest~left(firstSpace - 1)~lower
  if \self~delegatedNode(node) then return .false
  quoted = rest~substr(firstSpace + 1)
  if quoted~length < 2 | quoted~left(1) \= "'" | quoted~right(1) \= "'" then return .false
  remote = quoted~substr(2, quoted~length - 2)
  return self~delegatedRemote(remote)

::method delegatedNode private
  use arg node
  do allowedNode over .array~of("ed209a", "ed209b", "ed209c", "ed209d", "ed209e", "ed209h", "ed209i", "ed209x")
    if node = allowedNode then return .true
  end
  return .false

::method delegatedRemote private
  use arg remote
  do exact over .array~of( -
    "true", -
    "uname -a", -
    "uptime", -
    "cat /proc/loadavg", -
    "cat /proc/meminfo", -
    "df -Pk", -
    "ps -eo pid,ppid,user,stat,etime,pcpu,pmem,args", -
    "queue version", -
    "queue stats", -
    "cat /etc/os-release", -
    "stat -c %F:%s:%Y:%a:%U:%G:%n /usr/local/share/bashqueues/queuebash.sh", -
    "sha256sum /usr/local/share/bashqueues/queuebash.sh", -
    "systemctl is-active bashqueues-daemon.service", -
    "systemctl is-active bashqueues-cron.timer")
    if remote = exact then return .true
  end
  filePrefix = "stat -c %F:%s:%Y:%a:%U:%G:%n /"
  if remote~left(filePrefix~length) = filePrefix then return .true
  return .false

::method containsForbidden private
  use arg commandText
  text = " " || commandText~lower || " "
  /* No shell composition/output redirection at all in delegated probes. */
  if text~pos("|") > 0 | text~pos(">") > 0 | text~pos("<") > 0 | text~pos(";") > 0 | text~pos("&") > 0 | text~pos("`") > 0 then return .true
  if text~pos("0a"x) > 0 | text~pos("0d"x) > 0 then return .true
  if text~pos(" --transfer ") > 0 then return .true
  forbidden = .array~of(" rm ", " mv ", " cp ", " touch ", " mkdir ", " rmdir ", " ln ", " unlink ", " install ", " sudo ", " kill ", " pkill ", " killall ", " chmod ", " chown ", " truncate ", " tee ", " dd ", " mkfs", " mount ", " umount ", " reboot", " shutdown", " poweroff", " systemctl restart ", " systemctl start ", " systemctl stop ", " queue submit ", " queue run ", " queue start ", " queue daemon ", " queue health --fix ")
  do token over forbidden
    if text~pos(token) > 0 then return .true
  end
  return .false

/* Execution object used only to invoke a floating Method under its security
 * manager. stdout/stderr are redirected directly into Rexx arrays; no > file
 * or pipe is required. */
::class LlmPaMachineCommandActivation subclass Object public
::attribute commandText get
::attribute stdout get
::attribute stderr get

::method init
  expose commandText stdout stderr
  use arg commandArg
  commandText = commandArg~string
  stdout = .array~new
  stderr = .array~new

::method invoke
  use arg methodObject
  return self~run:super(methodObject)

::class LlmPaSecuredMachineRunner public
::method init
  expose helperPath
  use arg helperArg
  helperPath = helperArg~string~strip
  if helperPath = "" then raise syntax 88.900 array("secured machine runner requires sshnode helper path")

::method run
  expose helperPath
  use arg commandArg, labelArg = "machine-observation"
  commandText = commandArg~string
  manager = .LlmPaMachineCheckSecurityManager~new(.array~of(commandText), labelArg, helperPath)
  source = .array~of( -
    "out = self~stdout", -
    "err = self~stderr", -
    "address system self~commandText with output using (out) error using (err)", -
    "return rc")
  methodObject = .Method~new("", source)
  methodObject~setSecurityManager(manager)
  activation = .LlmPaMachineCommandActivation~new(commandText)
  signal on syntax name blocked
  commandRc = activation~invoke(methodObject)
  signal off syntax
  d = .directory~new
  d["rc"] = commandRc
  d["stdout"] = self~copyArray(activation~stdout)
  d["stderr"] = self~copyArray(activation~stderr)
  d["security_audit"] = self~copyArray(manager~audit)
  d["security_manager"] = "LlmPaMachineCheckSecurityManager"
  return .LlmPaResult~success(d)
blocked:
  signal off syntax
  detail = condition("D")
  if detail == .nil then detail = "SecurityManager rejected machine observation command"
  return .LlmPaResult~failure("MACHINE_SECURITY_DENIED", detail~string)

::method copyArray private
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item~string)
  end
  return out

::class LlmPaMachineAbilityService public
::attribute helperPath get

::method init
  expose helperPath runner descriptors knownNodes
  use arg helperArg = "/home/hc3/alchemy-autobuild/sshnode.sh", runnerArg = .nil
  helperPath = helperArg~string~strip
  if helperPath = "" then raise syntax 88.900 array("sshnode helper path is required")
  if runnerArg == .nil then runner = .LlmPaSecuredMachineRunner~new(helperPath)
  else runner = runnerArg
  knownNodes = .directory~new
  do node over .array~of("ed209a", "ed209b", "ed209c", "ed209d", "ed209e", "ed209h", "ed209i", "ed209x")
    knownNodes[node] = .true
  end
  descriptors = .directory~new
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("machine_health", "Reachability, kernel identity and uptime/load observation."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("memory_status", "RAM and swap totals/availability from /proc/meminfo."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("space_status", "Filesystem capacity/free-space observation using df."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("process_status", "Bounded observation of relevant worker, queue, deployment and analysis processes."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("queue_status", "Read-only QueueBash status observation."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("configuration_status", "OS, QueueBash version and installed queue script identity/hash observation."))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("file_status", "Metadata-only status for one explicitly named non-secret absolute path.", "path"))
  self~addDescriptor(.LlmPaMachineAbilityDescriptor~new("deployment_status", "Determine whether a QueueBash deployment is installed, active/in-progress, stale, or plausibly stuck.", "expected_version_optional"))

::method addDescriptor private
  expose descriptors
  use arg descriptor
  descriptors[descriptor~name] = descriptor

::method capabilities
  expose descriptors
  out = .array~new
  names = .array~new
  do name over descriptors
    names~append(name)
  end
  names~sort
  do name over names
    out~append(descriptors[name]~asDirectory)
  end
  return out

::method nodes
  expose knownNodes
  out = .array~new
  do node over knownNodes
    out~append(node)
  end
  out~sort
  return out

::method invokeText
  use arg textArg
  text = textArg~string~strip
  parse var text ability node argument
  return self~invoke(ability, node, argument)

::method invoke
  expose descriptors knownNodes
  use arg abilityArg, nodeArg, argumentArg = ""
  ability = abilityArg~string~strip~lower
  node = nodeArg~string~strip~lower
  argument = argumentArg~string~strip
  if \descriptors~hasIndex(ability) then return .LlmPaResult~failure("MACHINE_ABILITY_UNKNOWN", ability)
  if \knownNodes~hasIndex(node) then return .LlmPaResult~failure("MACHINE_NODE_NOT_DELEGATED", node)
  select
    when ability = "machine_health" then return self~machineHealth(node)
    when ability = "memory_status" then return self~memoryStatus(node)
    when ability = "space_status" then return self~spaceStatus(node)
    when ability = "process_status" then return self~processStatus(node)
    when ability = "queue_status" then return self~queueStatus(node)
    when ability = "configuration_status" then return self~configurationStatus(node)
    when ability = "file_status" then return self~fileStatus(node, argument)
    when ability = "deployment_status" then return self~deploymentStatus(node, argument)
    otherwise return .LlmPaResult~failure("MACHINE_ABILITY_UNKNOWN", ability)
  end

::method baseObservation private
  use arg ability, node
  d = .directory~new
  d["schema"] = "llm.pa.machine.observation/0.1"
  d["ability"] = ability
  d["node"] = node
  d["observed_at"] = .LlmPaUtil~timestamp
  d["authority"] = "SECURITY_MANAGER_DELEGATED_READ_ONLY"
  d["security_manager"] = "LlmPaMachineCheckSecurityManager"
  d["transport"] = "sshnode"
  d["read_only"] = .true
  d["eventable"] = .true
  d["mutating"] = .false
  d["status"] = "OK"
  d["probes"] = .array~new
  return d

::method machineHealth private
  use arg node
  observation = self~baseObservation("machine_health", node)
  ping = self~probe(node, "reachability", "true")
  self~appendProbe(observation, ping)
  if \ping~ok | ping~value["rc"] \= 0 then do
    observation["status"] = "UNREACHABLE_OR_SSH_FAILED"
    observation["summary"] = "sshnode reachability probe failed"
    return .LlmPaResult~success(observation)
  end
  kernel = self~probe(node, "kernel", "uname -a")
  uptime = self~probe(node, "uptime", "uptime")
  loadavg = self~probe(node, "loadavg", "cat /proc/loadavg")
  self~appendProbe(observation, kernel)
  self~appendProbe(observation, uptime)
  self~appendProbe(observation, loadavg)
  observation["kernel"] = self~firstLine(kernel)
  observation["uptime"] = self~firstLine(uptime)
  observation["loadavg"] = self~firstLine(loadavg)
  observation["summary"] = "reachable; " || observation["uptime"]
  return .LlmPaResult~success(observation)

::method memoryStatus private
  use arg node
  observation = self~baseObservation("memory_status", node)
  p = self~probe(node, "meminfo", "cat /proc/meminfo")
  self~appendProbe(observation, p)
  if \p~ok | p~value["rc"] \= 0 then return self~probeFailure(observation, p, "memory observation failed")
  totalKb = self~meminfoValue(p~value["stdout"], "MemTotal")
  availableKb = self~meminfoValue(p~value["stdout"], "MemAvailable")
  if availableKb < 0 then availableKb = self~meminfoValue(p~value["stdout"], "MemFree")
  swapTotalKb = self~meminfoValue(p~value["stdout"], "SwapTotal")
  swapFreeKb = self~meminfoValue(p~value["stdout"], "SwapFree")
  observation["mem_total_kb"] = totalKb
  observation["mem_available_kb"] = availableKb
  observation["swap_total_kb"] = swapTotalKb
  observation["swap_free_kb"] = swapFreeKb
  if totalKb > 0 & availableKb >= 0 then observation["mem_available_percent"] = trunc((availableKb * 10000) / totalKb) / 100
  observation["summary"] = "memory total_kb=" || totalKb || " available_kb=" || availableKb
  return .LlmPaResult~success(observation)

::method spaceStatus private
  use arg node
  observation = self~baseObservation("space_status", node)
  p = self~probe(node, "df", "df -Pk")
  self~appendProbe(observation, p)
  if \p~ok | p~value["rc"] \= 0 then return self~probeFailure(observation, p, "filesystem space observation failed")
  filesystems = .array~new
  root = .nil
  do i = 2 to p~value["stdout"]~items
    line = p~value["stdout"][i]~string~strip
    if words(line) < 6 then iterate
    rec = .directory~new
    rec["filesystem"] = word(line, 1)
    rec["blocks_kb"] = self~numberOr(word(line, 2), -1)
    rec["used_kb"] = self~numberOr(word(line, 3), -1)
    rec["available_kb"] = self~numberOr(word(line, 4), -1)
    usedPctText = word(line, 5)~changestr("%", "")
    rec["used_percent"] = self~numberOr(usedPctText, -1)
    if rec["used_percent"] >= 0 then rec["free_percent"] = 100 - rec["used_percent"]
    rec["mount"] = word(line, words(line))
    filesystems~append(rec)
    if rec["mount"] = "/" then root = rec
  end
  observation["filesystems"] = filesystems
  if root \== .nil then do
    observation["root"] = root
    observation["summary"] = "root free_percent=" || root["free_percent"] || " available_kb=" || root["available_kb"]
  end
  else observation["summary"] = "filesystem records=" || filesystems~items
  return .LlmPaResult~success(observation)

::method processStatus private
  use arg node
  observation = self~baseObservation("process_status", node)
  p = self~probe(node, "processes", "ps -eo pid,ppid,user,stat,etime,pcpu,pmem,args")
  self~appendProbe(observation, p)
  if \p~ok | p~value["rc"] \= 0 then return self~probeFailure(observation, p, "process observation failed")
  relevant = .array~new
  do i = 2 to p~value["stdout"]~items
    line = p~value["stdout"][i]~string
    if self~relevantProcess(line) then do
      if relevant~items < 40 then relevant~append(self~safeProcessRecord(line))
    end
  end
  observation["relevant_processes"] = relevant
  observation["relevant_process_count"] = relevant~items
  observation["summary"] = "relevant_processes=" || relevant~items
  return .LlmPaResult~success(observation)

::method queueStatus private
  use arg node
  observation = self~baseObservation("queue_status", node)
  version = self~probe(node, "queue_version", "queue version")
  status = self~probe(node, "queue_stats", "queue stats")
  self~appendProbe(observation, version)
  self~appendProbe(observation, status)
  observation["queue_version"] = self~firstLine(version)
  observation["queue_stats"] = self~copyStrings(status)
  if \status~ok | status~value["rc"] \= 0 then observation["status"] = "PARTIAL"
  observation["summary"] = "queue_version=" || observation["queue_version"]
  return .LlmPaResult~success(observation)

::method configurationStatus private
  use arg node
  observation = self~baseObservation("configuration_status", node)
  os = self~probe(node, "os_release", "cat /etc/os-release")
  version = self~probe(node, "queue_version", "queue version")
  stat = self~probe(node, "queue_script_stat", "stat -c %F:%s:%Y:%a:%U:%G:%n /usr/local/share/bashqueues/queuebash.sh")
  hash = self~probe(node, "queue_script_sha256", "sha256sum /usr/local/share/bashqueues/queuebash.sh")
  self~appendProbe(observation, os)
  self~appendProbe(observation, version)
  self~appendProbe(observation, stat)
  self~appendProbe(observation, hash)
  observation["os_release"] = self~keyValueLines(os)
  observation["queue_version"] = self~firstLine(version)
  observation["queue_script_stat"] = self~firstLine(stat)
  observation["queue_script_sha256"] = self~firstWord(hash)
  if version~ok & version~value["rc"] = 0 then observation["summary"] = observation["queue_version"] || "; queue script sha256=" || observation["queue_script_sha256"]
  else do
    observation["status"] = "PARTIAL"
    observation["summary"] = "OS observed; QueueBash installation could not be fully identified"
  end
  return .LlmPaResult~success(observation)

::method fileStatus private
  use arg node, pathArg
  path = pathArg~string~strip
  checked = self~validateMetadataPath(path)
  if \checked~ok then return checked
  observation = self~baseObservation("file_status", node)
  observation["path"] = path
  remote = "stat -c %F:%s:%Y:%a:%U:%G:%n " || path
  p = self~probe(node, "file_stat", remote)
  self~appendProbe(observation, p)
  if \p~ok | p~value["rc"] \= 0 then do
    observation["status"] = "NOT_FOUND_OR_UNREADABLE"
    observation["exists"] = .false
    observation["summary"] = "path not found or metadata unavailable: " || path
    return .LlmPaResult~success(observation)
  end
  observation["exists"] = .true
  observation["stat"] = self~firstLine(p)
  observation["summary"] = observation["stat"]
  return .LlmPaResult~success(observation)

::method deploymentStatus private
  use arg node, expectedArg
  expected = expectedArg~string~strip
  if expected \= "" then do
    if \self~safeToken(expected) then return .LlmPaResult~failure("MACHINE_EXPECTED_VERSION_INVALID", expected)
  end
  observation = self~baseObservation("deployment_status", node)
  observation["expected_version"] = expected
  version = self~probe(node, "queue_version", "queue version")
  processes = self~probe(node, "processes", "ps -eo pid,ppid,user,stat,etime,pcpu,pmem,args")
  stat = self~probe(node, "queue_script_stat", "stat -c %F:%s:%Y:%a:%U:%G:%n /usr/local/share/bashqueues/queuebash.sh")
  hash = self~probe(node, "queue_script_sha256", "sha256sum /usr/local/share/bashqueues/queuebash.sh")
  daemon = self~probe(node, "daemon_service", "systemctl is-active bashqueues-daemon.service")
  cron = self~probe(node, "cron_service", "systemctl is-active bashqueues-cron.timer")
  do p over .array~of(version, processes, stat, hash, daemon, cron)
    self~appendProbe(observation, p)
  end
  observation["queue_version"] = self~firstLine(version)
  observation["queue_script_stat"] = self~firstLine(stat)
  observation["queue_script_sha256"] = self~firstWord(hash)
  observation["daemon_service"] = self~firstLine(daemon)
  observation["cron_service"] = self~firstLine(cron)
  installers = .array~new
  maxElapsed = 0
  if processes~ok then do i = 2 to processes~value["stdout"]~items
    line = processes~value["stdout"][i]~string
    if self~deploymentProcess(line) then do
      if installers~items < 20 then installers~append(self~safeProcessRecord(line))
      elapsed = self~processElapsedSeconds(line)
      if elapsed > maxElapsed then maxElapsed = elapsed
    end
  end
  observation["deployment_processes"] = installers
  observation["deployment_process_count"] = installers~items
  observation["oldest_deployment_process_seconds"] = maxElapsed
  if installers~items > 0 then do
    if maxElapsed >= 300 then observation["deployment_state"] = "STUCK_SUSPECTED"
    else observation["deployment_state"] = "IN_PROGRESS"
  end
  else if expected \= "" then do
    if observation["queue_version"]~lower~pos(expected~lower) > 0 then observation["deployment_state"] = "DEPLOYED"
    else observation["deployment_state"] = "NOT_DEPLOYED_OR_STALE"
  end
  else if version~ok & version~value["rc"] = 0 & stat~ok & stat~value["rc"] = 0 then observation["deployment_state"] = "INSTALLED_QUIESCENT"
  else observation["deployment_state"] = "UNKNOWN"
  observation["summary"] = "deployment_state=" || observation["deployment_state"] || "; queue_version=" || observation["queue_version"] || "; deployment_processes=" || installers~items
  return .LlmPaResult~success(observation)

::method probe private
  expose helperPath runner
  use arg node, probeName, remoteCommand
  if remoteCommand~pos("'") > 0 then return .LlmPaResult~failure("MACHINE_PROBE_TEMPLATE_INVALID", probeName)
  if \self~remoteCommandDelegated(remoteCommand) then return .LlmPaResult~failure("MACHINE_PROBE_NOT_DELEGATED", probeName)
  if self~remoteCommandUnsafe(remoteCommand) then return .LlmPaResult~failure("MACHINE_PROBE_TEMPLATE_UNSAFE", probeName)
  localCommand = "timeout 20 " || helperPath || " " || node || " '" || remoteCommand || "'"
  executed = runner~run(localCommand, probeName || ":" || node)
  if \executed~ok then return executed
  d = executed~value
  d["probe"] = probeName
  return .LlmPaResult~success(d)

::method remoteCommandDelegated private
  use arg remote
  do exact over .array~of( -
    "true", -
    "uname -a", -
    "uptime", -
    "cat /proc/loadavg", -
    "cat /proc/meminfo", -
    "df -Pk", -
    "ps -eo pid,ppid,user,stat,etime,pcpu,pmem,args", -
    "queue version", -
    "queue stats", -
    "cat /etc/os-release", -
    "stat -c %F:%s:%Y:%a:%U:%G:%n /usr/local/share/bashqueues/queuebash.sh", -
    "sha256sum /usr/local/share/bashqueues/queuebash.sh", -
    "systemctl is-active bashqueues-daemon.service", -
    "systemctl is-active bashqueues-cron.timer")
    if remote = exact then return .true
  end
  filePrefix = "stat -c %F:%s:%Y:%a:%U:%G:%n /"
  if remote~left(filePrefix~length) = filePrefix then return .true
  return .false

::method remoteCommandUnsafe private
  use arg remoteCommand
  text = " " || remoteCommand~lower || " "
  if text~pos("|") > 0 | text~pos(">") > 0 | text~pos("<") > 0 | text~pos(";") > 0 | text~pos("&") > 0 | text~pos("`") > 0 then return .true
  if text~pos("0a"x) > 0 | text~pos("0d"x) > 0 then return .true
  forbidden = .array~of(" rm ", " mv ", " cp ", " touch ", " mkdir ", " rmdir ", " ln ", " unlink ", " sudo ", " kill ", " chmod ", " chown ", " truncate ", " tee ", " dd ", " mkfs", " mount ", " umount ", " reboot", " shutdown", " poweroff", " --transfer ", " queue submit ", " queue run ", " queue start ", " queue daemon ", " queue health --fix ")
  do token over forbidden
    if text~pos(token) > 0 then return .true
  end
  return .false

::method appendProbe private
  use arg observation, probeResult
  rec = .directory~new
  if probeResult~ok then do
    rec["probe"] = probeResult~value["probe"]
    rec["rc"] = probeResult~value["rc"]
    if rec["probe"] = "processes" then do
      rec["stdout"] = .array~new
      rec["stdout_redacted"] = .true
    end
    else rec["stdout"] = probeResult~value["stdout"]
    rec["stderr"] = probeResult~value["stderr"]
    rec["security_manager"] = probeResult~value["security_manager"]
    rec["security_audit"] = probeResult~value["security_audit"]
  end
  else do
    rec["probe"] = "unknown"
    rec["rc"] = -1
    rec["error_code"] = probeResult~code
    rec["error_detail"] = probeResult~detail
  end
  observation["probes"]~append(rec)
  return .true

::method probeFailure private
  use arg observation, probeResult, summary
  observation["status"] = "FAILED"
  observation["summary"] = summary
  if \probeResult~ok then do
    observation["error_code"] = probeResult~code
    observation["error_detail"] = probeResult~detail
  end
  return .LlmPaResult~success(observation)

::method firstLine private
  use arg probeResult
  if probeResult == .nil | \probeResult~ok then return ""
  lines = probeResult~value["stdout"]
  if lines == .nil | lines~items = 0 then return ""
  return lines[1]~string~strip

::method firstWord private
  use arg probeResult
  line = self~firstLine(probeResult)
  if line = "" then return ""
  return word(line, 1)

::method joinLines private
  use arg probeResult
  if probeResult == .nil | \probeResult~ok then return ""
  lines = probeResult~value["stdout"]
  text = ""
  do line over lines
    if text \= "" then text = text || "0a"x
    text = text || line~string
  end
  return text

::method copyStrings private
  use arg probeResult
  out = .array~new
  if probeResult == .nil | \probeResult~ok then return out
  do line over probeResult~value["stdout"]
    out~append(line~string)
  end
  return out

::method meminfoValue private
  use arg lines, key
  prefix = key || ":"
  do line over lines
    text = line~string~strip
    if text~left(prefix~length) = prefix then do
      value = word(text, 2)
      if datatype(value, "W") then return value + 0
    end
  end
  return -1

::method keyValueLines private
  use arg probeResult
  d = .directory~new
  if probeResult == .nil | \probeResult~ok then return d
  do line over probeResult~value["stdout"]
    text = line~string~strip
    eq = text~pos("=")
    if eq <= 1 then iterate
    key = text~left(eq - 1)
    value = text~substr(eq + 1)~strip
    if value~length >= 2 then do
      if (value~left(1) = '"' & value~right(1) = '"') | (value~left(1) = "'" & value~right(1) = "'") then value = value~substr(2, value~length - 2)
    end
    d[key] = value
  end
  return d

::method numberOr private
  use arg textArg, fallback
  text = textArg~string~strip
  if datatype(text, "N") then return text + 0
  return fallback

::method relevantProcess private
  use arg lineArg
  line = " " || lineArg~string~lower || " "
  do token over .array~of(" queue ", "queuebash", " rexx ", "ffmpeg", "worker", "analyse_", "analyze_", "ollama", "install-system", "system-install", "deploy", "migration", "jna_authority")
    if line~pos(token) > 0 then return .true
  end
  return .false

::method deploymentProcess private
  use arg lineArg
  line = " " || lineArg~string~lower || " "
  do token over .array~of("install-system", "system-install", "bashqueues-system-install", "deploy_tree", "deployment", " unzip ")
    if line~pos(token) > 0 then return .true
  end
  return .false

::method safeProcessRecord private
  use arg lineArg
  d = .directory~new
  d["pid"] = self~numberOr(word(lineArg, 1), -1)
  d["ppid"] = self~numberOr(word(lineArg, 2), -1)
  d["user"] = word(lineArg, 3)
  d["stat"] = word(lineArg, 4)
  d["elapsed"] = word(lineArg, 5)
  d["elapsed_seconds"] = self~processElapsedSeconds(lineArg)
  d["cpu_percent"] = self~numberOr(word(lineArg, 6), -1)
  d["memory_percent"] = self~numberOr(word(lineArg, 7), -1)
  d["kind"] = self~processKind(lineArg)
  return d

::method processKind private
  use arg lineArg
  line = " " || lineArg~string~lower || " "
  if self~deploymentProcess(lineArg) then return "DEPLOYMENT"
  if line~pos("queuebash") > 0 | line~pos(" queue ") > 0 then return "QUEUE"
  if line~pos("ollama") > 0 then return "MODEL"
  if line~pos("ffmpeg") > 0 then return "MEDIA"
  if line~pos("analyse_") > 0 | line~pos("analyze_") > 0 then return "ANALYSIS"
  if line~pos("worker") > 0 then return "WORKER"
  if line~pos("migration") > 0 | line~pos("jna_authority") > 0 then return "MIGRATION"
  if line~pos(" rexx ") > 0 then return "REXX"
  return "OTHER_RELEVANT"

::method processElapsedSeconds private
  use arg lineArg
  if words(lineArg) < 5 then return 0
  elapsed = word(lineArg, 5)
  days = 0
  dash = elapsed~pos("-")
  if dash > 0 then do
    dayText = elapsed~left(dash - 1)
    if datatype(dayText, "W") then days = dayText + 0
    elapsed = elapsed~substr(dash + 1)
  end
  parts = elapsed~changestr(":", " ")
  count = words(parts)
  hours = 0; minutes = 0; seconds = 0
  if count = 3 then do
    hours = word(parts, 1); minutes = word(parts, 2); seconds = word(parts, 3)
  end
  else if count = 2 then do
    minutes = word(parts, 1); seconds = word(parts, 2)
  end
  else if count = 1 then seconds = word(parts, 1)
  if \datatype(hours, "W") | \datatype(minutes, "W") | \datatype(seconds, "W") then return 0
  return (days * 86400) + (hours * 3600) + (minutes * 60) + seconds

::method validateMetadataPath private
  use arg path
  if path = "" | path~left(1) \= "/" then return .LlmPaResult~failure("MACHINE_PATH_INVALID", "absolute path required")
  if path~length > 512 then return .LlmPaResult~failure("MACHINE_PATH_INVALID", "path too long")
  if path~pos("..") > 0 then return .LlmPaResult~failure("MACHINE_PATH_INVALID", "parent traversal is not delegated")
  safeChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./+@:-"
  do i = 1 to path~length
    if safeChars~pos(path~substr(i, 1)) = 0 then return .LlmPaResult~failure("MACHINE_PATH_INVALID", "path contains non-delegated characters")
  end
  lower = path~lower
  do blocked over .array~of("/.ssh/", "/.gnupg/", "/.config/gcloud/", "credential", "secret", ".pem", ".key", "/etc/shadow", "/proc/")
    if lower~pos(blocked) > 0 then return .LlmPaResult~failure("MACHINE_PATH_SENSITIVE", path)
  end
  return .LlmPaResult~success(path)

::method safeToken private
  use arg textArg
  text = textArg~string~strip
  if text = "" | text~length > 128 then return .false
  safeChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.+-"
  do i = 1 to text~length
    if safeChars~pos(text~substr(i, 1)) = 0 then return .false
  end
  return .true

::method render public
  use arg observation
  if observation == .nil | \observation~isa(.Directory) then return "No machine observation."
  text = "OBSERVATION" || "0a"x || "node: " || observation["node"] || "0a"x || "ability: " || observation["ability"] || "0a"x || "status: " || observation["status"]
  if observation~hasIndex("summary") then text = text || "0a"x || "summary: " || observation["summary"]
  if observation~hasIndex("deployment_state") then text = text || "0a"x || "deployment_state: " || observation["deployment_state"]
  if observation~hasIndex("mem_available_percent") then text = text || "0a"x || "memory_available_percent: " || observation["mem_available_percent"]
  if observation~hasIndex("root") then text = text || "0a"x || "root_free_percent: " || observation["root"]["free_percent"]
  if observation~hasIndex("relevant_process_count") then text = text || "0a"x || "relevant_process_count: " || observation["relevant_process_count"]
  text = text || "0a"x || "authority: SECURITY_MANAGER_DELEGATED_READ_ONLY"
  return text

::requires "LlmPaCore.cls"
