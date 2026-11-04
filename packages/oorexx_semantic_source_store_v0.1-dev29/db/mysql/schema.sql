-- Semantic Source Control schema v13 - MySQL 8 / MariaDB backing
-- Same semantic 47-table model; physical types adapted for MySQL-family engines.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE ssc_repository_meta (
  meta_key VARCHAR(191) PRIMARY KEY,
  meta_value VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_import_batch (
  import_id VARCHAR(191) PRIMARY KEY,
  source_kind VARCHAR(96),
  archive_filename VARCHAR(1024),
  archive_sha256 CHAR(64),
  imported_at VARCHAR(64),
  imported_by VARCHAR(255),
  parser_id VARCHAR(191),
  status VARCHAR(96)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_import_member (
  import_member_id VARCHAR(191) PRIMARY KEY,
  import_id VARCHAR(191),
  member_path VARCHAR(1024),
  member_sha256 CHAR(64),
  language VARCHAR(96),
  status VARCHAR(96),
  object_count INTEGER,
  error_text LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_language_profile (
  language_id VARCHAR(191) PRIMARY KEY,
  display_name VARCHAR(255),
  adapter_id VARCHAR(191),
  rebuildable INTEGER,
  object_model VARCHAR(255),
  dependency_model VARCHAR(255),
  export_model VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_source_unit (
  source_unit_id VARCHAR(191) PRIMARY KEY,
  module_id VARCHAR(191),
  language VARCHAR(96),
  source_unit_kind VARCHAR(96),
  projection_path VARCHAR(1024),
  projection_extension VARCHAR(255),
  executable_object_id VARCHAR(191),
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_projection_binding (
  projection_binding_id VARCHAR(191) PRIMARY KEY,
  source_unit_id VARCHAR(191),
  object_id VARCHAR(191),
  semantic_owner_object_id VARCHAR(191),
  projection_owner_object_id VARCHAR(191),
  projection_role VARCHAR(96),
  ordinal INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_source_object (
  object_id VARCHAR(191) PRIMARY KEY,
  language VARCHAR(96),
  object_kind VARCHAR(96),
  logical_name VARCHAR(255),
  source_spelling VARCHAR(255),
  runtime_spelling VARCHAR(255),
  lookup_key VARCHAR(255),
  semantic_key VARCHAR(255),
  description LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  current_revision_id VARCHAR(191),
  accepted_revision_id VARCHAR(191),
  design_document_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_source_revision (
  revision_id VARCHAR(191) PRIMARY KEY,
  object_id VARCHAR(191),
  parent_revision_id VARCHAR(191),
  revision_no INTEGER,
  source_text LONGTEXT,
  source_sha256 CHAR(64),
  status VARCHAR(96),
  changed_at VARCHAR(64),
  changed_by VARCHAR(255),
  change_reason LONGTEXT,
  origin_import_id VARCHAR(191),
  origin_archive_filename VARCHAR(1024),
  origin_archive_sha256 CHAR(64),
  origin_member_path VARCHAR(1024),
  materialisation_path VARCHAR(1024)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_projection_member (
  projection_member_id VARCHAR(191) PRIMARY KEY,
  revision_id VARCHAR(191),
  project_id VARCHAR(191),
  relative_path VARCHAR(1024),
  ordinal INTEGER,
  prefix_text LONGTEXT,
  suffix_text LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_relation (
  relation_id VARCHAR(191) PRIMARY KEY,
  from_object_id VARCHAR(191),
  relation_kind VARCHAR(96),
  to_object_id VARCHAR(191),
  detail LONGTEXT,
  revision_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_qualification (
  qualification_id VARCHAR(191) PRIMARY KEY,
  revision_id VARCHAR(191),
  test_id VARCHAR(191),
  status VARCHAR(96),
  executed_at VARCHAR(64),
  executed_by VARCHAR(255),
  evidence LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_design_document (
  design_document_id VARCHAR(191) PRIMARY KEY,
  object_id VARCHAR(191),
  design_revision_no INTEGER,
  status VARCHAR(96),
  purpose LONGTEXT,
  design_text LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  parent_design_document_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_ticket (
  ticket_id VARCHAR(191) PRIMARY KEY,
  title VARCHAR(255),
  objective LONGTEXT,
  status VARCHAR(96),
  priority INTEGER,
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_ticket_item (
  ticket_item_id VARCHAR(191) PRIMARY KEY,
  ticket_id VARCHAR(191),
  sequence_no INTEGER,
  object_id VARCHAR(191),
  base_revision_id VARCHAR(191),
  design_document_id VARCHAR(191),
  requested_change VARCHAR(255),
  scope_boundary VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_rule (
  rule_id VARCHAR(191) PRIMARY KEY,
  ticket_item_id VARCHAR(191),
  sequence_no INTEGER,
  rule_kind VARCHAR(255),
  rule_text LONGTEXT,
  reference_object_id VARCHAR(191),
  reference_revision_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_entry (
  work_entry_id VARCHAR(191) PRIMARY KEY,
  ticket_id VARCHAR(191),
  producer VARCHAR(255),
  producer_model VARCHAR(255),
  submitted_at VARCHAR(64),
  status VARCHAR(96),
  summary LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_entry_item (
  work_entry_item_id VARCHAR(191) PRIMARY KEY,
  work_entry_id VARCHAR(191),
  ticket_item_id VARCHAR(191),
  object_id VARCHAR(191),
  parent_revision_id VARCHAR(191),
  proposed_revision_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_work_review (
  review_id VARCHAR(191) PRIMARY KEY,
  work_entry_id VARCHAR(191),
  outcome VARCHAR(96),
  reviewed_at VARCHAR(64),
  reviewed_by VARCHAR(255),
  findings LONGTEXT,
  evidence LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_package_request (
  package_request_id VARCHAR(191) PRIMARY KEY,
  requested_at VARCHAR(64),
  requested_by VARCHAR(255),
  resolution_policy VARCHAR(255),
  status VARCHAR(96),
  manifest_text LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_package_request_item (
  package_request_item_id VARCHAR(191) PRIMARY KEY,
  package_request_id VARCHAR(191),
  object_id VARCHAR(191),
  requested_revision_id VARCHAR(191),
  resolved_revision_id VARCHAR(191),
  is_root INTEGER,
  dependency_depth INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_code_finding (
  finding_id VARCHAR(191) PRIMARY KEY,
  object_id VARCHAR(191),
  revision_id VARCHAR(191),
  work_entry_id VARCHAR(191),
  ticket_id VARCHAR(191),
  category VARCHAR(255),
  severity VARCHAR(255),
  status VARCHAR(96),
  line_start INTEGER,
  line_end INTEGER,
  summary LONGTEXT,
  detail LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  resolved_at VARCHAR(64),
  resolved_by VARCHAR(255),
  resolution LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_method_requirement (
  requirement_id VARCHAR(191) PRIMARY KEY,
  object_id VARCHAR(191),
  requirement_kind VARCHAR(96),
  requirement_text LONGTEXT,
  status VARCHAR(96),
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  supersedes_requirement_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_method_note (
  note_id VARCHAR(191) PRIMARY KEY,
  object_id VARCHAR(191),
  revision_id VARCHAR(191),
  note_kind VARCHAR(96),
  title VARCHAR(255),
  note_text LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  supersedes_note_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_export (
  export_id VARCHAR(191) PRIMARY KEY,
  provider_object_id VARCHAR(191),
  provider_revision_id VARCHAR(191),
  export_kind VARCHAR(96),
  export_name VARCHAR(255),
  visibility VARCHAR(96),
  detail LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_resource_object (
  resource_id VARCHAR(191) PRIMARY KEY,
  logical_name VARCHAR(255),
  resource_kind VARCHAR(96),
  mime_type VARCHAR(255),
  description LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  accepted_revision_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_resource_revision (
  resource_revision_id VARCHAR(191) PRIMARY KEY,
  resource_id VARCHAR(191),
  parent_revision_id VARCHAR(191),
  revision_no INTEGER,
  content_text LONGTEXT,
  content_base64 LONGTEXT,
  content_sha256 CHAR(64),
  mime_type VARCHAR(255),
  status VARCHAR(96),
  changed_at VARCHAR(64),
  changed_by VARCHAR(255),
  origin_archive_filename VARCHAR(1024),
  origin_archive_sha256 CHAR(64),
  origin_member_path VARCHAR(1024),
  materialisation_path VARCHAR(1024)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_resource_relation (
  resource_relation_id VARCHAR(191) PRIMARY KEY,
  from_object_id VARCHAR(191),
  from_revision_id VARCHAR(191),
  relation_kind VARCHAR(96),
  resource_id VARCHAR(191),
  required_revision_id VARCHAR(191),
  detail LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_module (
  module_id VARCHAR(191) PRIMARY KEY,
  module_name VARCHAR(255),
  description LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  latest_qualified_deployment_id VARCHAR(191)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_deployment (
  deployment_id VARCHAR(191) PRIMARY KEY,
  module_id VARCHAR(191),
  deployment_label VARCHAR(255),
  deployment_sequence INTEGER,
  status VARCHAR(96),
  qualified_at VARCHAR(64),
  qualified_by VARCHAR(255),
  qualification_evidence LONGTEXT,
  manifest_sha256 CHAR(64),
  sealed_at VARCHAR(64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_deployment_object (
  deployment_object_id VARCHAR(191) PRIMARY KEY,
  deployment_id VARCHAR(191),
  object_id VARCHAR(191),
  revision_id VARCHAR(191),
  relative_path VARCHAR(1024),
  ordinal INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_deployment_resource (
  deployment_resource_id VARCHAR(191) PRIMARY KEY,
  deployment_id VARCHAR(191),
  resource_id VARCHAR(191),
  resource_revision_id VARCHAR(191),
  materialisation_path VARCHAR(1024)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_deployment_dependency (
  deployment_dependency_id VARCHAR(191) PRIMARY KEY,
  deployment_id VARCHAR(191),
  target_module_id VARCHAR(191),
  resolved_deployment_id VARCHAR(191),
  requirement_summary LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_module_requirement (
  module_requirement_id VARCHAR(191) PRIMARY KEY,
  requiring_module_id VARCHAR(191),
  scope_kind VARCHAR(96),
  scope_id VARCHAR(191),
  target_module_id VARCHAR(191),
  constraint_kind VARCHAR(96),
  required_deployment_id VARCHAR(191),
  reason LONGTEXT,
  status VARCHAR(96),
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_branch (
  branch_id VARCHAR(191) PRIMARY KEY,
  module_id VARCHAR(191),
  parent_branch_id VARCHAR(191),
  base_deployment_id VARCHAR(191),
  classification VARCHAR(96),
  upstream_policy VARCHAR(96),
  status VARCHAR(96),
  created_at VARCHAR(64),
  created_by VARCHAR(255),
  confirmed_at VARCHAR(64),
  confirmed_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_branch_override (
  branch_override_id VARCHAR(191) PRIMARY KEY,
  branch_id VARCHAR(191),
  object_id VARCHAR(191),
  revision_id VARCHAR(191),
  reason LONGTEXT,
  status VARCHAR(96),
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_branch_conflict (
  branch_conflict_id VARCHAR(191) PRIMARY KEY,
  branch_id VARCHAR(191),
  object_id VARCHAR(191),
  parent_revision_id VARCHAR(191),
  candidate_revision_a VARCHAR(255),
  candidate_revision_b VARCHAR(255),
  status VARCHAR(96),
  created_at VARCHAR(64),
  resolved_at VARCHAR(64),
  resolution LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_branch_protection (
  branch_protection_id VARCHAR(191) PRIMARY KEY,
  branch_id VARCHAR(191),
  scope_kind VARCHAR(96),
  scope_id VARCHAR(191),
  policy VARCHAR(96),
  reason LONGTEXT,
  status VARCHAR(96),
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_branch_event (
  branch_event_id VARCHAR(191) PRIMARY KEY,
  branch_id VARCHAR(191),
  event_kind VARCHAR(96),
  object_id VARCHAR(191),
  upstream_revision_id VARCHAR(191),
  outcome VARCHAR(96),
  detail LONGTEXT,
  event_at VARCHAR(64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_semantic_reference (
  reference_id VARCHAR(191) PRIMARY KEY,
  from_object_id VARCHAR(191),
  from_revision_id VARCHAR(191),
  reference_kind VARCHAR(96),
  lexeme VARCHAR(255),
  target_object_id VARCHAR(191),
  target_revision_id VARCHAR(191),
  target_module_id VARCHAR(191),
  resolution_state VARCHAR(96),
  source_line INTEGER,
  source_column INTEGER,
  detail LONGTEXT,
  created_at VARCHAR(64),
  created_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_reference_observation (
  observation_id VARCHAR(191) PRIMARY KEY,
  reference_id VARCHAR(191),
  observed_target_object_id VARCHAR(191),
  observed_target_revision_id VARCHAR(191),
  evidence_kind VARCHAR(255),
  evidence_id VARCHAR(191),
  observed_at VARCHAR(64),
  observed_by VARCHAR(255),
  detail LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_runtime_class_snapshot (
  snapshot_id VARCHAR(191) PRIMARY KEY,
  module_id VARCHAR(191),
  source_object_id VARCHAR(191),
  source_revision_id VARCHAR(191),
  package_name VARCHAR(255),
  class_id VARCHAR(191),
  runtime_name VARCHAR(255),
  runtime_version VARCHAR(255),
  captured_at VARCHAR(64),
  captured_by VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_runtime_inheritance_edge (
  edge_id VARCHAR(191) PRIMARY KEY,
  snapshot_id VARCHAR(191),
  child_class_id VARCHAR(191),
  parent_class_id VARCHAR(191),
  parent_ordinal INTEGER,
  depth INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_runtime_method_surface (
  surface_id VARCHAR(191) PRIMARY KEY,
  snapshot_id VARCHAR(191),
  method_scope VARCHAR(96),
  method_name VARCHAR(255),
  method_source_spelling VARCHAR(255),
  method_runtime_spelling VARCHAR(255),
  method_lookup_key VARCHAR(255),
  origin_package_name VARCHAR(255),
  origin_class_id VARCHAR(191),
  relation_kind VARCHAR(96),
  is_effective INTEGER,
  is_hidden INTEGER,
  overrides_package_name VARCHAR(255),
  overrides_class_id VARCHAR(191),
  depth INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_auth_challenge (
  challenge_id VARCHAR(191) PRIMARY KEY,
  key_id VARCHAR(191),
  audience VARCHAR(255),
  action_name VARCHAR(96),
  resource_id VARCHAR(191),
  nonce VARCHAR(255),
  issued_at VARCHAR(64),
  expires_at VARCHAR(64),
  consumed_at VARCHAR(64),
  status VARCHAR(96)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_auth_session (
  session_id VARCHAR(191) PRIMARY KEY,
  access_token_hash CHAR(64),
  principal_id VARCHAR(191),
  key_id VARCHAR(191),
  audience VARCHAR(255),
  issued_at VARCHAR(64),
  expires_at VARCHAR(64),
  status VARCHAR(96),
  auth_context LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_auth_event (
  event_id VARCHAR(191) PRIMARY KEY,
  event_time VARCHAR(64),
  event_kind VARCHAR(96),
  principal_id VARCHAR(191),
  key_id VARCHAR(191),
  challenge_id VARCHAR(191),
  session_id VARCHAR(191),
  action_name VARCHAR(96),
  resource_id VARCHAR(191),
  outcome VARCHAR(96),
  detail LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE ssc_test_request (
  test_request_id VARCHAR(191) PRIMARY KEY,
  package_request_id VARCHAR(191),
  work_entry_id VARCHAR(191),
  requested_at VARCHAR(64),
  requested_by VARCHAR(255),
  test_profile VARCHAR(96),
  status VARCHAR(96),
  result_summary LONGTEXT,
  evidence LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

SET FOREIGN_KEY_CHECKS = 1;
