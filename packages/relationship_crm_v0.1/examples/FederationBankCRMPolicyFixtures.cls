/* FederationBank example servicing policy.  It is policy payload, not engine code. */
::class FederationBankCRMPolicyFixtures public
::method standardPolicy class
  p=.RelationshipCRMPolicy~new
  p~addActionRule(.RelationshipCRMActionRule~new("REL-OPEN","RELATIONSHIP","","OPEN","*","ACTIVE",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("INTERACTION-RECORD","INTERACTION","","RECORD","*","",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMM-RECORD","COMMUNICATION","","RECORD","*","RECORDED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMM-SENT","COMMUNICATION","RECORDED","MARK_SENT","*","SENT",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMM-DELIVERED","COMMUNICATION","SENT","MARK_DELIVERED","*","DELIVERED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("PROMISE-RECORD","PROMISE","","RECORD","*","OPEN",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("PROMISE-FULFIL","PROMISE","OPEN","FULFIL","*","FULFILLED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("PROMISE-BREAK","PROMISE","OPEN","BREAK","*","BROKEN",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("TASK-CREATE","TASK","","CREATE","*","OPEN",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("TASK-COMPLETE","TASK","OPEN","COMPLETE","*","COMPLETED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("TASK-CANCEL","TASK","OPEN","CANCEL","SERVICE_MANAGER","CANCELLED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("TASK-CANCEL-DENY","TASK","OPEN","CANCEL","*","",.false))
  p~addActionRule(.RelationshipCRMActionRule~new("COMPLAINT-RECOGNISE","COMPLAINT","","RECOGNISE","*","OPEN",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMPLAINT-LINK","COMPLAINT","OPEN","LINK_CASE","*","OPEN",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMPLAINT-RESOLVE","COMPLAINT","OPEN","RESOLVE","COMPLAINTS","RESOLVED",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("COMPLAINT-RESOLVE-DENY","COMPLAINT","OPEN","RESOLVE","*","",.false))
  p~addActionRule(.RelationshipCRMActionRule~new("PROFILE-SET","SERVICE_PROFILE","","SET","SERVICE_MANAGER","",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("PROFILE-SET-COMPLAINTS","SERVICE_PROFILE","","SET","COMPLAINTS","",.true))
  p~addActionRule(.RelationshipCRMActionRule~new("PROFILE-SET-DENY","SERVICE_PROFILE","","SET","*","",.false))
  p~addProjectionRule(.RelationshipCRMProjectionRule~new("VIEW-DEFAULT","*","INTERNAL",.true))
  p~addProjectionRule(.RelationshipCRMProjectionRule~new("VIEW-TELLER","TELLER","INTERNAL",.true))
  p~addProjectionRule(.RelationshipCRMProjectionRule~new("VIEW-COMPLAINTS","COMPLAINTS","RESTRICTED",.true))
  p~addProjectionRule(.RelationshipCRMProjectionRule~new("VIEW-COMPLIANCE","COMPLIANCE","RESTRICTED",.true))
  return p~seal
::method publishedCatalog class
  p=self~standardPolicy; c=.InstitutionalPolicyCatalog~new; from=.DateTime~new-.TimeSpan~new(0,0,0,0,1)
  release=.InstitutionalPolicyRelease~new(.RelationshipCRMBuild~DEFAULT_POLICY_ID,"1",from,.nil,"FederationBank Service Design","FederationBank Operations","",p)~seal
  result=c~publish(release); if \result~ok then raise syntax 88.957 array("Could not publish CRM policy: "||result~code)
  return c
::requires "RelationshipCRM.cls"
::requires "InstitutionalPolicy.cls"
