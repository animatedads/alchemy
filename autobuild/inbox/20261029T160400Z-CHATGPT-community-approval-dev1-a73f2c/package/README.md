# ooRexx community correspondence — Draft approval gate v0.1-dev1

Pure ooRexx policy object. ChatGPT/Claude may draft, revise and argue. Only an active, authenticated human with MAIL_APPROVE can approve a specific draft SHA-256 and monotonically increasing revision. Every send checks human approval and independent MAIL_SEND permission again. Ambiguous SMTP acceptance goes to IN_DOUBT, not blind retry.

The class does not compute SHA-256, connect to IMAP/SMTP/LDAP, authenticate principals, journal state or submit mail. The trusted adapter must hash the EXACT RFC5322 bytes including recipients/headers/signatures/attachments, bind to (account, mailbox, UIDVALIDITY, UID), persist transitions BEFORE transport, enforce atomic compare-and-swap, and provide immutable evidence to the SMTP verifier. This code is not a substitute for a real approval authorization boundary.

Public methods: init(account, revision, digest), revise, approve, reserveSend, markUncertain, recordAccepted, recordRejected. Authority: isActive, isHuman, isAllowed(principal, right, account). Verifier: accepted(op,evidence), definitelyNotAccepted(op).

Run with ooRexx 5.3: bash tests/run.sh (17 deterministic policy assertions). Existing integration targets are packages/oorexx_imap, oorexx_smtp_secure_stack, oorexx_ldap_identity, and oorexx_mcp_service_v0.2-dev8. MAIL_APPROVE is proposed as an explicit capability, not inferred from MAIL_SEND, LDAP Bind or a signing key. The mail owner must verify real permission naming and integrate that right in Access Permissions.

Limitations: no ooRexx runtime available in the authoring container, so tests NOT EXECUTED. Production NOT DEPLOYED; autobuilder stopped. A real deployment needs a durable crash-safe store, IMAP Drafts PASSIVE_STORE confirmation, SMTP post-DATA reconciliation, independently verified auth and positive/negative protocol tests.

Architecture Tom Dyer; implementation and review ChatGPT GPT-6.
