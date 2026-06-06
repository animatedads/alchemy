/* ============================================================
 * sender/sender.rex
 *
 * Task 1 — runs in sender/ directory.
 * Has Ticker.cls.  Creates a Ticker, lets it run a few ticks,
 * then serializes and pushes to transport.
 * ============================================================ */

say copies("=", 60)
say "  SENDER  (has Ticker.cls)"
say copies("=", 60)
say ""

/* Create and start a ticker */
t = .Ticker~new("MyTicker", 2)
t~start
say "Waiting for 3 ticks..."
call SysSleep 7

/* Show state before transport */
say ""
say "Before transport:"
t~report

/* Serialize */
say ""
say "Serializing..."
json = .RTOSerializer~serialize(t)
say "  JSON length:" json~length "bytes"

/* Transport: JSON → base64 → MD5 → Queue */
say ""
say "Transporting..."
.RTOTransport~send(json)

/* Stop the ORIGINAL — it has been sent */
say ""
say "Stopping original ticker..."
t~stop
say ""
say "Sender log written to:" t~_stream_path
say "Sender log contents:"
s = .Stream~new(t~_stream_path); s~open("READ")
do while s~state = "READY"; say "  " s~lineIn; end
s~close

say ""
say copies("=", 60)
say "  Sender done.  Run receiver.rex to receive."
say copies("=", 60)
exit 0

::requires "Ticker.cls"
::requires "../RTOSerializer.cls"
::requires "../RTOTransport.cls"
