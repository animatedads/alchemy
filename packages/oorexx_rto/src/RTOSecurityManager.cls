/* ============================================================
 * RTOSecurityManager.cls
 *
 * SecurityManager for reconstructed (deserialized) objects.
 *
 * A deserialized object's method source came over a wire.
 * MD5 proves it wasn't tampered with in transit, but that
 * only establishes integrity, not safety. The SecurityManager
 * establishes what the reconstructed code is *allowed to do*
 * when it executes on the receiving side.
 *
 * Default policy (restrictive):
 *   COMMAND  (ADDRESS instruction)  → blocked
 *   Dangerous CALL targets           → blocked
 *   SAY / arithmetic / string ops   → allowed (no interception needed)
 *   .local access                   → allowed read, blocked write
 *
 * Usage:
 *   mgr = .RTOSecurityManager~new
 *   mgr~allow("CALL", "SYSSLEEP")    /* whitelist a specific call */
 *   mgr~deny("CALL",  "SYSRUN")
 *   obj = .RTOSerializer~deserialize(json, mgr)
 *
 * Attaching to an individual Method object directly:
 *   meth = .Method~new("", srcArray)
 *   meth~setSecurityManager(mgr)
 *   meth~execute
 * ============================================================ */

::class RTOSecurityManager public

::attribute _policy      /* Directory: "CALL:NAME" → "allow"/"deny" */
::attribute _log         /* Array of intercepted calls (audit trail) */
::attribute _logEnabled  /* .true = keep audit log */
::attribute _strict      /* .true = deny anything not explicitly allowed */

::method init
  expose _policy _log _logEnabled _strict
  _policy     = .Directory~new
  _log        = .Array~new
  _logEnabled = .true
  _strict     = .false   /* permissive by default — block only known bad */

  /* Default blocks: anything that shells out or touches the filesystem */
  self~deny("COMMAND", "*")          /* all ADDRESS instructions */
  self~deny("CALL", "SYSRUN")        /* SysRun — execute shell command */
  self~deny("CALL", "SYSCOMMAND")
  self~deny("CALL", "RXSYSTEMEVENTCREATE")
  self~deny("CALL", "SYSLOADFUNCS")  /* loading external function packages */
  self~deny("CALL", "RXFUNCADD")
  self~deny("CALL", "RXFUNCDROP")
  self~deny("CALL", "SYSFILEDELETE") /* filesystem mutation */
  self~deny("CALL", "SYSMKDIR")
  self~deny("CALL", "SYSFILEMOVE")

  /* Allow timer functions — the Alarm needs SysSleep on some paths */
  self~allow("CALL", "SYSSLEEP")

::method allow
  expose _policy
  use arg category, name
  _policy[category~upper || ":" || name~upper] = "allow"

::method deny
  expose _policy
  use arg category, name
  _policy[category~upper || ":" || name~upper] = "deny"

/* ── SecurityManager intercept methods ──────────────────── */

/* ADDRESS instruction — shell commands */
::method command
  expose _policy _log _logEnabled
  use arg context, env, cmd
  if _logEnabled then
    _log~append("COMMAND: " || env || " " || cmd~left(60))
  if self~_isDenied("COMMAND", "*") then
    raise syntax 93.901 array("RTOSecurityManager: ADDRESS commands blocked for deserialized objects")
  return 0   /* 0 = allow */

/* CALL function/routine */
::method call
  expose _policy _log _logEnabled _strict
  use arg context, name, args
  upper = name~upper
  if _logEnabled then
    _log~append("CALL: " || name)
  /* Check specific deny first */
  if self~_isDenied("CALL", upper) then
    raise syntax 93.901 array("RTOSecurityManager: call to " || name || " blocked")
  /* Check wildcard deny */
  if self~_isDenied("CALL", "*") then
    raise syntax 93.901 array("RTOSecurityManager: all calls blocked")
  /* In strict mode, block anything not explicitly allowed */
  if _strict & \self~_isAllowed("CALL", upper) then
    raise syntax 93.901 array("RTOSecurityManager: " || name || " not in allowlist")
  return 0

/* LOCAL (.local access) — allow reads, optionally block writes */
::method local
  expose _policy _log _logEnabled
  use arg context, name, value
  /* value supplied = write attempt */
  if value \== .nil & self~_isDenied("LOCAL", "*") then do
    if _logEnabled then
      _log~append("LOCAL write blocked: " || name)
    raise syntax 93.901 array("RTOSecurityManager: .local write blocked for deserialized objects")
  end
  return 0

/* ENVIRONMENT (SysGetEnv / VALUE with ENVIRONMENT) */
::method environment
  expose _log _logEnabled
  use arg context, name, value
  if _logEnabled then
    _log~append("ENV access: " || name)
  return 0   /* allow reads by default */

/* ── Audit log ───────────────────────────────────────────── */

::method auditLog
  expose _log
  return _log

::method printAudit
  expose _log
  say copies("-", 50)
  say "RTOSecurityManager audit log (" || _log~items || " entries):"
  do entry over _log
    say "  " entry
  end
  say copies("-", 50)

/* ── Internal helpers ────────────────────────────────────── */

::method _isDenied private
  expose _policy
  use arg category, name
  key = category~upper || ":" || name~upper
  pol = _policy[key]
  if pol == .nil then return .false
  return pol = "deny"

::method _isAllowed private
  expose _policy
  use arg category, name
  key = category~upper || ":" || name~upper
  pol = _policy[key]
  if pol == .nil then return .false
  return pol = "allow"
