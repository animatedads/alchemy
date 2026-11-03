/* Bounded DEFLATE LZ77 matcher: 32 KiB window, max match 258, 48 candidates. */
::class NativeLZ77Matcher public
::method find
  use strict arg data, pos
  n = length(data)
  if pos + 2 > n then return .array~of(0, 0)

  prefix = substr(data, pos, 3)
  windowStart = pos - 32768
  if windowStart < 1 then windowStart = 1
  windowLength = pos - windowStart
  if windowLength < 3 then return .array~of(0, 0)

  window = substr(data, windowStart, windowLength)
  searchEnd = length(window)
  bestLength = 0
  bestDistance = 0
  tries = 0
  maxTries = 48

  do while searchEnd > 0 & tries < maxTries
    hit = lastpos(prefix, window, searchEnd)
    if hit = 0 then leave
    candidate = windowStart + hit - 1
    distance = pos - candidate

    if distance >= 1 & distance <= 32768 then do
      maxLength = n - pos + 1
      if maxLength > 258 then maxLength = 258
      matchLength = 3
      do while matchLength < maxLength
        if substr(data, pos + matchLength, 1) \== substr(data, candidate + matchLength, 1) then leave
        matchLength += 1
      end
      if matchLength > bestLength then do
        bestLength = matchLength
        bestDistance = distance
        if bestLength = maxLength then leave
      end
    end

    searchEnd = hit - 1
    tries += 1
  end

  return .array~of(bestLength, bestDistance)
