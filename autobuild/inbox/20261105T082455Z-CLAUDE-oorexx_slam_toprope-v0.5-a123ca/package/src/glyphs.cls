/* ------------------------------------------------------------------ */
/* glyphs.cls -- read writing: the part that training and reading     */
/*               share, so a letter is seen the same way in both      */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* A glyph is one letter: the dark parts of one place across (the dot */
/* of an i goes with its stem). Each glyph is said as:                */
/*   a grid of 8 across and 12 down, how dark each cell is (0 to 9),  */
/*   how wide it is, and where its top and bottom are, from the line  */
/*   the letters sit on (all as parts of the height of a capital).    */
/* To read a glyph: the glyph learned before that is nearest.         */
/* Upright writing only: no turn, no slope (not yet).                 */
/* ------------------------------------------------------------------ */

::class GlyphReader public

::method init
  expose templates
  templates = .array~new

::method count
  expose templates
  return templates~items

/* ---------------- what was learned -------------------------------- */
/* one line each: char (as hex) font size wide top bottom grid */
::method load
  expose templates
  use arg file
  if \SysFileExists(file) then return .false
  s = .stream~new(file)
  rows = s~arrayIn
  s~close
  do r over rows
    if r = "" then iterate
    if left(r, 1) = "#" then iterate
    parse var r hx font size wrel top bot grid grid2 .
    t = .directory~new
    t["CH"] = x2c(hx)
    t["FONT"] = font
    t["SIZE"] = size
    t["W"] = wrel
    t["TOP"] = top
    t["BOT"] = bot
    t["GRID"] = grid
    t["GRID2"] = grid2
    t["COARSE"] = coarseOf(grid)
    templates~append(t)
  end
  return .true

::method add
  expose templates
  use arg t
  t["COARSE"] = coarseOf(t["GRID"])
  templates~append(t)

::method save
  expose templates
  use arg file
  s = .stream~new(file)
  s~open("write replace")
  s~lineout("# glyphs.txt: letters learned by train_glyphs.rex. Architecture: Tom Dyer. Code: Claude (Opus 5.5).")
  s~lineout("# char(hex) font size wide top bottom grid(8x12, 0-9) grid2(16x24, 0-9)")
  do t over templates
    s~lineout(c2x(t["CH"]) t["FONT"] t["SIZE"] fmt3(t["W"]) fmt3(t["TOP"]) fmt3(t["BOT"]) t["GRID"] t["GRID2"])
  end
  s~close

/* ---------------- glyphs in a region ------------------------------ */
/* data: RGB, 3 bytes a place, W across. Region x0..x1, y0..y1 (in). */
/* Returns a directory: GLYPHS (each X0 Y0 X1 Y1), COV (how dark each */
/* place is, 0 to 1), RW (region width), and RX0 RY0.                 */
::method glyphsIn
  use arg data, W, x0, y0, x1, y1, bpp = 3
  rw = x1 - x0 + 1
  rh = y1 - y0 + 1
  /* the background: the colour seen most; the ink: the farthest from it */
  counts = .directory~new
  do y = y0 to y1
    do x = x0 to x1
      k = substr(data, (y * W + x) * bpp + 1, bpp)
      n = counts[k]
      if n == .nil then counts[k] = 1
      else counts[k] = n + 1
    end
  end
  bgk = ""
  bgn = 0
  do k over counts
    if counts[k] > bgn then do
      bgn = counts[k]
      bgk = k
    end
  end
  parse value rgbOf(bgk) with br bg2 bb
  far = 0
  dist = .directory~new
  do k over counts
    parse value rgbOf(k) with r g b
    d = RxCalcSqrt((r - br) ** 2 + (g - bg2) ** 2 + (b - bb) ** 2, 9)
    dist[k] = d
    if d > far then far = d
  end
  out = .directory~new
  out["GLYPHS"] = .array~new
  out["RW"] = rw
  out["RX0"] = x0
  out["RY0"] = y0
  if far < 40 then return out
  cov = .array~new(rw * rh)
  ink = .array~new(rw * rh)
  do y = 0 to rh - 1
    do x = 0 to rw - 1
      k = substr(data, ((y + y0) * W + x + x0) * bpp + 1, bpp)
      v = min(1, dist[k] / (far * 0.85))
      cov[y * rw + x + 1] = v
      ink[y * rw + x + 1] = (v >= 0.3)
    end
  end
  out["COV"] = cov
  /* parts of ink that touch (also at a corner) */
  lab = .array~new(rw * rh)
  parts = .array~new
  stack = .array~new
  do p = 1 to rw * rh
    if \ink[p] then iterate
    if lab[p] \== .nil then iterate
    id = parts~items + 1
    lab[p] = id
    sp = 1
    stack[1] = p
    mx0 = rw
    mx1 = -1
    my0 = rh
    my1 = -1
    n = 0
    do while sp > 0
      q = stack[sp]
      sp = sp - 1
      n = n + 1
      y = (q - 1) % rw
      x = (q - 1) // rw
      mx0 = min(mx0, x)
      mx1 = max(mx1, x)
      my0 = min(my0, y)
      my1 = max(my1, y)
      do dy = -1 to 1
        do dx = -1 to 1
          nx = x + dx
          ny = y + dy
          if nx < 0 | ny < 0 | nx >= rw | ny >= rh then iterate
          r = ny * rw + nx + 1
          if \ink[r] then iterate
          if lab[r] \== .nil then iterate
          lab[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
    end
    parts~append(mx0 my0 mx1 my1 n)
  end
  /* left to right; a part over the same place across as the glyph before it is part of that glyph (the dot of i) */
  parts = parts~sortWith(.ByLeft~new)
  glyphs = .array~new
  do e over parts
    parse var e a0 b0 a1 b1 n
    if n < 2 then iterate
    if glyphs~items > 0 then do
      parse value glyphs[glyphs~items] with g0 h0 g1 h1
      over = min(a1, g1) - max(a0, g0) + 1
      if over >= 0.5 * min(a1 - a0 + 1, g1 - g0 + 1) then do
        glyphs[glyphs~items] = min(a0, g0) min(b0, h0) max(a1, g1) max(b1, h1)
        iterate
      end
    end
    glyphs~append(a0 b0 a1 b1)
  end
  out["GLYPHS"] = glyphs
  return out

/* the line the letters sit on, and the height of a capital: from the glyphs */
::method lineOf
  use arg glyphs
  hmax = 0
  do e over glyphs
    parse var e a0 b0 a1 b1
    hmax = max(hmax, b1 - b0 + 1)
  end
  bottoms = .directory~new
  do e over glyphs
    parse var e a0 b0 a1 b1
    if b1 - b0 + 1 < 0.5 * hmax then iterate
    n = bottoms[b1]
    if n == .nil then bottoms[b1] = 1
    else bottoms[b1] = n + 1
  end
  base = 0
  bn = 0
  do k over bottoms
    if bottoms[k] > bn | (bottoms[k] = bn & k > base) then do
      bn = bottoms[k]
      base = k
    end
  end
  cap = 0
  do e over glyphs
    parse var e a0 b0 a1 b1
    cap = max(cap, base - b0 + 1)
  end
  if cap < 1 then cap = hmax
  return base cap

/* the numbers that say one glyph */
::method features
  use arg cov, rw, glyph, base, cap
  parse var glyph a0 b0 a1 b1
  gw = a1 - a0 + 1
  gh = b1 - b0 + 1
  grid = ""
  do j = 0 to 11
    ya = b0 + j * gh / 12
    yb = b0 + (j + 1) * gh / 12
    do i = 0 to 7
      xa = a0 + i * gw / 8
      xb = a0 + (i + 1) * gw / 8
      grid = grid || trunc(9.49 * self~area(cov, rw, xa, ya, xb, yb) + 0.5)
    end
  end
  t = .directory~new
  t["W"] = gw / cap
  t["TOP"] = (base - b0 + 1) / cap
  t["BOT"] = (base - b1) / cap
  t["GRID"] = grid
  /* the same glyph, twice as fine: only for the difference finder */
  grid2 = ""
  do j = 0 to 23
    ya = b0 + j * gh / 24
    yb = b0 + (j + 1) * gh / 24
    do i = 0 to 15
      xa = a0 + i * gw / 16
      xb = a0 + (i + 1) * gw / 16
      grid2 = grid2 || trunc(9.49 * self~area(cov, rw, xa, ya, xb, yb) + 0.5)
    end
  end
  t["GRID2"] = grid2
  return t

/* how dark a box is, on average (parts of places count by how much is in it) */
::method area
  use arg cov, rw, xa, ya, xb, yb
  sum = 0
  wt = 0
  do y = trunc(ya) to ce(yb) - 1
    fy = min(y + 1, yb) - max(y, ya)
    if fy <= 0 then iterate
    do x = trunc(xa) to ce(xb) - 1
      fx = min(x + 1, xb) - max(x, xa)
      if fx <= 0 then iterate
      v = cov[y * rw + x + 1]
      if v == .nil then v = 0
      sum = sum + v * fx * fy
      wt = wt + fx * fy
    end
  end
  if wt = 0 then return 0
  return sum / wt

/* the nearest glyph learned before, and the nearest of each kind (letter, digit, small, capital) */
::method nearest
  expose templates
  use arg f
  out = .directory~new
  do k over .array~of("ANY", "LETTER", "DIGIT", "LOWER", "UPPER", "MARK")
    out[k] = "?"
    out[k"D"] = 1e9
  end
  all = .directory~new
  out["ALL"] = all
  /* low resolution for all: the 4 x 6 grid, and size and place; then the full grid only for the 40 nearest (as V5V) */
  fc = coarseOf(f["GRID"])
  cd = .array~new
  cbest = 1e9
  do t over templates
    d = 3 * (t["W"] - f["W"]) ** 2 + 4 * (t["TOP"] - f["TOP"]) ** 2 + 4 * (t["BOT"] - f["BOT"]) ** 2
    if d < 2.5 * cbest + 0.02 then do
      tc = t["COARSE"]
      s = 0
      do i = 1 to 24
        s = s + (substr(tc, i, 1) - substr(fc, i, 1)) ** 2
      end
      d = d + s / 1944
    end
    cd~append(d)
    if d < cbest then cbest = d
  end
  /* the near ones only: not more than 2.5 times the nearest (and 0.02), at most 60 */
  few = .array~new
  cut = 2.5 * cbest + 0.02
  i = 0
  do t over templates
    i = i + 1
    if cd[i] <= cut then few~append(t)
  end
  if few~items > 60 then do
    cut = 1.6 * cbest + 0.01
    keep = .array~new
    i = 0
    do t over templates
      i = i + 1
      if cd[i] <= cut then keep~append(t)
    end
    few = keep
  end
  bestT = .directory~new
  bestTF = .directory~new
  bestDF = .directory~new
  g = f["GRID"]
  do t over few
    ch = t["CH"]
    d = 3 * (t["W"] - f["W"]) ** 2 + 4 * (t["TOP"] - f["TOP"]) ** 2 + 4 * (t["BOT"] - f["BOT"]) ** 2
    kind = kindOf(ch)
    /* far enough from the best that no hint could want it: stop counting */
    limit = max(out["ANYD"] * 2, out["ANYD"] + 0.03, out[kind"D"])
    if kind = "LOWER" | kind = "UPPER" then limit = max(limit, out["LETTERD"])
    have = all[ch]
    if have \== .nil then limit = max(limit, have)
    if d >= limit then iterate
    tg = t["GRID"]
    s = 0
    full = .true
    do i = 1 to 96
      s = s + (substr(tg, i, 1) - substr(g, i, 1)) ** 2
      if i // 16 = 0 then if d + s / 7776 >= limit then do
        full = .false
        leave
      end
    end
    if \full then iterate
    d = d + s / 7776
    key = ch || "/" || t["FONT"]
    if bestDF[key] == .nil then do
      bestTF[key] = t
      bestDF[key] = d
    end
    else if d < bestDF[key] then do
      bestTF[key] = t
      bestDF[key] = d
    end
    if have == .nil then do
      all[ch] = d
      bestT[ch] = t
    end
    else if d < have then do
      all[ch] = d
      bestT[ch] = t
    end
    if d < out["ANYD"] then do
      out["ANY"] = ch
      out["ANYD"] = d
    end
    if d < out[kind"D"] then do
      out[kind] = ch
      out[kind"D"] = d
    end
    if kind = "LOWER" | kind = "UPPER" then if d < out["LETTERD"] then do
      out["LETTER"] = ch
      out["LETTERD"] = d
    end
  end
  if value("GLYPH_DF", , "ENVIRONMENT") \== "0" then self~differ(f, out, bestT, bestTF)
  return out

/* the difference finder (as V5V: a coarse look over all, then a fine look at one small place).
   When the two nearest chars are close, find the cells where those two differ, and look only
   there, at twice the fine-ness. The cells they share say nothing about which one it is. */
::method differ
  use arg f, out, bestT, bestTF
  all = out["ALL"]
  a = out["ANY"]
  if a == "?" then return
  da = all[a]
  b = ""
  db = 1e9
  do ch over all
    if ch == a then iterate
    if all[ch] < db then do
      db = all[ch]
      b = ch
    end
  end
  if b == "" then return
  if db > max(1.35 * da, da + 0.02) then return
  g = f["GRID2"]
  if g == .nil then return
  /* in the font A was nearest in, and in the font B was nearest in: both must say B */
  votes = 0
  looks = 0
  do font over .array~of(bestT[a]["FONT"], bestT[b]["FONT"])
    ta = bestTF[a || "/" || font]
    tb = bestTF[b || "/" || font]
    if ta == .nil | tb == .nil then iterate
    ga = ta["GRID2"]
    gb = tb["GRID2"]
    if ga == .nil | gb == .nil then iterate
    sa = 0
    sb = 0
    cells = 0
    do i = 1 to 384
      va = substr(ga, i, 1)
      vb = substr(gb, i, 1)
      if abs(va - vb) < 3 then iterate
      cells = cells + 1
      v = substr(g, i, 1)
      sa = sa + (v - va) ** 2
      sb = sb + (v - vb) ** 2
    end
    if cells < 3 then iterate
    looks = looks + 1
    if sb < sa then votes = votes + 1
  end
  if looks = 0 then return
  if votes < looks then return
  out["ANY"] = b
  out["ANYD"] = db
  out["SWAP"] = a "->" b
  k = kindOf(b)
  if db <= out[k"D"] then do
    out[k] = b
    out[k"D"] = db
  end

/* read a region: the words in it, with a space where a gap is wide */
::method read
  use arg data, W, x0, y0, x1, y1
  words = self~readWords(data, W, x0, y0, x1, y1)
  text = ""
  do word over words
    if text \== "" then text = text || " "
    text = text || self~wordText(word)
  end
  return text

/* one word, as the hint call wants it: each glyph is a list of char:how far, the near ones only */
::method lattice
  use arg word
  out = ""
  do m over word
    all = m["ALL"]
    best = m["ANYD"]
    list = .array~new
    do ch over all
      if all[ch] <= max(2 * best, best + 0.03) then list~append(format(all[ch], , 5) c2x(ch))
    end
    list = list~sortWith(.ByLeft~new)
    g = ""
    do k = 1 to min(10, list~items)
      parse value list[k] with dd hx
      if g \== "" then g = g || ","
      g = g || hx || ":" || dd
    end
    if out \== "" then out = out || "|"
    out = out || g
  end
  return out

/* the words of a region: each word an array of glyphs, each glyph what it is like */
::method readWords
  use arg data, W, x0, y0, x1, y1, bpp = 3
  r = self~glyphsIn(data, W, x0, y0, x1, y1, bpp)
  glyphs = r["GLYPHS"]
  if glyphs~items = 0 then return .array~new
  parse value self~lineOf(glyphs) with base cap
  cov = r["COV"]
  rw = r["RW"]
  /* each glyph: what it is like; a wide glyph that is not like one letter may be two that touch */
  seen = .array~new
  do e over glyphs
    m = self~nearest(self~features(cov, rw, e, base, cap))
    parse var e a0 b0 a1 b1
    if a1 - a0 + 1 >= 0.6 * cap then if m["ANYD"] > 0.06 then do
      two = self~split(cov, rw, e, base, cap, m["ANYD"])
      if two \== .nil then do
        seen~append(two[1])
        seen~append(two[2])
        iterate
      end
    end
    m["BOX"] = e
    seen~append(m)
  end
  /* a space: a gap wider than the usual gap, by a part of a capital */
  gaps = .array~new
  do i = 2 to seen~items
    parse value seen[i - 1]["BOX"] with . . pa1 .
    parse value seen[i]["BOX"] with qa0 .
    gaps~append(qa0 - pa1 - 1)
  end
  usual = 0
  if gaps~items > 0 then do
    sorted = gaps~copy~sortWith(.NumericComparator~new)
    usual = sorted[(sorted~items + 1) % 2]
  end
  words = .array~new
  word = .array~new
  do i = 1 to seen~items
    if i > 1 then if gaps[i - 1] > usual + 0.25 * cap then do
      words~append(word)
      word = .array~new
    end
    word~append(seen[i])
  end
  words~append(word)
  return words

/* the letters of one word: a word of letters has no digits in it, a word of small letters has no capital after the first */
::method wordText
  use arg word
  letters = 0
  digits = 0
  lowers = 0
  do m over word
    k = kindOf(m["ANY"])
    if k = "DIGIT" then digits = digits + 1
    if k = "LOWER" then do
      letters = letters + 1
      lowers = lowers + 1
    end
    if k = "UPPER" then letters = letters + 1
  end
  out = ""
  do i = 1 to word~items
    m = word[i]
    ch = m["ANY"]
    d = m["ANYD"]
    k = kindOf(ch)
    if k = "DIGIT" then if letters > digits then if m["LETTERD"] < 2.2 * d then do
      ch = m["LETTER"]
      d = m["LETTERD"]
      k = kindOf(ch)
    end
    if k = "LOWER" | k = "UPPER" then if digits > letters then if m["DIGITD"] < 2.2 * d then do
      ch = m["DIGIT"]
      d = m["DIGITD"]
      k = "DIGIT"
    end
    if k = "UPPER" then if i > 1 then if lowers >= 2 then if m["LOWERD"] < 2.2 * d then do
      ch = m["LOWER"]
      d = m["LOWERD"]
    end
    if d > 0.35 then ch = "?"
    out = out || ch
  end
  return out

/* two glyphs that touch: cut at the column with the least ink, in the middle part */
::method split
  use arg cov, rw, e, base, cap, dOne
  parse var e a0 b0 a1 b1
  gw = a1 - a0 + 1
  best = 0
  bestInk = 1e9
  do x = a0 + trunc(gw * 0.25) to a0 + trunc(gw * 0.75)
    ink = 0
    do y = b0 to b1
      v = cov[y * rw + x + 1]
      if v \== .nil then ink = ink + v
    end
    if ink < bestInk then do
      bestInk = ink
      best = x
    end
  end
  if best = 0 then return .nil
  left = self~shrink(cov, rw, a0, b0, best - 1, b1)
  right = self~shrink(cov, rw, best + 1, b0, a1, b1)
  if left == "" | right == "" then return .nil
  m1 = self~nearest(self~features(cov, rw, left, base, cap))
  m2 = self~nearest(self~features(cov, rw, right, base, cap))
  if max(m1["ANYD"], m2["ANYD"]) >= dOne then return .nil
  if (m1["ANYD"] + m2["ANYD"]) / 2 >= 0.75 * dOne then return .nil
  m1["BOX"] = left
  m2["BOX"] = right
  return .array~of(m1, m2)

/* the box round the ink in a box */
::method shrink
  use arg cov, rw, x0, y0, x1, y1
  u0 = 1e9
  v0 = 1e9
  u1 = -1
  v1 = -1
  do y = y0 to y1
    do x = x0 to x1
      v = cov[y * rw + x + 1]
      if v == .nil then iterate
      if v < 0.3 then iterate
      u0 = min(u0, x)
      v0 = min(v0, y)
      u1 = max(u1, x)
      v1 = max(v1, y)
    end
  end
  if u1 < 0 then return ""
  return u0 v0 u1 v1


::class ByLeft
::method compare
  use arg a, b
  parse var a xa .
  parse var b xb .
  if xa < xb then return -1
  if xa > xb then return 1
  return 0

::routine ce
  use arg v
  t = trunc(v)
  if v > 0 then if t \= v then t = t + 1
  return t

::routine fmt3
  use arg v
  return format(v, , 3)

::requires "rxmath" LIBRARY

::routine kindOf
  use arg ch
  if verify(ch, "0123456789") = 0 then return "DIGIT"
  if verify(ch, "abcdefghijklmnopqrstuvwxyz") = 0 then return "LOWER"
  if verify(ch, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") = 0 then return "UPPER"
  return "MARK"

/* the red, green and blue of a place: one byte is grey (all three the same) */
::routine rgbOf public
  use arg k
  if length(k) = 1 then do
    v = c2d(k)
    return v v v
  end
  return c2d(substr(k, 1, 1)) c2d(substr(k, 2, 1)) c2d(substr(k, 3, 1))

/* the 4 x 6 grid from the 8 x 12 grid: each cell the mean of four */
::routine coarseOf
  use arg grid
  out = ""
  do j = 0 to 5
    do i = 0 to 3
      a = substr(grid, (2 * j) * 8 + 2 * i + 1, 1)
      b = substr(grid, (2 * j) * 8 + 2 * i + 2, 1)
      c = substr(grid, (2 * j + 1) * 8 + 2 * i + 1, 1)
      d = substr(grid, (2 * j + 1) * 8 + 2 * i + 2, 1)
      out = out || trunc((a + b + c + d) / 4 + 0.5)
    end
  end
  return out
