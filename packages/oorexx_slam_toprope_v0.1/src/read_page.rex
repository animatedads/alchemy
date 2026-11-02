#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* read_page.rex -- read the lines of writing in a picture (a page)   */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:  rexx read_page.rex <picture> [scale%] [truth.txt]            */
/*                                                                    */
/* 1. ImageMagick makes the picture grey, then black ink on white by  */
/*    the light near each place (a photo is not the same light all    */
/*    over), then smaller, so a capital is near the size I learned.   */
/* 2. Lines: rows with ink, split by rows with little ink.            */
/* 3. Each line: glyphs, words (glyphs.cls), then the word hint call  */
/*    (word_hint.rex), when WORD_HINT names it.                       */
/* 4. With truth.txt (one line a line): how many chars are right      */
/*    (by edit distance), with and without the hint.                  */
/* Upright writing only: no turn and no slope (not yet).              */
/* ------------------------------------------------------------------ */
  parse arg pic scale truth .
  if pic = "" then do
    say "Use: rexx read_page.rex <picture> [scale%] [truth.txt]"
    exit 1
  end
  if scale = "" then scale = 50
  parse source . . me
  home = filespec("location", me)
  reader = .GlyphReader~new
  if \reader~load(home || "glyphs.txt") then do
    say "I need glyphs.txt: run train_glyphs.rex first."
    exit 2
  end
  tmp = "/tmp/page_" || random(1, 999999)
  address system 'convert "'pic'" -colorspace Gray -lat 25x25-8% -resize' scale'% -colorspace sRGB ppm:"'tmp'.ppm"'
  parse value readPpm(tmp".ppm") with W H .
  data = .local~ppmData
  call SysFileDelete tmp".ppm"

  /* 2. lines: how much ink in each row */
  ink = .array~new(H)
  most = 0
  do y = 0 to H - 1
    n = 0
    do x = 0 to W - 1 by 2
      if c2d(substr(data, (y * W + x) * 3 + 1, 1)) < 128 then n = n + 1
    end
    ink[y + 1] = n
    most = max(most, n)
  end
  lines = .array~new
  inLine = .false
  do y = 0 to H - 1
    full = ink[y + 1] > 0.03 * most
    if full then if \inLine then do
      y0 = y
      inLine = .true
    end
    if \full then if inLine then do
      lines~append(y0 (y - 1))
      inLine = .false
    end
  end
  if inLine then lines~append(y0 (H - 1))
  /* a line too thin is a part of the line next to it (the dot of an i, a comma) */
  keep = .array~new
  do e over lines
    parse var e a b
    if b - a + 1 < 4 then do
      if keep~items > 0 then do
        parse value keep[keep~items] with c d
        keep[keep~items] = c b
      end
      iterate
    end
    keep~append(e)
  end
  lines = keep

  hintCall = value("WORD_HINT", , "ENVIRONMENT")
  truthLines = .array~new
  if truth \== "" then do
    s = .stream~new(truth)
    truthLines = s~arrayIn
    s~close
  end
  sumR = 0
  sumH = 0
  sumN = 0
  i = 0
  do e over lines
    i = i + 1
    parse var e a b
    wordsIn = reader~readWords(data, W, 0, max(0, a - 1), W - 1, min(H - 1, b + 1))
    raw = ""
    do wd over wordsIn
      if raw \== "" then raw = raw || " "
      raw = raw || reader~wordText(wd)
    end
    hinted = raw
    if hintCall \== "" then hinted = withHint(reader, wordsIn, hintCall)
    say "line" i":" raw
    if hinted \== raw then say "  hint:" hinted
    if i <= truthLines~items then do
      t = truthLines[i]
      n = length(t)
      okRaw = n - min(n, editDistance(t, raw))
      okHint = n - min(n, editDistance(t, hinted))
      sumR = sumR + okRaw
      sumH = sumH + okHint
      sumN = sumN + n
      say "  true:" t
    end
  end
  if sumN > 0 then do
    say "Chars right, without the hint:" sumR "of" sumN "(" || format(100 * sumR / sumN, , 1) || "%)"
    say "Chars right, with the hint:   " sumH "of" sumN "(" || format(100 * sumH / sumN, , 1) || "%)"
  end
  exit 0

::routine withHint
  use arg reader, wordsIn, hintCall
  f = "/tmp/hint_" || random(1, 999999)
  s = .stream~new(f".in")
  s~open("write replace")
  do wd over wordsIn
    s~lineout(reader~lattice(wd))
  end
  s~close
  address system hintCall '< "'f'.in"' with output stem ans.
  call SysFileDelete f".in"
  out = ""
  do i = 1 to wordsIn~items
    if out \== "" then out = out || " "
    a = ""
    if i <= ans.0 then a = ans.i
    if word(a, 1) == "HINT" then out = out || word(a, 2)
    else out = out || reader~wordText(wordsIn[i])
  end
  return out

/* how many chars to change, add or take away, to make a into b */
::routine editDistance
  use arg a, b
  m = length(a)
  n = length(b)
  prev = .array~new(n + 1)
  do j = 0 to n
    prev[j + 1] = j
  end
  do i = 1 to m
    cur = .array~new(n + 1)
    cur[1] = i
    ca = substr(a, i, 1)
    do j = 1 to n
      cost = (ca \== substr(b, j, 1))
      cur[j + 1] = min(prev[j + 1] + 1, cur[j] + 1, prev[j] + cost)
    end
    prev = cur
  end
  return prev[n + 1]

::routine readPpm
  use arg f
  s = .stream~new(f)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  toks = .array~new
  p = 1
  do while toks~items < 4
    ch = substr(data, p, 1)
    if verify(ch, "200a0d09"x) = 0 then do
      p = p + 1
      iterate
    end
    q = verify(data, "200a0d09"x, "M", p)
    toks~append(substr(data, p, q - p))
    p = q
  end
  .local~ppmData = substr(data, p + 1)
  return toks[2] toks[3]

::requires "glyphs.cls"
