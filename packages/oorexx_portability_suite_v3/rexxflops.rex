#!/usr/bin/env rexx
/*
 * RexxFLOPS v3
 *
 * Portable ooRexx runtime numeric benchmark.
 *
 * Each kernel iteration executes ten ooRexx numeric arithmetic operators
 * at NUMERIC DIGITS 18.
 *
 * v2 calibration is pause-resistant for phones/VMs: it uses two calibration
 * trials and sizes from the faster one, so a scheduler/GC pause cannot make a
 * tiny workload look sufficiently long.  The score is the median of FIVE
 * measured trials.
 *
 * This is an ooRexx language/runtime score, not a hardware IEEE FLOPS claim.
 */

numeric digits 18

parse arg target
if target == "" then target = 1.0

say copies("=", 64)
say "RexxFLOPS v3"
say copies("=", 64)

parse version versionText
parse source platform invocation sourceName

say "Version      :" versionText
say "Platform     :" platform
say "Architecture :" .rexxInfo~architecture
say "Digits       :" digits()
say "Target/trial :" target "seconds"
say

result = .RexxFlops~measure(target)

score = result[1]
mega = score / 1000000

say "Iterations   :" result[2]
say "Trial 1      :" format(result[4] / 1000000,,3) "Mops/s"
say "Trial 2      :" format(result[5] / 1000000,,3) "Mops/s"
say "Trial 3      :" format(result[6] / 1000000,,3) "Mops/s"
say "Trial 4      :" format(result[7] / 1000000,,3) "Mops/s"
say "Trial 5      :" format(result[8] / 1000000,,3) "Mops/s"
say "Spread       :" format(result[9],,1) "%"
say "Checksum     :" result[3]
say
say "RexxFLOPS    :" format(mega,,3) "Mops/s"
say
say "Definition: 10 ooRexx numeric operators per kernel iteration,"
say "            NUMERIC DIGITS 18, median of five trials."
say "            This is an ooRexx runtime score, not hardware FLOPS."

exit 0


::class RexxFlops

::method measure class
  use strict arg targetSeconds = 1.0
  numeric digits 18

  n = 1000
  warm = self~trial(n)

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
