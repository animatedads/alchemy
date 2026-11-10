/* ComputerIntentions.cls - the "Computer" intentions for IntentionService.     */
/* Architecture: Tom Dyer.  Coding: Claude Sonnet 5.5.  UNTESTED first cut.     */
/* Meaning and specificity are decided by IntentionService; this file supplies  */
/* the phrase provider, the buckets, the registrations and the executors.       */

::requires "IntentionService.cls"

/* ------------------------------------------------------------------ */
/* ComputerKit - state files, quoting, safety checks, receipts          */
/* ------------------------------------------------------------------ */
::class ComputerKit public

::method init
  expose home stateDir findFile tmpFile logFile
  home = value("HOME", , "ENVIRONMENT")
  if home == "" then raise syntax 93.900 array("HOME is not set")
  stateDir = home || "/.computer"
  findFile = stateDir || "/find_locations.txt"
  tmpFile = stateDir || "/temp_dirs.txt"
  logFile = stateDir || "/receipts.log"
  address system "mkdir -p" '"' || stateDir || '"'

::attribute home get
::attribute stateDir get
::attribute findFile get
::attribute tmpFile get
::attribute logFile get

::method quote
  use arg text
  return '"' || text || '"'

::method unquote
  use arg text
  text = strip(text)
  if length(text) >= 2 then do
    first = left(text, 1)
    if first == '"' | first == "'" then do
      if right(text, 1) == first then text = substr(text, 2, length(text) - 2)
    end
  end
  return text

::method expandPath
  use arg text
  text = self~unquote(text)
  if text == "~" then return self~home
  if left(text, 2) == "~/" then return self~home || substr(text, 2)
  return text

::method safePath
  use arg text
  bad = '"$`|;&<>*?\' || "'"
  return verify(text, bad, "M") == 0

::method safeText
  use arg text
  bad = '"$`\' || "'"
  return verify(text, bad, "M") == 0

::method sshnodePath
  path = value("COMPUTER_SSHNODE", , "ENVIRONMENT")
  if path \== "" then return path
  return value("COMPUTER_DIR", , "ENVIRONMENT") || "/sshnode.sh"

/* Optional node table (hosts style: ip name [name...] # comment).  Set
 * COMPUTER_NODES to its path.  Unset or missing means no node validation.
 * Returns NOFILE, UNKNOWN, or KNOWN:<comment>. */
::method knownNodes
  path = self~sshnodePath
  address system "test -f" self~quote(path)
  if rc <> 0 then return .Array~new
  address system "sed -nE 's/^[[:space:]]+(ed[0-9a-z]+)\).*/\1/p'" self~quote(path) with output stem names.
  nodes = .Array~new
  do i = 1 to names.0
    nodes~append(names.i)
  end
  return nodes

/* "" when the node is acceptable, otherwise the reason.  The node list comes
 * from sshnode.sh's own case labels, so it cannot drift from the real script. */
::method nodeProblem
  use arg node
  if verify(node, "abcdefghijklmnopqrstuvwxyz0123456789-_.", "N") > 0 then return "invalid node name: " || node
  nodes = self~knownNodes
  if nodes~items == 0 then return ""
  do i = 1 to nodes~items
    if nodes~at(i) == node then return ""
  end
  list = ""
  do i = 1 to nodes~items
    list = list nodes~at(i)
  end
  return "unknown node " || node || "; sshnode.sh knows:" || list

/* Job id that appears in sshnode.log, so receipts and log lines correlate.
 * The $(date ...) is expanded by the shell that runs the command. */
::method jobId
  use arg intent, node
  return "computer-" || intent || "-" || node || "-$(date -u +%Y%m%dT%H%M%SZ)"

::method listRead
  use arg file
  items = .Array~new
  in = .stream~new(file)
  if in~query("exists") \== "" then do
    do while in~lines > 0
      line = strip(in~linein)
      if line \== "" then items~append(line)
    end
  end
  in~close
  return items

::method listHas
  use arg file, item
  items = self~listRead(file)
  do i = 1 to items~items
    if items~at(i) == item then return .true
  end
  return .false

::method listAdd
  use arg file, item
  out = .stream~new(file)
  out~open("WRITE APPEND")
  out~lineout(item)
  out~close
  return .true

::method receipt
  expose logFile
  use arg text
  say text
  out = .stream~new(logFile)
  out~open("WRITE APPEND")
  out~lineout(date("S") time("N") text)
  out~close
  return .true

::method ok
  use arg intent, changed
  self~receipt("OK intent=" || intent "changed=" || changed)
  return "OK"

::method fail
  use arg intent, reason
  self~receipt("FAIL intent=" || intent "reason=" || reason)
  return "FAIL"

/* Pending confirmations: a destructive intention is not executed on the call
 * that names it.  The phrase is parked under a token and run only by
 * "Computer confirm <token>".  A token works once. */
::method pendingSave
  use arg phrase
  dir = self~stateDir || "/pending"
  address system "mkdir -p" self~quote(dir)
  seed = right(space(translate(time("L"), " ", ":."), 0), 6)
  token = random(10, 99, seed) || random(1000, 9999)
  out = .stream~new(dir || "/" || token)
  out~open("WRITE REPLACE")
  out~lineout(phrase)
  out~close
  return token

::method pendingTake
  use arg token
  if \datatype(token, "W") then return ""
  file = self~stateDir || "/pending/" || token
  items = self~listRead(file)
  if items~items == 0 then return ""
  address system "rm -f" self~quote(file)
  return items~at(1)

/* ------------------------------------------------------------------ */
/* ComputerProvider - phrase matching that keeps the caller's case      */
/* (the stock DeterministicIntentionProvider upper-cases slot values,   */
/* which would corrupt paths).                                          */
/* ------------------------------------------------------------------ */
::class ComputerProvider public

::method name
  return "COMPUTER"

::method idFor
  use arg phrase
  return translate(changestr(" ", phrase, "_"))

::method propose
  use arg service, text
  proposals = .Array~new
  clean = space(strip(text))
  lc = lower(clean)
  bare = strip(strip(strip(lc, "T", "!"), "T", "."), "T", "?")
  proposal = .nil
  select
    when bare == "run tests" then proposal = self~proposeOne("run tests", "", "")
    when bare == "run the tests" then proposal = self~proposeOne("run tests", "", "")
    when left(lc, 16) == "check free space" then proposal = self~proposeCheck("check free space", lc, 16)
    when left(lc, 17) == "check free memory" then proposal = self~proposeCheck("check free memory", lc, 17)
    when left(lc, 15) == "deploy zipfile " then proposal = self~proposeDeploy(clean, lc)
    when left(lc, 4) == "add " then proposal = self~proposeAdd(clean, lc)
    when left(lc, 19) == "find files received" then proposal = self~proposeRecent(lc)
    when left(lc, 15) == "which file has " then proposal = self~proposeOne("which file has", "TEXT", substr(clean, 16))
    when left(lc, 24) == "find the latest copy of " then proposal = self~proposeLatest(substr(clean, 25))
    when lc == "set up the rexxpath" then proposal = self~proposeOne("set up the rexxpath", "", "")
    when lc == "set up rexxpath" then proposal = self~proposeOne("set up the rexxpath", "", "")
    when left(lc, 12) == "log me into " then proposal = self~proposeOne("log in to node", "NODE", word(clean, 4))
    when left(lc, 20) == "fix the firewall on " then proposal = self~proposeOne("fix firewall", "NODE", word(clean, 5))
    otherwise nop
  end
  if proposal \== .nil then proposals~append(proposal)
  return proposals

::method newProposal
  use arg phrase
  return .IntentionProposal~new(self~idFor(phrase), 101, "COMPUTER", .true, "computer phrase (exact grammar match, outranks fuzzy engines)")

::method proposeOne
  use arg phrase, slotName, value
  proposal = self~newProposal(phrase)
  value = strip(value)
  if slotName \== "" then do
    if value \== "" then proposal~putSlot(slotName, value, .true)
  end
  return proposal

::method proposeCheck
  use arg phrase, lc, prefixLength
  rest = strip(substr(lc, prefixLength + 1))
  if rest == "" then return self~proposeOne(phrase, "NODE", "local")
  if word(rest, 1) == "on" then do
    if words(rest) == 2 then return self~proposeOne(phrase, "NODE", word(rest, 2))
  end
  return self~proposeOne(phrase, "", "")

::method proposeDeploy
  use arg clean, lc
  toPos = lastpos(" to ", lc)
  zip = ""
  node = ""
  if toPos == 0 then zip = strip(substr(clean, 16))
  else do
    if toPos > 16 then zip = strip(substr(clean, 16, toPos - 16))
    node = strip(substr(lc, toPos + 4))
    if words(node) \== 1 then node = ""
  end
  proposal = self~newProposal("deploy zipfile")
  if zip \== "" then proposal~putSlot("ZIPFILE", zip, .true)
  if node \== "" then proposal~putSlot("NODE", node, .true)
  return proposal

::method proposeAdd
  use arg clean, lc
  suffixes = .Array~of(" to my find file locations", " to my find files locations", " to my find file location", " to my permitted temporary file directory", " to my permitted temporary file directories")
  do i = 1 to suffixes~items
    suffix = suffixes~at(i)
    if right(lc, length(suffix)) == suffix then do
      if i <= 3 then phrase = "add find location"
      else phrase = "add temporary directory"
      bodyLength = length(clean) - 4 - length(suffix)
      body = ""
      if bodyLength > 0 then body = substr(clean, 5, bodyLength)
      return self~proposeOne(phrase, "PATH", body)
    end
  end
  return .nil

::method proposeRecent
  use arg lc
  proposal = self~newProposal("find recent files")
  pastIndex = wordpos("past", lc)
  if pastIndex > 0 then do
    amount = word(lc, pastIndex + 1)
    unit = word(lc, pastIndex + 2)
    if datatype(amount, "W") then do
      if amount > 0 then do
        if left(unit, 4) == "hour" then proposal~putSlot("MINUTES", amount * 60, .true)
        else if left(unit, 3) == "min" then proposal~putSlot("MINUTES", amount, .true)
      end
    end
  end
  return proposal

::method proposeLatest
  use arg rest
  name = ""
  do i = 1 to words(rest)
    candidate = word(rest, i)
    if wordpos(lower(candidate), "the rexx class file script") == 0 then do
      name = candidate
      leave
    end
  end
  return self~proposeOne("find latest copy", "NAME", name)

/* ------------------------------------------------------------------ */
/* ComputerEvent - executors.  invoke() returns "OK" or "FAIL".         */
/* ------------------------------------------------------------------ */
::class ComputerEvent public

::method init
  expose action kit
  use arg action, kit

::method slotValue
  use arg slots, name
  if slots~hasIndex(name) then return slots~at(name)~value
  return ""

::method invoke
  expose action kit
  use arg decision
  slots = decision~slots
  select
    when action == "ADD_FIND_LOCATION" then return self~addToList(kit~findFile, "add-find-location", self~slotValue(slots, "PATH"))
    when action == "ADD_TEMPORARY_DIRECTORY" then return self~addToList(kit~tmpFile, "add-temp-dir", self~slotValue(slots, "PATH"))
    when action == "FIND_RECENT_FILES" then return self~recentFiles(self~slotValue(slots, "MINUTES"))
    when action == "WHICH_FILE_HAS" then return self~whichFileHas(self~slotValue(slots, "TEXT"))
    when action == "FIND_LATEST_COPY" then return self~latestCopy(self~slotValue(slots, "NAME"))
    when action == "SET_UP_THE_REXXPATH" then return self~setUpRexxPath
    when action == "RUN_TESTS" then return self~runTests
    when action == "CHECK_FREE_SPACE" then return self~hostCheck("check-free-space", self~slotValue(slots, "NODE"), "df")
    when action == "CHECK_FREE_MEMORY" then return self~hostCheck("check-free-memory", self~slotValue(slots, "NODE"), "free")
    when action == "DEPLOY_ZIPFILE" then return self~deployZip(self~slotValue(slots, "ZIPFILE"), self~slotValue(slots, "NODE"))
    when action == "LOG_IN_TO_NODE" then return self~loginNode(self~slotValue(slots, "NODE"))
    when action == "FIX_FIREWALL" then return kit~fail("fix-firewall", "not implemented yet - cloudctl needs per-provider details (project, zone, rule, tag, group id, NSG, OCID) that no file supplies; vultr nodes ed209h and ed209k support firewall list only; node " || self~slotValue(slots, "NODE"))
    otherwise return kit~fail("internal", "no executor for " || action)
  end

::method addToList
  expose kit
  use arg file, intent, rawPath
  path = kit~expandPath(rawPath)
  if path == "" then return kit~fail(intent, "no path given")
  if left(path, 1) \== "/" then return kit~fail(intent, "path must be absolute or start with ~/ : " || path)
  if \kit~safePath(path) then return kit~fail(intent, "path contains a forbidden character: " || path)
  address system "test -d" kit~quote(path)
  if rc <> 0 then return kit~fail(intent, "directory does not exist: " || path)
  if kit~listHas(file, path) then return kit~ok(intent, "nothing (already registered): " || path)
  kit~listAdd(file, path)
  return kit~ok(intent, "added " || path)

::method recentFiles
  expose kit
  use arg minutes
  locations = kit~listRead(kit~findFile)
  if locations~items == 0 then return kit~fail("find-recent-files", "no find file locations registered; use: Computer add <dir> to my find file locations")
  cmd = "("
  do i = 1 to locations~items
    cmd = cmd "find" kit~quote(locations~at(i)) "-type f -mmin -" || minutes "-printf '%T@\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null;"
  end
  cmd = cmd ") | sort -rn | cut -f2- | head -200"
  address system cmd with output stem found.
  do i = 1 to found.0
    say found.i
  end
  return kit~ok("find-recent-files", "nothing changed; " || found.0 || " files in the past " || minutes || " minutes")

::method whichFileHas
  expose kit
  use arg text
  text = kit~unquote(text)
  if \kit~safeText(text) then return kit~fail("which-file-has", "text contains a forbidden character")
  locations = kit~listRead(kit~findFile)
  if locations~items == 0 then return kit~fail("which-file-has", "no find file locations registered; use: Computer add <dir> to my find file locations")
  cmd = "grep -rIlF -e" kit~quote(text)
  do i = 1 to locations~items
    cmd = cmd kit~quote(locations~at(i))
  end
  cmd = cmd "2>/dev/null | head -50"
  address system cmd with output stem found.
  do i = 1 to found.0
    say found.i
  end
  return kit~ok("which-file-has", "nothing changed; " || found.0 || " matching files")

::method latestCopy
  expose kit
  use arg name
  name = kit~unquote(name)
  if \kit~safeText(name) then return kit~fail("find-latest-copy", "name contains a forbidden character")
  locations = kit~listRead(kit~findFile)
  if locations~items == 0 then return kit~fail("find-latest-copy", "no find file locations registered; use: Computer add <dir> to my find file locations")
  cmd = "("
  do i = 1 to locations~items
    cmd = cmd "find" kit~quote(locations~at(i)) "-type f -iname" kit~quote("*" || name || "*") "-printf '%T@\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null;"
  end
  cmd = cmd ") | sort -rn | cut -f2-"
  address system cmd with output stem found.
  if found.0 == 0 then return kit~fail("find-latest-copy", "no file name matches *" || name || "* in the registered locations")
  say "LATEST" found.1
  if found.0 > 1 then do
    say "OTHER CANDIDATES (newest first, rule is newest modification time):"
    last = min(found.0, 10)
    do i = 2 to last
      say found.i
    end
  end
  return kit~ok("find-latest-copy", "nothing changed; " || found.0 || " candidates for " || name)

::method hostCheck
  expose kit
  use arg intent, node, cmdName
  node = lower(strip(node))
  if node == "" | node == "local" then do
    cmd = cmdName "2>&1"
    where = "local"
  end
  else do
    problem = kit~nodeProblem(node)
    if problem \== "" then return kit~fail(intent, problem)
    sshnode = kit~sshnodePath
    address system "test -x" kit~quote(sshnode)
    if rc <> 0 then return kit~fail(intent, "sshnode.sh not found or not executable at " || sshnode || " (set COMPUTER_SSHNODE)")
    cmd = "timeout 120" kit~quote(sshnode) "--job-id" kit~jobId(intent, node) node cmdName "2>&1"
    where = node
  end
  address system cmd with output stem found.
  cmdRc = rc
  do i = 1 to found.0
    say found.i
  end
  if cmdRc <> 0 then return kit~fail(intent, cmdName || " on " || where || " exited with rc=" || cmdRc)
  return kit~ok(intent, "nothing changed; " || cmdName || " on " || where)

::method deployZip
  expose kit
  use arg zip, node
  intent = "deploy-zipfile"
  node = lower(strip(node))
  if node == "" then return kit~fail(intent, "no node given")
  problem = kit~nodeProblem(node)
  if problem \== "" then return kit~fail(intent, problem)
  zip = kit~expandPath(zip)
  if zip == "" then return kit~fail(intent, "no zipfile given")
  if \kit~safePath(zip) then return kit~fail(intent, "zipfile name contains a forbidden character: " || zip)
  path = zip
  if left(zip, 1) \== "/" then do
    if pos("/", zip) > 0 then return kit~fail(intent, "give a bare file name or an absolute path: " || zip)
    locations = kit~listRead(kit~findFile)
    if locations~items == 0 then return kit~fail(intent, "no find file locations registered; use: Computer add <dir> to my find file locations")
    cmd = "("
    do i = 1 to locations~items
      cmd = cmd "find" kit~quote(locations~at(i)) "-type f -name" kit~quote(zip) "-printf '%T@\t%p\n' 2>/dev/null;"
    end
    cmd = cmd ") | sort -rn | cut -f2- | head -1"
    address system cmd with output stem found.
    if found.0 == 0 then return kit~fail(intent, zip || " not found in the registered find file locations")
    path = found.1
  end
  address system "test -f" kit~quote(path)
  if rc <> 0 then return kit~fail(intent, "file does not exist: " || path)
  sshnode = kit~sshnodePath
  address system "test -x" kit~quote(sshnode)
  if rc <> 0 then return kit~fail(intent, "sshnode.sh not found or not executable at " || sshnode || " (set COMPUTER_SSHNODE)")
  cmd = "timeout 600" kit~quote(sshnode) "--job-id" kit~jobId(intent, node) "--transfer" node kit~quote(path) "2>&1"
  address system cmd with output stem found.
  cmdRc = rc
  do i = 1 to found.0
    say found.i
  end
  if cmdRc <> 0 then return kit~fail(intent, "transfer of " || path || " to " || node || " exited with rc=" || cmdRc)
  return kit~ok(intent, "transferred " || path || " to " || node || ":" || substr(path, lastpos("/", path) + 1) || " (remote home directory)")

::method loginNode
  expose kit
  use arg node
  intent = "log-me-into"
  node = lower(strip(node))
  problem = kit~nodeProblem(node)
  if problem \== "" then return kit~fail(intent, problem)
  say "An interactive login needs a terminal, so a one-shot command cannot do it. Type this yourself:"
  say kit~sshnodePath || " " || node
  return kit~ok(intent, "nothing changed; printed the login command for " || node)

::method runTests
  expose kit
  dir = value("COMPUTER_DIR", , "ENVIRONMENT")
  if dir == "" then return kit~fail("run-tests", "COMPUTER_DIR is not set; run through the ./Computer wrapper")
  address system "test -f" kit~quote(dir || "/ComputerTest.sh")
  if rc <> 0 then return kit~fail("run-tests", "ComputerTest.sh not found in " || dir)
  address system "cd" kit~quote(dir) "&& bash ComputerTest.sh 2>&1" with output stem found.
  testRc = rc
  score = "no SCORE line found"
  do i = 1 to found.0
    if left(found.i, 6) == "SCORE:" then score = substr(found.i, 8)
    if left(found.i, 4) == "FAIL" then say found.i
  end
  if testRc == 0 then return kit~ok("run-tests", "nothing changed; " || score)
  return kit~fail("run-tests", score)

::method setUpRexxPath
  expose kit
  locations = kit~listRead(kit~findFile)
  if locations~items == 0 then return kit~fail("set-up-rexxpath", "no find file locations registered; use: Computer add <dir> to my find file locations")
  joined = ""
  do i = 1 to locations~items
    if joined == "" then joined = locations~at(i)
    else joined = joined || ":" || locations~at(i)
  end
  shFile = kit~stateDir || "/rexxpath.sh"
  out = .stream~new(shFile)
  out~open("WRITE REPLACE")
  out~lineout("export REXX_PATH=" || '"' || joined || ':$REXX_PATH"')
  out~close
  say "A script cannot change your shell. Type this line yourself:"
  say ". " || shFile
  return kit~ok("set-up-rexxpath", "wrote " || shFile || " with " || locations~items || " locations")

/* ------------------------------------------------------------------ */
/* ComputerFactory - builds the configured IntentionService             */
/* ------------------------------------------------------------------ */
::class ComputerFactory public

::method build class
  use arg kit
  service = .IntentionService~new
  /* SAFE: reads and reversible registry edits.  EXPLICIT = the operation must be
   * stated outright; no confirmation round trip. */
  service~registerBucket("SAFE", .IntentionBucketPolicy~new("EXPLICIT", 55, 12, .false, .false))
  /* DESTRUCTIVE: exact phrase, every slot explicit, and CONFIRM before READY. */
  service~registerBucket("DESTRUCTIVE", .IntentionBucketPolicy~new("EXACT", 75, 8, .true, .false))
  service~registerProvider(.ComputerProvider~new)

  reg = service~register("add find location", .ComputerEvent~new("ADD_FIND_LOCATION", kit), "SAFE")
  reg~requireSlot("PATH", "Which directory? Say: add <dir> to my find file locations", .true)
  reg = service~register("add temporary directory", .ComputerEvent~new("ADD_TEMPORARY_DIRECTORY", kit), "SAFE")
  reg~requireSlot("PATH", "Which directory? Say: add <dir> to my permitted temporary file directory", .true)
  reg = service~register("find recent files", .ComputerEvent~new("FIND_RECENT_FILES", kit), "SAFE")
  reg~requireSlot("MINUTES", "How far back? Say: find files received in my find files location in the past 30 minutes", .true)
  reg = service~register("which file has", .ComputerEvent~new("WHICH_FILE_HAS", kit), "SAFE")
  reg~requireSlot("TEXT", "Which text? Say: which file has <text>", .true)
  reg = service~register("find latest copy", .ComputerEvent~new("FIND_LATEST_COPY", kit), "SAFE")
  reg~requireSlot("NAME", "Which name? Say: find the latest copy of <name>", .true)
  reg = service~register("set up the rexxpath", .ComputerEvent~new("SET_UP_THE_REXXPATH", kit), "SAFE")
  reg = service~register("run tests", .ComputerEvent~new("RUN_TESTS", kit), "SAFE")
  reg = service~register("check free space", .ComputerEvent~new("CHECK_FREE_SPACE", kit), "SAFE")
  reg~requireSlot("NODE", "Which node? Say: check free space [on <node>]", .true)
  reg = service~register("check free memory", .ComputerEvent~new("CHECK_FREE_MEMORY", kit), "SAFE")
  reg~requireSlot("NODE", "Which node? Say: check free memory [on <node>]", .true)
  reg = service~register("deploy zipfile", .ComputerEvent~new("DEPLOY_ZIPFILE", kit), "DESTRUCTIVE")
  reg~requireSlot("ZIPFILE", "Which zipfile? Say: deploy zipfile <name.zip> to <node>", .true)
  reg~requireSlot("NODE", "Which node? Say: deploy zipfile <name.zip> to <node>", .true)
  reg = service~register("log in to node", .ComputerEvent~new("LOG_IN_TO_NODE", kit), "SAFE")
  reg~requireSlot("NODE", "Which node? Say: log me into <node>", .true)
  reg = service~register("fix firewall", .ComputerEvent~new("FIX_FIREWALL", kit), "DESTRUCTIVE")
  reg~requireSlot("NODE", "Which node? Say: fix the firewall on <node>", .true)
  return service

::method catalogue class
  text = "VALID INTENTS:" || .endOfLine
  text = text || "  Computer add <dir> to my find file locations" || .endOfLine
  text = text || "  Computer add <dir> to my permitted temporary file directory" || .endOfLine
  text = text || "  Computer find files received in my find files location in the past <N> minutes" || .endOfLine
  text = text || "  Computer which file has <text>" || .endOfLine
  text = text || "  Computer find the latest copy of <name>" || .endOfLine
  text = text || "  Computer set up the rexxpath" || .endOfLine
  text = text || "  Computer check free space [on <node>]" || .endOfLine
  text = text || "  Computer check free memory [on <node>]" || .endOfLine
  text = text || "  Computer deploy zipfile <name.zip> to <node>   (needs confirm; copies the zip to the node's home directory)" || .endOfLine
  text = text || "  Computer run tests" || .endOfLine
  text = text || "  Computer log me into <node>            (prints the command; you type it)" || .endOfLine
  text = text || "  Computer fix the firewall on <node>    (needs confirm; not implemented yet)" || .endOfLine
  text = text || "  Computer confirm <token>" || .endOfLine
  text = text || "  Computer help"
  return text
