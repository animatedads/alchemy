#!/usr/bin/env rexx
/*
 * ooRexx portable feature/qualification suite
 *
 * Intended to run unchanged on normal ooRexx installations and on the
 * Android/XCover build.  The RxSock test deliberately uses two distinct
 * ooRexx objects in two activities: one listener and one client.
 *
 * Requires:
 *   rxsock
 *   csvStream.cls
 *   yaml.cls
 */

numeric digits 18

suite = .FeatureSuite~new
exit suite~run


::class FeatureSuite

::method init
  expose passed failed
  passed = 0
  failed = 0

::method run
  expose passed failed

  say copies("=", 72)
  say "ooRexx Portable Feature Suite"
  say copies("=", 72)

  parse version versionText
  parse source platform invocation sourceName

  say "Version      :" versionText
  say "Platform     :" platform
  say "Invocation   :" invocation
  say "Architecture :" .rexxInfo~architecture
  say "Source       :" sourceName
  say

  self~runOne("core language / compounds", "testCore")
  self~runOne("objects / dispatch", "testObjects")
  self~runOne("activities / START / RESULT", "testActivities")
  self~runOne("stream filesystem I/O", "testFilesystem")
  self~runOne("named Rexx queue / rxapi", "testQueue")
  self~runOne("CSVStream round trip", "testCsv")
  self~runOne("YAML parse / emit / reparse", "testYaml")
  self~runOne("RxSock two-object loopback", "testRxSock")
  self~runOne("RexxFLOPS portable score", "testRexxFlops")

  say
  say copies("-", 72)
  say "PASS:" passed " FAIL:" failed
  if failed = 0 then do
    say "SUITE RESULT: PASS"
    return 0
  end

  say "SUITE RESULT: FAIL"
  return failed

::method runOne private
  expose passed failed
  use strict arg label, methodName

  signal on syntax  name trapped
  signal on error   name trapped
  signal on failure name trapped

  result = self~send(methodName)

  if result~left(4) = "PASS" then do
    passed += 1
    say "[PASS]" label
    detail = result~substr(5)~strip
    if detail \== "" then say "       " detail
  end
  else do
    failed += 1
    say "[FAIL]" label
    say "       " result
  end
  return

trapped:
  failed += 1
  conditionName = condition("C")
  description = condition("D")
  info = condition("O")
  say "[FAIL]" label
  say "       condition:" conditionName description
  if info <> .nil then do
    if info["CODE"] <> .nil then say "       code     :" info["CODE"]
    if info["RC"] <> .nil then say "       rc       :" info["RC"]
    if info["POSITION"] <> .nil then say "       position :" info["POSITION"]
    if info["PROGRAM"] <> .nil then say "       program  :" info["PROGRAM"]
    if info["ADDITIONAL"] <> .nil then say "       additional:" info["ADDITIONAL"]
  end
  return

::method testCore private
  numeric digits 18

  if 6 * 7 <> 42 then return "FAIL arithmetic"
  if "android"~upper <> "ANDROID" then return "FAIL string method"

  a.1 = "one"
  a.foo = "bar"
  addr.!family = "AF_INET"

  if a.1 <> "one" then return "FAIL numeric compound"
  if a.foo <> "bar" then return "FAIL named compound"
  if addr.!family <> "AF_INET" then return "FAIL bang-tail compound"

  arr = .array~of("alpha", "beta", "gamma")
  if arr~items <> 3 | arr[2] <> "beta" then return "FAIL Array"

  /* Explicitly qualify indexed assignment / auto-extension from .Array~new. */
  grow = .array~new
  grow[1] = "one"
  grow[2] = "two"
  if grow[1] <> "one" | grow[2] <> "two" then
    return "FAIL Array indexed assignment / auto-extension"

  tab = .table~new
  tab["answer"] = 42
  tab["name"] = "ooRexx"
  if tab["answer"] <> 42 | tab["name"] <> "ooRexx" then return "FAIL Table"

  /* Modest allocation/retention pass, large enough to exercise object paths. */
  objects = .array~new(10000)
  do i = 1 to 10000
    objects[i] = "object-" || i
  end
  if objects[1] <> "object-1" | objects[10000] <> "object-10000" then
    return "FAIL allocation/retention"

  objects = .nil
  return "PASS arithmetic, strings, compounds, collections, allocation"

::method testObjects private
  counter = .SuiteCounter~new
  do 2500
    counter~increment
  end
  if counter~value <> 2500 then return "FAIL method dispatch/state"
  counter~add(17)
  if counter~value <> 2517 then return "FAIL argument dispatch"
  return "PASS 2517 object-state mutations"

::method testActivities private
  a = .SuiteWorker~new
  b = .SuiteWorker~new

  ma = a~start("WORK", "A", 20000)
  mb = b~start("WORK", "B", 15000)

  ra = ma~result
  rb = mb~result

  expectedA = 20000 * 20001 / 2
  expectedB = 15000 * 15001 / 2

  if ra <> "A:" || expectedA then return "FAIL worker A result=" ra
  if rb <> "B:" || expectedB then return "FAIL worker B result=" rb

  return "PASS two concurrent activities returned deterministic results"

::method testFilesystem private
  file = "oorexx_suite_" || time("S") || "_" || random(1000, 9999) || ".txt"

  out = .stream~new(file)
  state = out~open("WRITE REPLACE")
  if state~upper~pos("READY") <> 1 then return "FAIL open write:" state

  out~lineOut("alpha")
  out~lineOut("beta")
  out~close

  inp = .stream~new(file)
  state = inp~open("READ")
  if state~upper~pos("READY") <> 1 then return "FAIL open read:" state

  one = inp~lineIn
  two = inp~lineIn
  inp~close

  if one <> "alpha" | two <> "beta" then
    return "FAIL data round trip"

  f = .File~new(file)
  if f~exists then f~delete

  return "PASS write/read/close/delete"

::method testQueue private
  qname = "REXXSUITE_" || time("S") || "_" || random(1000, 9999)
  q = rxqueue("CREATE", qname)
  if q == "" then return "FAIL queue create"

  oldq = rxqueue("SET", q)

  queue "one"
  queue "two"
  queue "three"

  depth = queued()
  parse pull one
  parse pull two
  parse pull three

  call rxqueue "SET", oldq
  call rxqueue "DELETE", q

  if depth <> 3 then return "FAIL queued()=" depth
  if one <> "one" | two <> "two" | three <> "three" then
    return "FAIL queue payload"

  return "PASS create/set/queue/pull/delete via rxapi"

::method testCsv private
  file = "oorexx_suite_" || time("S") || "_" || random(1000, 9999) || ".csv"

  csv = .CsvStream~new(file)
  csv~open("WRITE REPLACE")
  state = csv~state
  if state~upper~pos("READY") <> 1 then return "FAIL CSV open write:" state

  rowOut = .array~of("alpha", "two,three", 42, " spaced ")
  csv~csvLineOut(rowOut)
  csv~close

  csv = .CsvStream~new(file)
  csv~open("READ")
  state = csv~state
  if state~upper~pos("READY") <> 1 then return "FAIL CSV open read:" state

  rowIn = csv~csvLineIn
  csv~close

  if rowIn~items <> 4 then return "FAIL CSV field count=" rowIn~items
  if rowIn[1] <> "alpha" then return "FAIL CSV field 1"
  if rowIn[2] <> "two,three" then return "FAIL CSV quoted delimiter"
  if rowIn[3] <> "42" then return "FAIL CSV numeric"
  if rowIn[4] <> " spaced " then return "FAIL CSV literal spacing"

  f = .File~new(file)
  if f~exists then f~delete

  return "PASS quoted delimiter, numeric and literal round trip"

::method testYaml private
  doc = .table~new
  doc["title"] = "XCover"
  doc["count"] = 3
  doc["items"] = .array~of("alpha", "beta", "gamma")

  emitted = .Yaml~toYaml(doc)
  if emitted == "" then return "FAIL empty YAML emission"

  parser = .Yaml~new
  parsed = parser~parseString(emitted)

  if parsed["title"] <> "XCover" then return "FAIL YAML title"
  if parsed["count"] <> "3" then return "FAIL YAML integer"

  items = parsed["items"]
  if \items~isA(.array) then return "FAIL YAML sequence type"
  if items~items <> 3 | items[2] <> "beta" then return "FAIL YAML sequence"

  emitted2 = .Yaml~toYaml(parsed)
  reparsed = .Yaml~new~parseString(emitted2)

  if reparsed["title"] <> "XCover" then return "FAIL YAML reparse"
  return "PASS Table/Array -> YAML -> objects -> YAML -> objects"

::method testRxSock private
  latch = .SuiteSocketLatch~new
  listener = .SuiteSocketListener~new
  client = .SuiteSocketClient~new

  listenerMessage = listener~start("RUN", latch)
  state = latch~wait

  if state[1] <> .true then do
    /* RESULT makes sure the listener activity has actually terminated. */
    ignored = listenerMessage~result
    return "FAIL listener setup:" state[3]
  end

  port = state[2]
  payload = "hello-from-" || .rexxInfo~platform

  clientMessage = client~start("RUN", port, payload)

  clientResult = clientMessage~result
  serverResult = listenerMessage~result

  if clientResult~left(5) = "FAIL:" then return clientResult
  if serverResult~left(5) = "FAIL:" then return serverResult

  if serverResult <> payload then
    return "FAIL server received:" serverResult

  expectedReply = "ACK:" || payload
  if clientResult <> expectedReply then
    return "FAIL client reply:" clientResult

  return "PASS listener object + client object, ephemeral localhost TCP port"

::method testRexxFlops private
  result = .RexxFlops~measure(0.50)
  score = result[1]
  mega = score / 1000000

  return "PASS RexxFLOPS=" || format(mega,,3) || " Mops/s; iterations=" || result[2] || ,
         "; trials=" || format(result[4]/1000000,,3) || "," || ,
                        format(result[5]/1000000,,3) || "," || ,
                        format(result[6]/1000000,,3) || "," || ,
                        format(result[7]/1000000,,3) || "," || ,
                        format(result[8]/1000000,,3) || ,
         "; spread=" || format(result[9],,1) || "%"


::class SuiteCounter
::method init
  expose value
  value = 0
::attribute value get
::method increment
  expose value
  value += 1
::method add
  expose value
  use strict arg amount
  value += amount


::class SuiteWorker
::method work
  use strict arg tag, n
  total = 0
  do i = 1 to n
    total += i
  end
  return tag || ":" || total


/*
 * Small latch used only by the RxSock test.  GUARD ON WHEN releases the
 * object's guard while waiting, allowing the listener activity to signal it.
 */
::class SuiteSocketLatch
::method init
  expose ready ok port detail
  ready = .false
  ok = .false
  port = 0
  detail = ""

::method signalReady
  expose ready ok port detail
  use strict arg p
  port = p
  detail = ""
  ok = .true
  ready = .true

::method signalFailure
  expose ready ok port detail
  use strict arg why
  port = 0
  detail = why
  ok = .false
  ready = .true

::method wait
  expose ready ok port detail
  guard on when ready
  return .array~of(ok, port, detail)


::class SuiteSocketListener
::method run
  use strict arg latch

  s = -1
  c = -1

  signal on syntax  name trapped
  signal on error   name trapped
  signal on failure name trapped

  s = SockSocket("AF_INET", "SOCK_STREAM", "IPPROTO_TCP")
  if s < 0 then do
    latch~signalFailure("SockSocket errno=" || errno)
    return "FAIL: SockSocket errno=" || errno
  end

  addr.!family = "AF_INET"
  addr.!addr = "127.0.0.1"
  addr.!port = 0

  if SockBind(s, "addr.!") < 0 then do
    why = "SockBind errno=" || errno
    call SockClose s
    latch~signalFailure(why)
    return "FAIL: " || why
  end

  if SockListen(s, 1) < 0 then do
    why = "SockListen errno=" || errno
    call SockClose s
    latch~signalFailure(why)
    return "FAIL: " || why
  end

  if SockGetSockName(s, "bound.!") < 0 then do
    why = "SockGetSockName errno=" || errno
    call SockClose s
    latch~signalFailure(why)
    return "FAIL: " || why
  end

  latch~signalReady(bound.!port)

  c = SockAccept(s)
  if c < 0 then do
    why = "SockAccept errno=" || errno
    call SockClose s
    return "FAIL: " || why
  end

  received = SockRecv(c, "payload", 4096)
  if received < 1 then do
    why = "SockRecv rc=" || received || " errno=" || errno
    call SockClose c
    call SockClose s
    return "FAIL: " || why
  end

  reply = "ACK:" || payload
  sent = SockSend(c, reply)
  if sent <> reply~length then do
    why = "SockSend rc=" || sent || " expected=" || reply~length
    call SockClose c
    call SockClose s
    return "FAIL: " || why
  end

  call SockClose c
  call SockClose s
  return payload

trapped:
  why = condition("C") || " " || condition("D")
  if c >= 0 then call SockClose c
  if s >= 0 then call SockClose s
  latch~signalFailure(why)
  return "FAIL: listener condition " || why


::class SuiteSocketClient
::method run
  use strict arg port, payload

  s = SockSocket("AF_INET", "SOCK_STREAM", "IPPROTO_TCP")
  if s < 0 then return "FAIL: client SockSocket errno=" || errno

  dest.!family = "AF_INET"
  dest.!addr = "127.0.0.1"
  dest.!port = port

  if SockConnect(s, "dest.!") < 0 then do
    why = "client SockConnect errno=" || errno
    call SockClose s
    return "FAIL: " || why
  end

  sent = SockSend(s, payload)
  if sent <> payload~length then do
    why = "client SockSend rc=" || sent
    call SockClose s
    return "FAIL: " || why
  end

  received = SockRecv(s, "reply", 4096)
  if received < 1 then do
    why = "client SockRecv rc=" || received || " errno=" || errno
    call SockClose s
    return "FAIL: " || why
  end

  call SockClose s
  return reply


/*
 * RexxFLOPS
 *
 * This is deliberately a language/runtime benchmark, not a claim about
 * hardware IEEE floating-point FLOPS.  Each kernel iteration executes ten
 * ooRexx numeric arithmetic operators at NUMERIC DIGITS 18.  The median of
 * three timed trials is the portable score.
 */
::class RexxFlops

::method measure class
  use strict arg targetSeconds = 0.50
  numeric digits 18

  n = 1000
  warm = self~trial(n)

  /*
   * Calibration uses TWO trials and the faster elapsed time.
   * A phone can be descheduled for seconds; one long pause must not make us
   * believe a tiny workload has reached the target duration.
   */
  do forever
    c1 = self~trial(n)
    c2 = self~trial(n)
    fastest = min(c1[1], c2[1])

    if fastest >= targetSeconds then leave

    if fastest <= 0 then do
      n *= 2
    end
    else do
      factor = targetSeconds / fastest
      if factor < 1.25 then factor = 1.25
      if factor > 4 then factor = 4
      n = trunc(n * factor * 1.10)
    end

    if n < 1000 then n = 1000
    if n > 100000000 then leave
  end

  scores = .array~new(5)
  checksum = 0
  ops = n * 10

  do i = 1 to 5
    t = self~trial(n)
    if t[1] <= 0 then
      raise syntax 93.900 additional("RexxFLOPS timer resolution too low")
    scores[i] = ops / t[1]
    checksum = t[2]
  end

  sorted = scores~copy
  sorted~sort
  median = sorted[3]
  spread = (sorted[5] - sorted[1]) / median * 100

  return .array~of(median, n, checksum, ,
                   scores[1], scores[2], scores[3], scores[4], scores[5], spread)

::method trial class private
  use strict arg n
  numeric digits 18

  x = 1.000001
  y = 0.999999

  ignored = time("R")

  do i = 1 to n
    x = x * 1.000001 + y * 0.000001
    y = y * 0.999999 + x * 0.000001
    x = x - y * 0.0000001
    y = y + x / 1000000
  end

  elapsed = time("E")
  checksum = x + y

  return .array~of(elapsed, checksum)


::requires "rxsock" LIBRARY
::requires "csvStream.cls"
::requires "yaml.cls"
