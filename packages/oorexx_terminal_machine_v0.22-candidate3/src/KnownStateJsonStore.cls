/* Persistent JSON store for known terminal states v0.1.
 *
 * This is deliberately separate from TerminalCore so the core has no JSON or
 * filesystem dependency.  It stores interpretation/provenance plus frozen
 * exemplar snapshots.  It does not store executable actions or authority.
 */

::class KnownStateJsonBuild public
::constant PRODUCT "ooRexx Known Terminal State JSON Store"
::constant RELEASE "0.1"
::constant SCHEMA "terminal.known-state.catalog/0.1"

::class KnownStateJsonStore public
::method save class
  use arg catalog, path
  root = .directory~new
  root["schema"] = .KnownStateJsonBuild~SCHEMA
  stateArray = .array~new
  states = catalog~states
  do state over states
    stateArray~append(self~stateToObject(state))
  end
  root["states"] = stateArray
  text = .JSON~toJSON(root)
  stream = .Stream~new(path~string)
  opened = stream~open("WRITE REPLACE")
  if left(opened, 6) \== "READY:" then return .TerminalResult~failure("STATE_STORE_OPEN", opened)
  stream~charOut(text)
  stream~close
  return .TerminalResult~success(path~string)

::method load class
  use arg path
  stream = .Stream~new(path~string)
  opened = stream~open("READ")
  if left(opened, 6) \== "READY:" then return .TerminalResult~failure("STATE_STORE_OPEN", opened)
  count = stream~chars
  text = ""
  if count > 0 then text = stream~charIn(, count)
  stream~close
  signal on syntax name parseError
  root = .JSON~fromJSON(text)
  signal off syntax
  if root["schema"] \== .KnownStateJsonBuild~SCHEMA then return .TerminalResult~failure("STATE_STORE_SCHEMA", .TerminalUtil~safeString(root["schema"]))
  catalog = .KnownStateCatalog~new
  stateArray = root["states"]
  if stateArray \== .nil then do stateObject over stateArray
    state = self~objectToState(stateObject)
    added = catalog~register(state)
    if \added~ok then return added
  end
  return .TerminalResult~success(catalog)
parseError:
  signal off syntax
  return .TerminalResult~failure("STATE_STORE_JSON", "invalid JSON")

::method stateToObject class private
  use arg state
  d = .directory~new
  d["state_id"] = state~stateId
  d["name"] = state~name
  d["description"] = state~description
  d["created_by"] = state~createdBy
  d["created_at"] = state~createdAt

  criteriaArray = .array~new
  do criterion over state~criteria
    c = .directory~new
    c["id"] = criterion~criterionId
    c["kind"] = criterion~kind
    c["arg1"] = criterion~arg1
    c["arg2"] = criterion~arg2
    if criterion~negate then c["negate"] = 1
    else c["negate"] = 0
    criteriaArray~append(c)
  end
  d["criteria"] = criteriaArray

  annotationArray = .array~new
  do annotation over state~annotations
    a = .directory~new
    a["id"] = annotation~annotationId
    a["author"] = annotation~author
    a["description"] = annotation~description
    a["status"] = annotation~status
    a["timestamp"] = annotation~timestamp
    a["supersedes"] = annotation~supersedes
    annotationArray~append(a)
  end
  d["annotations"] = annotationArray

  transitionArray = .array~new
  do transition over state~transitions
    t = .directory~new
    t["from_state_id"] = transition~fromStateId
    t["action_kind"] = transition~actionKind
    t["action_name"] = transition~actionName
    t["to_state_id"] = transition~toStateId
    t["observation_count"] = transition~observationCount
    t["note"] = transition~note
    transitionArray~append(t)
  end
  d["transitions"] = transitionArray

  exemplarArray = .array~new
  do frozen over state~exemplars
    exemplarArray~append(self~frozenToObject(frozen))
  end
  d["exemplars"] = exemplarArray
  return d

::method frozenToObject class private
  use arg frozen
  d = .directory~new
  d["trace_position"] = frozen~tracePosition
  d["frozen_at"] = frozen~frozenAt
  d["snapshot"] = self~snapshotToObject(frozen~snapshot)
  previous = frozen~previousSnapshot
  if previous \== .nil then d["previous_snapshot"] = self~snapshotToObject(previous)
  return d

::method snapshotToObject class private
  use arg snapshot
  d = .directory~new
  d["generation"] = snapshot~generation
  d["terminal_type"] = snapshot~terminalType
  d["rows"] = snapshot~rows
  d["columns"] = snapshot~columns
  d["cursor_row"] = snapshot~cursorRow
  d["cursor_column"] = snapshot~cursorColumn
  d["keyboard_state"] = snapshot~keyboardState
  d["session_state"] = snapshot~sessionState
  d["content_digest"] = snapshot~contentDigest
  d["layout_fingerprint"] = snapshot~layoutFingerprint
  d["timestamp"] = snapshot~timestamp
  d["text_rows"] = snapshot~textRows
  d["capabilities"] = snapshot~capabilities~names
  d["metadata"] = snapshot~metadata
  fieldArray = .array~new
  do field over snapshot~fields
    f = .directory~new
    f["id"] = field~fieldId
    f["row"] = field~row
    f["column"] = field~column
    f["length"] = field~length
    if field~nonDisplay then f["value"] = "<SECRET>"
    else f["value"] = field~value
    if field~inputCapable then f["input"] = 1; else f["input"] = 0
    if field~protected then f["protected"] = 1; else f["protected"] = 0
    if field~nonDisplay then f["nondisplay"] = 1; else f["nondisplay"] = 0
    if field~modified then f["modified"] = 1; else f["modified"] = 0
    if field~numeric then f["numeric"] = 1; else f["numeric"] = 0
    f["attributes"] = field~attributes
    fieldArray~append(f)
  end
  d["fields"] = fieldArray
  return d

::method objectToState class private
  use arg d
  state = .KnownTerminalState~new(d["state_id"], d["name"], d["description"], d["created_by"])
  criteriaArray = d["criteria"]
  if criteriaArray \== .nil then do c over criteriaArray
    state~addCriterion(.KnownStateCriterion~new(c["id"], c["kind"], c["arg1"], c["arg2"], c["negate"] == 1))
  end
  annotationArray = d["annotations"]
  if annotationArray \== .nil then do a over annotationArray
    state~addAnnotation(.KnownStateAnnotation~new(a["id"], a["author"], a["description"], a["status"], a["supersedes"], a["timestamp"]))
  end
  transitionArray = d["transitions"]
  if transitionArray \== .nil then do t over transitionArray
    state~addTransition(.KnownStateTransition~new(t["from_state_id"], t["action_kind"], t["action_name"], t["to_state_id"], t["observation_count"], t["note"]))
  end
  exemplarArray = d["exemplars"]
  if exemplarArray \== .nil then do e over exemplarArray
    state~addExemplar(self~objectToFrozen(e))
  end
  return state

::method objectToFrozen class private
  use arg d
  snapshot = self~objectToSnapshot(d["snapshot"])
  previous = .nil
  if d["previous_snapshot"] \== .nil then previous = self~objectToSnapshot(d["previous_snapshot"])
  return .FrozenTerminalState~new(snapshot, previous, d["trace_position"])

::method objectToSnapshot class private
  use arg d
  caps = .TerminalCapabilities~new
  capArray = d["capabilities"]
  if capArray \== .nil then do cap over capArray
    caps~add(cap)
  end
  fieldArray = .array~new
  sourceFields = d["fields"]
  if sourceFields \== .nil then do f over sourceFields
    value = f["value"]
    /* Persisted nondisplay exemplars never restore secret bytes. */
    if f["nondisplay"] == 1 then value = ""
    fieldArray~append(.TerminalFieldSnapshot~new(f["id"], f["row"], f["column"], f["length"], value, f["input"] == 1, f["protected"] == 1, f["nondisplay"] == 1, f["modified"] == 1, f["numeric"] == 1, f["attributes"]))
  end
  return .TerminalSnapshot~new(d["generation"], d["terminal_type"], d["rows"], d["columns"], d["cursor_row"], d["cursor_column"], d["keyboard_state"], d["session_state"], d["text_rows"], fieldArray, caps, d["metadata"], d["content_digest"], d["layout_fingerprint"], d["timestamp"])

::requires "TerminalCore.cls"
::requires "json.cls"
