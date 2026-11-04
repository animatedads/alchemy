# Wire Direct dev22 — module-by-module stack

This is the stack used by the current qualified MailReader composition. It is an authority/dependency map, not a claim that every module is called for every event.

```text
                                  APPLICATION / BUILDER

  WireBuilderSession
        │ edits symbolic bindings
        ▼
  WireBuilderBindingSpec ──► WireBindingCompiler ──► WireBinding
                                                     │
  WireBehaviourRegistry ◄──── resolves target ──────┘
                                                     │
                                                     ▼
  WireApplicationModel ───────────────────► WireApplicationController
                                                     │ dispatch
                                                     ▼
                                            WireApplicationEvent
                                                     │
                                   ┌─────────────────┼─────────────────┐
                                   │                 │                 │
                                   ▼                 ▼                 ▼
                              ooRexx behaviour  WireLanguageBlock  MailReader behaviour
                                   │                 │                 │
                                   │                 │                 ├─► WireSelectionProjection
                                   │                 │                 ├─► WireEventSubjectProjection
                                   │                 │                 └─► WireVisibleAssessmentProjection
                                   │                 │
                                   │                 ▼
                                   │        WireLanguageBlockBridge
                                   │                 │
                     ┌─────────────┴───────────┬─────┴─────────────────────┐
                     │                         │                           │
                     │                   JAVASCRIPT PATH              PROLOG PATH
                     │                         │                           │
                     │              JavaScript Alchemy dev23       Prolog Alchemy dev13
                     │                         │                           │
                     │                  Alchemy Objects               rexxObject / rexx_send/4
                     │                         │                           │
                     │                  Foreign Runtime                    │
                     │                         │                           │
                     │                 Crypto / OpenSSL                    │
                     │                         │                           │
                     │                 QuickJS-NG 0.17.0             SWI-Prolog 10.0.2
                     │                         │                           │
                     │                 bounded predicate            relational rules
                     │                         │                     + backtracking
                     │                         │                           │
                     └────────────── ooRexx value/result ◄────────────────┘

                                  DATA / WINDOW PATH

  ooRexx IMAP dev8
        │ EXAMINE / UID SEARCH / UID FETCH PEEK
        ▼
  WireImapMailboxCollection
        │ stable identity = mailbox | UIDVALIDITY | UID
        ▼
  backing identity collection
        │
        ▼
  WireFilterWindow  ◄──── owns pull/continuation authority
        │
        ├─► bounded source window ─► JS predicate ─► accept/reject
        │
        └─► filter-owned output window
                         │
                         ▼
                    WireListRow
                         │
                         ▼
                  Renderer ABI 4
                    ┌────┴────┐
                    ▼         ▼
              TestRenderer   GTK4 renderer

                             RELATED-MAIL QUERY PATH

  selected Wire/ooRexx Mail identity
        │ explicit capability
        ▼
  Prolog Alchemy retained Rexx object
        │
        ▼
  SWI rule, e.g. needs_attention/1 / related_mail/2
        │ rexx_send/4
        ▼
  live ooRexx relationship source / Supplier
        │ PROLOGNEXT under SWI backtracking
        ▼
  productive result window
        │ stable identities
        ▼
  Wire / Renderer
```

## Module ownership by layer

| Layer | Modules actually in the current stack | Owns | Must not own |
|---|---|---|---|
| Builder | `WireBuilderSession`, `WireBuilderBindingSpec`, `WireBindingCompiler`, `WireBehaviourRegistry` | symbolic editing and behaviour resolution | GTK, IMAP protocol, JS/SWI engine handles |
| Application | `WireApplicationModel`, `WireBinding`, `WireApplicationController`, `WireApplicationEvent` | elements, triggers, dispatch, stable application identity | renderer mechanics, foreign runtime policy |
| Behaviour/projection | `WireMailReaderBehaviour`, `WireSelectionProjection`, `WireEventSubjectProjection`, `WireVisibleAssessmentProjection` | semantic application behaviour and projections | source traversal, toolkit mechanics |
| Source | `WireImapSource`, vendored ooRexx IMAP dev8 | mailbox/UID identity, bounded fetch | GTK, Builder, language runtime |
| Windowing | `wire_filter_window.c` / `WireFilterWindow` | pull budget, continuation, output-window fill | predicate semantics, IMAP protocol, rendering |
| Language boundary | `WireLanguageBlock`, `WireLanguageBlockBridge` | ooRexx→langX variable set and langX→ooRexx return seam | language engine internals |
| JavaScript | JavaScript Alchemy dev23 | live/capability projection into JS | backing-store pull authority, GTK |
| JS runtime | QuickJS-NG 0.17.0 | ECMAScript execution/microtasks/runtime limits | Wire application model |
| Prolog | Prolog Alchemy dev13 | retained Rexx identity, `rexx_send/4`, productive continuation | renderer/Builder authority |
| Prolog runtime | SWI-Prolog 10.0.2 | unification, rules, backtracking | Wire application model |
| Shared Alchemy dependencies | Alchemy Objects, Foreign Runtime, Crypto/OpenSSL (plus runtime-distribution RxMath where required by Alchemy Objects) | object membrane, native/runtime boundary, crypto support | application policy |
| Renderer | Renderer ABI 4, TestRenderer, GTK4 renderer | presentation and native event translation | IMAP, business behaviour, language reasoning |

## Three-language pin

The application is deliberately pinned around **one ooRexx-owned model**:

```text
                     ooRexx application/model
                       /        |         \
                      /         |          \
          ooRexx behaviour   JavaScript    Prolog
               native role   filter role   relation role
                              bounded       explicit query
```

`QuickJS-NG` and `SWI-Prolog` are deployment/runtime providers. They are not identities in the `.wire` application model. The invariant remains:

```text
Wire -> ooRexx -> language block -> ooRexx -> Wire
```

The JavaScript filter is additionally constrained by `WireFilterWindow`: the predicate receives candidates but no source/pull handle. Prolog receives broader relationship authority only for an explicit relational operation such as **Find Related Mail**; this does not weaken the ordinary filter-window boundary.
