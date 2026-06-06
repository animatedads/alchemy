/* ============================================================
 * sender/Ticker.cls
 *
 * Demo class that demonstrates:
 *   - .Alarm + AlarmNotification (the alarm that must survive transport)
 *   - All OORexx collection types as attributes
 *   - Full attribute restoration after teleportation
 *
 * This file exists ONLY in sender/.
 * The receiver reconstructs the class purely from serialized source.
 * ============================================================ */

::class Ticker public inherit AlarmNotification

::attribute _label      unguarded
::attribute _interval   unguarded    /* seconds between ticks */
::attribute _running    unguarded    /* .true while alarm is live */
::attribute _count      unguarded    /* ticks fired so far */
::attribute _history    unguarded    /* List of tick timestamps */
::attribute _config     unguarded    /* Directory of config k/v */
::attribute _tags       unguarded    /* Set of string tags */
::attribute _log        unguarded    /* Queue of last N log entries */
::attribute _scores     unguarded    /* Array of numeric scores */
::attribute _tally      unguarded    /* Bag (allows duplicates) */
::attribute _alarm      unguarded    /* live .Alarm — NOT serialized */
::attribute _stream     unguarded    /* file stream handle — NOT serialized */
::attribute _stream_path unguarded   /* path survives transport */

::method init
  expose _label _interval _running _count _history ,
         _config _tags _log _scores _tally _alarm
  use arg label, secs
  if label == .nil then label = "Ticker"
  if secs  == .nil then secs  = 5
  _label    = label
  _interval = secs
  _running  = .false
  _count    = 0
  _alarm    = .nil
  /* Demonstrate full type spectrum */
  _history = .List~new
  _config  = .Directory~new
  _config["label"]    = label
  _config["interval"] = secs~string
  _config["version"]  = "1.0"
  _tags    = .Set~of("ticker", "demo", "serializable")
  _log     = .Queue~new
  _scores  = .Array~of(10, 20, 30)
  _tally   = .Bag~new
  _tally~put("tick"); _tally~put("tick"); _tally~put("tock")
  /* Open a tick log stream — handle is local, path travels */
  _stream_path = "/tmp/ticker_" || _label~lower || ".log"
  _stream = .Stream~new(_stream_path)
  _stream~open("WRITE REPLACE")
  rc = _stream~lineOut("Ticker started: " || _label || " at " || time())

::method start unguarded
  expose _running _interval _alarm _label
  if _running then return
  _running = .true
  _alarm   = .Alarm~new(_interval, .Message~new(self, "tick"))
  say "[" || _label || "]  alarm started — interval:" _interval "s"

::method stop unguarded
  expose _running _alarm _label
  _running = .false
  if _alarm \== .nil then do
    _alarm~cancel
    _alarm = .nil
  end
  say "[" || _label || "]  stopped"
  if _stream \== .nil then do
    rc = _stream~lineOut("Ticker stopped at " || time())
    _stream~close
    _stream = .nil
  end

::method tick unguarded
  expose _running _interval _count _history _log _tally _alarm _label
  _count   = _count + 1
  stamp    = time("L")
  _history~append(stamp)
  _log~queue("tick #" || _count || " at " || stamp)
  _tally~put("tick")
  say "[" || _label || "]  tick" _count "at" stamp
  if _stream \== .nil then
    rc = _stream~lineOut("tick " || _count || " at " || stamp)
  /* Reschedule if still running */
  if _running then
    _alarm = .Alarm~new(_interval, .Message~new(self, "tick"))

::method report unguarded
  expose _label _count _running _config _tags _scores _history _tally
  say copies("-", 50)
  say "[" || _label || "]  Report"
  say "  ticks:    " _count
  say "  running:  " _running
  say "  interval: " _config["interval"] || "s"
  say "  tags:"
  do tag over _tags;   say "    " tag;   end
  say "  scores:"
  do s   over _scores; say "    " s;     end
  say "  history:" _history~items "entries"
  tickCount = 0; tockCount = 0
  do item over _tally
    if item = "tick" then tickCount = tickCount + 1
    if item = "tock" then tockCount = tockCount + 1
  end
  say "  tally:   tick x" || tickCount || "  tock x" || tockCount
  say copies("-", 50)

/* ── Explicit RTO serialization protocol ─────────────────── *
 * RTOSerializer calls ~_rto_export to capture state and
 * ~_rto_import to restore it.  Direct expose access avoids
 * dependence on attribute method discovery.                  */

::method _rto_export
  expose _label _interval _running _count ,
         _history _config _tags _log _scores _tally
  d = .Directory~new
  d["_LABEL"]    = _label
  d["_INTERVAL"] = _interval
  d["_RUNNING"]  = _running
  d["_COUNT"]    = _count
  d["_HISTORY"]  = _history
  d["_CONFIG"]   = _config
  d["_TAGS"]     = _tags
  d["_LOG"]      = _log
  d["_SCORES"]   = _scores
  d["_TALLY"]      = _tally
  d["_STREAM_PATH"] = _stream_path   /* path travels; handle does not */
  return d

::method _rto_import
  expose _label _interval _running _count ,
         _history _config _tags _log _scores _tally
  use arg d
  _label    = d["_LABEL"]
  _interval = d["_INTERVAL"]
  _running  = d["_RUNNING"]
  _count    = d["_COUNT"]
  _history  = d["_HISTORY"]
  _config   = d["_CONFIG"]
  _tags     = d["_TAGS"]
  _log      = d["_LOG"]
  _scores   = d["_SCORES"]
  _tally       = d["_TALLY"]
  _stream_path = d["_STREAM_PATH"]
  _stream      = .nil   /* handle not restored — call _rto_reconnect */

/* Explicit method source export — method~source may not return
 * source for ::method unguarded in a ::requires'd file.
 * RTOSerializer calls this if available and merges into _classDefs. */
::method _rto_sources
  d = .Directory~new

  tick = .Array~new
  tick~append("expose _running _interval _count _history _log _tally _alarm _label _stream")
  tick~append("_count = _count + 1")
  tick~append("stamp = time('L')")
  tick~append("_history~append(stamp)")
  tick~append("_log~queue('tick #' || _count || ' at ' || stamp)")
  tick~append("_tally~put('tick')")
  tick~append("say '[' || _label || ']  tick' _count 'at' stamp")
  tick~append("if _stream \== .nil then rc = _stream~lineOut('tick ' || _count || ' at ' || stamp)")
  tick~append("if _running then _alarm = .Alarm~new(_interval, .Message~new(self, 'tick'))")
  d["TICK"] = tick

  stop = .Array~new
  stop~append("expose _running _alarm _label _stream")
  stop~append("_running = .false")
  stop~append("if _alarm \== .nil then do; _alarm~cancel; _alarm = .nil; end")
  stop~append("say '[' || _label || ']  stopped'")
  stop~append("if _stream \== .nil then do")
  stop~append("  rc = _stream~lineOut('--- stopped ---')")
  stop~append("  _stream~close")
  stop~append("  _stream = .nil")
  stop~append("end")
  d["STOP"] = stop

  report = .Array~new
  report~append("expose _label _count _running _config _tags _scores _history _tally")
  report~append("say copies('-', 50)")
  report~append("say '[' || _label || ']  Report'")
  report~append("say '  ticks:    ' _count")
  report~append("say '  running:  ' _running")
  report~append("say '  interval: ' _config['interval'] || 's'")
  report~append("say '  history: ' _history~items 'entries'")
  report~append("tc = 0; oc = 0")
  report~append("do item over _tally")
  report~append("  if item = 'tick' then tc = tc+1")
  report~append("  if item = 'tock' then oc = oc+1")
  report~append("end")
  report~append("say '  tally:   tick x' || tc || '  tock x' || oc")
  report~append("say copies('-', 50)")
  d["REPORT"] = report

  return d

/* Reopen OS resources after transport.
 * Called automatically by RTOSerializer after state restoration.
 * Receiver may override _stream_path before calling manually. */
::method _rto_reconnect
  expose _stream _stream_path _label
  if _stream_path == .nil then return
  /* Append to existing log (receiver continues where sender left off) */
  _stream = .Stream~new(_stream_path)
  _stream~open("WRITE APPEND")
  rc = _stream~lineOut("--- reconnected on receiver at " || time() || " ---")
  say "[" || _label || "]  stream reconnected: " || _stream_path
