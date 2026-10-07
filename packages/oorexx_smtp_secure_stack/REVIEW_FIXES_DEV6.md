# SMTP protocol review validation — dev6

The 2026-09-27 review comments were treated as hypotheses until reproduced against the sealed dev5 source on Open Object Rexx 5.3.0 r13196.

## SMTP-001 — durable state writes

**Review claim:** outbound state transitions could report success even when their journal write failed.

**Reproduction on dev5:** `StorageFabricSmtpStore~transitionSpool()` against an unwritable `/proc/...` path returned `ok=1 / SPOOL_STATE_RECORDED` even though `lineout()` returned failure. The dispatcher also ignored transition and bounce-write results.

**dev6 repair:** journal append/close results are checked. Membership, enqueue, spool-state, recipient-state and bounce writes fail explicitly. `SmtpOutboundDispatcher` checks those results. If remote DATA was already accepted but the DELIVERED recipient journal cannot be committed, dispatch returns `DELIVERY_STATE_UNCERTAIN` rather than a retryable transport result.

## SMTP-002 — final 250 followed by QUIT disconnect

**Review claim:** a failure after the server's final DATA `250` could overwrite a successful delivery result and cause duplicate delivery on retry.

**Reproduction on dev5:** a fixture accepted DATA with `250 queued` and then closed without replying to QUIT. dev5 returned `NEXT_HOP_TRANSPORT_EXCEPTION` even though the recipient had already been accepted.

**dev6 repair:** the final DATA reply is authoritative for the SMTP transaction. QUIT is best-effort cleanup only; the client sends it but does not make delivery success depend on a QUIT response. The same fixture now returns `REMOTE_ATTEMPT` with recipient state `DELIVERED / 250`.

## SMTP-003 — reply framing/resource bounds and EOF guards

**Review claim:** reply lines and multiline replies were insufficiently bounded, and EOF guards used non-short-circuit expressions.

**Reproduction on dev5:** a completed 68-byte reply was accepted despite `readLine(16)`; a 22-line multiline reply had no aggregate bound; EOF in `readReply()` raised a syntax condition because `.nil~length` was evaluated.

**dev6 repair:** SMTP reply lines are bounded to 510 bytes excluding CRLF, reply code/separator syntax is validated, multiline replies are bounded to 100 lines / 51,000 bytes, and nil checks are explicitly ordered before object sends. Overlong replies fail closed.

## Qualification

Permanent regression tests:

- `tests/review_repro_io.rex`
- `tests/review_repro_journal.rex`
- `tests/review_repro_quit.rex`
- `tests/review_quit_fixture.py`
- `tests/review_protocol_regressions.sh`

The full dev5 qualification suite plus these regressions passes on the user-supplied ooRexx 5.3.0 r13196 runtime, including S/MIME/CMS, Access Permissions, durable delivery, SMTP wire tests and live outbound STARTTLS with Foreign Runtime v0.22.6.
