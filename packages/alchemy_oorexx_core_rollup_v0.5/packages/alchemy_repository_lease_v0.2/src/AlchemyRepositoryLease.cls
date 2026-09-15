/*
 * AlchemyRepositoryLease v0.2
 *
 * One kernel-backed, cross-process lease for operations which mutate the
 * local Git object/ref/worktree state of an Alchemy repository handle.
 *
 * The ooRexx object owns policy and lifecycle.  A tiny shell holder owns the
 * flock(2) file descriptor while watching the owning ooRexx PID + start-time.
 * If the ooRexx owner disappears, the helper exits and the kernel releases the
 * lock.  No stale lock-directory recovery protocol exists.
 */

::class AlchemyRepositoryLeaseBuild public
::constant VERSION "0.2"
::constant API "alchemy.repository.lease/0.1"


::class AlchemyRepositoryLease subclass AlchemyCoreComponent public
::attribute repoRoot get
::attribute lockPath get
::attribute holderPid get
::attribute ownerPid get
::attribute ownerStart get

::method init
  expose repoRoot lockPath holderPid ownerPid ownerStart statusPath releasePath active
  use strict arg repoRoot
  self~initCoreComponent("AlchemyRepositoryLease", "0.2", "Kernel-backed cross-process Alchemy repository lease")
  repoRoot = repoRoot~string
  if \.AlchemyRepositoryLeaseFs~isDirectory(repoRoot || "/.git") then -
    raise syntax 88.900 array("repository lease requires ordinary Git checkout: " || repoRoot)
  lockPath = repoRoot || "/.git/alchemy-autobuild.repository.lock"
  holderPid = ""
  ownerPid = ""
  ownerStart = ""
  statusPath = ""
  releasePath = ""
  active = .false

::method acquire
  expose lockPath holderPid ownerPid ownerStart statusPath releasePath active
  use strict arg timeoutSeconds = 30
  timeoutSeconds = timeoutSeconds + 0
  if timeoutSeconds < 0 then raise syntax 88.900 array("repository lease timeout must not be negative")
  if active then raise syntax 88.900 array("repository lease already active")

  identity = .AlchemyRepositoryProcess~selfIdentity
  ownerPid = identity["pid"]
  ownerStart = identity["start"]
  statusPath = SysTempFileName("/tmp/alchemy-repository-lease-status-??????")
  releasePath = SysTempFileName("/tmp/alchemy-repository-lease-release-??????")
  if statusPath = "" | releasePath = "" then raise syntax 88.900 array("unable to allocate repository lease control paths")

  holderScript = '(' ||,
    ' exec 9>"$1" || { printf ''%s\n'' ''ERROR lock-open'' >"$2"; exit 73; };' ||,
    ' if ! flock -x -w "$6" 9; then printf ''%s\n'' ''TIMEOUT'' >"$2"; exit 75; fi;' ||,
    ' printf ''LOCKED %s\n'' "$$" >"$2";' ||,
    ' while :; do' ||,
    '   [ -e "$3" ] && break;' ||,
    '   stat=$(cat "/proc/$4/stat" 2>/dev/null) || break;' ||,
    '   state=$(printf ''%s\n'' "$stat" | awk ''{print $3}'');' ||,
    '   start=$(printf ''%s\n'' "$stat" | awk ''{print $22}'');' ||,
    '   [ "$state" != ''Z'' ] || break;' ||,
    '   [ "$start" = "$5" ] || break;' ||,
    '   sleep 0.05;' ||,
    ' done' ||,
    ') >/dev/null 2>&1 & printf ''%s\n'' "$!"'

  command = .AlchemyRepositoryLeaseShell~joinArgv(.array~of("sh", "-c", holderScript, "alchemy-lock-holder", lockPath, statusPath, releasePath, ownerPid, ownerStart, timeoutSeconds))
  capture = .AlchemyRepositoryLeaseShell~capture(command)
  if capture["rc"] \= 0 then do
    self~cleanupControls
    raise syntax 88.900 array("unable to launch repository lease holder: " || capture["stderr"]~strip)
  end
  holderPid = capture["stdout"]~changeStr("0d"x, "")~changeStr("0a"x, "")~strip
  if holderPid = "" then do
    self~cleanupControls
    raise syntax 88.900 array("repository lease holder did not report pid")
  end

  /* Holder writes LOCKED only after flock has succeeded. */
  launched = time("E")
  deadline = launched + timeoutSeconds + 2
  do while time("E") <= deadline
    if .AlchemyRepositoryLeaseFs~isFile(statusPath) then do
      status = .AlchemyRepositoryLeaseFs~readFile(statusPath)
      statusWord = status~changeStr("0d"x, "")~changeStr("0a"x, "")~strip~word(1)
      if statusWord = "LOCKED" then do
        active = .true
        return self
      end
      if statusWord = "TIMEOUT" then do
        self~cleanupControls
        holderPid = ""
        raise syntax 88.900 array("repository lease acquisition timed out: " || lockPath)
      end
      if statusWord = "ERROR" then do
        self~cleanupControls
        holderPid = ""
        raise syntax 88.900 array("repository lease holder failed: " || status)
      end
    end
    if time("E") - launched > 0.25 & \.AlchemyRepositoryProcess~isLive(holderPid) then do
      self~cleanupControls
      holderPid = ""
      raise syntax 88.900 array("repository lease holder exited before acquisition")
    end
    call SysSleep 0.05
  end

  /* Defensive: ask a still-running holder to terminate before returning error. */
  .AlchemyRepositoryLeaseFs~touch(releasePath)
  self~waitHolder(2)
  self~cleanupControls
  holderPid = ""
  raise syntax 88.900 array("repository lease acquisition status timeout: " || lockPath)

::method close
  expose holderPid statusPath releasePath active
  if \active then return .false
  .AlchemyRepositoryLeaseFs~touch(releasePath)
  if \self~waitHolder(3) then do
    /* Owner still exists, so an unresponsive helper is safe to terminate. */
    .AlchemyRepositoryLeaseShell~system(.array~of("kill", "-TERM", holderPid))
    self~waitHolder(1)
  end
  active = .false
  holderPid = ""
  self~cleanupControls
  return .true

::method isActive
  expose active
  return active

::method waitHolder private
  expose holderPid
  use strict arg seconds
  if holderPid = "" then return .true
  deadline = time("E") + seconds
  do while time("E") <= deadline
    if \.AlchemyRepositoryProcess~isLive(holderPid) then return .true
    call SysSleep 0.05
  end
  return \.AlchemyRepositoryProcess~isLive(holderPid)

::method cleanupControls private
  expose statusPath releasePath
  if statusPath \= "" then call SysFileDelete statusPath
  if releasePath \= "" then call SysFileDelete releasePath
  statusPath = ""
  releasePath = ""
  return


::class AlchemyRepositoryProcess public
::method selfIdentity class
  stat = .AlchemyRepositoryLeaseFs~readFile("/proc/self/stat")
  if stat = "" then raise syntax 88.900 array("unable to read ooRexx process identity")
  out = .table~new
  out["pid"] = word(stat, 1)
  out["state"] = word(stat, 3)
  out["start"] = word(stat, 22)
  if out["pid"] = "" | out["start"] = "" then raise syntax 88.900 array("invalid ooRexx process identity")
  return out

::method isLive class
  use strict arg pid
  pid = pid~string~strip
  if pid = "" then return .false
  path = "/proc/" || pid || "/stat"
  if \.AlchemyRepositoryLeaseFs~isFile(path) then return .false
  stat = .AlchemyRepositoryLeaseFs~readFile(path)
  if stat = "" then return .false
  return word(stat, 3) \= "Z"


::class AlchemyRepositoryLeaseFs public
::method isDirectory class
  use strict arg path
  stem = "ALCHEMY_LEASE_DIR."
  call SysFileTree path, stem, "DO"
  return value(stem || "0") > 0

::method isFile class
  use strict arg path
  stem = "ALCHEMY_LEASE_FILE."
  call SysFileTree path, stem, "FO"
  return value(stem || "0") > 0

::method readFile class
  use strict arg path
  s = .stream~new(path)
  r = s~open("read")
  if r \= "READY:" then return ""
  n = s~chars
  if n > 0 then data = s~charin(1, n)
  else data = s~linein
  s~close
  return data

::method touch class
  use strict arg path
  s = .stream~new(path)
  s~open("write replace")
  s~charout("")
  s~close
  return path


::class AlchemyRepositoryLeaseShell public
::method quote class
  use strict arg value
  s = value~string
  q = "27"x
  escapedQuote = "2722272227"x
  return q || s~changeStr(q, escapedQuote) || q

::method joinArgv class
  use strict arg argv
  out = ""
  do a over argv
    if out \= "" then out ||= " "
    out ||= self~quote(a)
  end
  return out

::method system class
  use strict arg argv
  command = self~joinArgv(argv)
  address system command
  return rc

::method capture class
  use strict arg command
  outPath = SysTempFileName("/tmp/alchemy-lease-out-??????")
  errPath = SysTempFileName("/tmp/alchemy-lease-err-??????")
  if outPath = "" | errPath = "" then raise syntax 88.900 array("unable to allocate repository lease command capture")
  address system command || " >" || self~quote(outPath) || " 2>" || self~quote(errPath)
  code = rc
  out = .AlchemyRepositoryLeaseFs~readFile(outPath)
  err = .AlchemyRepositoryLeaseFs~readFile(errPath)
  call SysFileDelete outPath
  call SysFileDelete errPath
  captured = .table~new
  captured["rc"] = code
  captured["stdout"] = out
  captured["stderr"] = err
  return captured

::requires "AlchemyCoreComponent.cls"
