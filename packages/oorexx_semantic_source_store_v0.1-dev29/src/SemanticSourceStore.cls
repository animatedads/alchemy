/*
 * Semantic Source Control - backend-neutral persistence boundary
 *
 * The semantic objects are authoritative. Materialised source files are projections.
 * All mutations are intended to arrive through the MCP service layer.
 */

::class SemanticSourceStore public

::constant SCHEMA_VERSION "13"

::method init
  use strict arg databaseRoot, sqlExecutor, backendId

  if databaseRoot = "" then
    raise syntax 88.900 array("databaseRoot must not be empty")
  if backendId = "" then
    raise syntax 88.900 array("backendId must not be empty")

  self~databaseRoot = databaseRoot
  self~backendId = backendId

  -- Database provider selection belongs to the registered backend-selector
  -- framework at the composition root.  The semantic store is deliberately
  -- backend-neutral and will never load NoSQLServer, Database Core, PostgreSQL,
  -- MySQL, or provider packages itself.
  if sqlExecutor == .nil then
    raise syntax 88.900 array("sqlExecutor is required; resolve OOREXX_DATABASE_PROVIDER through DatabaseBackendSelector before constructing SemanticSourceStore")

  self~engine = .nil
  self~sql = sqlExecutor

::attribute databaseRoot get
::attribute databaseRoot set private
::attribute backendId get
::attribute backendId set private
::attribute engine get
::attribute engine set private
::attribute sql get
::attribute sql set private

::method bootstrap
  statements = .array~new

  statements~append("CREATE TABLE ssc_repository_meta (meta_key VARCHAR PRIMARY KEY, meta_value VARCHAR)")

  statements~append("CREATE TABLE ssc_import_batch (" ||,
                    "import_id VARCHAR PRIMARY KEY, " ||,
                    "source_kind VARCHAR, " ||,
                    "archive_filename VARCHAR, " ||,
                    "archive_sha256 VARCHAR, " ||,
                    "imported_at VARCHAR, " ||,
                    "imported_by VARCHAR, " ||,
                    "parser_id VARCHAR, " ||,
                    "status VARCHAR)")

  statements~append("CREATE TABLE ssc_import_member (" ||,
                    "import_member_id VARCHAR PRIMARY KEY, " ||,
                    "import_id VARCHAR, " ||,
                    "member_path VARCHAR, " ||,
                    "member_sha256 VARCHAR, " ||,
                    "language VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "object_count INTEGER, " ||,
                    "error_text VARCHAR)")

  statements~append("CREATE TABLE ssc_language_profile (" ||,
                    "language_id VARCHAR PRIMARY KEY, " ||,
                    "display_name VARCHAR, " ||,
                    "adapter_id VARCHAR, " ||,
                    "rebuildable INTEGER, " ||,
                    "object_model VARCHAR, " ||,
                    "dependency_model VARCHAR, " ||,
                    "export_model VARCHAR)")

  -- A language source unit is independent of filename extension.  In ooRexx,
  -- .rex and .cls are both package source units and may contain a runnable
  -- executable section plus directives.
  statements~append("CREATE TABLE ssc_source_unit (" ||,
                    "source_unit_id VARCHAR PRIMARY KEY, " ||,
                    "module_id VARCHAR, " ||,
                    "language VARCHAR, " ||,
                    "source_unit_kind VARCHAR, " ||,
                    "projection_path VARCHAR, " ||,
                    "projection_extension VARCHAR, " ||,
                    "executable_object_id VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  -- Semantic ownership may differ from textual/projection ownership.  This is
  -- required for Rust impl blocks and C++ out-of-class definitions.
  statements~append("CREATE TABLE ssc_projection_binding (" ||,
                    "projection_binding_id VARCHAR PRIMARY KEY, " ||,
                    "source_unit_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "semantic_owner_object_id VARCHAR, " ||,
                    "projection_owner_object_id VARCHAR, " ||,
                    "projection_role VARCHAR, " ||,
                    "ordinal INTEGER)")

  statements~append("CREATE TABLE ssc_source_object (" ||,
                    "object_id VARCHAR PRIMARY KEY, " ||,
                    "language VARCHAR, " ||,
                    "object_kind VARCHAR, " ||,
                    "logical_name VARCHAR, " ||,
                    "source_spelling VARCHAR, " ||,
                    "runtime_spelling VARCHAR, " ||,
                    "lookup_key VARCHAR, " ||,
                    "semantic_key VARCHAR, " ||,
                    "description VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "current_revision_id VARCHAR, " ||,
                    "accepted_revision_id VARCHAR, " ||,
                    "design_document_id VARCHAR)")

  statements~append("CREATE TABLE ssc_source_revision (" ||,
                    "revision_id VARCHAR PRIMARY KEY, " ||,
                    "object_id VARCHAR, " ||,
                    "parent_revision_id VARCHAR, " ||,
                    "revision_no INTEGER, " ||,
                    "source_text VARCHAR, " ||,
                    "source_sha256 VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "changed_at VARCHAR, " ||,
                    "changed_by VARCHAR, " ||,
                    "change_reason VARCHAR, " ||,
                    "origin_import_id VARCHAR, " ||,
                    "origin_archive_filename VARCHAR, " ||,
                    "origin_archive_sha256 VARCHAR, " ||,
                    "origin_member_path VARCHAR, " ||,
                    "materialisation_path VARCHAR)")

  statements~append("CREATE TABLE ssc_projection_member (" ||,
                    "projection_member_id VARCHAR PRIMARY KEY, " ||,
                    "revision_id VARCHAR, " ||,
                    "project_id VARCHAR, " ||,
                    "relative_path VARCHAR, " ||,
                    "ordinal INTEGER, " ||,
                    "prefix_text VARCHAR, " ||,
                    "suffix_text VARCHAR)")

  statements~append("CREATE TABLE ssc_relation (" ||,
                    "relation_id VARCHAR PRIMARY KEY, " ||,
                    "from_object_id VARCHAR, " ||,
                    "relation_kind VARCHAR, " ||,
                    "to_object_id VARCHAR, " ||,
                    "detail VARCHAR, " ||,
                    "revision_id VARCHAR)")

  statements~append("CREATE TABLE ssc_qualification (" ||,
                    "qualification_id VARCHAR PRIMARY KEY, " ||,
                    "revision_id VARCHAR, " ||,
                    "test_id VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "executed_at VARCHAR, " ||,
                    "executed_by VARCHAR, " ||,
                    "evidence VARCHAR)")

  -- Design is attached to the semantic element, but revisioned independently of code.
  statements~append("CREATE TABLE ssc_design_document (" ||,
                    "design_document_id VARCHAR PRIMARY KEY, " ||,
                    "object_id VARCHAR, " ||,
                    "design_revision_no INTEGER, " ||,
                    "status VARCHAR, " ||,
                    "purpose VARCHAR, " ||,
                    "design_text VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "parent_design_document_id VARCHAR)")

  -- A ticket is the bounded unit of requested work.
  statements~append("CREATE TABLE ssc_work_ticket (" ||,
                    "ticket_id VARCHAR PRIMARY KEY, " ||,
                    "title VARCHAR, " ||,
                    "objective VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "priority INTEGER, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  statements~append("CREATE TABLE ssc_work_ticket_item (" ||,
                    "ticket_item_id VARCHAR PRIMARY KEY, " ||,
                    "ticket_id VARCHAR, " ||,
                    "sequence_no INTEGER, " ||,
                    "object_id VARCHAR, " ||,
                    "base_revision_id VARCHAR, " ||,
                    "design_document_id VARCHAR, " ||,
                    "requested_change VARCHAR, " ||,
                    "scope_boundary VARCHAR)")

  -- Rules are intentionally first-class so coders and reviewers refer to the same obligation IDs.
  statements~append("CREATE TABLE ssc_work_rule (" ||,
                    "rule_id VARCHAR PRIMARY KEY, " ||,
                    "ticket_item_id VARCHAR, " ||,
                    "sequence_no INTEGER, " ||,
                    "rule_kind VARCHAR, " ||,
                    "rule_text VARCHAR, " ||,
                    "reference_object_id VARCHAR, " ||,
                    "reference_revision_id VARCHAR)")

  -- One submission may cover several semantic source objects from one ticket.
  statements~append("CREATE TABLE ssc_work_entry (" ||,
                    "work_entry_id VARCHAR PRIMARY KEY, " ||,
                    "ticket_id VARCHAR, " ||,
                    "producer VARCHAR, " ||,
                    "producer_model VARCHAR, " ||,
                    "submitted_at VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "summary VARCHAR)")

  statements~append("CREATE TABLE ssc_work_entry_item (" ||,
                    "work_entry_item_id VARCHAR PRIMARY KEY, " ||,
                    "work_entry_id VARCHAR, " ||,
                    "ticket_item_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "parent_revision_id VARCHAR, " ||,
                    "proposed_revision_id VARCHAR)")

  statements~append("CREATE TABLE ssc_work_review (" ||,
                    "review_id VARCHAR PRIMARY KEY, " ||,
                    "work_entry_id VARCHAR, " ||,
                    "outcome VARCHAR, " ||,
                    "reviewed_at VARCHAR, " ||,
                    "reviewed_by VARCHAR, " ||,
                    "findings VARCHAR, " ||,
                    "evidence VARCHAR)")

  -- Package requests provide reproducible review/test projections through MCP.
  statements~append("CREATE TABLE ssc_package_request (" ||,
                    "package_request_id VARCHAR PRIMARY KEY, " ||,
                    "requested_at VARCHAR, " ||,
                    "requested_by VARCHAR, " ||,
                    "resolution_policy VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "manifest_text VARCHAR)")

  statements~append("CREATE TABLE ssc_package_request_item (" ||,
                    "package_request_item_id VARCHAR PRIMARY KEY, " ||,
                    "package_request_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "requested_revision_id VARCHAR, " ||,
                    "resolved_revision_id VARCHAR, " ||,
                    "is_root INTEGER, " ||,
                    "dependency_depth INTEGER)")

  -- Human code examiner findings are durable review evidence against exact revisions.
  statements~append("CREATE TABLE ssc_code_finding (" ||,
                    "finding_id VARCHAR PRIMARY KEY, " ||,
                    "object_id VARCHAR, " ||,
                    "revision_id VARCHAR, " ||,
                    "work_entry_id VARCHAR, " ||,
                    "ticket_id VARCHAR, " ||,
                    "category VARCHAR, " ||,
                    "severity VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "line_start INTEGER, " ||,
                    "line_end INTEGER, " ||,
                    "summary VARCHAR, " ||,
                    "detail VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "resolved_at VARCHAR, " ||,
                    "resolved_by VARCHAR, " ||,
                    "resolution VARCHAR)")

  -- Method-level requirements are explicit obligations attached to a semantic method object.
  statements~append("CREATE TABLE ssc_method_requirement (" ||,
                    "requirement_id VARCHAR PRIMARY KEY, " ||,
                    "object_id VARCHAR, " ||,
                    "requirement_kind VARCHAR, " ||,
                    "requirement_text VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "supersedes_requirement_id VARCHAR)")

  -- Human/LLM notes and documentation remain revisioned evidence separate from source text.
  statements~append("CREATE TABLE ssc_method_note (" ||,
                    "note_id VARCHAR PRIMARY KEY, " ||,
                    "object_id VARCHAR, " ||,
                    "revision_id VARCHAR, " ||,
                    "note_kind VARCHAR, " ||,
                    "title VARCHAR, " ||,
                    "note_text VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "supersedes_note_id VARCHAR)")

  -- Explicit exports allow ::requires dependencies to prove that required public symbols exist.
  statements~append("CREATE TABLE ssc_export (" ||,
                    "export_id VARCHAR PRIMARY KEY, " ||,
                    "provider_object_id VARCHAR, " ||,
                    "provider_revision_id VARCHAR, " ||,
                    "export_kind VARCHAR, " ||,
                    "export_name VARCHAR, " ||,
                    "visibility VARCHAR, " ||,
                    "detail VARCHAR)")

  -- Non-code package resources are first-class, versioned semantic resources.
  statements~append("CREATE TABLE ssc_resource_object (" ||,
                    "resource_id VARCHAR PRIMARY KEY, " ||,
                    "logical_name VARCHAR, " ||,
                    "resource_kind VARCHAR, " ||,
                    "mime_type VARCHAR, " ||,
                    "description VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "accepted_revision_id VARCHAR)")

  statements~append("CREATE TABLE ssc_resource_revision (" ||,
                    "resource_revision_id VARCHAR PRIMARY KEY, " ||,
                    "resource_id VARCHAR, " ||,
                    "parent_revision_id VARCHAR, " ||,
                    "revision_no INTEGER, " ||,
                    "content_text VARCHAR, " ||,
                    "content_base64 VARCHAR, " ||,
                    "content_sha256 VARCHAR, " ||,
                    "mime_type VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "changed_at VARCHAR, " ||,
                    "changed_by VARCHAR, " ||,
                    "origin_archive_filename VARCHAR, " ||,
                    "origin_archive_sha256 VARCHAR, " ||,
                    "origin_member_path VARCHAR, " ||,
                    "materialisation_path VARCHAR)")

  statements~append("CREATE TABLE ssc_resource_relation (" ||,
                    "resource_relation_id VARCHAR PRIMARY KEY, " ||,
                    "from_object_id VARCHAR, " ||,
                    "from_revision_id VARCHAR, " ||,
                    "relation_kind VARCHAR, " ||,
                    "resource_id VARCHAR, " ||,
                    "required_revision_id VARCHAR, " ||,
                    "detail VARCHAR)")

  -- A module is the durable logical code unit; deployment versions are qualified fixed points.
  statements~append("CREATE TABLE ssc_module (" ||,
                    "module_id VARCHAR PRIMARY KEY, " ||,
                    "module_name VARCHAR, " ||,
                    "description VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "latest_qualified_deployment_id VARCHAR)")

  statements~append("CREATE TABLE ssc_deployment (" ||,
                    "deployment_id VARCHAR PRIMARY KEY, " ||,
                    "module_id VARCHAR, " ||,
                    "deployment_label VARCHAR, " ||,
                    "deployment_sequence INTEGER, " ||,
                    "status VARCHAR, " ||,
                    "qualified_at VARCHAR, " ||,
                    "qualified_by VARCHAR, " ||,
                    "qualification_evidence VARCHAR, " ||,
                    "manifest_sha256 VARCHAR, " ||,
                    "sealed_at VARCHAR)")

  -- Exact semantic revisions and resources contained by an immutable deployment.
  statements~append("CREATE TABLE ssc_deployment_object (" ||,
                    "deployment_object_id VARCHAR PRIMARY KEY, " ||,
                    "deployment_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "revision_id VARCHAR, " ||,
                    "relative_path VARCHAR, " ||,
                    "ordinal INTEGER)")

  statements~append("CREATE TABLE ssc_deployment_resource (" ||,
                    "deployment_resource_id VARCHAR PRIMARY KEY, " ||,
                    "deployment_id VARCHAR, " ||,
                    "resource_id VARCHAR, " ||,
                    "resource_revision_id VARCHAR, " ||,
                    "materialisation_path VARCHAR)")

  -- A sealed deployment records the exact dependency closure that was qualified.
  statements~append("CREATE TABLE ssc_deployment_dependency (" ||,
                    "deployment_dependency_id VARCHAR PRIMARY KEY, " ||,
                    "deployment_id VARCHAR, " ||,
                    "target_module_id VARCHAR, " ||,
                    "resolved_deployment_id VARCHAR, " ||,
                    "requirement_summary VARCHAR)")

  -- Requirements may be scoped at module, file or method.  MINIMUM constraints accumulate;
  -- the deployment with the greatest deployment_sequence wins.  EXACT constraints must agree.
  statements~append("CREATE TABLE ssc_module_requirement (" ||,
                    "module_requirement_id VARCHAR PRIMARY KEY, " ||,
                    "requiring_module_id VARCHAR, " ||,
                    "scope_kind VARCHAR, " ||,
                    "scope_id VARCHAR, " ||,
                    "target_module_id VARCHAR, " ||,
                    "constraint_kind VARCHAR, " ||,
                    "required_deployment_id VARCHAR, " ||,
                    "reason VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  -- Sparse semantic branches. Hard conflicts create CONFLICT branches automatically.
  statements~append("CREATE TABLE ssc_branch (" ||,
                    "branch_id VARCHAR PRIMARY KEY, " ||,
                    "module_id VARCHAR, " ||,
                    "parent_branch_id VARCHAR, " ||,
                    "base_deployment_id VARCHAR, " ||,
                    "classification VARCHAR, " ||,
                    "upstream_policy VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR, " ||,
                    "confirmed_at VARCHAR, " ||,
                    "confirmed_by VARCHAR)")

  statements~append("CREATE TABLE ssc_branch_override (" ||,
                    "branch_override_id VARCHAR PRIMARY KEY, " ||,
                    "branch_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "revision_id VARCHAR, " ||,
                    "reason VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  statements~append("CREATE TABLE ssc_branch_conflict (" ||,
                    "branch_conflict_id VARCHAR PRIMARY KEY, " ||,
                    "branch_id VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "parent_revision_id VARCHAR, " ||,
                    "candidate_revision_a VARCHAR, " ||,
                    "candidate_revision_b VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "resolved_at VARCHAR, " ||,
                    "resolution VARCHAR)")

  statements~append("CREATE TABLE ssc_branch_protection (" ||,
                    "branch_protection_id VARCHAR PRIMARY KEY, " ||,
                    "branch_id VARCHAR, " ||,
                    "scope_kind VARCHAR, " ||,
                    "scope_id VARCHAR, " ||,
                    "policy VARCHAR, " ||,
                    "reason VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  statements~append("CREATE TABLE ssc_branch_event (" ||,
                    "branch_event_id VARCHAR PRIMARY KEY, " ||,
                    "branch_id VARCHAR, " ||,
                    "event_kind VARCHAR, " ||,
                    "object_id VARCHAR, " ||,
                    "upstream_revision_id VARCHAR, " ||,
                    "outcome VARCHAR, " ||,
                    "detail VARCHAR, " ||,
                    "event_at VARCHAR)")


  -- Semantic source references are explicit graph edges.  They may be resolved,
  -- possible, dynamic or unresolved; the store never invents certainty.
  statements~append("CREATE TABLE ssc_semantic_reference (" ||,
                    "reference_id VARCHAR PRIMARY KEY, " ||,
                    "from_object_id VARCHAR, " ||,
                    "from_revision_id VARCHAR, " ||,
                    "reference_kind VARCHAR, " ||,
                    "lexeme VARCHAR, " ||,
                    "target_object_id VARCHAR, " ||,
                    "target_revision_id VARCHAR, " ||,
                    "target_module_id VARCHAR, " ||,
                    "resolution_state VARCHAR, " ||,
                    "source_line INTEGER, " ||,
                    "source_column INTEGER, " ||,
                    "detail VARCHAR, " ||,
                    "created_at VARCHAR, " ||,
                    "created_by VARCHAR)")

  -- Optional runtime/test observations strengthen or qualify static graph edges.
  statements~append("CREATE TABLE ssc_reference_observation (" ||,
                    "observation_id VARCHAR PRIMARY KEY, " ||,
                    "reference_id VARCHAR, " ||,
                    "observed_target_object_id VARCHAR, " ||,
                    "observed_target_revision_id VARCHAR, " ||,
                    "evidence_kind VARCHAR, " ||,
                    "evidence_id VARCHAR, " ||,
                    "observed_at VARCHAR, " ||,
                    "observed_by VARCHAR, " ||,
                    "detail VARCHAR)")

  -- Runtime class introspection captures the effective ooRexx class surface
  -- without constructing application instances.  Package activation is performed
  -- by an isolated host because package prologs may execute while loading.
  statements~append("CREATE TABLE ssc_runtime_class_snapshot (" ||,
                    "snapshot_id VARCHAR PRIMARY KEY, " ||,
                    "module_id VARCHAR, " ||,
                    "source_object_id VARCHAR, " ||,
                    "source_revision_id VARCHAR, " ||,
                    "package_name VARCHAR, " ||,
                    "class_id VARCHAR, " ||,
                    "runtime_name VARCHAR, " ||,
                    "runtime_version VARCHAR, " ||,
                    "captured_at VARCHAR, " ||,
                    "captured_by VARCHAR)")

  statements~append("CREATE TABLE ssc_runtime_inheritance_edge (" ||,
                    "edge_id VARCHAR PRIMARY KEY, " ||,
                    "snapshot_id VARCHAR, " ||,
                    "child_class_id VARCHAR, " ||,
                    "parent_class_id VARCHAR, " ||,
                    "parent_ordinal INTEGER, " ||,
                    "depth INTEGER)")

  statements~append("CREATE TABLE ssc_runtime_method_surface (" ||,
                    "surface_id VARCHAR PRIMARY KEY, " ||,
                    "snapshot_id VARCHAR, " ||,
                    "method_scope VARCHAR, " ||,
                    "method_name VARCHAR, " ||,
                    "method_source_spelling VARCHAR, " ||,
                    "method_runtime_spelling VARCHAR, " ||,
                    "method_lookup_key VARCHAR, " ||,
                    "origin_package_name VARCHAR, " ||,
                    "origin_class_id VARCHAR, " ||,
                    "relation_kind VARCHAR, " ||,
                    "is_effective INTEGER, " ||,
                    "is_hidden INTEGER, " ||,
                    "overrides_package_name VARCHAR, " ||,
                    "overrides_class_id VARCHAR, " ||,
                    "depth INTEGER)")

  -- Authentication challenge state is application-local evidence only.
  -- Keys, trust/revocation and permissions remain authoritative in the security framework.
  statements~append("CREATE TABLE ssc_auth_challenge (" ||,
                    "challenge_id VARCHAR PRIMARY KEY, " ||,
                    "key_id VARCHAR, " ||,
                    "audience VARCHAR, " ||,
                    "action_name VARCHAR, " ||,
                    "resource_id VARCHAR, " ||,
                    "nonce VARCHAR, " ||,
                    "issued_at VARCHAR, " ||,
                    "expires_at VARCHAR, " ||,
                    "consumed_at VARCHAR, " ||,
                    "status VARCHAR)")

  statements~append("CREATE TABLE ssc_auth_session (" ||,
                    "session_id VARCHAR PRIMARY KEY, " ||,
                    "access_token_hash VARCHAR, " ||,
                    "principal_id VARCHAR, " ||,
                    "key_id VARCHAR, " ||,
                    "audience VARCHAR, " ||,
                    "issued_at VARCHAR, " ||,
                    "expires_at VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "auth_context VARCHAR)")

  statements~append("CREATE TABLE ssc_auth_event (" ||,
                    "event_id VARCHAR PRIMARY KEY, " ||,
                    "event_time VARCHAR, " ||,
                    "event_kind VARCHAR, " ||,
                    "principal_id VARCHAR, " ||,
                    "key_id VARCHAR, " ||,
                    "challenge_id VARCHAR, " ||,
                    "session_id VARCHAR, " ||,
                    "action_name VARCHAR, " ||,
                    "resource_id VARCHAR, " ||,
                    "outcome VARCHAR, " ||,
                    "detail VARCHAR)")

  -- Test requests are server-authoritative requests; execution may be delegated to the qualification broker.
  statements~append("CREATE TABLE ssc_test_request (" ||,
                    "test_request_id VARCHAR PRIMARY KEY, " ||,
                    "package_request_id VARCHAR, " ||,
                    "work_entry_id VARCHAR, " ||,
                    "requested_at VARCHAR, " ||,
                    "requested_by VARCHAR, " ||,
                    "test_profile VARCHAR, " ||,
                    "status VARCHAR, " ||,
                    "result_summary VARCHAR, " ||,
                    "evidence VARCHAR)")

  do statement over statements
    rs = self~sql~execute(statement)
    self~requireSuccess(rs, statement)
  end

  self~insertLiteral("ssc_repository_meta", "meta_key", "schema_version", "meta_value", self~SCHEMA_VERSION)
  self~insertLiteral("ssc_repository_meta", "meta_key", "repository_kind", "meta_value", "semantic-source-control")
  self~insertLiteral("ssc_repository_meta", "meta_key", "write_authority", "meta_value", "mcp-only")
  self~insertLiteral("ssc_repository_meta", "meta_key", "package_default_resolution", "meta_value", "latest-accepted")
  self~insertLiteral("ssc_repository_meta", "meta_key", "storage_backend", "meta_value", self~backendId)

  return self~verify

::method verify
  rs = self~sql~execute("SELECT meta_key, meta_value FROM ssc_repository_meta ORDER BY meta_key")
  self~requireSuccess(rs, "repository verification")
  return rs

::method insertLiteral private
  use strict arg tableName, keyColumn, keyValue, valueColumn, valueValue

  statement = "INSERT INTO " || tableName ||,
              " (" || keyColumn || "," || valueColumn || ") VALUES (" ||,
              self~quote(keyValue) || "," || self~quote(valueValue) || ")"
  rs = self~sql~execute(statement)
  self~requireSuccess(rs, statement)

::method quote private
  use strict arg value
  return "'" || value~changestr("'", "''") || "'"

::method requireSuccess private
  use strict arg result, operation

  if result~status = "SUCCESS" then return

  message = "Semantic Source database operation failed (" || self~backendId || "): " || operation ||,
            "; status=" || result~status ||,
            "; error=" || result~error ||,
            "; message=" || result~message
  raise syntax 88.900 array(message)

