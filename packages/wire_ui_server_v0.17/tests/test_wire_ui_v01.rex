/* Acceptance tests for Alchemy Wire UI Server v0.1 core. */
call testMain
exit 0

testMain: procedure
  app = buildApp()
  view = app~view

  /* 1 snapshot */
  snap = view~snapshot
  call expect snap["type"] = .WireUIProtocol~UI_VIEW_SNAPSHOT, "1 snapshot type"
  call expect snap["revision"] = 0, "1 initial revision"

  /* 2/9 definitions according to subscription only */
  defs = app~requiredDefinitions
  call expect defs~items = 2, "2 active subscription supplies exactly two definitions"
  call expect defs[1]["definitionId"] \= "UNSUBSCRIBED", "9 unsubscribed definition absent"
  call expect defs[2]["definitionId"] \= "UNSUBSCRIBED", "9 unsubscribed definition absent #2"

  /* 3/4/5 semantic action -> state -> precise patch */
  msg = actionMessage("m-1", app, "cancel", "SERVICE.CANCEL.BEGIN", 0)
  r = app~receive(msg)
  call expect r~ok, "3 action reaches owning app"
  patches = app~drainOutbound
  call expect patches~items = 1, "4 one precise patch produced"
  p = patches[1]
  call expect p["operations"]~items = 1, "4 one slot operation"
  call expect p["operations"][1]["op"] = "SET_SLOT", "4 SET_SLOT"
  call expect p["operations"][1]["slot"] = "value", "4 status slot"
  call expect p["previousRevision"] = 0 & p["newRevision"] = 1, "5 monotonic revision"

  /* 6 stale action */
  stale = actionMessage("m-2", app, "cancel", "SERVICE.CANCEL.BEGIN", 0)
  r = app~receive(stale)
  call expect \r~ok & r~code = "STALE_UI_ACTION", "6 stale revision detected"

  /* 7 resync */
  rs = .table~new
  rs["type"] = .WireUIProtocol~UI_RESYNC_REQUEST
  rs["messageId"] = "m-rs"
  r = app~receive(rs)
  call expect r~ok & r~value["type"] = .WireUIProtocol~UI_VIEW_SNAPSHOT, "7 resync snapshot"
  call expect r~value["revision"] = view~revision, "7 resync current revision"

  /* 8 dedupe business effect */
  fresh = actionMessage("m-3", app, "retry", "ORDER.RETRY", view~revision)
  r1 = app~receive(fresh)
  count1 = app~state("retryCount")
  r2 = app~receive(fresh)
  count2 = app~state("retryCount")
  call expect count1 = count2 & r2~code = "DUPLICATE", "8 duplicate does not repeat effect"

  /* 10 subscription changes */
  ignore = app~activateSubscription("CHAT")
  defs2 = app~requiredDefinitions
  call expect defs2~items = 3, "10 state can activate subscription"
  ignore = app~deactivateSubscription("CHAT")
  call expect app~requiredDefinitions~items = 2, "10 subscription can deactivate"

  /* 11 guard revalidation */
  app~setSecurityPolicy(.DenyCancelPolicy~new)
  rev = view~revision
  view~setActionAvailable("cancel", "SERVICE.CANCEL.BEGIN", .true)
  denied = actionMessage("m-4", app, "cancel", "SERVICE.CANCEL.BEGIN", rev)
  r = app~receive(denied)
  call expect \r~ok & r~code = "ACTION_GUARD_REJECTED", "11 server revalidates guarded action"

  /* 12 complete reconstruction independent of DOM */
  rebuilt = view~snapshot
  call expect rebuilt["rootInstance"] = "root" & rebuilt["elementInstances"]~items = 4, "12 full semantic reconstruction"

  say "PASS wire_ui_server_v0.1 acceptance 12/12"
  return

buildApp: procedure
  view = .WireUIView~new("CustomerPanel", "root")
  rootSlots = .table~new; rootSlots["visible"] = .true
  call must view~createInstance("root", "CUSTOMER_PANEL@1", rootSlots), "root"
  statusSlots = .table~new; statusSlots["value"] = "ACTIVE"
  call must view~createInstance("status", "ORDER_STATUS@1", statusSlots, "root"), "status"
  cancelSlots = .table~new; cancelSlots["action"] = "SERVICE.CANCEL.BEGIN"; cancelSlots["enabled"] = .true
  call must view~createInstance("cancel", "CANCEL_SERVICE_ACTION@1", cancelSlots, "root"), "cancel"
  retrySlots = .table~new; retrySlots["action"] = "ORDER.RETRY"; retrySlots["enabled"] = .true
  call must view~createInstance("retry", "RETRY_ACTION@1", retrySlots, "root"), "retry"
  view~setActionAvailable("cancel", "SERVICE.CANCEL.BEGIN", .true)
  view~setActionAvailable("retry", "ORDER.RETRY", .true)

  projection = .WireUIProjection~new
  projection~bind("orderStatus", "status", "value")

  app = .DemoApplication~new("APP-1", "SESSION-1", "AP-1", view, projection)
  call must app~registerDefinition(.WireUIElementDefinition~new("CUSTOMER_PANEL", "1", "PANEL")), "def panel"
  call must app~registerDefinition(.WireUIElementDefinition~new("CANCEL_SERVICE_ACTION", "1", "ACTION_BUTTON", "SERVICE.CANCEL.BEGIN", "cancel_service", "secondary_destructive")), "def cancel"
  call must app~registerDefinition(.WireUIElementDefinition~new("CHAT_LAUNCHER", "1", "ACTION_BUTTON", "CHAT.OPEN", "chat")), "def chat"
  call must app~registerDefinition(.WireUIElementDefinition~new("UNSUBSCRIBED", "1", "TEXT")), "def unused"

  account = .WireUISubscription~new("ACCOUNT", "1", "account view", "policy:account")
  account~addDefinition("CUSTOMER_PANEL@1")
  account~addDefinition("CANCEL_SERVICE_ACTION@1")
  account~activate
  app~addSubscription(account)
  chat = .WireUISubscription~new("CHAT", "1", "chat entered", "policy:chat")
  chat~addDefinition("CHAT_LAUNCHER@1")
  app~addSubscription(chat)
  return app

actionMessage: procedure
  use arg id, app, instance, action, revision
  m = .table~new
  m["type"] = .WireUIProtocol~UI_ACTION
  m["messageId"] = id
  m["applicationId"] = app~applicationId
  m["sessionId"] = app~sessionId
  m["accessPointId"] = app~accessPointId
  m["viewRef"] = app~view~viewRef
  m["elementInstance"] = instance
  m["action"] = action
  m["renderedRevision"] = revision
  return m

must: procedure
  use arg result, label
  if \result~ok then do
    say "FAIL setup" label result~code result~detail
    exit 1
  end
  return

expect: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  say "ok" label
  return

::class DemoApplication subclass WireUIApplication
::method dispatchSemanticAction
  use arg action, message
  select
    when action = "SERVICE.CANCEL.BEGIN" then do
      ignore = self~mutateState("orderStatus", "CANCELLATION_PENDING")
      return .WireUIResult~success("cancel-begun")
    end
    when action = "ORDER.RETRY" then do
      count = self~state("retryCount")
      if count == .nil then count = 0
      ignore = self~mutateState("retryCount", count + 1)
      return .WireUIResult~success(count + 1)
    end
    otherwise return .WireUIResult~failure("UNKNOWN_ACTION", action)
  end

::class DenyCancelPolicy
::method allows
  use arg app, message
  if message["action"] = "SERVICE.CANCEL.BEGIN" then return .false
  return .true

::requires "WireUIAll.cls"
