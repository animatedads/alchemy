# Architecture

```text
Codex / human
    |
line commands
    v
MiniNotesTextUi             presentation/controller only
    |
    +--> CliUiTableModel
    +--> CliUiDocument
    +--> CliUiSemanticTrace
    |
    v
MiniNotesApp                application semantics
    |
    +--> dependency gate
    +--> query/subset selection
    +--> value/risk workflow rules
    |
    v
Alchemy NotNotes dev15      authoritative documents
    |
    +--> first-class approvals
    +--> referrals / decisions
    +--> revisions
    +--> application definitions/views
```

Stable document keys are application identifiers (`PR-1002`, `SEC-2001`, etc.).
NotNotes retains its own durable document identities underneath them.

## dev2 query semantics

The query path composes structured predicates with residual free-text terms. Recognised terms such as document type, approval state, risk and numeric thresholds remain structured predicates. Remaining meaningful words are required free-text terms over document key, type, title, risk and dependency text. Unknown terms therefore cannot silently disappear and broaden a query to every document.

`VIEW` begins from a registered NotNotes view and then applies the same subset semantics. Release Authorization and Approval Document now have registered views alongside Purchase Request and Security Review.
