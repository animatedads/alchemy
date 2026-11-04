-- Semantic Source Control v13 - PostgreSQL performance indexes
-- Safe to create after schema.sql and before/after bulk import.
BEGIN;

-- Catalog / semantic identity
CREATE INDEX ssc_source_object_lookup_idx ON ssc_source_object (lookup_key);
CREATE INDEX ssc_source_object_kind_lang_idx ON ssc_source_object (language, object_kind);
CREATE INDEX ssc_source_object_semantic_key_idx ON ssc_source_object (semantic_key);
CREATE INDEX ssc_source_object_current_rev_idx ON ssc_source_object (current_revision_id);
CREATE INDEX ssc_source_object_accepted_rev_idx ON ssc_source_object (accepted_revision_id);

-- Revision history and exact source projection
CREATE INDEX ssc_source_revision_object_no_idx ON ssc_source_revision (object_id, revision_no DESC);
CREATE INDEX ssc_source_revision_object_status_idx ON ssc_source_revision (object_id, status);
CREATE INDEX ssc_source_revision_sha_idx ON ssc_source_revision (source_sha256);
CREATE INDEX ssc_source_revision_changed_idx ON ssc_source_revision (changed_at);
CREATE INDEX ssc_source_revision_origin_member_idx ON ssc_source_revision (origin_archive_sha256, origin_member_path);
CREATE INDEX ssc_projection_member_revision_idx ON ssc_projection_member (revision_id, ordinal);
CREATE INDEX ssc_projection_member_path_idx ON ssc_projection_member (project_id, relative_path);

-- Built-in PostgreSQL full-text index; no extension required.
-- Use the 'simple' dictionary because programming-language identifiers must not
-- be stemmed as natural-language English words.
CREATE INDEX ssc_source_revision_fts_idx
  ON ssc_source_revision USING GIN (to_tsvector('simple', coalesce(source_text, '')));

-- Semantic graph
CREATE INDEX ssc_relation_from_kind_idx ON ssc_relation (from_object_id, relation_kind);
CREATE INDEX ssc_relation_to_kind_idx ON ssc_relation (to_object_id, relation_kind);
CREATE INDEX ssc_relation_revision_idx ON ssc_relation (revision_id);
CREATE INDEX ssc_reference_from_kind_idx ON ssc_semantic_reference (from_object_id, reference_kind);
CREATE INDEX ssc_reference_target_kind_idx ON ssc_semantic_reference (target_object_id, reference_kind);
CREATE INDEX ssc_reference_revision_idx ON ssc_semantic_reference (from_revision_id);
CREATE INDEX ssc_reference_state_idx ON ssc_semantic_reference (resolution_state);
CREATE INDEX ssc_reference_observation_ref_idx ON ssc_reference_observation (reference_id);

-- Source units / projection bindings
CREATE INDEX ssc_source_unit_module_idx ON ssc_source_unit (module_id, language);
CREATE INDEX ssc_source_unit_path_idx ON ssc_source_unit (projection_path);
CREATE INDEX ssc_projection_binding_source_idx ON ssc_projection_binding (source_unit_id, ordinal);
CREATE INDEX ssc_projection_binding_semantic_owner_idx ON ssc_projection_binding (semantic_owner_object_id);

-- Modules / deployments / sealed dependency closure
CREATE INDEX ssc_module_name_idx ON ssc_module (module_name);
CREATE INDEX ssc_deployment_module_seq_idx ON ssc_deployment (module_id, deployment_sequence DESC);
CREATE INDEX ssc_deployment_module_status_idx ON ssc_deployment (module_id, status);
CREATE INDEX ssc_deployment_object_deployment_idx ON ssc_deployment_object (deployment_id, ordinal);
CREATE INDEX ssc_deployment_object_object_idx ON ssc_deployment_object (object_id, revision_id);
CREATE INDEX ssc_deployment_resource_deployment_idx ON ssc_deployment_resource (deployment_id);
CREATE INDEX ssc_deployment_dependency_deployment_idx ON ssc_deployment_dependency (deployment_id);
CREATE INDEX ssc_module_requirement_scope_idx ON ssc_module_requirement (requiring_module_id, scope_kind, scope_id);
CREATE INDEX ssc_module_requirement_target_idx ON ssc_module_requirement (target_module_id, status);

-- Branch overlays / conflict navigation
CREATE INDEX ssc_branch_module_status_idx ON ssc_branch (module_id, status);
CREATE INDEX ssc_branch_override_branch_object_idx ON ssc_branch_override (branch_id, object_id, status);
CREATE INDEX ssc_branch_conflict_branch_status_idx ON ssc_branch_conflict (branch_id, status);
CREATE INDEX ssc_branch_conflict_object_idx ON ssc_branch_conflict (object_id, status);
CREATE INDEX ssc_branch_protection_branch_scope_idx ON ssc_branch_protection (branch_id, scope_kind, scope_id, status);
CREATE INDEX ssc_branch_event_branch_time_idx ON ssc_branch_event (branch_id, event_at);

-- Runtime class inspection: default Examiner view should be cheap.
CREATE INDEX ssc_runtime_snapshot_class_idx ON ssc_runtime_class_snapshot (class_id, captured_at);
CREATE INDEX ssc_runtime_snapshot_source_idx ON ssc_runtime_class_snapshot (source_object_id, source_revision_id);
CREATE INDEX ssc_runtime_inheritance_snapshot_idx ON ssc_runtime_inheritance_edge (snapshot_id, depth, parent_ordinal);
CREATE INDEX ssc_runtime_inheritance_child_idx ON ssc_runtime_inheritance_edge (child_class_id);
CREATE INDEX ssc_runtime_method_snapshot_idx ON ssc_runtime_method_surface (snapshot_id, method_name, depth);
CREATE INDEX ssc_runtime_method_origin_idx ON ssc_runtime_method_surface (origin_class_id, method_name);
CREATE INDEX ssc_runtime_method_lookup_idx ON ssc_runtime_method_surface (method_lookup_key);

-- Method metadata, findings, work, qualification
CREATE INDEX ssc_method_requirement_object_idx ON ssc_method_requirement (object_id, status);
CREATE INDEX ssc_method_note_object_idx ON ssc_method_note (object_id, revision_id);
CREATE INDEX ssc_code_finding_object_rev_idx ON ssc_code_finding (object_id, revision_id, status);
CREATE INDEX ssc_qualification_revision_idx ON ssc_qualification (revision_id, status);
CREATE INDEX ssc_work_ticket_item_ticket_idx ON ssc_work_ticket_item (ticket_id, sequence_no);
CREATE INDEX ssc_work_entry_ticket_idx ON ssc_work_entry (ticket_id, status);
CREATE INDEX ssc_work_entry_item_work_idx ON ssc_work_entry_item (work_entry_id);

-- Package/build resolution
CREATE INDEX ssc_package_item_request_idx ON ssc_package_request_item (package_request_id, dependency_depth);
CREATE INDEX ssc_package_item_object_idx ON ssc_package_request_item (object_id, resolved_revision_id);

-- Resources and exports
CREATE INDEX ssc_export_provider_idx ON ssc_export (provider_object_id);
CREATE INDEX ssc_resource_relation_object_idx ON ssc_resource_relation (from_object_id, from_revision_id);
CREATE INDEX ssc_resource_revision_resource_idx ON ssc_resource_revision (resource_id, revision_no DESC);

-- Security: bearer lookup must not scan the session table.
CREATE UNIQUE INDEX ssc_auth_session_token_hash_uidx ON ssc_auth_session (access_token_hash);
CREATE INDEX ssc_auth_session_principal_status_idx ON ssc_auth_session (principal_id, status, expires_at);
CREATE INDEX ssc_auth_challenge_key_status_idx ON ssc_auth_challenge (key_id, status, expires_at);
CREATE INDEX ssc_auth_event_principal_time_idx ON ssc_auth_event (principal_id, event_time);

COMMIT;
ANALYZE;
