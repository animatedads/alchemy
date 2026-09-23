/* Durable work plans for a stateless LLM. State is reconstructed from
 * append-only events; a completion claim retains its evidence classification. */

::class LlmPaPlanStore public
::attribute path get
::method init
  expose path
  use arg pathArg
  path = pathArg~string~strip
  if path = "" then raise syntax 88.900 array("plan journal path is required")

::method appendEvent
  expose path
  use arg event
  fields = .array~of("event", "plan_id")
  do field over fields
    if \event~hasIndex(field) then return .LlmPaResult~failure("PLAN_EVENT_FIELD_REQUIRED", field)
  end
  names = .array~of("event", "plan_id", "item_id", "title", "objective", "status", "evidence", "note")
  line = .LlmPaUtil~timestamp
  do name over names
    value = ""
    if event~hasIndex(name) then value = event[name]
    line = line || "09"x || c2x(value~string)
  end
  call lineout path, line
  call lineout path
  return .LlmPaResult~success(.true)

::method readEvents
  expose path
  out = .array~new
  line = linein(path)
  do while line \= ""
    fields = line~makeArray("09"x)
    if fields \== .nil & fields~items >= 2 then do
      event = .directory~new
      event["timestamp"] = fields[1]
      names = .array~of("event", "plan_id", "item_id", "title", "objective", "status", "evidence", "note")
      do i = 1 to names~items
        value = ""
        if i + 1 <= fields~items then value = x2c(fields[i + 1])
        event[names[i]] = value
      end
      out~append(event)
    end
    line = linein(path)
  end
  ignore = stream(path, "C", "CLOSE")
  return out

::class LlmPaPlanManager public
::attribute path get
::method init
  expose store plans
  use arg storeArg
  store = storeArg
  plans = .table~new
  events = store~readEvents
  do event over events
    ignore = self~applyEvent(event)
  end

::method create
  expose store plans
  use arg titleArg, objectiveArg = "", sourceArg = "codex"
  title = titleArg~string~strip
  objective = objectiveArg~string~strip
  if title = "" then return .LlmPaResult~failure("PLAN_TITLE_REQUIRED")
  planId = "plan-" || date("S") || "-" || time("L")~changestr(":", "") || "-" || random(1000,9999)
  event = .directory~new
  event["event"] = "CREATE"
  event["plan_id"] = planId
  event["title"] = title
  event["objective"] = objective
  event["status"] = "ACTIVE"
  event["evidence"] = "operator:" || sourceArg~string
  written = store~appendEvent(event)
  if \written~ok then return written
  ignore = self~applyEvent(event)
  return .LlmPaResult~success(self~copyPlan(plans[planId]))

::method addItem
  expose store plans
  use arg planIdArg, textArg, dependsArg = ""
  planId = planIdArg~string~strip
  if \plans~hasIndex(planId) then return .LlmPaResult~failure("PLAN_NOT_FOUND", planId)
  text = textArg~string~strip
  if text = "" then return .LlmPaResult~failure("PLAN_ITEM_REQUIRED")
  itemId = "item-" || random(100000,999999)
  event = .directory~new
  event["event"] = "ADD_ITEM"
  event["plan_id"] = planId
  event["item_id"] = itemId
  event["title"] = text
  event["note"] = dependsArg~string
  written = store~appendEvent(event)
  if \written~ok then return written
  ignore = self~applyEvent(event)
  return .LlmPaResult~success(self~copyPlan(plans[planId]))

::method tick
  expose store plans
  use arg planIdArg, itemIdArg, statusArg = "DONE", evidenceArg = "told_done", noteArg = ""
  planId = planIdArg~string~strip
  itemId = itemIdArg~string~strip
  if \plans~hasIndex(planId) then return .LlmPaResult~failure("PLAN_NOT_FOUND", planId)
  status = statusArg~string~upper~strip
  allowed = .array~of("TODO", "IN_PROGRESS", "DONE", "BLOCKED", "CANCELLED")
  if allowed~hasItem(status) = 0 then return .LlmPaResult~failure("PLAN_STATUS_INVALID", status)
  item = self~findItem(plans[planId], itemId)
  if item == .nil then return .LlmPaResult~failure("PLAN_ITEM_NOT_FOUND", itemId)
  event = .directory~new
  event["event"] = "TICK"
  event["plan_id"] = planId
  event["item_id"] = itemId
  event["status"] = status
  event["evidence"] = evidenceArg~string~strip
  event["note"] = noteArg~string
  written = store~appendEvent(event)
  if \written~ok then return written
  ignore = self~applyEvent(event)
  return .LlmPaResult~success(self~copyPlan(plans[planId]))

::method list
  expose plans
  out = .array~new
  do id over plans~allIndexes
    out~append(self~copyPlan(plans[id]))
  end
  return .LlmPaResult~success(out)

::method similar
  expose plans
  use arg queryArg, limitArg = 5
  query = queryArg~string~lower
  out = .array~new
  do id over plans~allIndexes
    plan = plans[id]
    haystack = plan["title"] || " " || plan["objective"]
    do item over plan["items"]
      haystack = haystack || " " || item["title"]
    end
    score = 0
    do i = 1 to words(query)
      token = word(query, i)
      if token~length >= 3 & haystack~lower~pos(token) > 0 then score += 1
    end
    if score > 0 then do
      row = self~copyPlan(plan)
      row["similarity_score"] = score
      out~append(row)
    end
  end
  return .LlmPaResult~success(out)

::method show
  expose plans
  use arg planIdArg
  planId = planIdArg~string~strip
  if \plans~hasIndex(planId) then return .LlmPaResult~failure("PLAN_NOT_FOUND", planId)
  return .LlmPaResult~success(self~copyPlan(plans[planId]))

::method command
  use arg textArg
  parse var textArg verb rest
  verb = verb~lower
  if verb = "create" then do
    parse var rest title "|" objective
    return self~create(title, objective)
  end
  if verb = "item" then do
    parse var rest planId "|" itemText
    return self~addItem(planId, itemText)
  end
  if verb = "done" | verb = "tick" then do
    parse var rest planId "|" itemId "|" note
    return self~tick(planId, itemId, "DONE", "told_done", note)
  end
  if verb = "verified" then do
    parse var rest planId "|" itemId "|" note
    return self~tick(planId, itemId, "DONE", "tool_verified", note)
  end
  if verb = "similar" then return self~similar(rest)
  if verb = "show" then return self~show(rest)
  if verb = "list" then return self~list
  return .LlmPaResult~failure("PLAN_COMMAND_INVALID", verb)

::method applyEvent private
  expose plans
  use arg event
  planId = event["plan_id"]
  if event["event"] = "CREATE" then do
    plan = .directory~new
    plan["plan_id"] = planId
    plan["title"] = event["title"]
    plan["objective"] = event["objective"]
    plan["status"] = event["status"]
    plan["items"] = .array~new
    plan["created_at"] = event["timestamp"]
    plan["source"] = event["evidence"]
    plans[planId] = plan
  end
  else if event["event"] = "ADD_ITEM" & plans~hasIndex(planId) then do
    item = .directory~new
    item["item_id"] = event["item_id"]
    item["title"] = event["title"]
    item["status"] = "TODO"
    item["evidence"] = ""
    item["note"] = event["note"]
    plans[planId]["items"]~append(item)
  end
  else if event["event"] = "TICK" & plans~hasIndex(planId) then do
    item = self~findItem(plans[planId], event["item_id"])
    if item \== .nil then do
      item["status"] = event["status"]
      item["evidence"] = event["evidence"]
      item["note"] = event["note"]
      item["updated_at"] = event["timestamp"]
    end
  end
  return .true

::method findItem private
  use arg plan, itemId
  do item over plan["items"]
    if item["item_id"] = itemId then return item
  end
  return .nil

::method copyPlan private
  use arg plan
  copy = .LlmPaUtil~copyDirectory(plan)
  copy["items"] = .array~new
  do item over plan["items"]
    copy["items"]~append(.LlmPaUtil~copyDirectory(item))
  end
  return copy

::requires "LlmPaCore.cls"
