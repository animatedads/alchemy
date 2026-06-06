/* ============================================================
 * receiver/receiver.rex
 *
 * Task 2 — runs in receiver/ directory.
 * NO Ticker.cls here.  Reconstructs the class purely from
 * the method source stored in the serialized payload.
 * Verifies the alarm resumes on this side.
 * ============================================================ */

say copies("=", 60)
say "  RECEIVER  (no Ticker.cls — class from serialized source)"
say copies("=", 60)
say ""

/* Pull from transport */
say "Pulling from transport queue..."
json = .RTOTransport~receive()
if json == .nil then do
  say "Nothing in transport queue.  Run sender.rex first."
  exit 1
end
say "  JSON received:" json~length "bytes"

/* Build a security manager for the deserialized object.
 * MD5 proved integrity.  SecurityManager proves safety. */
mgr = .RTOSecurityManager~new
mgr~deny("COMMAND", "*")           /* no shell-outs from deserialized code */
mgr~allow("CALL", "SYSSLEEP")      /* alarm needs sleep */
say ""
say "Security manager configured."

/* Deserialize — class is reconstructed from stored method source.
 * Security manager is attached to all reconstructed methods. */
say ""
say "Deserializing..."
obj = .RTOSerializer~deserialize(json, mgr)
if obj == .nil then do
  say "Deserialization failed."
  exit 1
end

say ""
say "Object received and reconstructed:"
say "  Class:    " obj~class~id
say "  Ticks so far:" obj~send("_COUNT")
say "  Was running: " obj~send("_RUNNING")
say "  Label:    " obj~send("_LABEL")

/* Verify collection attributes survived */
say ""
say "Type spectrum check:"
history = obj~send("_HISTORY")
config  = obj~send("_CONFIG")
tags    = obj~send("_TAGS")
log     = obj~send("_LOG")
scores  = obj~send("_SCORES")
tally   = obj~send("_TALLY")
say "  OrderedCollection (_history):" history~class~id "items:" history~items
say "  Directory (_config):"          config~class~id  "keys:"  config~items
say "  Set (_tags):"                  tags~class~id    "items:" tags~items
say "  Queue (_log):"                 log~class~id     "items:" log~items
say "  Array (_scores):"              scores~class~id  "items:" scores~items
tc = 0; oc = 0
do item over tally; if item = "tick" then tc = tc+1; if item = "tock" then oc = oc+1; end
say "  Bag (_tally): tick×" tc "  tock×" oc

/* Override the stream path for the receiver — write to a receiver-local log */
rcvLog = "/tmp/ticker_receiver.log"
/* Reconnect already called by deserializer — stream open at: " || obj~send("_STREAM_PATH") || "*/
say "Stream log: " obj~send("_STREAM_PATH")
say ""

/* The alarm should have been restarted by the deserializer.
 * Wait for a few more ticks to prove it is live on this side. */
say ""
say "Waiting 8 seconds to observe alarm ticks on receiver side..."
call SysSleep 8

/* Final report via the reconstructed object's own method */
say ""
obj~send("REPORT")

/* Stop cleanly */
say ""
say "Stopping reconstructed ticker..."
obj~send("STOP")

/* Show what the receiver's stream log contains */
say ""
say "Receiver log contents (" || rcvLog || "):"
s2 = .Stream~new(rcvLog)
s2~open("READ")
do while s2~state = "READY"; say "  " s2~lineIn; end
s2~close
say ""

/* Print the security audit trail */
say ""
mgr~printAudit

say ""
say copies("=", 60)
say "  Receiver done."
say copies("=", 60)
exit 0

::requires "../RTOSerializer.cls"
::requires "../RTOTransport.cls"
::requires "../RTOSecurityManager.cls"
