/*
 * Secondary indexes the Semantic Source Store needs on SQLite, and a session opener that
 * applies them. Every primary key is already indexed by SQLite.
 *
 * Derived from EXPLAIN QUERY PLAN over the store's own dogfood import/accept/rebuild of the GA
 * Intentions package (RexxSqlPlanAuditSession; see ../../evidence/ssc_scan_audit_*.log) plus the
 * store's ORDER BY revision_no and origin_import_id lookups.
 * Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
 */
::class SemanticSourceSqliteIndexPlan public
::method plan class
  p = .directory~new
  p["ssc_resource_relation"] = .array~of("from_object_id", "resource_id")
  p["ssc_relation"]          = .array~of("from_object_id", "to_object_id, relation_kind")
  p["ssc_source_unit"]       = .array~of("module_id", "projection_path")
  p["ssc_resource_revision"] = .array~of("resource_id, revision_no")
  p["ssc_projection_member"] = .array~of("project_id", "revision_id")
  p["ssc_source_revision"]   = .array~of("object_id, revision_no", "origin_import_id")
  return p
::method options class
  o = .directory~new
  o["index_plan"] = self~plan
  return o
/* The executor the store expects (status/message/rows), on SQLite with the plan applied. */
::method open class
  use strict arg path
  return .RexxSqlSqliteSession~open(path, self~options)
::method openAudited class
  use strict arg path
  return .RexxSqlPlanAuditSession~open(path, self~options)

::requires "RexxSqlBackend.cls"
::requires "RexxSqlPlanAudit.cls"
