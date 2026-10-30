# Initech NotNotes Help Desk — Gopher sphere v0.1

## Purpose

This sphere preserves the two-tier support architecture for Initech's TPS Help
Desk. The outer Help Desk interprets conversational purpose and session context;
NotNotes remains the authoritative business application.

```text
employee chat
  -> Help Desk purpose / clarification / presentation
  -> dynamic discovery on the current turn
  -> NotNotes semantic application + Intention Service
  -> authoritative TPS documents/reports/relationships/workflow
```

Specialist operational evidence is also discovered rather than copied into the
Help Desk. Instrumentation is currently integrated read-only. Current portfolio
continuation is Management Intention Discovery dev9 plus Instrumentation
Intentions dev2; they remain provider-owned specialist contracts for transient
machine/service/MVS/cloud/network/instrumentation evidence.

## Core invariants

1. Intention discovery is dynamic, not a one-time startup catalogue.
2. Existence, applicability/meaning, feasibility and execution authority remain
   distinct facts.
3. The Help Desk must not duplicate NotNotes document/report/workflow semantics.
4. An LLM may help recognition but does not become business, persistence,
   permission or transport authority.
5. Provider-owned specialist surfaces remain intact and are re-discovered against
   current evidence.
6. Every closed Help Desk session writes a real TPS Report and linked TPS Report
   Review recording SUCCESS or FAILURE; later sessions can query that evidence
   as ordinary NotNotes data.
7. Management/cloud/MVS integration must arrive through specialist discovery,
   not by teaching the Help Desk a permanent infrastructure vocabulary.

## Current baseline

The accepted implementation baseline remains
`initech_notnotes_helpdesk_v0.1-dev5.zip`, SHA-256
`0448068f18fee165381441e2afb33dbee170f44957f6d3c704ef2948ed42f9c6`.
It was qualified under ooRexx 5.3.0 r13196 with live NotNotes semantic projection,
management-review relationship traversal, recursive Help Desk TPS evidence,
Instrumentation Mesh dev7 and Instrumentation Intentions dev1.

Repository source lives at `examples/initech_notnotes_helpdesk_v0.1-dev5`.
The previously missing NotNotes/Intention source dependencies are now published
in GitHub. A clean-checkout consumer smoke has also been committed under
`tools/run_github_source_smoke.sh`; it uses disposable TPS schema/data and does
not publish the historic Initech management-review customer fixture.

## Continuation

Preserve dev5 as the accepted runtime baseline until a successor receives fresh
r13196 qualification. Consume current specialist evolution through generic
discovery contracts: Management Intention Discovery dev9 and Instrumentation
Intentions dev2. Do not retarget onto separately owned Mini NotNotes/RexxSQL
work merely because newer package revisions exist.

The next qualified successor should:
- keep the Help Desk domain-blind to infrastructure vocabulary;
- adopt the current generic management-specialist seam read-only first;
- fix any consumer-local defects without modifying separately owned NotNotes core;
- run the committed-source smoke and full Help Desk/NotNotes/specialist suite.
