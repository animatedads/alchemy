# XTP interactive contexts (sessions)

**Architecture:** Tom Dyer. **Coding:** Claude (Opus 5.5), dev31. **Written by:** Claude (Opus 5.5), 27 October 2026.

## Why

Until dev30, every libxtp context carried one message in one direction: a single FIRST, or a FIRST+DATA stream that is delivered only when it is complete. That rules out anything interactive.

- SSH over XTP (candidate4) works around this by opening a new transaction for every frame.
- The gateway specification (`docs/XTP_GATEWAY_SPEC.md`, gate G1) lists a "persistent interactive FIRST-to-KEY context" as one of two XTP release gates, alongside authentication.

dev31 provides that context. It is the full-duplex XTP context that the 3.4 protocol already describes, built from fields libxtp already carries.

## What a session gives

| Property | How |
| --- | --- |
| Both directions on one KEY | The initiator's packets carry KEY; the responder's carry KEY with the return bit. Each direction has its own sequence space, counting user bytes. |
| Delivery as data arrives | In-order bytes go to `read()` at once; nothing waits for the end of a message. |
| Message boundaries | `write(data, eom=true)` sets EOM on the segment that ends there. `read()` never returns bytes from two messages in one chunk, and flags the last chunk of each message. |
| Per-direction close | `shutdown_write()` sends WCLOSE after everything queued. The peer's `read()` then returns `end`, and it can still write. The context finishes when both WCLOSEs are acknowledged. |
| Flow control from the reader | ALLOC = the bytes the application has read + `receive_window`. A peer that does not read stops the writer once the window and `send_buffer_bytes` are full (test S5). |
| Loss repair | Selective, as dev28 does for streams: SPANs report what arrived out of order. The dev29 SYNC/ECHO exact repair resends anything sent before an echoed SYNC that is still missing. A timer (2 × SRTT, 10 ms floor, doubling, capped at `rto_max_ms`) covers the rest. |
| Liveness | After `keepalive_ms` of silence a status request is sent. After `dead_after_ms` of silence, or of no acknowledgement progress, the context fails with a reason. |
| Refusal | DIAG code 1. VALUE 1 SERVICE_NOT_ADMITTED; VALUE 4 MODE_UNSUPPORTED, for a FIRST without the interactive flag; VALUE 19 QUOTA_EXCEEDED, when the context table or the accept backlog is full. DIAGs are rate-limited and size-bounded exactly as in dev30. |
| Abort | CNTL with END alone. The peer's `read()` fails with "XTP context aborted by peer". |

## Wire

Everything below uses the libxtp 3.4 profile's existing formats. Only one previously reserved byte, descriptor byte 4, is now used.

1. **Open.** The initiator sends a FIRST with seq 0 and SREQ. It carries the named-service descriptor (format 0xA11C) with byte 4 = `0x01` (INTERACTIVE). A CNTL with SREQ and a SYNC follows, carrying the initiator's ALLOC.
2. **Accept.** The responder sends a FIRST with the return bit, seq 0, and the same descriptor and flag. A CNTL with SREQ and a SYNC follows. A dev30 or earlier listener never sends a return-bit FIRST, so the opener fails at `open_timeout_ms` with "not accepted by peer". It is never mistaken for an accepted session (test S7). Until it is accepted, FIRST is resent after 250 ms, then at intervals of 500 ms, 1 s and 2 s (test S12).
3. **Data.** DATA, seq = byte offset in that direction. The trailer carries EOM at a message end and WCLOSE on the direction's last segment; that segment may be empty. Default segment: 1408 bytes on raw36 and UDP (one unfragmented packet on a 1500-byte path), and MTU − 40 on L2.
4. **Status.** A CNTL from either end reports that end's receive side:
   - RSEQ = next byte expected;
   - ALLOC;
   - DSEQ = bytes its application has read (the trailer field that dev30 and earlier fill with RSEQ);
   - SPANs = byte ranges received beyond RSEQ;
   - ECHO = the last SYNC it received.

   SREQ + SYNC asks the other end for its status. RCLOSE means the peer's WCLOSE and everything before it have arrived. WCLOSE means our own WCLOSE has been sent. After each burst the sender sends a CNTL with SREQ.
5. **Finish.** When our WCLOSE is acknowledged and the peer's has arrived, the end sends a CNTL with RCLOSE|WCLOSE|END and finishes. For `close_linger_ms` (default 5 s, more than `rto_max_ms`) it answers retransmissions with that CNTL, so a lost END cannot strand the peer. Until the peer's own END arrives, it also resends its END with SREQ on the retransmission timer; the peer answers a retry, though never an END without SREQ, so two finished ends cannot bounce ENDs back and forth. `close()` returns when the peer's END arrives, and gives up waiting after `close_linger_ms`. Destroying a finished Session waits in the same way. An aborted context sends its END again, at most every 200 ms, to a peer that is still sending (test S20).
6. **Context binding.** This defends against packets from elsewhere and stale ones. It is not authentication.
   - A packet is taken only from the peer address the context belongs to: the UDP address and port, the raw36 address, or the L2 MAC.
   - It must also have the right return-bit orientation (tests S10, S19).
   - Once the peer has echoed one of our SYNCs, a CNTL whose ECHO is not a SYNC of this context is ignored, and so is an END (graceful or abort). SYNC bases and automatic KEYs come from the system random source, so they cannot be predicted from an earlier context.
   - A DIAG is honoured only while the context is opening (test S19).
   - What this does not stop: an on-path attacker who can see the traffic and send from the peer's address. Only authentication stops that.
7. **Bounds against a hostile peer** (tests S16 to S18):
   - An RSEQ inside a segment we still hold is taken as that segment's start.
   - Out-of-order data is held only up to the receive window and 1,024 segments, and overlapping segments are refused.
   - Message-boundary marks and acknowledged bytes are released as data is sent and acknowledged.
   - Diagnostic lines are limited to one per second per endpoint, with a count of the rest.

## API

C++ (`include/xtp/xtp_session.hpp`):

```cpp
xtp::SessionListener L(route, listen_options);      // owns the carrier socket
auto s = L.accept(timeout_ms);                      // nullptr on timeout
xtp::SessionOptions o; o.service_name = "svc";
auto c = xtp::open_session(route, o);
c->write(bytes, /*eom*/ true);
auto chunk = s->read(65536, timeout_ms);            // chunk.data, chunk.eom, chunk.end
c->shutdown_write();
bool clean = c->close(5000);
```

ooRexx (`rexx/XtpSession.cls`; routes from `XTP_ROUTE_FILE`, as for XtpSocketProvider):

```rexx
listener = .XtpSessionListener~new('PEER', 'svc.a,svc.b')
session  = listener~accept(5000)                    -- .nil on timeout
client   = .XtpSession~open('PEER', 'svc.a', 3000)
client~writeMessage(data)
reply    = session~readMessage(5000)                -- .nil at END
client~shutdown
rest     = client~readAll(5000)
closed   = client~close(5000)
```

`read`, `write` and `accept` are unguarded, so one thread may read a session while another writes it (the ooRexx test does this with 200 messages). A gateway pumping both directions needs exactly that. A session or listener object that is dropped without `close` is released by `uninit`; for a session, that means an abort.

## Limits

- **Authentication and encryption are optional, per service (dev32).** See `docs/SECURITY.md`. A session to a service that has no keys is bound to the peer's address only, as in dev31.
- **No wire filters.** Session bytes are not wrapped in an XWF1 envelope.
- **Unicast only.**
- **At most 2^32 − 1 bytes per direction.** `write()` refuses beyond that, and a long-lived session must be reopened. Sequence wrap is not implemented.
- **Threads.** Each opened session uses one socket and one pump thread. A SessionListener uses one socket and one thread for all its sessions.
- **A dev30 or earlier Listener on the same raw36 host** sees a session FIRST as the start of a stream and holds it within its stream bounds. Use separate routes for sessions and messages.

## SocketProvider stream (dev35)

**Architecture:** Tom Dyer. **Coding and this section:** Claude (Opus 5.5), 29 October 2026.

An XTP address whose metadata has `XTP_MODE=session` and `XTP_SERVICE=<name>` makes `XtpSocketBackend~sender` return an `XtpSessionSocket`, a two-way byte stream over one session, and `~listener` return an `XtpSessionSocketListener` (`accept`, `tryAccept`, `waitReady(timeoutMs)`). Without that metadata, XTP sockets are message-oriented, as before.

| Method | Contract |
| --- | --- |
| `send(bytes)` | Queues all of the bytes (blocking while the peer is not reading) and returns their length; -1 once closed or failed |
| `recv(maxBytes)` | Up to `maxBytes`, waiting until some arrive; `''` at the end of the peer's stream; `.nil` if the session failed or the socket is closed |
| `pump(timeoutMs)`, `poll` | A bounded wait: `.true` once `recv` would not block (bytes, end of stream or failure), `.false` on timeout |
| `shutdown` | Ends our direction; reading continues |
| `close` | Graceful close of both directions (up to 5 s) |
| `evidence` | dev36: the session's protection evidence, read from libxtp (`docs/SECURITY.md`, "Protection evidence"); `.XtpSessionSocket~routeEvidence(address)` answers before the open |
| `asStream` | Itself: it provides SocketStreamAdapter's `write`, `read`, `pump`, `close` and `isOpen`, so `SocketProvider~streamSender` works without this file depending on SocketProvider.cls |

Optional metadata: `XTP_PROTECTION` (a minimum; default the service's profile), `XTP_OPEN_TIMEOUT_MS` (default 3000), `XTP_KEY_PRINCIPAL` (a client's keys, gateway mode B), and on a listener `XTP_REQUIRE_PROTECTION=1`.

`tests/test_xtp_session_socket_rexx.sh` sends 200,000 bytes through `SocketProvider~streamSender` in uneven writes, and checks a bounded `pump`, the end of stream, the reversed answer and that the session was encrypted.

Two things outside this package: `oorexx_socket_provider/src/SocketProvider.cls` declares the XTP family `stream=.true` although its message sockets are not streams, and `oorexx_socket_provider/src` ships an older `XtpSocketProvider.cls`. Put this package's `rexx` directory first in `REXX_PATH`.
