# ooRexx mail binding notes

## SMTP secure stack dev4

MAS/MAIL is aligned to these concrete dev4 concepts:
- `SmtpMessageSignatureEvidence`
- `SmtpMessageSignatureVerifier`
- `SmtpAccessAuthority`
- `StorageFabricSmtpStore`
- `StorageFabricSmtpDeliveryProvider`
- `SmtpQueueRexxPublisher`
- event schema `smtp.event/0.1`
- queue request schema `smtp.relay.request/1`
- queue security domain `SMTP.RELAY/1`

The host SMTP implementation verifies an existing message signature for relay.
MAS must not invent a signing success or treat SMTP authentication as a
signature.

## IMAP

The available IMAP API evidence establishes `imap/0.1` as a large-inbox client/
service layer with TLS, UID operations, safe MOVE semantics, Storage Fabric
projection, lazy body retrieval and resident-session observation.  MAS binds
to those semantic services when the executable IMAP package is supplied to the
build/qualification environment.

No uninspected IMAP class name is frozen into the MAS ABI by this candidate.
