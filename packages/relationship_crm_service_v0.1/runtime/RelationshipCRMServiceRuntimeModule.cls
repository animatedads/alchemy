::class RelationshipCRMServiceRuntimeModule public
::method componentId; return "relationship_crm_service"
::method version; return .RelationshipCRMServiceBuild~VERSION
::method apiVersion; return .RelationshipCRMServiceBuild~API_VERSION
::method capabilities; return .array~of("crm-commands","policy-projected-reads","idempotency","durable-state","outbox","queue-worker")
::requires "RelationshipCRMService.cls"
