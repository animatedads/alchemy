#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* word_hint.rex -- a hint from a list of words, for reading writing  */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:  rexx word_hint.rex <word list> [word list ...] < words.in    */
/*                                                                    */
/* In: one word a line. Glyphs split with |. Each glyph: the chars it */
/* is near, as  hex:how-far  split with commas, nearest first.        */
/* Out: one line for each line in:                                    */
/*   SAME             no word in the lists is a near reading          */
/*   HINT word cost   this word is a near reading                     */
/*   WORD word        the reading is a word in the lists, as it is     */
/*                                                                    */
/* The hint does not make a word. It can only choose, at each glyph,  */
/* between chars that are near the best: not more than 1.6 times as   */
/* far, or 0.02 more, and not more than 0.05 more in all. And it may  */
/* change at most a third of the glyphs of a word (one, in a short    */
/* word): it helps, it does not make a new word.                      */
/* If one glyph is not near any char of a word in                     */
/* the list, that word is not a hint. So "1itera11y" can be           */
/* "literally" (1 and l are near), but "Qzx7" stays "Qzx7". Words of */
/* one char, and words with no letter, are not hinted.                */
/* Each glyph keeps its own case: the char of the word that is nearer.*/
/* ------------------------------------------------------------------ */
  parse arg lists
  if lists = "" then do
    say "Use: rexx word_hint.rex <word list> [word list ...] < words.in"
    exit 1
  end
  byLen = .directory~new
  seen = .directory~new
  do i = 1 to words(lists)
    f = word(lists, i)
    if \SysFileExists(f) then do
      say "SAME"
      exit 2
    end
    s = .stream~new(f)
    rows = s~arrayIn
    s~close
    do w over rows
      w = w~strip~lower
      if w = "" then iterate
      if verify(w, "abcdefghijklmnopqrstuvwxyz") > 0 then iterate
      if seen~hasIndex(w) then iterate
      seen[w] = 1
      n = length(w)
      if \byLen~hasIndex(n) then byLen[n] = .array~new
      byLen[n]~append(w)
    end
  end
  do while lines() > 0
    line = linein()
    if line = "" then do
      say "SAME"
      iterate
    end
    say hint(line, byLen)
  end
  exit 0

::routine hint
  use arg line, byLen
  glyphs = line~makeArray("|")
  n = glyphs~items
  /* one char is not a word to hint: "2" is not "Z", "&" is not "a" */
  if n < 2 then return "SAME"
  if \byLen~hasIndex(n) then return "SAME"
  near = .array~new(n)
  cost = .array~new(n)
  form = .array~new(n)
  raw = ""
  do i = 1 to n
    cands = glyphs[i]~makeArray(",")
    best = 1e9
    c = .directory~new
    f = .directory~new
    first = ""
    do e over cands
      parse var e hx ":" d
      ch = x2c(hx)
      if first == "" then first = ch
      best = min(best, d)
      lc = ch~lower
      if verify(lc, "abcdefghijklmnopqrstuvwxyz") > 0 then iterate
      if c[lc] == .nil | d < c[lc] then do
        c[lc] = d
        f[lc] = ch
      end
    end
    raw = raw || first
    ok = ""
    do lc over c
      if c[lc] <= max(1.6 * best, best + 0.02) then if c[lc] <= best + 0.05 then ok = ok || lc
    end
    near[i] = ok
    cost[i] = c
    form[i] = f
  end
  /* a word with no letter in it (as "42") is not hinted */
  if verify(raw~lower, "abcdefghijklmnopqrstuvwxyz", "M") = 0 then return "SAME"
  bestW = ""
  bestC = 1e9
  do w over byLen[n]
    fit = .true
    do i = 1 to n
      if pos(substr(w, i, 1), near[i]) = 0 then do
        fit = .false
        leave
      end
    end
    if \fit then iterate
    /* a hint helps with some glyphs; it does not make a new word: at most a third of the glyphs change */
    changed = 0
    do i = 1 to n
      if substr(w, i, 1) \== substr(raw, i, 1)~lower then changed = changed + 1
    end
    if changed > max(1, (n + 2) % 3) then iterate
    sum = 0
    do i = 1 to n
      sum = sum + cost[i][substr(w, i, 1)]
    end
    if sum < bestC then do
      bestC = sum
      bestW = w
    end
  end
  if bestW == "" then return "SAME"
  out = ""
  ups = 0
  do i = 1 to n
    ch = form[i][substr(bestW, i, 1)]
    if ch == ch~upper then if ch \== ch~lower then ups = ups + 1
    out = out || ch
  end
  /* the case of a word: all capitals, or the first as it is and the rest small */
  if ups < n then out = left(out, 1) || substr(out, 2)~lower
  if out == raw then return "WORD" out
  return "HINT" out format(bestC, , 4)
