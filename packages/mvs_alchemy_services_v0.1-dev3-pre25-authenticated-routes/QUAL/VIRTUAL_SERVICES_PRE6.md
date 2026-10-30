# dev3-pre6 virtual services qualification

Scope: host-side executable reference only; no claim of live ED209Z/DYN75 crossing.

Expected command:

    python3 host/reference/virtual_services_selftest.py

Required assertions:

- Queue FIFO preserves all byte values.
- Database put/get/delete/scan preserves opaque byte keys and values.
- IMAP projection preserves UIDVALIDITY+UID identity and mailbox separation.
- SMTP submission refuses unsigned, invalid, identity-mismatched, unauthorized and egress-denied drafts.
- Fully authorized/signed draft reaches `RELAY_ELIGIBLE`.
- Service inventory reports QUEUE, DATABASE, IMAP and SMTP independently.

Production adapters to Queue Fabric, NoSQLServer, ooRexx IMAP dev10 and SMTP Secure Stack dev6 are separate live-integration qualification items.
