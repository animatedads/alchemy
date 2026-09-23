# Server behaviour profiles — dev5

IMAP wire operations do not always imply the same application semantics on every server.
`APPEND` is therefore modelled separately from the semantic effect of inserting the
message into the chosen mailbox/room.

## Generic profile

For an ordinary mailbox, the generic profile treats `APPEND` as `PASSIVE_STORE`.
For special-use mailboxes such as `Sent` and `Drafts`, dev5 deliberately leaves the
effect `SERVER_DEFINED` unless a server profile says otherwise.  Migration/restore
code must not silently assume that inserting into a special-use mailbox is passive.

## Citadel profile

The Citadel compatibility profile represents the operational behaviour supplied for
this project:

* Citadel's IMAP interface reflects its room/BBS message model.
* APPEND to an ordinary room can be an intentional `POST` operation.
* APPEND to the Sent room can intentionally act as `SUBMIT`, allowing mail submission
  without a separate SMTP transaction.
* Mail submitted through Citadel SMTP is automatically recorded in Sent; a client
  should therefore not blindly perform the common `SMTP send + IMAP APPEND Sent`
  sequence or it can create a duplicate Sent copy.

These are explicit profile semantics, not generic IMAP invariants.  dev5 does not
attempt to infer a Citadel profile from a greeting string or CAPABILITY tokens.
Applications select a profile deliberately.

## Intent-aware APPEND

`ImapServerBehaviorProfile~planAppend(role,intent)` compares the semantic effect of
APPEND on that profile with the caller's declared intent:

* `STORE`, `RESTORE`, `MIGRATE` expect `PASSIVE_STORE`.
* `POST` expects `POST`.
* `SUBMIT` expects `SUBMIT`.

A mismatch is denied by the intent-aware session helpers before any bytes are written
to the IMAP connection.  The low-level `appendBytes()` / `appendSource()` protocol
operations remain available for applications that intentionally own the raw IMAP
semantics.

Intent-aware helpers emit a redacted `MUTATION_PLAN` diagnostic containing only
profile, mailbox role, intent, expected/actual effect and policy outcome.  Mailbox
names and message content are not included.

## Gmail mutation qualification note

The generic live APPEND round-trip uses a freshly created ordinary mailbox only.
It does not infer that deleting the mailbox would delete the underlying Gmail
message from every Gmail view/label, and therefore retains the test object. Gmail
cleanup semantics are to be qualified separately from generic IMAP APPEND storage.

## COPY/MOVE policy boundary (dev8)

The project has observed and modelled Citadel APPEND semantics, but has not yet
qualified whether every server gives COPY/MOVE into each special-use room the same
semantic effect. Therefore the dev8 high-level move engine accepts only the
`ORDINARY` destination role. Special-use movement is fail-closed until an explicit
server profile is qualified.

This is deliberate: a filesystem-visible rename must not accidentally become a mail
submission operation merely because the destination happens to project a Sent room.
Applications that knowingly own a server's semantics can still use raw `uidMove()` or
`uidCopy()`.
