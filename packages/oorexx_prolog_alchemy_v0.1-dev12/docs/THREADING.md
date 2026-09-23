# Threading and engine mobility contract

`PL_engine_t` is the unit of Prolog logical-state ownership.  An OS thread is
only a temporary execution carrier.  A query, its `qid_t`, frames and `term_t`
handles permanently belong to the engine on which the query was opened.

## Required invariants

1. **Engine, not thread, affinity.** Every native operation resolves the query
   or term to its owning `EngineRec` before entering SWI-Prolog.
2. **Same-engine mobility.** The owning engine may be detached from thread A
   and later attached to thread B.  The existing query and term handles are
   then continued; they are never reconstructed on B.
3. **No cross-engine migration.** A query cannot be rebound to another engine.
   Moving execution means moving/attaching the *same* `PL_engine_t`.
4. **No concurrent engine entry.** `EngineRec::mu` serializes execution in an
   engine.  The recursive form is intentional: same-thread
   Rexx -> Prolog -> Rexx -> Prolog re-entry must not self-deadlock.
5. **Scoped attachment.** `EngineScope` calls `PL_set_engine()` on entry and
   restores the thread's previous engine on exit, including exceptional exits.
   Thus an idle bridge engine is not left attached to an OS thread by the
   bridge after an operation completes.
6. **Query lifetime pins the engine.** `QueryRec::owner` is a strong shared
   reference.  Engine close rejects live queries; query release invalidates
   all projected terms before the query record disappears.
7. **Callback authority is invocation-scoped.** `ActiveQueryScope` exposes the
   current Rexx call context/query only while SWI is executing that invocation
   and restores the previous scope during nested re-entry.

## Native mobility acceptance

The decisive runtime test is intentionally stronger than two independent
threaded queries:

1. Thread A enters engine E, opens nondeterministic Q=`between(1,3,X)` and
   obtains X=1.
2. A leaves the bridge operation; scoped engine attachment is restored.
3. Thread B enters the *same* engine E and advances the *same* Q to X=2 and
   then X=3.
4. B closes Q.  The original X projection is invalid after close.

Negative cases must prove that E is never concurrently executed, that Q is
never transplanted to another engine, and that close cannot destroy E while Q
is live.

The dev10 source makes these invariants explicit and adds native ownership
introspection (`queryEngineId` and `engineIsClosed`) for qualification.  The
packaged dependency-free tests validate the contract structurally; they do not
claim the cross-thread runtime experiment has executed until SWI-Prolog and
its development library are present in the qualification environment.
