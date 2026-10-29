# CLI UI — semantic terminal presentation sphere

Sphere ID: `oorexx.cli.ui/0.1`  
Owner: CLI UI implementation lane  
Status: design/evidence sphere; not registered in LLM Gopher; dev11 source not yet synchronized  
Updated: 2026-10-23

## Purpose and authority boundary

The CLI UI package supplies a renderer-neutral semantic terminal presentation layer for ooRexx applications, including NewShell and Mini NotNotes. Application and domain truth remain in ooRexx. Neither the native ANSI backend nor the Headless projection may decide business operations, authorizations, mailbox identities, or document revisions.

```
ooRexx application / service truth
            |
semantic document, table, form, detail, prompt, actions
            |
bounded composite screen projection
            |
       cell/frame boundary
        /          \
   Headless        ANSI
```

Wire is an independent presentation path over the same semantic application contract; a terminal-native renderer must not become the application architecture. No ooDialog-like or GTK-like widget hierarchy.

## Semantic object responsibilities

- **Document/editor**: text, caret/anchor, language, completion and syntax spans. Completion is descriptive, not execution authority.
- **Table**: bounded visible window, stable row identities, column descriptions, selected identity, viewport; row position is not identity.
- **Detail**: title, field/value projection, sections and semantic actions.
- **Form**: ordered semantic field definitions, labels, editable/read-only state, selection options with distinct stable option identities; focus is semantic, not toolkit-specific.
- **Prompt**: input buffer, caret, history, candidates, submit/cancel.
- **Action map**: canonical keys/chords mapped to application-owned commands.
- **Screen**: deterministic layout at a given width/height; preserve prompt/status; truncate or scroll content rather than overwrite reserved rows.
- **Renderer**: draw text/styles/cursor and normalize input/resize; no domain mutation.

## Terminal invariants

1. No alternate-screen takeover, mouse capture or bracketed-paste capture by default; terminal copy/paste remains available.
2. No writes outside the declared terminal bounds.
3. Detail/form/table rendering cannot overwrite prompt or status rows.
4. Selected document and choice identity persist across resize, filtering and projection changes.
5. ANSI and Headless consume equivalent semantic frames; only terminal byte sequences and presentation geometry may differ.
6. No implicit transport coupling. NewShell CLI remains a Queue Fabric client; standalone CLI UI is independently usable.
7. Explicit, version-qualified ooRexx package resolution; no dependency on caller's working directory.

## Acceptance and evidence

Latest *reported* source candidate: `oorexx_cli_ui_v0.1-dev11.zip`. Earlier qualification under ooRexx r13196 applied to dev7/dev8; **it does not qualify dev11**. dev10/dev11 source-candidate status is retained.

Mandatory gates before promoting dev11 or later:
- Check complete archive manifest, version labels, and source closure.
- Build native ABI bridge and execute all Rexx tests with actual ooRexx runtime.
- Run strict coding standards checker; report actual mode and error/warning counts.
- Capture ANSI output at 80x24 and 48x16; reconstruct cell surfaces and compare against Headless frame.
- Exercise resize, stable selection, form choice identity, prompt input, clipped long detail, cursor and footer.
- Run from unrelated working directory with explicit package paths.
- Keep ncurses fail-closed unless compiled and tested with available headers.
- Record hashes and source provenance before claiming GitHub synchronization.

## Consumer integration

Mini NotNotes drives DOCUMENTS/SELECT/READ/APPROVE/REJECT/QUERY/VIEW and interactive document-definition/completion wizards. Its authoritative document keys, workflow decisions and persistence belong to NotNotes; CLI UI supplies presentation only. Mail clients similarly delegate IMAP UID/UIDVALIDITY identity, SMTP signing/relay governance, and LDAP identity to their owning services.

## Known gaps and decisions

- Full dev11 source import to GitHub is outstanding.
- Actual ANSI-vs-Headless terminal cell comparison is outstanding.
- Real ooRexx dev11 runtime qualification is outstanding.
- ncurses backend is not claimed operational.
- Gopher sphere registration is not claimed; this file is the source-controlled sphere specification.

## GitHub provenance

Branch: `cli-ui-dev11-sync-20261023`. This sphere documents work and gates; a sphere-only commit does not make the code synchronized.
## dev12 completion ownership integration (2026-10-28)

Mailbox REQ-00000593 identifies Source Editor `SourceCompletionCandidate` and `SourceCompletionProvider` as the authoritative ooRexx source-completion API. CLI UI must not implement competing source completion logic. The `CliUiCompletionPresentation` adapter holds exact supplied candidate objects, preserving identity and order; it only tracks presentation selection and resets selection on candidate replacement. NewShell retains command/completion transport authority. The new identity regression fixture is committed under `packages/oorexx-cli-ui/tests/test_completion_presentation.rex`. Candidate accessor binding to the accepted Source Editor revision is pending. dev12 is source-only; no r13196 qualification claimed.

## 2026-10-29 development increment

GitHub commits `456a5bf3` and `1f69bd72` add identity-preserving completion refresh and regression cases for reordered, removed and invalid candidate selections. Source Editor remains the sole authority for completion candidates; CLI UI retains only presentation selection. The test is committed but **has not been executed under ooRexx r13196**. GitHub remains a source-only development branch; autobuilder is not running. CLI UI is not an owner of the website, SMTP, IMAP, LDAP, HTTPS or MU/MI transport, and makes no deployment claims for them.
