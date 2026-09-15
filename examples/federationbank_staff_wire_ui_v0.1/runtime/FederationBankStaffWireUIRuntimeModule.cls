/* Runtime metadata for FederationBank Staff Wire UI v0.1. */
::class FederationBankStaffWireUIRuntimeModule public
::method componentId class
  return "federationbank.staff.wire-ui"
::method version class
  return "0.1"
::method apiVersion class
  return "federationbank.staff.wire-ui/0.1"
::method capabilities class
  return .array~of( -
    "SERVER_AUTHORITATIVE_STAFF_CONTEXT", -
    "DURABLE_STAFF_WORKSPACE_PROJECTION", -
    "WIRE_UI_V017_RESULT_REVISION_AUTHORITY", -
    "EXACT_METHOD_PERMISSION_BEFORE_CUSTOMER_MUTATION", -
    "CUSTOMER_TRANSFER_INSTRUCTION", -
    "STAFF_CHANNEL_ACTION_PORT", -
    "DUPLICATE_UI_MESSAGE_REPLAY", -
    "QUEUE_FABRIC_WEB_GATEWAY_SEAM", -
    "NON_AUTHORITATIVE_VISUAL_PREVIEW" )
::method limitations class
  return .array~of( -
    "Early UI: checker-completion controls are not yet exposed.", -
    "Early UI: customer transfer is the only mutation exposed.", -
    "The browser does not authenticate staff or grant Access Control.", -
    "A visible or enabled UI control does not grant Method Permission or Staff Authority.", -
    "The UI does not execute Core Banking commands directly.", -
    "The packaged preview is deliberately non-authoritative and submits no banking actions." )
