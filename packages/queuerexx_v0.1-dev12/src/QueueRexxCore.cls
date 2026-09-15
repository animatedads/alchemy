/* QueueRexxCore.cls - shared QueueBash filesystem reader, v0.1-dev6 */

::class QueueRexxVersion public
::constant RELEASE "0.1-dev12"
::constant QUEUEBASH_COMPATIBILITY "0.18.144"
::method version class
  return self~RELEASE
::method queueBashCompatibility class
  return self~QUEUEBASH_COMPATIBILITY

/* Internal queue state is typed.  The string directory names are compatibility
 * boundary values only. */
::class QueueState public
::constant ALL -1
::constant UNKNOWN 0
::constant PENDING 1
::constant WAITING 2
::constant RUNNING 3
::constant PAUSED 4
::constant DONE 5
::constant FAILED 6
::constant POL_BLOCKED 7
::constant POLICY_BLOCKED 8
::constant INTERRUPTED 9
::constant CANCELLED 10
::constant DELETED 11

/* QueueBash on-disk / CLI spellings.  These are boundary tokens owned by the
 * state class; business logic compares the numeric constants above. */
::constant NAME_ALL "all"
::constant NAME_UNKNOWN "unknown"
::constant NAME_PENDING "pending"
::constant NAME_WAITING "waiting"
::constant NAME_RUNNING "running"
::constant NAME_PAUSED "paused"
::constant NAME_DONE "done"
::constant NAME_FAILED "failed"
::constant NAME_POL_BLOCKED "pol_blocked"
::constant NAME_POLICY_BLOCKED "policy_blocked"
::constant NAME_INTERRUPTED "interrupted"
::constant NAME_CANCELLED "cancelled"
::constant NAME_DELETED "deleted"

::method fromName class
  use arg valueArg
  if valueArg == .nil then return self~UNKNOWN
  value = valueArg~string~lower
  select
    when value == self~NAME_ALL then return self~ALL
    when value == self~NAME_PENDING then return self~PENDING
    when value == self~NAME_WAITING then return self~WAITING
    when value == self~NAME_RUNNING then return self~RUNNING
    when value == self~NAME_PAUSED then return self~PAUSED
    when value == self~NAME_DONE then return self~DONE
    when value == self~NAME_FAILED then return self~FAILED
    when value == self~NAME_POL_BLOCKED then return self~POL_BLOCKED
    when value == self~NAME_POLICY_BLOCKED then return self~POLICY_BLOCKED
    when value == self~NAME_INTERRUPTED then return self~INTERRUPTED
    when value == self~NAME_CANCELLED then return self~CANCELLED
    when value == self~NAME_DELETED then return self~DELETED
    otherwise return self~UNKNOWN
  end

::method coerce class
  use arg valueArg
  if valueArg == .nil then return self~UNKNOWN
  text = valueArg~string
  if text~datatype("W") then do
    value = text + 0
    do known over self~values
      if value == known then return value
    end
    if value == self~ALL | value == self~UNKNOWN then return value
  end
  return self~fromName(text)

::method name class
  use arg stateArg
  state = stateArg + 0
  select
    when state == self~ALL then return self~NAME_ALL
    when state == self~PENDING then return self~NAME_PENDING
    when state == self~WAITING then return self~NAME_WAITING
    when state == self~RUNNING then return self~NAME_RUNNING
    when state == self~PAUSED then return self~NAME_PAUSED
    when state == self~DONE then return self~NAME_DONE
    when state == self~FAILED then return self~NAME_FAILED
    when state == self~POL_BLOCKED then return self~NAME_POL_BLOCKED
    when state == self~POLICY_BLOCKED then return self~NAME_POLICY_BLOCKED
    when state == self~INTERRUPTED then return self~NAME_INTERRUPTED
    when state == self~CANCELLED then return self~NAME_CANCELLED
    when state == self~DELETED then return self~NAME_DELETED
    otherwise return self~NAME_UNKNOWN
  end

::method values class
  return .Array~of(self~PENDING, self~WAITING, self~RUNNING, self~PAUSED, self~DONE, self~FAILED, self~POL_BLOCKED, self~POLICY_BLOCKED, self~INTERRUPTED, self~CANCELLED, self~DELETED)


::class QueueJobClass public
::constant DEFAULT "DEFAULT"

::class QueueRunnerKind public
::constant AUTO "auto"
::constant DIRECT "direct"
::constant SYSTEMD "systemd"

/* WLU is a first-class QueueRexx job requirement.  QueueBash has no WLU
 * execution authority, so managed jobs are staged in the existing WAITING
 * state until a WLU-aware QueueRexx placement/execution path admits them. */
::class QueueWLUMode public
::constant UNMANAGED 0
::constant MANAGED 1
::constant NAME_UNMANAGED "unmanaged"
::constant NAME_MANAGED "managed"
::constant NAME_UNKNOWN "unknown"
::method fromName class
  use arg valueArg
  if valueArg == .nil then return self~UNMANAGED
  value = valueArg~string~strip~lower
  if value == "" | value == self~NAME_UNMANAGED then return self~UNMANAGED
  if value == self~NAME_MANAGED then return self~MANAGED
  return -1
::method name class
  use arg valueArg
  value = valueArg + 0
  if value == self~UNMANAGED then return self~NAME_UNMANAGED
  if value == self~MANAGED then return self~NAME_MANAGED
  return self~NAME_UNKNOWN

::class QueueWLUContract public
::constant API_VERSION "work.load.units/0.12"
::constant MICRO_PER_WLU 1000000
::constant HOLD_CLASS "QUEUEREXX_WLU_HOLD"

::class QueueWLUProjectionState public
::constant UNMANAGED 0
::constant DECLARED 1
::constant ACTIVE 2
::constant SETTLED 3
::constant RELEASED 4
::constant EXPIRED 5
::constant UNKNOWN 6
::constant NAME_UNMANAGED "unmanaged"
::constant NAME_DECLARED "declared"
::constant NAME_ACTIVE "active"
::constant NAME_SETTLED "settled"
::constant NAME_RELEASED "released"
::constant NAME_EXPIRED "expired"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg value
  select
    when value == self~UNMANAGED then return self~NAME_UNMANAGED
    when value == self~DECLARED then return self~NAME_DECLARED
    when value == self~ACTIVE then return self~NAME_ACTIVE
    when value == self~SETTLED then return self~NAME_SETTLED
    when value == self~RELEASED then return self~NAME_RELEASED
    when value == self~EXPIRED then return self~NAME_EXPIRED
    otherwise return self~NAME_UNKNOWN
  end

::class QueueWLURequirement public
::attribute mode get
::attribute identity get
::attribute scope get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute targetSeconds get
::attribute requestedRateMicroWluPerSecond get
::method init
  expose mode identity scope expectedMicroWlu ceilingMicroWlu targetSeconds requestedRateMicroWluPerSecond
  use arg modeArg = (.QueueWLUMode~UNMANAGED), identityArg = "", scopeArg = "", expectedArg = 0, ceilingArg = .nil, targetArg = 0, rateArg = .nil
  numeric digits 30
  if modeArg~string~datatype("W") then mode = modeArg + 0
  else mode = .QueueWLUMode~fromName(modeArg)
  identity = identityArg~string~strip
  scope = scopeArg~string~strip
  expectedMicroWlu = expectedArg + 0
  if ceilingArg == .nil then ceilingMicroWlu = expectedMicroWlu
  else ceilingMicroWlu = ceilingArg + 0
  targetSeconds = targetArg + 0
  if rateArg == .nil then do
    if targetSeconds > 0 & expectedMicroWlu > 0 then requestedRateMicroWluPerSecond = (expectedMicroWlu + targetSeconds - 1) % targetSeconds
    else requestedRateMicroWluPerSecond = 0
  end
  else requestedRateMicroWluPerSecond = rateArg + 0
::method managed
  expose mode
  return mode == .QueueWLUMode~MANAGED
::method valid
  expose mode identity scope expectedMicroWlu ceilingMicroWlu targetSeconds requestedRateMicroWluPerSecond
  if mode == .QueueWLUMode~UNMANAGED then return .true
  if mode \= .QueueWLUMode~MANAGED then return .false
  if identity == "" | scope == "" then return .false
  if \expectedMicroWlu~string~datatype("W") | expectedMicroWlu <= 0 then return .false
  if \ceilingMicroWlu~string~datatype("W") | ceilingMicroWlu < expectedMicroWlu then return .false
  if \targetSeconds~string~datatype("W") | targetSeconds < 0 then return .false
  if \requestedRateMicroWluPerSecond~string~datatype("W") | requestedRateMicroWluPerSecond < 0 then return .false
  if targetSeconds > 0 & requestedRateMicroWluPerSecond == 0 then return .false
  return .true
::method asDirectory
  expose mode identity scope expectedMicroWlu ceilingMicroWlu targetSeconds requestedRateMicroWluPerSecond
  d = .Directory~new
  d["mode"] = .QueueWLUMode~name(mode)
  d["managed"] = .QueueRexxUtil~jsonBoolean(mode == .QueueWLUMode~MANAGED)
  d["api_version"] = .QueueWLUContract~API_VERSION
  if mode == .QueueWLUMode~MANAGED then do
    d["identity"] = identity
    d["scope"] = scope
    d["expected_micro_wlu"] = expectedMicroWlu
    d["ceiling_micro_wlu"] = ceilingMicroWlu
    d["target_seconds"] = targetSeconds
    d["requested_rate_micro_wlu_per_second"] = requestedRateMicroWluPerSecond
  end
  return d
::method unmanaged class
  return self~new(.QueueWLUMode~UNMANAGED)
::method managedDemand class
  use strict arg identity, scope, expectedMicroWlu, ceilingMicroWlu = .nil, targetSeconds = 0, requestedRateMicroWluPerSecond = .nil
  return self~new(.QueueWLUMode~MANAGED, identity, scope, expectedMicroWlu, ceilingMicroWlu, targetSeconds, requestedRateMicroWluPerSecond)
::method fromRecord class
  use strict arg record
  modeName = record~field(.QueueRecord~FIELD_WLU_MODE, .QueueWLUMode~NAME_UNMANAGED)
  mode = .QueueWLUMode~fromName(modeName)
  if mode \= .QueueWLUMode~MANAGED then return self~unmanaged
  expected = record~field(.QueueRecord~FIELD_WLU_EXPECTED_MICRO_WLU, "0")
  ceiling = record~field(.QueueRecord~FIELD_WLU_CEILING_MICRO_WLU, expected)
  target = record~field(.QueueRecord~FIELD_WLU_TARGET_SECONDS, "0")
  rate = record~field(.QueueRecord~FIELD_WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND, "0")
  return self~new(mode, record~field(.QueueRecord~FIELD_WLU_IDENTITY, ""), record~field(.QueueRecord~FIELD_WLU_SCOPE, ""), expected, ceiling, target, rate)

::class QueueCommandName public
::constant VERSION "version"
::constant LIST "list"
::constant LIST_SHORT "ls"
::constant EXPLAIN "explain"
::constant PROVIDERS "providers"
::constant PROVIDER_PLAN "provider-plan"
::constant HEALTH "health"
::constant OBSERVE "observe"
::constant DIAGNOSE "diagnose"
::constant RUNTIME_STATUS "runtime-status"
::constant RUNTIME_SCAN "runtime-scan"
::constant PROVIDER_HEALTH "provider-health"
::constant POLICY_CHECK "policy-check"

::class QueueOption public
::constant JSON "--json"
::constant JSON_SHORT "-j"
::constant STATE "--state"
::constant STATE_SHORT "-s"
::constant FIX "--fix"
::constant DEEP "--deep"

::class QueueSchema public
::constant HEALTH "queuebash.health.v1"
::constant VERSION "queuerexx.version.v1"
::constant EXPLAIN_READONLY "queuerexx.explain.readonly.v1"
::constant PROVIDER_REGISTRY "queuerexx.provider_registry.v1"
::constant PROVIDER_DECISION "queuerexx.provider_decision.v1"
::constant JOB_OBSERVATION "queuerexx.job_observation.v1"
::constant SUBMIT "queuebash.submit_result.v1"
::constant OPERATION "queuerexx.operation_result.v1"
::constant DIAGNOSIS "queuerexx.diagnosis.v1"
::constant MIGRATION_STATUS_PROJECTION "queuerexx.migration_status_projection.v1"
::constant JOB_STATUS_PROJECTION "queuerexx.job_status_projection.v1"
::constant WLU_PROJECTION "queuerexx.wlu_projection.v1"
::constant WLU_LIFECYCLE "queuerexx.wlu_lifecycle.v1"
::constant EXECUTION "queuerexx.execution.v1"
::constant SCHEDULING "queuerexx.scheduling.v1"
::constant RUNTIME_STATUS "queuerexx.runtime_status.v1"
::constant RUNTIME_SCAN "queuerexx.runtime_scan.v1"
::constant RUNTIME_RECOVERY "queuerexx.runtime_recovery.v1"
::constant PROVIDER_HEALTH "queuerexx.provider_health.v1"
::constant TRIGGER_DELIVERY "queuerexx.trigger_delivery.v1"
::constant FLEET_RECOVERY "queuerexx.fleet_recovery.v1"
::constant WLU_BRIDGE "queuerexx.wlu_bridge.v1"
::constant POLICY_ASSESSMENT "queuerexx.policy_assessment.v1"

::class QueueRexxUtil public
::method baseName class
  use arg path
  p = path~lastpos("/")
  if p = 0 then return path
  return path~substr(p + 1)

::method stripJobSuffix class
  use arg name
  if name~right(4) == ".job" then return name~left(name~length - 4)
  return name

::method jsonBoolean class
  use arg value
  if value == .true | value == 1 | value~string~lower == "true" then return .JSONBoolean~true
  return .JSONBoolean~false

::method currentUser class
  u = value("USER",, "ENVIRONMENT")
  if u = "" then u = value("LOGNAME",, "ENVIRONMENT")
  if u = "" then u = "unknown"
  return u

::method shellOutput class
  use arg command
  out = .Array~new
  err = .Array~new
  address system command with output using (out) error using (err)
  if rc \= 0 | out~items = 0 then return ""
  return out[1]~strip

::method cleanSystemdUnit class
  use arg unitArg
  unit = unitArg~string
  p = unit~pos("; invocation ID:")
  if p > 0 then unit = unit~left(p - 1)
  p = unit~pos(" invocation ID:")
  if p > 0 then unit = unit~left(p - 1)
  return unit~strip

/* QueueBash timestamps are ISO-8601 with an explicit numeric zone.  Use the
 * ooRexx DateTime class rather than shelling out to `date`. */
::class QueueTime public
::constant FRACTION_DIGITS 6

::method parseQueueIso class
  use arg textArg
  signal on syntax name invalidDate
  if textArg == .nil then return .nil
  text = textArg~string~strip
  if text == "" then return .nil

  offsetMinutes = .nil
  core = text
  if core~right(1)~upper == "Z" then do
    core = core~left(core~length - 1)
    offsetMinutes = 0
  end
  else if core~length >= 6 then do
    zonePos = core~length - 5
    signChar = core~substr(zonePos, 1)
    if (signChar == "+" | signChar == "-") & core~substr(zonePos + 3, 1) == ":" then do
      hh = core~substr(zonePos + 1, 2)
      mm = core~substr(zonePos + 4, 2)
      if hh~datatype("W") & mm~datatype("W") then do
        offsetMinutes = (hh + 0) * 60 + (mm + 0)
        if signChar == "-" then offsetMinutes = -offsetMinutes
        core = core~left(zonePos - 1)
      end
    end
  end

  dotPos = core~pos(".")
  if dotPos = 0 then core = core || ".000000"
  else do
    fraction = core~substr(dotPos + 1)
    if fraction~length < self~FRACTION_DIGITS then fraction = fraction || copies("0", self~FRACTION_DIGITS - fraction~length)
    if fraction~length > self~FRACTION_DIGITS then fraction = fraction~left(self~FRACTION_DIGITS)
    core = core~left(dotPos) || fraction
  end

  if offsetMinutes == .nil then return .DateTime~fromIsoDate(core)
  return .DateTime~fromIsoDate(core, offsetMinutes)
invalidDate:
  return .nil

::method ageSeconds class
  use arg textArg, nowArg = .nil
  parsed = self~parseQueueIso(textArg)
  if parsed == .nil then return .nil
  if nowArg == .nil then now = .DateTime~new
  else now = nowArg
  span = now - parsed
  return span~totalSeconds

::class QueueShellQuoteCodec public
::method decodeScalar class
  use arg raw
  if raw == .nil then return ""
  s = raw~string~strip
  if s = "" then return ""
  out = ""
  i = 1
  mode = "plain"
  do while i <= s~length
    c = s~substr(i, 1)
    if mode = "plain" then do
      if c = "'" then mode = "single"
      else if c = '"' then mode = "double"
      else if c = "$" & i < s~length & s~substr(i + 1, 1) = "'" then do
        j = self~findQuoteEnd(s, i + 2, "ansi")
        if j = 0 then return s
        out = out || self~decodeAnsiC(s~substr(i + 2, j - (i + 2)))
        i = j
      end
      else if c = "\" then do
        if i < s~length then do
          i = i + 1
          out = out || s~substr(i, 1)
        end
        else out = out || c
      end
      else out = out || c
    end
    else if mode = "single" then do
      if c = "'" then mode = "plain"
      else out = out || c
    end
    else if mode = "double" then do
      if c = '"' then mode = "plain"
      else if c = "\" & i < s~length then do
        i = i + 1
        out = out || s~substr(i, 1)
      end
      else out = out || c
    end
    i = i + 1
  end
  return out

::method findQuoteEnd class private
  use arg text, startAt, kind
  escaped = .false
  do i = startAt to text~length
    c = text~substr(i, 1)
    if kind = "ansi" then do
      if escaped then escaped = .false
      else if c = "\" then escaped = .true
      else if c = "'" then return i
    end
    else if c = "'" then return i
  end
  return 0

::method decodeAnsiC class private
  use arg body
  out = ""
  i = 1
  do while i <= body~length
    c = body~substr(i, 1)
    if c \= "\" then out = out || c
    else if i = body~length then out = out || "\"
    else do
      i = i + 1
      e = body~substr(i, 1)
      select
        when e = "n" then out = out || "0A"x
        when e = "r" then out = out || "0D"x
        when e = "t" then out = out || "09"x
        when e = "b" then out = out || "08"x
        when e = "f" then out = out || "0C"x
        when e = "v" then out = out || "0B"x
        when e = "a" then out = out || "07"x
        when e = "e" | e = "E" then out = out || "1B"x
        when e = "\" then out = out || "\"
        when e = "'" then out = out || "'"
        when e = '"' then out = out || '"'
        when e = "x" then do
          hex = ""
          do k = 1 to 2 while i < body~length
            n = body~substr(i + 1, 1)
            if \n~datatype("X") then leave
            hex = hex || n
            i = i + 1
          end
          if hex = "" then out = out || "x"
          else out = out || x2c(hex)
        end
        otherwise do
          if e >= "0" & e <= "7" then do
            oct = e
            do k = 2 to 3 while i < body~length
              n = body~substr(i + 1, 1)
              if n < "0" | n > "7" then leave
              oct = oct || n
              i = i + 1
            end
            dec = 0
            do k = 1 to oct~length
              dec = dec * 8 + (oct~substr(k, 1) + 0)
            end
            out = out || d2c(dec)
          end
          else out = out || e
        end
      end
    end
    i = i + 1
  end
  return out

::method arrayRawBody class
  use arg raw
  if raw == .nil then return ""
  s = raw~string~strip
  if s~left(1) = "(" & s~right(1) = ")" then return s~substr(2, s~length - 2)~strip
  return s

::method decodeArray class
  use arg raw
  body = self~arrayRawBody(raw)
  arr = .Array~new
  token = ""
  mode = "plain"
  escaped = .false
  i = 1
  do while i <= body~length
    c = body~substr(i, 1)
    if mode = "plain" then do
      if c = " " | c = "09"x then do
        if token \= "" then do
          arr~append(self~decodeScalar(token))
          token = ""
        end
      end
      else do
        token = token || c
        if c = "\" then do
          if i < body~length then do
            i = i + 1
            token = token || body~substr(i, 1)
          end
        end
        else if c = "'" then mode = "single"
        else if c = '"' then mode = "double"
        else if c = "$" & i < body~length & body~substr(i + 1, 1) = "'" then do
          i = i + 1
          token = token || "'"
          mode = "ansi"
          escaped = .false
        end
      end
    end
    else do
      token = token || c
      if mode = "ansi" then do
        if escaped then escaped = .false
        else if c = "\" then escaped = .true
        else if c = "'" then mode = "plain"
      end
      else if mode = "single" then do
        if c = "'" then mode = "plain"
      end
      else if mode = "double" then do
        if c = "\" & i < body~length then do
          i = i + 1
          token = token || body~substr(i, 1)
        end
        else if c = '"' then mode = "plain"
      end
    end
    i = i + 1
  end
  if token \= "" then arr~append(self~decodeScalar(token))
  return arr


::class QueueRecord public
::constant FIELD_JOB_ID "JOB_ID"
::constant FIELD_JOB_NAME "JOB_NAME"
::constant FIELD_JOB_CLASS "JOB_CLASS"
::constant FIELD_PRIORITY "PRIORITY"
::constant FIELD_COMMAND "COMMAND"
::constant FIELD_ON_SUCCESS "ON_SUCCESS"
::constant FIELD_ON_FAILURE "ON_FAILURE"
::constant FIELD_ON_RETRY_FAILURE "ON_RETRY_FAILURE"
::constant FIELD_RETRIES_MAX "RETRIES_MAX"
::constant FIELD_RETRIES_DONE "RETRIES_DONE"
::constant FIELD_RETRY_BACKOFF "RETRY_BACKOFF"
::constant FIELD_RETRY_NOT_BEFORE_EPOCH "RETRY_NOT_BEFORE_EPOCH"
::constant FIELD_NOT_BEFORE_EPOCH "NOT_BEFORE_EPOCH"
::constant FIELD_MAX_LOG_SIZE_BYTES "MAX_LOG_SIZE_BYTES"
::constant FIELD_ALLOW_LARGE_LOG "ALLOW_LARGE_LOG"
::constant FIELD_LOG_OVERFLOW_POLICY "LOG_OVERFLOW_POLICY"
::constant FIELD_SECURITY_SANDBOX_EXPLICIT "SECURITY_SANDBOX_EXPLICIT"
::constant FIELD_SECURITY_SECCOMP_EXPLICIT "SECURITY_SECCOMP_EXPLICIT"
::constant FIELD_PWD_AT_SUBMIT "PWD_AT_SUBMIT"
::constant FIELD_SUBMITTED_AT "SUBMITTED_AT"
::constant FIELD_RUN_STARTED_AT "RUN_STARTED_AT"
::constant FIELD_EXEC_FINISHED_AT "EXEC_FINISHED_AT"
::constant FIELD_FINISHED_AT "FINISHED_AT"
::constant FIELD_EXIT_CODE "EXIT_CODE"
::constant FIELD_RUNNER "RUNNER"
::constant FIELD_RUNNER_USED "RUNNER_USED"
::constant FIELD_RUN_USER "RUN_USER"
::constant FIELD_RUN_PID "RUN_PID"
::constant FIELD_RUN_PGID "RUN_PGID"
::constant FIELD_SYSTEMD_UNIT "SYSTEMD_UNIT"
::constant FIELD_CPU_LIMIT "CPU_LIMIT"
::constant FIELD_MEM_LIMIT "MEM_LIMIT"
::constant FIELD_SANDBOX_LEVEL "SANDBOX_LEVEL"
::constant FIELD_SECCOMP_PROFILE "SECCOMP_PROFILE"
::constant FIELD_INTERRUPTED_REASON "INTERRUPTED_REASON"
::constant FIELD_POLICY_BLOCKED_REASON "POLICY_BLOCKED_REASON"
::constant FIELD_RECONCILED_FROM "RECONCILED_FROM"
::constant FIELD_WLU_MODE "WLU_MODE"
::constant FIELD_WLU_API_VERSION "WLU_API_VERSION"
::constant FIELD_WLU_IDENTITY "WLU_IDENTITY"
::constant FIELD_WLU_SCOPE "WLU_SCOPE"
::constant FIELD_WLU_EXPECTED_MICRO_WLU "WLU_EXPECTED_MICRO_WLU"
::constant FIELD_WLU_CEILING_MICRO_WLU "WLU_CEILING_MICRO_WLU"
::constant FIELD_WLU_TARGET_SECONDS "WLU_TARGET_SECONDS"
::constant FIELD_WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND "WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND"
::constant FIELD_WLU_ORIGINAL_JOB_CLASS "WLU_ORIGINAL_JOB_CLASS"
::constant FIELD_EXECUTION_ID "QUEUEREXX_EXECUTION_ID"
::constant FIELD_EXECUTION_EXIT_FILE "QUEUEREXX_EXECUTION_EXIT_FILE"
::constant FIELD_EXECUTION_PID_FILE "QUEUEREXX_EXECUTION_PID_FILE"

::attribute path get
::attribute root get
::attribute state get
::attribute fields get
::attribute rawFields get
::attribute arrays get
::attribute rawLines get

::method init
  expose path root state fields rawFields arrays rawLines
  use arg pathArg, stateArg = .nil, rootArg = ""
  if stateArg == .nil then stateArg = .QueueState~UNKNOWN
  path = pathArg~string
  root = rootArg~string
  state = .QueueState~coerce(stateArg)
  fields = .Directory~new
  rawFields = .Directory~new
  arrays = .Directory~new
  rawLines = .Array~new
  self~load

::method load private
  expose path fields rawFields arrays rawLines
  s = .Stream~new(path)
  openState = s~open("READ")
  if openState \= "READY:" then return
  do while s~lines > 0
    line = s~lineIn
    rawLines~append(line)
    p = line~pos("=")
    if p <= 1 then iterate
    key = line~left(p - 1)~strip~upper
    if key = "" then iterate
    raw = line~substr(p + 1)
    rawFields[key] = raw
    trimmed = raw~strip
    if trimmed~left(1) = "(" & trimmed~right(1) = ")" then do
      arrays[key] = .QueueShellQuoteCodec~decodeArray(trimmed)
      fields[key] = .QueueShellQuoteCodec~arrayRawBody(trimmed)
    end
    else fields[key] = .QueueShellQuoteCodec~decodeScalar(raw)
  end
  s~close

::method field
  expose fields
  use arg key, defaultValue = ""
  k = key~string~upper
  if fields~hasIndex(k) then return fields[k]
  return defaultValue

::method rawField
  expose rawFields
  use arg key, defaultValue = ""
  k = key~string~upper
  if rawFields~hasIndex(k) then return rawFields[k]
  return defaultValue

::method arrayField
  expose arrays
  use arg key
  k = key~string~upper
  if arrays~hasIndex(k) then return arrays[k]
  return .Array~new

::method hasArrayField
  expose arrays
  use arg key
  return arrays~hasIndex(key~string~upper)

::method qid
  expose path
  id = self~field(self~FIELD_JOB_ID, "")
  if id \= "" then return id
  return .QueueRexxUtil~stripJobSuffix(.QueueRexxUtil~baseName(path))

::method name
  return self~field(self~FIELD_JOB_NAME, "")

::method jobClass
  return self~field(self~FIELD_JOB_CLASS, .QueueJobClass~DEFAULT)
::method effectiveJobClass
  wlu = self~wluRequirement
  if wlu~managed then do
    original = self~field(self~FIELD_WLU_ORIGINAL_JOB_CLASS, "")
    if original \= "" then return original
  end
  return self~jobClass

::method priority
  p = self~field(self~FIELD_PRIORITY, "10")
  if \p~datatype("N") then return 10
  return p + 0

::method stateName
  expose state
  return .QueueState~name(state)

::method commandLine
  raw = self~rawField(self~FIELD_COMMAND, "")~strip
  if raw == "" then return ""
  return .QueueShellQuoteCodec~arrayRawBody(raw)

::method hasHook
  use arg fieldName
  a = self~arrayField(fieldName)
  do x over a
    if x~string \= "" then return .true
  end
  return .false

::method systemdUnit
  expose root
  unit = self~field(self~FIELD_SYSTEMD_UNIT, "")
  if unit == "" & root \= "" then do
    logPath = root || "/logs/" || self~qid || ".log"
    if SysFileExists(logPath) then do
      s = .Stream~new(logPath)
      if s~open("READ") == "READY:" then do
        do while s~lines > 0
          line = s~lineIn
          prefix = "Running as unit:"
          if line~left(prefix~length) == prefix then do
            unit = line~substr(prefix~length + 1)~strip
            leave
          end
        end
        s~close
      end
    end
  end
  return .QueueRexxUtil~cleanSystemdUnit(unit)

::method wluRequirement
  return .QueueWLURequirement~fromRecord(self)

::method summary
  expose path
  d = .Directory~new
  d["qid"] = self~qid
  d["state"] = self~stateName
  d["priority"] = self~priority
  d["name"] = self~name
  d["class"] = self~jobClass
  d["ok_hook"] = .QueueRexxUtil~jsonBoolean(self~hasHook(self~FIELD_ON_SUCCESS))
  d["fail_hook"] = .QueueRexxUtil~jsonBoolean(self~hasHook(self~FIELD_ON_FAILURE))
  d["command_line"] = self~commandLine
  times = .Directory~new
  times["submitted_at"] = self~field(self~FIELD_SUBMITTED_AT, "")
  times["run_started_at"] = self~field(self~FIELD_RUN_STARTED_AT, "")
  finished = self~field(self~FIELD_EXEC_FINISHED_AT, "")
  if finished == "" then finished = self~field(self~FIELD_FINISHED_AT, "")
  times["finished_at"] = finished
  d["times"] = times
  d["rc"] = self~field(self~FIELD_EXIT_CODE, "")
  d["job_file"] = path
  return d

::method explainSummary
  expose path
  d = .Directory~new
  d["qid"] = self~qid
  d["name"] = self~name
  d["state"] = self~stateName
  d["class"] = self~jobClass
  d["priority"] = self~priority
  d["command_line"] = self~commandLine
  times = .Directory~new
  times["submitted_at"] = self~field(self~FIELD_SUBMITTED_AT, "")
  times["run_started_at"] = self~field(self~FIELD_RUN_STARTED_AT, "")
  finished = self~field(self~FIELD_EXEC_FINISHED_AT, "")
  if finished == "" then finished = self~field(self~FIELD_FINISHED_AT, "")
  times["finished_at"] = finished
  d["times"] = times
  pids = .Directory~new
  pids["run_pid"] = self~field(self~FIELD_RUN_PID, "")
  pids["run_pgid"] = self~field(self~FIELD_RUN_PGID, "")
  pids["systemd_unit"] = self~systemdUnit
  d["pids"] = pids
  d["runner_requested"] = self~field(self~FIELD_RUNNER, .QueueRunnerKind~AUTO)
  d["runner_used"] = self~field(self~FIELD_RUNNER_USED, "")
  d["job_file"] = path
  return d


::class QueueStateStore public
::attribute root get
::method init
  expose root
  use arg rootArg
  root = rootArg~string

::method stateValues class
  return .QueueState~values

::method records
  expose root
  use arg requestedState = .nil, maxRecords = 0
  if requestedState == .nil then requestedState = .QueueState~ALL
  requested = .QueueState~coerce(requestedState)
  arr = .Array~new
  stopScan = .false
  do stateValue over .QueueState~values
    if stopScan then leave
    if requested \= .QueueState~ALL & requested \= stateValue then iterate
    stateName = .QueueState~name(stateValue)
    dir = root || "/" || stateName
    if \SysFileExists(dir) then iterate
    drop qrxfiles.
    call SysFileTree dir || "/*", "qrxfiles.", "FSO"
    do i = 1 to qrxfiles.0
      p = qrxfiles.i
      if p~right(4) \= ".job" then iterate
      arr~append(.QueueRecord~new(p, stateValue, root))
      if maxRecords > 0 & arr~items >= maxRecords then do
        stopScan = .true
        leave
      end
    end
  end
  return arr

::method findAll
  use arg qid
  arr = .Array~new
  do record over self~records(.QueueState~ALL)
    if record~qid == qid then arr~append(record)
  end
  return arr

::method findOne
  use arg qid
  all = self~findAll(qid)
  if all~items = 0 then return .nil
  return all[1]


::class QueueJobRequirement public
::attribute requestedRunner get
::attribute runUser get
::attribute cpuLimit get
::attribute memLimit get
::attribute sandboxLevel get
::attribute seccompProfile get
::attribute jobClass get
::attribute wluRequirement get
::method init
  expose requestedRunner runUser cpuLimit memLimit sandboxLevel seccompProfile jobClass wluRequirement
  use arg runnerArg = .nil, runUserArg = "", cpuArg = "", memArg = "", sandboxArg = "", seccompArg = "", classArg = "DEFAULT", wluArg = .nil
  if runnerArg == .nil then runnerArg = .QueueRunnerKind~AUTO
  requestedRunner = runnerArg~string~lower
  if requestedRunner = "" then requestedRunner = .QueueRunnerKind~AUTO
  runUser = runUserArg~string
  cpuLimit = cpuArg~string
  memLimit = memArg~string
  sandboxLevel = sandboxArg~string
  seccompProfile = seccompArg~string
  jobClass = classArg~string
  if wluArg == .nil then wluRequirement = .QueueWLURequirement~unmanaged
  else wluRequirement = wluArg

::method fromRecord class
  use arg record
  return self~new(record~field(.QueueRecord~FIELD_RUNNER, .QueueRunnerKind~AUTO), record~field(.QueueRecord~FIELD_RUN_USER, ""), record~field(.QueueRecord~FIELD_CPU_LIMIT, ""), record~field(.QueueRecord~FIELD_MEM_LIMIT, ""), record~field(.QueueRecord~FIELD_SANDBOX_LEVEL, ""), record~field(.QueueRecord~FIELD_SECCOMP_PROFILE, ""), record~effectiveJobClass, record~wluRequirement)

::method asDirectory
  expose requestedRunner runUser cpuLimit memLimit sandboxLevel seccompProfile jobClass wluRequirement
  d = .Directory~new
  d["requested_runner"] = requestedRunner
  d["run_user"] = runUser
  d["cpu_limit"] = cpuLimit
  d["mem_limit"] = memLimit
  d["sandbox_level"] = sandboxLevel
  d["seccomp_profile"] = seccompProfile
  d["class"] = jobClass
  d["wlu"] = wluRequirement~asDirectory
  return d


::class QueuePlatformFacts public
::constant OS_LINUX "linux"
::constant OS_UNKNOWN "unknown"
::attribute osFamily get
::attribute currentUser get
::attribute uid get
::attribute systemdUserAvailable get
::attribute systemdProbeKnown get
::method init
  expose osFamily currentUser uid systemdUserAvailable systemdProbeKnown
  use arg osArg = .nil, userArg = "unknown", uidArg = "-1", systemdArg = .false, knownArg = .true
  if osArg == .nil then osArg = self~OS_LINUX
  osFamily = osArg~string~lower
  currentUser = userArg~string
  uid = uidArg + 0
  systemdUserAvailable = systemdArg
  systemdProbeKnown = knownArg

::method rootLaunchingForeignUser
  expose uid currentUser
  use arg runUser
  if uid \= 0 then return .false
  if runUser == .nil | runUser~string = "" then return .false
  return runUser~string \= currentUser

::method probeLocal class
  user = .QueueRexxUtil~currentUser
  uidText = .QueueRexxUtil~shellOutput("id -u 2>/dev/null")
  uid = -1
  if uidText~datatype("W") then uid = uidText + 0
  os = .QueueRexxUtil~shellOutput("uname -s 2>/dev/null")~lower
  if os = "" then os = self~OS_UNKNOWN
  out = .Array~new
  err = .Array~new
  address system "systemctl --user show-environment >/dev/null 2>&1" with output using (out) error using (err)
  systemdAvailable = (rc = 0)
  return self~new(os, user, uid, systemdAvailable, .true)

::method asDirectory
  expose osFamily currentUser uid systemdUserAvailable systemdProbeKnown
  d = .Directory~new
  d["os_family"] = osFamily
  d["current_user"] = currentUser
  d["uid"] = uid
  d["systemd_user_available"] = .QueueRexxUtil~jsonBoolean(systemdUserAvailable)
  d["systemd_probe_known"] = .QueueRexxUtil~jsonBoolean(systemdProbeKnown)
  return d

::requires "json.cls"
