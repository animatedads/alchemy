/*
 * Semantic Source Control - module/deployment and requirement resolver.
 *
 * Module is logical identity. Deployment is an immutable qualified fixed point.
 * Requirements may be declared at MODULE, FILE or METHOD scope. For MINIMUM
 * constraints the highest deployment_sequence wins. EXACT constraints must agree
 * and must not fall below the effective minimum.
 */

::class SemanticSourceModuleService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

::method createModule
  use strict arg moduleId, moduleName, description, createdAt, createdBy
  if moduleId = "" then raise syntax 88.900 array("moduleId must not be empty")
  statement = "INSERT INTO ssc_module (module_id,module_name,description,created_at,created_by,latest_qualified_deployment_id) VALUES (" ||,
              self~quote(moduleId) || "," || self~quote(moduleName) || "," || self~quote(description) || "," ||,
              self~quote(createdAt) || "," || self~quote(createdBy) || ",'' )"
  return self~query(statement)

::method createDeployment
  use strict arg deploymentId, moduleId, deploymentLabel, deploymentSequence, qualifiedAt, qualifiedBy, qualificationEvidence = ""
  if deploymentSequence < 1 then raise syntax 88.900 array("deploymentSequence must be positive")
  statement = "INSERT INTO ssc_deployment (deployment_id,module_id,deployment_label,deployment_sequence,status,qualified_at,qualified_by,qualification_evidence,manifest_sha256,sealed_at) VALUES (" ||,
              self~quote(deploymentId) || "," || self~quote(moduleId) || "," || self~quote(deploymentLabel) || "," || deploymentSequence || "," ||,
              self~quote("DRAFT") || "," || self~quote(qualifiedAt) || "," || self~quote(qualifiedBy) || "," || self~quote(qualificationEvidence) || ",'','')"
  return self~query(statement)

::method addDeploymentObject
  use strict arg rowId, deploymentId, objectId, revisionId, relativePath = "", ordinal = 0
  self~assertDraftDeployment(deploymentId)
  return self~query("INSERT INTO ssc_deployment_object (deployment_object_id,deployment_id,object_id,revision_id,relative_path,ordinal) VALUES (" ||,
                    self~quote(rowId) || "," || self~quote(deploymentId) || "," || self~quote(objectId) || "," || self~quote(revisionId) || "," || self~quote(relativePath) || "," || ordinal || ")")

::method addDeploymentResource
  use strict arg rowId, deploymentId, resourceId, resourceRevisionId, materialisationPath = ""
  self~assertDraftDeployment(deploymentId)
  return self~query("INSERT INTO ssc_deployment_resource (deployment_resource_id,deployment_id,resource_id,resource_revision_id,materialisation_path) VALUES (" ||,
                    self~quote(rowId) || "," || self~quote(deploymentId) || "," || self~quote(resourceId) || "," || self~quote(resourceRevisionId) || "," || self~quote(materialisationPath) || ")")

::method createRequirement
  use strict arg requirementId, requiringModuleId, scopeKind, scopeId, targetModuleId, constraintKind, requiredDeploymentId, reason, createdAt, createdBy
  scope = scopeKind~upper
  constraint = constraintKind~upper
  if scope <> "MODULE" & scope <> "FILE" & scope <> "METHOD" then,
    raise syntax 88.900 array("scopeKind must be MODULE, FILE or METHOD")
  if constraint <> "MINIMUM" & constraint <> "EXACT" then,
    raise syntax 88.900 array("constraintKind must be MINIMUM or EXACT")
  required = self~deployment(requiredDeploymentId)
  if required["module_id"] <> targetModuleId then,
    raise syntax 88.900 array("required deployment does not belong to target module")
  statement = "INSERT INTO ssc_module_requirement (module_requirement_id,requiring_module_id,scope_kind,scope_id,target_module_id,constraint_kind,required_deployment_id,reason,status,created_at,created_by) VALUES (" ||,
              self~quote(requirementId) || "," || self~quote(requiringModuleId) || "," || self~quote(scope) || "," || self~quote(scopeId) || "," ||,
              self~quote(targetModuleId) || "," || self~quote(constraint) || "," || self~quote(requiredDeploymentId) || "," || self~quote(reason) || "," ||,
              self~quote("ACTIVE") || "," || self~quote(createdAt) || "," || self~quote(createdBy) || ")"
  return self~query(statement)

::method effectiveRequirement
  use strict arg requiringModuleId, targetModuleId, filePath = "", methodObjectId = ""
  statement = "SELECT module_requirement_id,scope_kind,scope_id,constraint_kind,required_deployment_id,reason FROM ssc_module_requirement WHERE requiring_module_id=" ||,
              self~quote(requiringModuleId) || " AND target_module_id=" || self~quote(targetModuleId) || " AND status='ACTIVE' AND (scope_kind='MODULE'"
  if filePath <> "" then statement ||= " OR (scope_kind='FILE' AND scope_id=" || self~quote(filePath) || ")"
  if methodObjectId <> "" then statement ||= " OR (scope_kind='METHOD' AND scope_id=" || self~quote(methodObjectId) || ")"
  statement ||= ") ORDER BY module_requirement_id"
  rs = self~query(statement)

  highestMinId = ""
  highestMinSequence = 0
  exactId = ""
  applied = .array~new

  do row over rs~rows
    deploymentId = row["required_deployment_id"]
    dep = self~deployment(deploymentId)
    sequence = dep["deployment_sequence"]
    applied~append(row["module_requirement_id"])
    kind = row["constraint_kind"]~upper
    if kind = "MINIMUM" then do
      if sequence > highestMinSequence then do
        highestMinSequence = sequence
        highestMinId = deploymentId
      end
    end
    else if kind = "EXACT" then do
      if exactId = "" then exactId = deploymentId
      else if exactId <> deploymentId then,
        raise syntax 88.900 array("REQUIREMENT_CONFLICT: conflicting EXACT deployments " || exactId || " and " || deploymentId)
    end
  end

  if exactId <> "" then do
    exact = self~deployment(exactId)
    if exact["deployment_sequence"] < highestMinSequence then,
      raise syntax 88.900 array("REQUIREMENT_CONFLICT: EXACT deployment " || exactId || " is below effective minimum " || highestMinId)
  end

  effectiveResult = .directory~new
  effectiveResult["requiring_module_id"] = requiringModuleId
  effectiveResult["target_module_id"] = targetModuleId
  effectiveResult["minimum_deployment_id"] = highestMinId
  effectiveResult["minimum_sequence"] = highestMinSequence
  effectiveResult["exact_deployment_id"] = exactId
  effectiveResult["applied_requirement_ids"] = applied
  if exactId <> "" then effectiveResult["effective_constraint"] = "EXACT"
  else if highestMinId <> "" then effectiveResult["effective_constraint"] = "MINIMUM"
  else effectiveResult["effective_constraint"] = "NONE"
  return effectiveResult

::method resolveDevelopmentDependency
  use strict arg requiringModuleId, targetModuleId, filePath = "", methodObjectId = ""
  effective = self~effectiveRequirement(requiringModuleId, targetModuleId, filePath, methodObjectId)
  exactId = effective["exact_deployment_id"]
  if exactId <> "" then return self~deployment(exactId)

  minSequence = effective["minimum_sequence"]
  statement = "SELECT deployment_id,module_id,deployment_label,deployment_sequence,status,manifest_sha256 FROM ssc_deployment WHERE module_id=" || self~quote(targetModuleId) ||,
              " AND status='QUALIFIED' AND deployment_sequence>=" || minSequence || " ORDER BY deployment_sequence DESC"
  rs = self~query(statement)
  if rs~rows~items = 0 then raise syntax 88.900 array("no qualified deployment satisfies requirement for " || targetModuleId)
  return rs~rows[1]

::method sealedDependencies
  use strict arg deploymentId
  self~assertQualifiedDeployment(deploymentId)
  return self~query("SELECT target_module_id,resolved_deployment_id,requirement_summary FROM ssc_deployment_dependency WHERE deployment_id=" || self~quote(deploymentId) || " ORDER BY target_module_id")

::method sealDeployment
  use strict arg deploymentId, manifestSha256, sealedAt
  self~assertDraftDeployment(deploymentId)
  self~query("UPDATE ssc_deployment SET status='QUALIFIED',manifest_sha256=" || self~quote(manifestSha256) || ",sealed_at=" || self~quote(sealedAt) || " WHERE deployment_id=" || self~quote(deploymentId))
  dep = self~deployment(deploymentId)
  self~query("UPDATE ssc_module SET latest_qualified_deployment_id=" || self~quote(deploymentId) || " WHERE module_id=" || self~quote(dep["module_id"]))
  return self~deployment(deploymentId)

::method recordResolvedDependency
  use strict arg rowId, deploymentId, targetModuleId, resolvedDeploymentId, requirementSummary
  self~assertDraftDeployment(deploymentId)
  resolved = self~deployment(resolvedDeploymentId)
  if resolved["module_id"] <> targetModuleId then raise syntax 88.900 array("resolved deployment belongs to wrong module")
  if resolved["status"] <> "QUALIFIED" then raise syntax 88.900 array("resolved dependency must be QUALIFIED")
  return self~query("INSERT INTO ssc_deployment_dependency (deployment_dependency_id,deployment_id,target_module_id,resolved_deployment_id,requirement_summary) VALUES (" ||,
                    self~quote(rowId) || "," || self~quote(deploymentId) || "," || self~quote(targetModuleId) || "," || self~quote(resolvedDeploymentId) || "," || self~quote(requirementSummary) || ")")

::method deployment
  use strict arg deploymentId
  rs = self~query("SELECT deployment_id,module_id,deployment_label,deployment_sequence,status,qualified_at,qualified_by,qualification_evidence,manifest_sha256,sealed_at FROM ssc_deployment WHERE deployment_id=" || self~quote(deploymentId))
  if rs~rows~items = 0 then raise syntax 88.900 array("deployment not found: " || deploymentId)
  return rs~rows[1]

::method assertDraftDeployment private
  use strict arg deploymentId
  dep = self~deployment(deploymentId)
  if dep["status"] <> "DRAFT" then raise syntax 88.900 array("deployment is immutable after qualification: " || deploymentId)

::method assertQualifiedDeployment private
  use strict arg deploymentId
  dep = self~deployment(deploymentId)
  if dep["status"] <> "QUALIFIED" then raise syntax 88.900 array("deployment is not qualified: " || deploymentId)

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"

