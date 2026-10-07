/*
 * Semantic Source Control - review/test package resolver
 *
 * getPackage() returns an MCP-serializable object containing materialised source
 * files and the exact revision manifest used to build them.  The default policy
 * is latest accepted dependency closure.  Explicit revision pins override it.
 */

::class SemanticSourcePackage public
::method init
  self~files = .directory~new
  self~resources = .directory~new
  self~manifest = .array~new
  self~resourceManifest = .array~new
  self~roots = .array~new
::attribute files
::attribute resources
::attribute manifest
::attribute resourceManifest
::attribute roots
::attribute resolutionPolicy
::attribute packageRequestId
::attribute branchId
::attribute branchClassification

::class SemanticSourcePackageService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

/*
 * roots: Array of semantic object IDs.
 * pins:  Directory object_id -> revision_id.  Omit or pass .nil for no pins.
 * projectId: projection project identifier.  Defaults to "default".
 *
 * The returned SemanticSourcePackage contains:
 *   files[path] = complete materialised source text
 *   manifest[]  = directories describing every resolved semantic object/revision
 *   roots[]     = requested root object IDs
 */
::method getPackage
  use strict arg roots, pins = .nil, projectId = "default"

  if roots == .nil | roots~items = 0 then
    raise syntax 88.900 array("getPackage requires at least one root object id")
  if pins == .nil then pins = .directory~new

  package = .SemanticSourcePackage~new
  package~resolutionPolicy = "latest-accepted-unless-pinned"
  resolved = .directory~new
  depthByObject = .directory~new
  frontier = .array~new

  do root over roots
    if root = "" then raise syntax 88.900 array("root object id must not be empty")
    package~roots~append(root)
    if \depthByObject~hasIndex(root) then depthByObject[root] = 0
    frontier~append(root)
  end

  -- Resolve dependency closure breadth-first in sets.  The previous resolver
  -- performed several SQL round-trips per semantic object; a 1,400-file package
  -- therefore produced thousands of queries before JSON was even considered.
  do while frontier~items > 0
    batch = .array~new
    seenBatch = .directory~new
    do objectId over frontier
      if resolved~hasIndex(objectId) | seenBatch~hasIndex(objectId) then iterate
      seenBatch[objectId] = 1
      batch~append(objectId)
    end
    if batch~items = 0 then leave

    batchRevisions = self~loadRevisionBatch(batch, pins)
    do objectId over batch
      if \batchRevisions~hasIndex(objectId) then,
        raise syntax 88.900 array("source object not found or revision unavailable: " || objectId)
      revision = batchRevisions[objectId]
      resolved[objectId] = revision
      revisionId = revision["revision_id"]

      item = .directory~new
      item["object_id"] = objectId
      item["revision_id"] = revisionId
      item["revision_no"] = revision["revision_no"]
      item["source_sha256"] = revision["source_sha256"]
      item["origin_archive_filename"] = revision["origin_archive_filename"]
      item["origin_archive_sha256"] = revision["origin_archive_sha256"]
      item["origin_member_path"] = revision["origin_member_path"]
      item["dependency_depth"] = depthByObject[objectId]
      if pins~hasIndex(objectId) then item["resolution"] = "pinned"
      else item["resolution"] = "latest-accepted"
      package~manifest~append(item)
    end

    relationSql = "SELECT from_object_id,revision_id,relation_kind,to_object_id,detail FROM ssc_relation " ||,
                  "WHERE from_object_id IN (" || self~quotedList(batch) || ") " ||,
                  "AND relation_kind IN ('DEPENDS_ON','REQUIRES','IMPORTS','USES') " ||,
                  "ORDER BY from_object_id,to_object_id"
    relationRows = self~queryRows(relationSql)

    requireRows = .array~new
    nextFrontier = .array~new
    nextSeen = .directory~new
    do relation over relationRows
      fromId = relation["from_object_id"]
      if \batchRevisions~hasIndex(fromId) then iterate
      if relation["revision_id"] <> batchRevisions[fromId]["revision_id"] then iterate
      dependencyId = relation["to_object_id"]
      if dependencyId == .nil | dependencyId = "" then iterate
      if relation["relation_kind"] = "REQUIRES" then requireRows~append(relation)
      if \resolved~hasIndex(dependencyId) & \nextSeen~hasIndex(dependencyId) then do
        nextSeen[dependencyId] = 1
        if \depthByObject~hasIndex(dependencyId) then depthByObject[dependencyId] = depthByObject[fromId] + 1
        nextFrontier~append(dependencyId)
      end
    end

    self~validateRequiresBatch(requireRows, pins)
    frontier = nextFrontier
  end

  self~materialiseResolved(package, resolved, projectId)
  self~materialiseResources(package, resolved)
  return package

::method loadRevisionBatch private
  use strict arg objectIds, pins
  result = .directory~new
  unpinned = .array~new
  pinnedRevisionIds = .array~new

  do objectId over objectIds
    if pins~hasIndex(objectId) then do
      revisionId = pins[objectId]
      if revisionId = "" then raise syntax 88.900 array("empty revision pin for " || objectId)
      pinnedRevisionIds~append(revisionId)
    end
    else unpinned~append(objectId)
  end

  columns = "r.revision_id,r.object_id,r.revision_no,r.source_text,r.source_sha256," ||,
            "r.origin_archive_filename,r.origin_archive_sha256,r.origin_member_path,r.materialisation_path"
  if unpinned~items > 0 then do
    sql = "SELECT " || columns || " FROM ssc_source_object o JOIN ssc_source_revision r " ||,
          "ON r.object_id=o.object_id AND r.revision_id=o.accepted_revision_id " ||,
          "WHERE o.object_id IN (" || self~quotedList(unpinned) || ")"
    rows = self~queryRows(sql)
    do row over rows
      result[row["object_id"]] = row
    end
  end

  if pinnedRevisionIds~items > 0 then do
    sql = "SELECT " || columns || " FROM ssc_source_revision r WHERE r.revision_id IN (" || self~quotedList(pinnedRevisionIds) || ")"
    rows = self~queryRows(sql)
    do row over rows
      objectId = row["object_id"]
      if pins~hasIndex(objectId) then if pins[objectId] = row["revision_id"] then result[objectId] = row
    end
  end
  return result

::method validateRequiresBatch private
  use strict arg requireRows, pins
  if requireRows~items = 0 then return

  providerIds = .array~new
  seenProviders = .directory~new
  do relation over requireRows
    providerId = relation["to_object_id"]
    if \seenProviders~hasIndex(providerId) then do
      seenProviders[providerId] = 1
      providerIds~append(providerId)
    end
  end
  providers = self~loadRevisionBatch(providerIds, pins)

  exportSql = "SELECT provider_object_id,provider_revision_id,export_name,visibility FROM ssc_export " ||,
              "WHERE provider_object_id IN (" || self~quotedList(providerIds) || ") AND visibility='PUBLIC'"
  exportRows = self~queryRows(exportSql)
  exports = .directory~new
  do exportRow over exportRows
    key = exportRow["provider_object_id"] || "@" || exportRow["provider_revision_id"] || "@" || exportRow["export_name"]
    exports[key] = 1
  end

  do relation over requireRows
    requiredExport = self~orEmpty(relation["detail"])
    if requiredExport = "" then iterate
    providerId = relation["to_object_id"]
    if \providers~hasIndex(providerId) then raise syntax 88.900 array("::requires provider not found: " || providerId)
    providerRevision = providers[providerId]["revision_id"]
    key = providerId || "@" || providerRevision || "@" || requiredExport
    if \exports~hasIndex(key) then raise syntax 88.900 array("::requires dependency " || providerId || " does not export required public symbol " || requiredExport)
  end

::method resolveRevision private
  use strict arg objectId, pins

  if pins~hasIndex(objectId) then do
    pinned = pins[objectId]
    if pinned = "" then raise syntax 88.900 array("empty revision pin for " || objectId)
    return pinned
  end

  statement = "SELECT accepted_revision_id FROM ssc_source_object WHERE object_id=" || self~quote(objectId)
  rs = self~query(statement)
  if rs~rows~items = 0 then,
    raise syntax 88.900 array("source object not found: " || objectId)

  revisionId = rs~rows[1]["accepted_revision_id"]
  if revisionId == .nil | revisionId = "" then,
    raise syntax 88.900 array("source object has no accepted revision: " || objectId)
  return revisionId

::method loadRevision private
  use strict arg objectId, revisionId

  statement = "SELECT revision_id, object_id, revision_no, source_text, source_sha256, " ||,
              "origin_archive_filename, origin_archive_sha256, origin_member_path, materialisation_path " ||,
              "FROM ssc_source_revision WHERE revision_id=" || self~quote(revisionId) ||,
              " AND object_id=" || self~quote(objectId)
  rs = self~query(statement)
  if rs~rows~items = 0 then,
    raise syntax 88.900 array("revision " || revisionId || " does not belong to " || objectId)
  return rs~rows[1]

::method dependenciesFor private
  use strict arg objectId, revisionId

  dependencies = .array~new
  statement = "SELECT to_object_id FROM ssc_relation WHERE from_object_id=" || self~quote(objectId) ||,
              " AND revision_id=" || self~quote(revisionId) ||,
              " AND relation_kind IN ('DEPENDS_ON','REQUIRES','IMPORTS','USES') ORDER BY to_object_id"
  rs = self~query(statement)
  do row over rs~rows
    dependencyId = row["to_object_id"]
    if dependencyId \== .nil & dependencyId \= "" then dependencies~append(dependencyId)
  end
  return dependencies

::method validateRequiresExports private
  use strict arg objectId, revisionId, pins
  statement = "SELECT to_object_id, detail FROM ssc_relation WHERE from_object_id=" || self~quote(objectId) ||,
              " AND revision_id=" || self~quote(revisionId) || " AND relation_kind='REQUIRES' ORDER BY to_object_id"
  rs = self~query(statement)
  do row over rs~rows
    providerId = row["to_object_id"]
    requiredExport = self~orEmpty(row["detail"])
    providerRevision = self~resolveRevision(providerId, pins)
    if requiredExport = "" then iterate
    exportSql = "SELECT export_id FROM ssc_export WHERE provider_object_id=" || self~quote(providerId) ||,
                " AND provider_revision_id=" || self~quote(providerRevision) ||,
                " AND export_name=" || self~quote(requiredExport) || " AND visibility='PUBLIC'"
    exportRs = self~query(exportSql)
    if exportRs~rows~items = 0 then raise syntax 88.900 array("::requires dependency " || providerId || " does not export required public symbol " || requiredExport)
  end

::method materialiseResources private
  use strict arg package, resolved
  seen = .directory~new
  objectIds = resolved~allIndexes
  do objectId over objectIds
    revision = resolved[objectId]
    revisionId = revision["revision_id"]
    statement = "SELECT resource_id, required_revision_id, relation_kind, detail FROM ssc_resource_relation WHERE from_object_id=" || self~quote(objectId) ||,
                " AND (from_revision_id='' OR from_revision_id=" || self~quote(revisionId) || ") ORDER BY resource_id"
    rs = self~query(statement)
    do relation over rs~rows
      resourceId = relation["resource_id"]
      requestedRevision = self~orEmpty(relation["required_revision_id"])
      resourceRevision = self~resolveResourceRevision(resourceId, requestedRevision)
      key = resourceId || "@" || resourceRevision["resource_revision_id"]
      if seen~hasIndex(key) then iterate
      seen[key] = 1
      path = resourceRevision["materialisation_path"]
      if path == .nil | path = "" then raise syntax 88.900 array("resource has no materialisation path: " || resourceId)
      content = self~orEmpty(resourceRevision["content_text"])
      if content = "" then content = self~orEmpty(resourceRevision["content_base64"])
      package~resources[path] = content
      -- Resources are also conventional package files. Binary values are base64 and identified in the manifest.
      package~files[path] = content
      item = .directory~new
      item["resource_id"] = resourceId
      item["resource_revision_id"] = resourceRevision["resource_revision_id"]
      item["content_sha256"] = resourceRevision["content_sha256"]
      item["mime_type"] = resourceRevision["mime_type"]
      item["materialisation_path"] = path
      item["encoding"] = "text"
      if self~orEmpty(resourceRevision["content_text"]) = "" then item["encoding"] = "base64"
      item["relation_kind"] = relation["relation_kind"]
      package~resourceManifest~append(item)
    end
  end

::method resolveResourceRevision private
  use strict arg resourceId, requestedRevision
  revisionId = requestedRevision
  if revisionId = "" then do
    rs = self~query("SELECT accepted_revision_id FROM ssc_resource_object WHERE resource_id=" || self~quote(resourceId))
    if rs~rows~items = 0 then raise syntax 88.900 array("resource not found: " || resourceId)
    revisionId = rs~rows[1]["accepted_revision_id"]
  end
  if revisionId == .nil | revisionId = "" then raise syntax 88.900 array("resource has no accepted revision: " || resourceId)
  rs = self~query("SELECT resource_revision_id,resource_id,content_text,content_base64,content_sha256,mime_type,materialisation_path FROM ssc_resource_revision WHERE resource_id=" || self~quote(resourceId) || " AND resource_revision_id=" || self~quote(revisionId))
  if rs~rows~items = 0 then raise syntax 88.900 array("resource revision not found: " || revisionId)
  return rs~rows[1]

::method materialiseResolved private
  use strict arg package, resolved, projectId

  members = .array~new
  objectIds = resolved~allIndexes
  if objectIds~items = 0 then return

  -- Fetch every projection member for the resolved closure in one result set.
  -- This is deliberately bulk: a 1,400-object package must not issue 1,400
  -- projection queries merely to rebuild files.
  revisionIds = .array~new
  revisionById = .directory~new
  do objectId over objectIds
    revision = resolved[objectId]
    revisionId = revision["revision_id"]
    revisionIds~append(revisionId)
    revisionById[revisionId] = revision
  end

  projectionByRevision = .directory~new
  statement = "SELECT revision_id,relative_path,ordinal,prefix_text,suffix_text FROM ssc_projection_member " ||,
              "WHERE project_id=" || self~quote(projectId) ||,
              " AND revision_id IN (" || self~quotedList(revisionIds) || ") " ||,
              "ORDER BY revision_id,relative_path,ordinal"
  rows = self~queryRows(statement)
  do row over rows
    revisionId = row["revision_id"]
    if \projectionByRevision~hasIndex(revisionId) then projectionByRevision[revisionId] = .array~new
    projectionByRevision[revisionId]~append(row)
  end

  do objectId over objectIds
    revision = resolved[objectId]
    revisionId = revision["revision_id"]
    if \projectionByRevision~hasIndex(revisionId) | projectionByRevision[revisionId]~items = 0 then do
      fallback = .directory~new
      fallback["relative_path"] = revision["materialisation_path"]
      fallback["ordinal"] = 0
      fallback["prefix_text"] = ""
      fallback["suffix_text"] = ""
      fallback["source_text"] = revision["source_text"]
      if fallback["relative_path"] == .nil | fallback["relative_path"] = "" then,
        raise syntax 88.900 array("no materialisation path for revision " || revisionId)
      members~append(fallback)
    end
    else do row over projectionByRevision[revisionId]
      member = .directory~new
      member["relative_path"] = row["relative_path"]
      member["ordinal"] = row["ordinal"]
      member["prefix_text"] = self~orEmpty(row["prefix_text"])
      member["suffix_text"] = self~orEmpty(row["suffix_text"])
      member["source_text"] = revision["source_text"]
      members~append(member)
    end
  end

  -- Keep assembly deterministic without requiring caller filesystem access.
  do member over members
    path = member["relative_path"]
    if package~files~hasIndex(path) then existing = package~files[path]
    else existing = ""
    package~files[path] = existing || member["prefix_text"] || member["source_text"] || member["suffix_text"]
  end

/*
 * Build an immutable qualified deployment exactly as it was sealed.
 * Unlike getPackage(), this never floats dependencies to newer deployments.
 */
::method getDeploymentPackage
  use strict arg deploymentId, projectId = "default"

  package = .SemanticSourcePackage~new
  package~resolutionPolicy = "sealed-deployment-exact-closure"
  package~roots~append(deploymentId)

  deploymentQueue = .queue~new
  seenDeployments = .directory~new
  resolvedObjects = .directory~new
  deploymentQueue~queue(deploymentId)

  do while deploymentQueue~items > 0
    currentDeploymentId = deploymentQueue~pull
    if seenDeployments~hasIndex(currentDeploymentId) then iterate
    deployment = self~loadQualifiedDeployment(currentDeploymentId)
    seenDeployments[currentDeploymentId] = deployment

    objectSql = "SELECT d.object_id,d.revision_id,d.relative_path,d.ordinal," ||,
                "r.revision_no,r.source_text,r.source_sha256,r.origin_archive_filename," ||,
                "r.origin_archive_sha256,r.origin_member_path,r.materialisation_path " ||,
                "FROM ssc_deployment_object d JOIN ssc_source_revision r " ||,
                "ON r.revision_id=d.revision_id AND r.object_id=d.object_id " ||,
                "WHERE d.deployment_id=" || self~quote(currentDeploymentId) ||,
                " ORDER BY d.relative_path,d.ordinal,d.object_id"
    objectRows = self~queryRows(objectSql)
    do objectRow over objectRows
      objectId = objectRow["object_id"]
      revisionId = objectRow["revision_id"]
      revision = objectRow
      resolvedObjects[objectId] = revision

      item = .directory~new
      item["module_id"] = deployment["module_id"]
      item["deployment_id"] = currentDeploymentId
      item["deployment_label"] = deployment["deployment_label"]
      item["deployment_sequence"] = deployment["deployment_sequence"]
      item["object_id"] = objectId
      item["revision_id"] = revisionId
      item["revision_no"] = revision["revision_no"]
      item["source_sha256"] = revision["source_sha256"]
      item["relative_path"] = objectRow["relative_path"]
      item["resolution"] = "sealed"
      package~manifest~append(item)
    end

    resourceSql = "SELECT d.resource_id,d.resource_revision_id,d.materialisation_path AS deployment_path," ||,
                  "r.content_text,r.content_base64,r.content_sha256,r.mime_type,r.materialisation_path " ||,
                  "FROM ssc_deployment_resource d JOIN ssc_resource_revision r " ||,
                  "ON r.resource_id=d.resource_id AND r.resource_revision_id=d.resource_revision_id " ||,
                  "WHERE d.deployment_id=" || self~quote(currentDeploymentId) ||,
                  " ORDER BY d.materialisation_path,d.resource_id"
    resourceRows = self~queryRows(resourceSql)
    do resource over resourceRows
      path = resource["deployment_path"]
      if path == .nil | path = "" then path = resource["materialisation_path"]
      content = self~orEmpty(resource["content_text"])
      encoding = "text"
      if content = "" then do
        content = self~orEmpty(resource["content_base64"])
        encoding = "base64"
      end
      package~files[path] = content
      package~resources[path] = content
      resourceItem = .directory~new
      resourceItem["module_id"] = deployment["module_id"]
      resourceItem["deployment_id"] = currentDeploymentId
      resourceItem["resource_id"] = resource["resource_id"]
      resourceItem["resource_revision_id"] = resource["resource_revision_id"]
      resourceItem["content_sha256"] = resource["content_sha256"]
      resourceItem["mime_type"] = resource["mime_type"]
      resourceItem["materialisation_path"] = path
      resourceItem["encoding"] = encoding
      resourceItem["resolution"] = "sealed"
      package~resourceManifest~append(resourceItem)
    end

    dependencyRows = self~queryRows("SELECT target_module_id,resolved_deployment_id,requirement_summary FROM ssc_deployment_dependency WHERE deployment_id=" || self~quote(currentDeploymentId) || " ORDER BY target_module_id")
    do dependencyRow over dependencyRows
      deploymentQueue~queue(dependencyRow["resolved_deployment_id"])
    end
  end

  self~materialiseResolved(package, resolvedObjects, projectId)
  return package

/*
 * Build a sparse branch projection from an upstream qualified deployment.
 * No text patching occurs: exact upstream semantic revisions are loaded, then
 * branch-local object revisions replace the corresponding semantic editions.
 */
::method getBranchPackage
  use strict arg branchId, upstreamDeploymentId = "", projectId = "default"

  branchRs = self~query("SELECT branch_id,module_id,base_deployment_id,classification,upstream_policy,status FROM ssc_branch WHERE branch_id=" || self~quote(branchId))
  if branchRs~rows~items = 0 then raise syntax 88.900 array("branch not found: " || branchId)
  branch = branchRs~rows[1]
  if branch["status"] <> "OPEN" then raise syntax 88.900 array("branch is not open: " || branchId)

  if upstreamDeploymentId = "" then upstreamDeploymentId = branch["base_deployment_id"]
  upstream = self~loadQualifiedDeployment(upstreamDeploymentId)
  if upstream["module_id"] <> branch["module_id"] then,
    raise syntax 88.900 array("upstream deployment belongs to wrong module for branch " || branchId)

  openConflicts = self~query("SELECT branch_conflict_id,object_id FROM ssc_branch_conflict WHERE branch_id=" || self~quote(branchId) || " AND status='OPEN' ORDER BY branch_conflict_id")
  if openConflicts~rows~items > 0 then,
    raise syntax 88.900 array("BRANCH_CONFLICT: branch " || branchId || " has unresolved semantic conflicts")

  package = .SemanticSourcePackage~new
  package~resolutionPolicy = "branch-sparse-overlay-on-sealed-upstream"
  package~branchId = branchId
  package~branchClassification = branch["classification"]
  package~roots~append(upstreamDeploymentId)

  deploymentQueue = .queue~new
  seenDeployments = .directory~new
  resolvedObjects = .directory~new
  deploymentQueue~queue(upstreamDeploymentId)

  do while deploymentQueue~items > 0
    currentDeploymentId = deploymentQueue~pull
    if seenDeployments~hasIndex(currentDeploymentId) then iterate
    deployment = self~loadQualifiedDeployment(currentDeploymentId)
    seenDeployments[currentDeploymentId] = deployment

    objectRs = self~query("SELECT object_id,revision_id,relative_path,ordinal FROM ssc_deployment_object WHERE deployment_id=" || self~quote(currentDeploymentId) || " ORDER BY relative_path,ordinal,object_id")
    do objectRow over objectRs~rows
      objectId = objectRow["object_id"]
      revisionId = objectRow["revision_id"]
      resolution = "sealed-upstream"
      if deployment["module_id"] = branch["module_id"] then do
        overrideRs = self~query("SELECT revision_id FROM ssc_branch_override WHERE branch_id=" || self~quote(branchId) || " AND object_id=" || self~quote(objectId) || " AND status='ACTIVE' ORDER BY created_at DESC,branch_override_id DESC")
        if overrideRs~rows~items > 1 then,
          raise syntax 88.900 array("BRANCH_CONFLICT: multiple active overrides for " || objectId)
        if overrideRs~rows~items = 1 then do
          revisionId = overrideRs~rows[1]["revision_id"]
          resolution = "branch-override"
        end
      end
      revision = self~loadRevision(objectId, revisionId)
      resolvedObjects[objectId] = revision

      item = .directory~new
      item["module_id"] = deployment["module_id"]
      item["deployment_id"] = currentDeploymentId
      item["object_id"] = objectId
      item["revision_id"] = revisionId
      item["revision_no"] = revision["revision_no"]
      item["source_sha256"] = revision["source_sha256"]
      item["relative_path"] = objectRow["relative_path"]
      item["resolution"] = resolution
      item["branch_id"] = branchId
      package~manifest~append(item)
    end

    resourceRs = self~query("SELECT resource_id,resource_revision_id,materialisation_path FROM ssc_deployment_resource WHERE deployment_id=" || self~quote(currentDeploymentId) || " ORDER BY materialisation_path,resource_id")
    do resourceRow over resourceRs~rows
      resource = self~resolveResourceRevision(resourceRow["resource_id"], resourceRow["resource_revision_id"])
      path = resourceRow["materialisation_path"]
      if path == .nil | path = "" then path = resource["materialisation_path"]
      content = self~orEmpty(resource["content_text"])
      encoding = "text"
      if content = "" then do
        content = self~orEmpty(resource["content_base64"])
        encoding = "base64"
      end
      package~files[path] = content
      package~resources[path] = content
      resourceItem = .directory~new
      resourceItem["module_id"] = deployment["module_id"]
      resourceItem["deployment_id"] = currentDeploymentId
      resourceItem["resource_id"] = resource["resource_id"]
      resourceItem["resource_revision_id"] = resource["resource_revision_id"]
      resourceItem["content_sha256"] = resource["content_sha256"]
      resourceItem["mime_type"] = resource["mime_type"]
      resourceItem["materialisation_path"] = path
      resourceItem["encoding"] = encoding
      resourceItem["resolution"] = "sealed-resource"
      package~resourceManifest~append(resourceItem)
    end

    dependencyRs = self~query("SELECT resolved_deployment_id FROM ssc_deployment_dependency WHERE deployment_id=" || self~quote(currentDeploymentId) || " ORDER BY target_module_id")
    do dependencyRow over dependencyRs~rows
      deploymentQueue~queue(dependencyRow["resolved_deployment_id"])
    end
  end

  self~materialiseResolved(package, resolvedObjects, projectId)
  return package

::method loadQualifiedDeployment private
  use strict arg deploymentId
  rs = self~query("SELECT deployment_id,module_id,deployment_label,deployment_sequence,status,manifest_sha256,sealed_at FROM ssc_deployment WHERE deployment_id=" || self~quote(deploymentId))
  if rs~rows~items = 0 then raise syntax 88.900 array("deployment not found: " || deploymentId)
  deployment = rs~rows[1]
  if deployment["status"] <> "QUALIFIED" then,
    raise syntax 88.900 array("deployment is not a qualified fixed point: " || deploymentId)
  return deployment

::method orEmpty private
  use strict arg value
  if value == .nil then return ""
  return value

::method queryRows private
  use strict arg statement
  -- Prefer the provider-owned bulk relation path when available. PostgreSQL
  -- Native Backends v0.2 implements querySet()->asArray without TSV framing or
  -- per-row Database Core reconstruction. Other providers retain execute().
  if self~sql~hasMethod("QUERYSET") then do
    bulk = self~sql~querySet(statement)
    if bulk~hasMethod("OK") then if \bulk~ok then,
      raise syntax 88.900 array("Database bulk query failed: " || statement || "; " || bulk~errorText)
    if bulk~hasMethod("ASARRAY") then return bulk~asArray
  end
  rs = self~query(statement)
  return rs~rows

::method quotedList private
  use strict arg values
  text = ""
  do value over values
    if text <> "" then text ||= ","
    text ||= self~quote(value)
  end
  return text

::method query private
  use strict arg statement
  rs = self~sql~execute(statement)
  if rs~status = "SUCCESS" then return rs
  raise syntax 88.900 array("Database query failed: " || statement || "; " || rs~message)

::method quote private
  use strict arg value
  return "'" || value~changestr("'", "''") || "'"

