# IMAP adapter — dev2

`WireImapMailboxCollection` is the first real `wire.source/1` adapter and targets the supplied ooRexx IMAP v0.1-dev8 API.

It opens a mailbox read-only with `EXAMINE`, captures `UIDVALIDITY`, and obtains the UID population through `UID SEARCH`/ESEARCH as a compact `ImapUidSet`. It never calls `toArray()`.

Wire message identity is `(mailbox, UIDVALIDITY, UID)`. `range(start,count)` maps only the requested ordinal window through dev8 `uidAtOrdinal()`. Header and body reads use `BODY.PEEK`; body access is partial and bounded.

No delete/move/archive operation is exposed in this first adapter. Those are authority-bearing mutations and are unnecessary for the read-only MailReader milestone.
