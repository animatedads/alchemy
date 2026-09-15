::class RelationshipCRMRuntimeModule public
::method componentId; return "relationship_crm"
::method version; return .RelationshipCRMBuild~VERSION
::method apiVersion; return .RelationshipCRMBuild~API_VERSION
::method capabilities
  return .array~of("relationship-record","interaction-reference","communication","promise","task","complaint","service-profile","policy-projection")
::requires "RelationshipCRM.cls"
