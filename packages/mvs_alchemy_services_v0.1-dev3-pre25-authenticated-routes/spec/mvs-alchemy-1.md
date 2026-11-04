# mvs.alchemy/1 wire contract — draft 0.1

## Fixed frame header

All multi-byte integer fields are unsigned big-endian wire quantities unless an operation explicitly declares otherwise.

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | Eye catcher `ALCH` |
| 4 | 1 | Protocol major (1) |
| 5 | 1 | Protocol minor (0) |
| 6 | 2 | Header length (48 for level 1.0) |
| 8 | 4 | Total frame length |
| 12 | 8 | Session identifier |
| 20 | 8 | Request identifier |
| 28 | 4 | Remote object handle |
| 32 | 2 | Operation |
| 34 | 2 | Flags |
| 36 | 4 | Status |
| 40 | 4 | Reason |
| 44 | 4 | Payload length |

Validation order: eye catcher; supported major; header length; total/header relationship; payload/total relationship; negotiated maximum; flags; operation/state; session; request.

## Initial operations

`HELLO=1`, `ACCEPT=2`, `PING=3`, `OPEN=16`, `CALL=17`, `CLOSE=18`, `DISCONNECT=19`.

## Typed values

Initial type codes: `NULL=0`, `BYTES=1`, `CHAR=2`, `UINT32=3`, `SINT32=4`, `UINT64=5`, `HANDLE=6`, `ARRAY=7`, `STRUCT=8`.

`BYTES` is opaque and MUST NOT be translated. `CHAR` carries an explicit character-set/CCSID declaration. The negotiated default guest CCSID does not authorize translation of `BYTES`.

## Replay

A request is identified within a session by its 64-bit request identifier. The endpoint binds it to a semantic fingerprint including operation, object handle, and canonical payload. Repeating an identical completed request returns its recorded completion without executing the operation again. Reusing an identifier for different semantics is `REPLAY_CONFLICT`.

A lost connection does not by itself imply operation failure. If completion cannot be established, the outcome is `OUTCOME_UNKNOWN`.

## Handles

Wire handles are opaque 32-bit values scoped to a MAS protocol session. They are not MVS application handles and are not provider-native handles/pointers.


## Reserved personality range added in pre4

- `1400-14FF` MAS/MAIL

### MAS/MAIL initial operation assignments

`MAILINIT=1400`, `MAILBOX=1401`, `MAILLIST=1402`, `MAILOPEN=1403`,
`MAILENV=1404`, `MAILHEAD=1405`, `MAILBODY=1406`, `MAILPART=1407`,
`MAILNEXT=1408`, `MAILSEEN=1409`, `MAILCLOS=140A`, `MAILTERM=140B`.

Outbound construction is separated at `1420`: `MAILNEW=1420`,
`MAILFROM=1421`, `MAILTO=1422`, `MAILTEXT=1423`, `MAILSIGN=1424`,
`MAILSEND=1425`, `MAILSTAT=1426`.

These are MAS operation numbers, not provider-native method numbers. `BYTES`
remains opaque for bodies, MIME and attachments.

## dev3-pre6 executable database personality

Reserved range `1100-11FF` now has an executable host reference with initial assignments:
`DBOPEN=1100`, `DBGET=1101`, `DBPUT=1102`, `DBDELETE=1103`, `DBSCAN=1104`, `DBCLOSE=1105`.
Keys and values are opaque `BYTES`.  `DBSCAN` is bounded to at most 256 records per request.

### dev3-pre6 executable queue personality

Reserved range `1000-10FF` has initial assignments:
`QOPEN=1000`, `QPUT=1001`, `QGET=1002`, `QDEPTH=1003`, `QCLOSE=1004`.
Queue payloads are opaque `BYTES`; handles are session-scoped and provider-native identities do not cross the MAS ABI.

## pre9 PATH operation range

The live guest cut assigns `1500-15FF` to the previously specified PATH
personality.  Initial operations are `PATHOPEN=1500`, `PATHREAD=1501`,
`PATHWRITE=1502`, `PATHAPPEND=1503`, `PATHCLOSE=1504`, `PATHSTAT=1505`, and
`PATHLIST=1506`.
