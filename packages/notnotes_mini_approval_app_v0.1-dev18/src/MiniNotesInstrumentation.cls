/* MiniNotesInstrumentation.cls
 * Optional instrumentation.mesh/0.1 adapter for Mini NotNotes.
 * NotNotes remains authoritative for application/workflow facts; NoSQLServer
 * separately owns database/query/materialisation telemetry.
 */

::class MiniNotesInstrumentationSource public

::method init
  expose app emitter
  use strict arg appArg, identity
  app = appArg
  emitter = .InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  app~instrumentation(self)
  self~refresh

::method notNotesEvent
  expose emitter
  use strict arg eventName, facts = .nil
  name = eventName~string~upper
  select
    when name = "PERSIST_BEGIN" then emitter~counterAdd("notnotes.persistence.started_total")
    when name = "PERSIST_COMPLETED" then emitter~counterAdd("notnotes.persistence.completed_total")
    when name = "PERSIST_FAILED" then emitter~counterAdd("notnotes.persistence.failed_total")
    when name = "BATCH_BEGIN" then emitter~counterAdd("notnotes.batch.started_total")
    when name = "BATCH_END" then emitter~counterAdd("notnotes.batch.ended_total")
    when name = "QUERY_COMPLETED" then do
      emitter~counterAdd("notnotes.query.completed_total")
      if facts \== .nil then emitter~gaugeSet("notnotes.query.last_result_count", facts["RESULT_COUNT"], "documents")
    end
    when name = "SUBMIT_COMPLETED" then emitter~counterAdd("notnotes.workflow.submitted_total")
    when name = "SUBMIT_REJECTED" then emitter~counterAdd("notnotes.workflow.submit_rejected_total")
    when name = "DECISION_COMPLETED" then do
      emitter~counterAdd("notnotes.workflow.decisions_total")
      if facts \== .nil then do
        if facts["OUTCOME"] = "APPROVED" then emitter~counterAdd("notnotes.workflow.approved_total")
        if facts["OUTCOME"] = "REJECTED" then emitter~counterAdd("notnotes.workflow.rejected_total")
      end
    end
    when name = "DECISION_REJECTED" then emitter~counterAdd("notnotes.workflow.decision_rejected_total")
    when name = "FORMAT_INSTALLED" then emitter~counterAdd("notnotes.schema.formats_installed_total")
    when name = "FORMAT_EVOLVED" then emitter~counterAdd("notnotes.schema.formats_evolved_total")
    otherwise emitter~counterAdd("notnotes.instrumentation.unknown_events_total")
  end
  self~refresh
  return self

::method refresh
  expose app emitter
  documents = app~allDocuments
  draft = 0
  pending = 0
  approved = 0
  rejected = 0
  do document over documents
    status = document~ApprovalStatus~string~upper
    select
      when status = "DRAFT" then draft = draft + 1
      when status = "PENDING APPROVAL" then pending = pending + 1
      when status = "APPROVED" then approved = approved + 1
      when status = "REJECTED" then rejected = rejected + 1
      otherwise nop
    end
  end
  emitter~gaugeSet("notnotes.documents.total", documents~items, "documents")
  emitter~gaugeSet("notnotes.documents.draft", draft, "documents")
  emitter~gaugeSet("notnotes.documents.pending_approval", pending, "documents")
  emitter~gaugeSet("notnotes.documents.approved", approved, "documents")
  emitter~gaugeSet("notnotes.documents.rejected", rejected, "documents")
  emitter~gaugeSet("notnotes.formats.total", app~userFormatNames~items, "formats")
  emitter~gaugeSet("notnotes.reports.total", app~reportDefinitionNames~items, "reports")
  emitter~gaugeSet("notnotes.subviews.total", app~subviewDefinitionNames~items, "subviews")
  emitter~gaugeSet("notnotes.batch.depth", app~batchDepth, "levels")
  return self

::method snapshot
  expose emitter
  use strict arg observedAt = ""
  self~refresh
  return emitter~snapshot(observedAt)

::method emitter
  expose emitter
  return emitter

::requires "InstrumentationMesh.cls"
