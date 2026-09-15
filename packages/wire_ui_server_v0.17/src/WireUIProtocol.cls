/* Alchemy Wire UI Server package v0.15; integration lock retained. Wire protocol remains WIRE-UI/0.1. */

::class WireUIProtocol public
::constant VERSION "WIRE-UI/0.1"
::constant UI_HELLO "UI_HELLO"
::constant SUBSCRIPTION_ACTIVATE "SUBSCRIPTION_ACTIVATE"
::constant SUBSCRIPTION_DEACTIVATE "SUBSCRIPTION_DEACTIVATE"
::constant SUBSCRIPTION_STATE "SUBSCRIPTION_STATE"
::constant UI_DEFINITION "UI_DEFINITION"
::constant UI_MATERIAL_SET "UI_MATERIAL_SET"
::constant UI_DEFINITION_REQUIRED "UI_DEFINITION_REQUIRED"
::constant UI_RENDER_PROFILE "UI_RENDER_PROFILE"
::constant UI_DEFINITION_MANIFEST "UI_DEFINITION_MANIFEST"
::constant UI_JOURNEY_PLAN "UI_JOURNEY_PLAN"
::constant UI_ON_DEMAND_REQUEST "UI_ON_DEMAND_REQUEST"
::constant INTERACTION_PROFILE_OFFER "INTERACTION_PROFILE_OFFER"
::constant UI_VIEW_SNAPSHOT "UI_VIEW_SNAPSHOT"
::constant UI_VIEW_PATCH "UI_VIEW_PATCH"
::constant UI_ACTION "UI_ACTION"
::constant UI_RESYNC_REQUEST "UI_RESYNC_REQUEST"
::constant UI_ACK "UI_ACK"
::constant UI_ERROR "UI_ERROR"
::constant OBSERVATION_PLAN "OBSERVATION_PLAN"
::constant INTERACTION_OBSERVATION "INTERACTION_OBSERVATION"
::constant INTERACTION_PROFILE_SELECT "INTERACTION.PROFILE.SELECT"
::constant PROFILE_HUMAN_VISUAL "HUMAN_VISUAL"
::constant PROFILE_AI_AGENT_OPTIMISED "AI_AGENT_OPTIMISED"

::method message class
  use arg type, fields = .nil
  m = .table~new
  m["type"] = type
  m["protocolVersion"] = self~VERSION
  if fields \== .nil then do key over fields
    m[key] = fields[key]
  end
  return m

::class WireUIResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::method init
  expose ok code value detail
  use arg ok, code = "OK", value = .nil, detail = ""
::method success class
  use arg value = .nil, code = "OK"
  return self~new(.true, code, value, "")
::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, value, detail)
