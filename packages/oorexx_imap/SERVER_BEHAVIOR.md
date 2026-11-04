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

## Dev10 inbound IMAP server behavior

Dev10 introduces a partial server core with an honest capability boundary.
Before authentication it advertises `X-OOREXX-SERVER-CORE`, `LOGINDISABLED`,
and any actually implemented safe extension such as NAMESPACE. It does not
advertise IMAP4rev1 yet.

After TLS is established, LOGIN may attribute an identity through the injected
authentication provider. Each mailbox operation is then separately authorized.
SELECT and EXAMINE create a selected snapshot; EXAMINE is read-only. CLOSE on a
read-write selected mailbox asks the provider for expunge semantics rather than
pretending metadata-only state can expunge messages.

The qualification provider exposes two delivery-managed mailboxes:
`INBOX` and `INBOX-UNSIGNED`. Their meaning originates with the SMTP/mail
classification layer; IMAP observes that classification and must not forge it.

APPEND/FETCH/STORE/SEARCH/COPY/MOVE/EXPUNGE/UID/IDLE are explicit dev10 gaps and
return NOTIMPLEMENTED on the server side. Existing client implementations of
those commands are unchanged.
\n\n## Dev11 inbound IMAP server behavior\n\nThe server now accepts a bounded message-data command subset in selected state. APPEND requires a final literal marker and exact byte count; the endpoint emits a continuation for synchronizing literals and reads exactly the announced length before processing the command. FETCH can return literal bytes without materializing a mailbox-wide message list. STORE mutations require read-write selection. UID operations preserve UID identity, COPY returns COPYUID evidence, MOVE performs copy-then-exact-source-removal, and UID EXPUNGE removes only deleted messages whose UIDs are in the supplied set.\n\nThe in-memory provider exists for protocol qualification. It is not a persistence claim. Production providers must map the same contract onto durable storage and preserve commit/recovery semantics.\n

## Dev12 operational observation

`ImapServerEndpoint` can now report session/command/byte lifecycle to an optional
observer. The supplied Instrumentation Mesh adapter records aggregate operational
facts only; it does not inspect message content or mailbox names and it never
changes protocol behavior. Observer absence is the normal zero-integration path.
Observer failure must not be used as an authorization decision or as evidence that
an IMAP operation itself failed.

## Dev13 selected-session / IDLE behaviour

A selected session owns a provider cursor in addition to its snapshot. Provider
mutations publish typed changes; `pollSelectedChanges()` consumes them in order,
emits unsolicited IMAP state and then refreshes the selected snapshot. A session's
origin id is used only for duplicate-echo policy and is not durable message identity.

`IDLE` requires all of: authenticated/selected state, explicit `IMAP_IDLE` mailbox
authority, provider change-feed capability and transport readiness. The command does
not create a new authentication state. `DONE` returns to normal command mode while the
session remains selected. Missing change history fails closed so the server never
pretends a selected view is coherent after an unknown gap.
