/* RunJournal.cls
   Durable Development Floor run journal.

   Every externally meaningful phase writes both:
   - exact payload artifacts (prompts, model replies, source snapshots, evidence), and
   - append-only structured LogEvent projections in events.jsonl.

   Credentials and secret values are deliberately never accepted by this interface.
*/

::class DFRunJournalBuild public
::constant API_VERSION "development.floor.run-journal/0.1"

::class DFPersistentJsonlLogTarget public
::attribute name get
::attribute scope get
::attribute enabled get

::method init
  expose name scope enabled path
  use strict arg pathArg
  name = "development-floor-run-jsonl"
  scope = "INTERNAL"
  enabled = .true
  path = pathArg~string

::method accept public
  expose enabled path
  use strict arg event
  if \enabled then return .false
  payload = event~payload
  phase = ""; eventName = ""; detail = ""; artifact = ""; artifactSha = ""
  if payload \== .nil then do
    if payload~hasMethod("AT") then do
    if payload~at("phase") \== .nil then phase = payload~at("phase")~string
    if payload~at("event") \== .nil then eventName = payload~at("event")~string
    if payload~at("detail") \== .nil then detail = payload~at("detail")~string
    if payload~at("artifact") \== .nil then artifact = payload~at("artifact")~string
    if payload~at("sha256") \== .nil then artifactSha = payload~at("sha256")~string
    end
  end
  line = '{"schema":"development.floor.run-event/0.1"'
  line ||= ',"event_id":"' || self~escape(event~eventId) || '"'
  line ||= ',"sequence":' || event~sequence
  line ||= ',"occurred_at":"' || self~escape(event~occurredAt) || '"'
  line ||= ',"level":"' || self~escape(event~levelName) || '"'
  line ||= ',"phase":"' || self~escape(phase) || '"'
  line ||= ',"event":"' || self~escape(eventName) || '"'
  line ||= ',"detail":"' || self~escape(detail) || '"'
  line ||= ',"artifact":"' || self~escape(artifact) || '"'
  line ||= ',"sha256":"' || self~escape(artifactSha) || '"}'
  s = .Stream~new(path)
  opened = s~open("WRITE APPEND")
  if opened \= "READY:" then return .false
  ignore = s~lineOut(line)
  ignore = s~close
  return .true

::method escape private
  use strict arg valueArg
  value = valueArg~string
  value = value~changestr('\\', '\\\\')
  value = value~changestr('"', '\\"')
  value = value~changestr("0d"x, '\\r')
  value = value~changestr("0a"x, '\\n')
  value = value~changestr("09"x, '\\t')
  return value

::method enable public
  expose enabled
  enabled = .true
  return self

::method disable public
  expose enabled
  enabled = .false
  return self


::class DFRunJournal public
::method init
  expose runRoot sequence target
  use strict arg runRootArg
  runRoot = runRootArg~string
  sequence = 0
  ignore = self~ensureDirectory(runRoot)
  do dir over .Array~of("session", "plan", "implement", "verify", "review", "management", "provider")
    ignore = self~ensureDirectory(self~joinPath(runRoot, dir))
  end
  target = .DFPersistentJsonlLogTarget~new(self~joinPath(runRoot, "events.jsonl"))

::attribute runRoot get

::method artifactPath public
  expose runRoot
  use strict arg relativePath
  return self~joinPath(runRoot, relativePath)

::method artifact public
  use strict arg relativePath, content
  path = self~artifactPath(relativePath)
  slash = path~lastPos("/")
  if slash > 0 then ignore = self~ensureDirectory(path~left(slash - 1))
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if opened \= "READY:" then return .Array~of(.false, path, "")
  ignore = s~charOut(content)
  ignore = s~close
  sha = self~sha256(path)
  return .Array~of(.true, path, sha)

::method event public
  expose sequence target
  use strict arg phase, eventName, detail="", relativeArtifact="", sha="", level=20
  sequence += 1
  payload = .Directory~new
  payload["phase"] = phase~string
  payload["event"] = eventName~string
  payload["detail"] = detail~string
  payload["artifact"] = relativeArtifact~string
  payload["sha256"] = sha~string
  eventId = "DFRUN-" || sequence
  event = .LogEvent~new(eventId, sequence, level, .Log~INTERNAL, .Log~INTERNAL, "DEVELOPMENT_FLOOR", self, "RUN", phase || "." || eventName, "DF-RUN-JOURNAL", payload)
  return target~accept(event)

::method persist public
  use strict arg phase, eventName, relativeArtifact, content, detail="", level=20
  saved = self~artifact(relativeArtifact, content)
  if saved[1] then do
    ignore = self~event(phase, eventName, detail, relativeArtifact, saved[3], level)
    return saved
  end
  ignore = self~event(phase, "PERSIST_FAILED", saved[2], relativeArtifact, "", .Log~ERROR)
  return saved

::method sha256 public
  use strict arg path
  temp = path || ".sha256.tmp"
  command = "sha256sum -- " || self~shellQuote(path) || " >" || self~shellQuote(temp) || " 2>&1"
  address system command
  commandRc = rc
  if commandRc \= 0 then do
    ignore = SysFileDelete(temp)
    return ""
  end
  s = .Stream~new(temp)
  opened = s~open("READ")
  if opened \= "READY:" then return ""
  line = s~lineIn
  ignore = s~close
  ignore = SysFileDelete(temp)
  return word(line, 1)

::method ensureDirectory private
  use strict arg path
  address system "mkdir -p -- " || self~shellQuote(path)
  return rc = 0

::method joinPath private
  use strict arg left, right
  if left~right(1) = "/" then return left || right
  return left || "/" || right

::method shellQuote private
  use strict arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "LoggingCore.cls"
