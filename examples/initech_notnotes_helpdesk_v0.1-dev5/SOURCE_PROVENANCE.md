# Source provenance — Initech NotNotes TPS Help Desk v0.1-dev5

This repository source was recovered from the accepted delivery archive
`initech_notnotes_helpdesk_v0.1-dev5.zip` with SHA-256:

`0448068f18fee165381441e2afb33dbee170f44957f6d3c704ef2948ed42f9c6`

The accepted delivery was independently exercised under Open Object Rexx 5.3.0
r13196. The vendored dependency closure and durable NotNotes fixture remain in
the delivery archive; they are not duplicated into this source-import directory.

Important authority boundaries preserved by this source:

- the Help Desk owns conversational routing/session accounting only;
- Mini NotNotes owns TPS documents, saved reports, relationships, workflow and
  semantic application/document projections;
- Intention Service owns interpretation-state semantics;
- Instrumentation Mesh / Instrumentation Intentions own read-only operational
  evidence;
- API Client owns external LLM HTTP/TLS transport;
- the LLM is recognition fallback only and never owns business execution.

The package writes a real TPS Report plus linked TPS Report Review when a Help
Desk session closes. Those records become ordinary live NotNotes business data
for later sessions.
