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
