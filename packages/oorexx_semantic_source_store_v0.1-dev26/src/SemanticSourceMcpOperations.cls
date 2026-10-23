/*
 * Semantic Source Control - MCP operation dispatcher.
 *
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 *
 * Transport-neutral: an MCP/HTTPS host (oorexx_mcp_service, oorexx_https_server)
 * terminates JSON-RPC, authenticates the caller (auth.challenge/auth.authenticate
 * -> opaque bearer session), and calls
 *
 *     reply = operations~dispatch(operationName, requestDirectory, principal)
 *
 * The principal is the authenticated session's principal.  A principal or
 * permission claim inside the request body is ignored (SSC auth design: an
 * authentication session is not an authorization grant).  Acceptance decisions
 * are additionally authorized per operation by the repository's authorizer.
 *
 * Documented operations (MCP_COMMANDS.md):
 *   source.import_archive_begin | source.import_archive_member |
 *   source.import_archive_complete | source.import_archive_fail | source.get_package
 * Added with the repository authority (2026-10-23):
 *   source.import_archive_resource | source.accept_revision | source.refuse_revision |
 *   source.accept_import | source.history | source.objects_in
 *
 * Every reply is a Directory with ok=1|0, operation, and either the payload or
 * error.  Nothing is raised to the transport.
 */

::class SemanticSourceMcpOperations public

::method init
  expose repository reader
  use strict arg repositoryService, packageReader
  if repositoryService == .nil | packageReader == .nil then raise syntax 88.900 array("repository and package reader are required")
  repository = repositoryService
  reader = packageReader

::method operations
  return .array~of("source.import_archive_begin", "source.import_archive_member", "source.import_archive_resource",,
                   "source.import_archive_complete", "source.import_archive_fail", "source.get_package",,
                   "source.accept_revision", "source.refuse_revision", "source.accept_import",,
                   "source.history", "source.objects_in")

::method dispatch
  expose repository reader
  use strict arg operation, request, principal = ""
  reply = .directory~new
  reply["operation"] = operation
  reply["ok"] = 0
  signal on syntax name failed
  if request == .nil then request = .directory~new
  if request~hasIndex("imported_by") then request["submitted_imported_by"] = request["imported_by"]
  if principal \= "" then request["imported_by"] = principal
  select
    when operation = "source.import_archive_begin" then reply["import_id"] = repository~beginArchive(request)
    when operation = "source.import_archive_member" then reply["result"] = repository~importArchiveMember(request)
    when operation = "source.import_archive_resource" then reply["result"] = repository~importResourceMember(request)
    when operation = "source.import_archive_complete" then reply["completed"] = repository~completeArchive(self~need(request, "import_id"), request["summary"])
    when operation = "source.import_archive_fail" then reply["failed"] = repository~failArchive(self~need(request, "import_id"), request["summary"])
    when operation = "source.accept_revision" then reply["accepted"] = repository~acceptRevision(self~need(request, "revision_id"), principal, self~opt(request, "reason"))
    when operation = "source.refuse_revision" then reply["refused"] = repository~refuseRevision(self~need(request, "revision_id"), principal, self~opt(request, "reason"))
    when operation = "source.accept_import" then reply["result"] = repository~acceptImport(self~need(request, "import_id"), principal, self~opt(request, "reason"))
    when operation = "source.history" then reply["revisions"] = self~plainRows(repository~history(self~need(request, "object_id")))
    when operation = "source.objects_in" then reply["objects"] = repository~objectsIn(self~need(request, "source_unit_object_id"))
    when operation = "source.get_package" then do
      roots = request["roots"]
      if roots == .nil then raise syntax 88.900 array("roots is required")
      if \roots~isA(.Array) then roots = .array~of(roots)
      pins = request["pins"]
      projectId = self~opt(request, "project_id")
      if projectId = "" then projectId = "default"
      pkg = reader~getPackage(roots, pins, projectId)
      reply["files"] = pkg~files
      reply["manifest"] = pkg~manifest
      reply["resolution_policy"] = pkg~resolutionPolicy
    end
    otherwise raise syntax 88.900 array("unknown operation: " || operation)
  end
  signal off syntax
  reply["ok"] = 1
  return reply

failed:
  signal off syntax
  co = condition("O")
  text = condition("D")
  if co \== .nil then if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]
    text = text a
  end
  reply["error"] = text~strip
  return reply

::method need private
  use strict arg request, name
  v = request[name]
  if v == .nil then raise syntax 88.900 array(name || " is required")
  if v = "" then raise syntax 88.900 array(name || " is required")
  return v

::method opt private
  use strict arg request, name
  v = request[name]
  if v == .nil then return ""
  return v

/* DatabaseRow -> Directory so replies serialize as plain JSON objects. */
::method plainRows private
  use strict arg rows
  out = .array~new
  do row over rows
    d = .directory~new
    if row~hasMethod("VALUES") then do name over row~values~allIndexes
      d[name] = row~values[name]
    end
    out~append(d)
  end
  return out

::requires "SemanticSourceRepositoryService.cls"
::requires "SemanticSourceLayoutPackageService.cls"
