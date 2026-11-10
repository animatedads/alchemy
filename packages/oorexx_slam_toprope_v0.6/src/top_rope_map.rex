#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* top_rope_map.rex -- Top Rope Slam reads map pictures: the water     */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/*   - make the shapes in each picture first, then fit the pictures   */
/*     together (they may not have the same zoom), then merge         */
/*   - V5V dual mode: compare at low resolution, ask for detail only  */
/*     where the low pass says to look                                */
/*   - the answer is SLAM words with places on the earth, not a       */
/*     picture                                                        */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use: rexx top_rope_map.rex <picture> <picture> <words out> [width] */
/*                                                                    */
/* Steps                                                              */
/*   1 each picture: find the map (not the phone's bars), call each   */
/*     place water, land, or not known (writing, pins, buttons). Not  */
/*     known places take the kind of the nearest known place.         */
/*   2 each picture: the water as shapes (outlines), islands as holes */
/*   3 fit: which picture is the closer one, by how much, and where   */
/*     it sits in the other. Coarse (one cell = 16 places), then 4,   */
/*     then 1, each time only near the best of the step before.       */
/*   4 merge the shapes of the two pictures into one; the closer      */
/*     picture wins where it saw the place, the other where it did    */
/*     not (under its pins and buttons)                               */
/*   5 put it on the earth: two islands with known places fix where   */
/*     and how big (Goat Island, Fort Denison); a third (Bradleys     */
/*     Head Light) checks it                                          */
/*   6 write SLAM words: places as latitude and longitude, and a copy */
/*     in kilometres that SLAM Draw can draw                          */
/* ------------------------------------------------------------------ */
  parse arg picA picB outWords wide .
  if outWords = "" then do
    say "Use: rexx top_rope_map.rex <picture> <picture> <words out> [width]"
    exit 1
  end
  if wide = "" then wide = 540
  signal on syntax name seeError
  call time "R"

  pieces = .array~new
  do f over .array~of(picA, picB)
    if \SysFileExists(f) then call fail "I can not find the picture" f"."
    pc = readPiece(f, wide)
    call phase "read" filespec("name", f)
    call shapesOf pc, 1.0
    if pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then call debugMap pc, "/tmp/harbour_"filespec("name", f)".pgm"
    call phase "shapes" filespec("name", f)
    say "  " filespec("name", f)": map" pc~W "by" pc~H "(rows" pc~y0 "to" pc~y1"),",
        pc~shapes~items "water shapes," pc~islands~items "islands"
    pieces~append(pc)
  end
  fit = fitPieces(pieces[1], pieces[2])
  call phase "fit"
  mg = mergePieces(fit)
  call phase "merge"
  geo = placeOnEarth(mg)
  call phase "earth"
  call writeWords outWords, mg, geo, fit, pieces
  call phase "words"
  exit 0

fail:
  raise syntax 98.900 array (arg(1))

phase:
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "  time:" left(arg(1), 24) format(time("E"), , 1) "s"
  return

seeError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "Top Rope Slam stopped." co["ADDITIONAL"][1]
  else say "Top Rope Slam broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  exit 2

::requires "rxmath" LIBRARY
::requires "master.cls"

/* ================================================================== */
/* 1  one picture: map area, and water / land / not known             */
/* ================================================================== */
::routine readPiece
  use arg file, wide
  m = .Master~new(file)
  /* no shrink first: a shrunk letter is grey, and grey is land. Each */
  /* place of the working map is f by f places of the picture: one    */
  /* letter in it makes it not known, else most of it decides         */
  f = max(1, m~W % wide)
  FW = m~W
  FH = m~H
  WW = FW % f
  rgb = m~rgb
  /* each byte: 1 if 250 or more, else 0; a place is white when its  */
  /* three bytes are all 1                                            */
  hiTab = copies("00"x, 250) || copies("01"x, 6)
  whiteRow = .array~new(FH)
  do y = 0 to FH - 1
    row = translate(substr(rgb, y * FW * 3 + 1, FW * 3), hiTab, xrange("00"x, "ff"x))
    whiteRow[y + 1] = countstr("010101"x, row) / FW
  end
  top = 0
  do y = 0 to FH % 4
    if whiteRow[y + 1] >= 0.45 then top = y + 14
  end
  bottom = FH - 1
  do y = FH * 6 % 10 to FH - 1
    if whiteRow[y + 1] >= 0.80 then do
      bottom = y - 8
      leave
    end
  end
  top = (top + f - 1) % f
  bottom = (bottom + 1) % f - 1
  MH = bottom - top + 1
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "    at" format(time("E"), , 1) "s"

  cls = .array~new(WW * MH)
  memo = .directory~new
  need = (f * f + 1) % 2
  i = 0
  do y = top to bottom
    rows = .array~new(f)
    do r = 1 to f
      rows[r] = substr(rgb, ((y * f + r - 1) * FW) * 3 + 1, FW * 3)
    end
    do x = 0 to WW - 1
      nw = 0
      ink = 0
      do r = 1 to f
        do q = 0 to f - 1
          k = substr(rows[r], (x * f + q) * 3 + 1, 3)
          c = memo[k]
          if c == .nil then do
            c = kindOf(c2d(substr(k, 1, 1)), c2d(substr(k, 2, 1)), c2d(substr(k, 3, 1)))
            memo[k] = c
          end
          if c == "w" then nw = nw + 1
          else if c == "?" then ink = 1
        end
      end
      i = i + 1
      if ink then cls[i] = "?"
      else if nw >= need then cls[i] = "w"
      else cls[i] = "l"
    end
  end
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "    at" format(time("E"), , 1) "s"

  /* a card on the side of the screen (a photo): a long straight     */
  /* up-and-down line near the side, with the picture beyond it. The  */
  /* map under it was not seen                                        */
  card = cardOf(rgb, FW, top * f, (bottom + 1) * f - 1)
  if card \== "" then do
    parse var card cx cy0 cy1
    cx = cx % f
    cy0 = cy0 % f - top
    cy1 = cy1 % f - top
    do y = max(0, cy0 - 1) to min(MH - 1, cy1 + 1)
      do x = cx - 1 to WW - 1
        cls[y * WW + x + 1] = "."
      end
    end
  end
  /* blue inside a pin or a photo (Tom: "an overlaid Google box is    */
  /* blue"): real water meets land at its edge; the blue of a pin     */
  /* meets the pin's white ring. Blue whose edge is mostly not known  */
  /* is not known                                                     */
  lab = labels(cls, WW, MH, .nil)
  comp = lab[1]
  info = lab[2]
  nq = .array~new(info~items)
  nl = .array~new(info~items)
  do id = 1 to info~items
    nq[id] = 0
    nl[id] = 0
  end
  do i = 1 to WW * MH
    if cls[i] \== "w" then iterate
    id = comp[i]
    x = (i - 1) // WW
    nbs = .array~new
    if x > 0 then nbs~append(i - 1)
    if x < WW - 1 then nbs~append(i + 1)
    if i > WW then nbs~append(i - WW)
    if i + WW <= WW * MH then nbs~append(i + WW)
    do q over nbs
      if cls[q] == "?" then nq[id] = nq[id] + 1
      else if cls[q] == "l" then nl[id] = nl[id] + 1
    end
  end
  pinBlue = .directory~new
  do id = 1 to info~items
    if word(info[id], 1) \== "w" then iterate
    if word(info[id], 2) > 800 then iterate
    if nq[id] + nl[id] = 0 then iterate
    if nq[id] / (nq[id] + nl[id]) >= 0.75 then pinBlue[id] = 1
  end
  if pinBlue~items > 0 then do i = 1 to WW * MH
    if cls[i] == "w" then if pinBlue[comp[i]] == 1 then cls[i] = "?"
  end
  if pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "    blue in pins:" pinBlue~items "bits"
  /* writing has a pale edge: grow the not known places by 2 */
  mark = .array~new(WW * MH)
  do i = 1 to WW * MH
    if cls[i] \== "?" then iterate
    x = (i - 1) // WW
    y = (i - 1) % WW
    do yy = max(0, y - 2) to min(MH - 1, y + 2)
      do xx = max(0, x - 2) to min(WW - 1, x + 2)
        if cls[yy * WW + xx + 1] \== "." then mark[yy * WW + xx + 1] = 1
      end
    end
  end
  guess = .array~new(WW * MH)
  known = 0
  do i = 1 to WW * MH
    if cls[i] == "." then guess[i] = -1
    else if mark[i] == 1 then do
      cls[i] = "?"
      guess[i] = 1
    end
    else do
      guess[i] = 0
      known = known + 1
    end
  end

  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "    at" format(time("E"), , 1) "s"
  /* not known places take the kind of the nearest known place */
  qu = .array~new
  do i = 1 to WW * MH
    if cls[i] == "?" | cls[i] == "." then iterate
    x = (i - 1) // WW
    if x > 0 then if cls[i - 1] == "?" then do; qu~append(i); iterate; end
    if x < WW - 1 then if cls[i + 1] == "?" then do; qu~append(i); iterate; end
    if i > WW then if cls[i - WW] == "?" then do; qu~append(i); iterate; end
    if i + WW <= WW * MH then if cls[i + WW] == "?" then qu~append(i)
  end
  hd = 1
  do while hd <= qu~items
    p = qu[hd]
    hd = hd + 1
    c = cls[p]
    x = (p - 1) // WW
    /* guess: how far (in places) from anything seen; 0 = seen        */
    gd = guess[p] + 1
    if guess[p] = 0 then gd = 1
    if x > 0 then if cls[p - 1] == "?" then do; cls[p - 1] = c; guess[p - 1] = gd; qu~append(p - 1); end
    if x < WW - 1 then if cls[p + 1] == "?" then do; cls[p + 1] = c; guess[p + 1] = gd; qu~append(p + 1); end
    if p > WW then if cls[p - WW] == "?" then do; cls[p - WW] = c; guess[p - WW] = gd; qu~append(p - WW); end
    if p + WW <= WW * MH then if cls[p + WW] == "?" then do; cls[p + WW] = c; guess[p + WW] = gd; qu~append(p + WW); end
  end
  do i = 1 to WW * MH
    if cls[i] == "?" then cls[i] = "l"
  end

  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "    at" format(time("E"), , 1) "s"
  pc = .directory~new
  pc~file = file
  pc~name = filespec("name", file)
  pc~W = WW
  pc~H = MH
  pc~y0 = top
  pc~y1 = bottom
  pc~cls = cls
  pc~guess = guess
  pc~known = known / (WW * MH)
  return pc

/* a card at the right side: the column (in the last fifth) where     */
/* the most rows in a row change sharply; 80 rows or more. Gives      */
/* "x y0 y1" in picture places, or ""                                 */
::routine cardOf
  use arg rgb, FW, ya, yb
  x0 = FW * 4 % 5
  run = .array~new(FW)
  best = .array~new(FW)
  bestEnd = .array~new(FW)
  do x = x0 to FW - 1
    run[x + 1] = 0
    best[x + 1] = 0
    bestEnd[x + 1] = 0
  end
  do y = ya to yb
    row = substr(rgb, y * FW * 3 + 1, FW * 3)
    prev = c2d(substr(row, x0 * 3 - 2, 1)) + c2d(substr(row, x0 * 3 - 1, 1)) + c2d(substr(row, x0 * 3, 1))
    do x = x0 to FW - 1
      p = x * 3 + 1
      v = c2d(substr(row, p, 1)) + c2d(substr(row, p + 1, 1)) + c2d(substr(row, p + 2, 1))
      if abs(v - prev) > 90 then do
        run[x + 1] = run[x + 1] + 1
        if run[x + 1] > best[x + 1] then do
          best[x + 1] = run[x + 1]
          bestEnd[x + 1] = y
        end
      end
      else run[x + 1] = 0
      prev = v
    end
  end
  bx = 0
  bn = 0
  do x = x0 to FW - 1
    /* the line may wobble by one place: take the best of two columns */
    n = max(best[x + 1], best[min(FW, x + 2)])
    if best[x + 1] > bn then do
      bn = best[x + 1]
      bx = x
    end
  end
  if bn < 80 then return ""
  return bx (bestEnd[bx + 1] - bn + 1) bestEnd[bx + 1]

/* water: the blue of the sea and of the ferry lines on it            */
/* not known: dark, strong colour (writing, pins), pure white, or     */
/* blue-grey (roads, bridges)                                         */
/* (buttons, roads: white over water would make a false island)       */
::routine kindOf
  use arg r, g, b
  if r >= 80 & g >= 170 & g - r >= 40 & b - r >= 50 then return "w"
  mx = max(r, g, b)
  mn = min(r, g, b)
  if mn >= 252 then return "?"
  /* blue-grey: a road, and on the water a bridge -- not known, so it */
  /* takes the kind of what is under it                               */
  if b - r >= 35 & b - g >= 15 then return "?"
  /* pale and a little blue, not green: the soft white edge round the */
  /* writing on the water, and the map's round buttons -- not known.  */
  /* (islands here are pale green: green above blue, so they stay)    */
  if mn >= 170 & b - r >= 12 & b >= g - 5 then return "?"
  if mx < 120 then return "?"
  if mx - mn > 70 then return "?"
  return "l"

/* ================================================================== */
/* 2  shapes: the water as outlines, the islands as holes             */
/* ================================================================== */
::routine shapesOf
  use arg pc, tol, minWater = 40, minLand = 3, edgeOk = .nil
  WW = pc~W
  HH = pc~H
  cls = pc~cls
  /* small bits are noise: a speck of land in water is water, a drop  */
  /* of blue on land is land                                          */
  lab = labels(cls, WW, HH, edgeOk)
  comp = lab[1]
  info = lab[2]
  flipTo = .directory~new
  do id = 1 to info~items
    parse value info[id] with kind size edge first
    if kind == "w" then if size < minWater then flipTo[id] = "l"
    if kind == "l" then if size < minLand then if edge = 0 then flipTo[id] = "w"
  end
  if flipTo~items > 0 then do
    do i = 1 to WW * HH
      t = flipTo[comp[i]]
      if t \== .nil then cls[i] = t
    end
    lab = labels(cls, WW, HH, edgeOk)
    comp = lab[1]
    info = lab[2]
  end
  shapes = .array~new
  islands = .array~new
  do id = 1 to info~items
    parse value info[id] with kind size edge first
    if kind == "." then iterate
    if kind == "l" then if edge = 1 then iterate
    pts = outline(comp, WW, HH, id, first)
    if pts~items < 3 then iterate
    few = simplify(pts, tol)
    if few~items >= 3 then pts = few
    if kind == "w" then shapes~append(pts)
    else islands~append(grow(pts, 0.5))
  end
  pc~comp = comp
  pc~info = info
  pc~shapes = shapes
  pc~islands = islands
  return

/* parts of one kind that touch (4 ways); each: kind size edge first  */
/* edge = 1 when the part touches the side of the map, or a place no  */
/* picture saw (".")                                                  */
::routine labels
  use arg cls, WW, HH, edgeOk
  N = WW * HH
  comp = .array~new(N)
  info = .array~new
  do i = 1 to N
    if comp[i] \== .nil then iterate
    c = cls[i]
    id = info~items + 1
    comp[i] = id
    st = .array~of(i)
    size = 0
    edge = 0
    do while st~items > 0
      p = st[st~items]
      st~remove(st~items)
      size = size + 1
      x = (p - 1) // WW
      if x = 0 | x = WW - 1 | p <= WW | p > N - WW then edge = 1
      if x > 0 then do
        q = p - 1
        if cls[q] == "." then edge = 1; else if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if x < WW - 1 then do
        q = p + 1
        if cls[q] == "." then edge = 1; else if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if p > WW then do
        q = p - WW
        if cls[q] == "." then edge = 1; else if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if p + WW <= N then do
        q = p + WW
        if cls[q] == "." then edge = 1; else if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
    end
    info~append(c size edge i)
  end
  return .array~of(comp, info)

/* the outline of one part (Moore, 8 ways), places "x y" from 0       */
::routine outline
  use arg comp, WW, HH, id, start
  dx = .array~of(-1, -1, 0, 1, 1, 1, 0, -1)
  dy = .array~of(0, -1, -1, -1, 0, 1, 1, 1)
  sx = (start - 1) // WW
  sy = (start - 1) % WW
  pts = .array~new
  pts~append(sx sy)
  cx = sx
  cy = sy
  back = 1
  firstDir = 0
  limit = 8 * (WW + HH) * 8
  do steps = 1 to limit
    found = 0
    do k = 1 to 8
      d = (back - 1 + k) // 8 + 1
      nx = cx + dx[d]
      ny = cy + dy[d]
      if nx < 0 | ny < 0 | nx >= WW | ny >= HH then iterate
      if comp[ny * WW + nx + 1] = id then do
        found = d
        leave
      end
    end
    if found = 0 then leave
    if steps = 1 then firstDir = found
    else if cx = sx then if cy = sy then if found = firstDir then leave
    prev = (found + 6) // 8 + 1
    bx = cx + dx[prev]
    by = cy + dy[prev]
    cx = cx + dx[found]
    cy = cy + dy[found]
    do j = 1 to 8
      if cx + dx[j] = bx then if cy + dy[j] = by then do
        back = j
        leave
      end
    end
    if cx \= sx | cy \= sy then pts~append(cx cy)
  end
  return pts

/* the outline goes through the middle of the edge places: an island */
/* is half a place bigger than that (this keeps a rock of 3 places)   */
::routine grow
  use arg pts, by
  sx = 0
  sy = 0
  do p over pts
    parse var p x y
    sx = sx + x
    sy = sy + y
  end
  cx = sx / pts~items
  cy = sy / pts~items
  out = .array~new
  do p over pts
    parse var p x y
    d = RxCalcSqrt((x - cx) ** 2 + (y - cy) ** 2, 9)
    if d = 0 then out~append(x y)
    else out~append(format(x + (x - cx) * by / d, , 2) format(y + (y - cy) * by / d, , 2))
  end
  return out

/* fewer places, the same outline (Douglas-Peucker on a closed line)  */
::routine simplify
  use arg pts, tol
  n = pts~items
  if n < 4 then return pts
  parse value pts[1] with x0 y0
  far = 1
  best = -1
  do i = 2 to n
    parse value pts[i] with x y
    d = (x - x0) ** 2 + (y - y0) ** 2
    if d > best then do
      best = d
      far = i
    end
  end
  keep = .array~new(n + 1)
  do i = 1 to n + 1
    keep[i] = .false
  end
  keep[1] = .true
  keep[far] = .true
  all = pts~copy
  all~append(pts[1])
  todo = .array~of(1 far, far (n + 1))
  do while todo~items > 0
    parse value todo[todo~items] with i j
    todo~remove(todo~items)
    if j - i < 2 then iterate
    parse value all[i] with xa ya
    parse value all[j] with xb yb
    L = RxCalcSqrt((xb - xa) ** 2 + (yb - ya) ** 2, 9)
    best = -1
    at = 0
    do k = i + 1 to j - 1
      parse value all[k] with x y
      if L = 0 then d = RxCalcSqrt((x - xa) ** 2 + (y - ya) ** 2, 9)
      else d = abs((xb - xa) * (ya - y) - (xa - x) * (yb - ya)) / L
      if d > best then do
        best = d
        at = k
      end
    end
    if best > tol then do
      keep[at] = .true
      todo~append(i at)
      todo~append(at j)
    end
  end
  out = .array~new
  do i = 1 to n
    if keep[i] then out~append(pts[i])
  end
  return out

/* ================================================================== */
/* 3  fit the two pictures: V5V dual mode                             */
/*    low: cells of 16 places, every zoom and place                   */
/*    then cells of 4, then 1, only near the best of the step before  */
/* ================================================================== */
::routine fitPieces
  use arg pa, pb
  dbg = pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0
  lv = .directory~new
  do f over .array~of(16, 4, 1)
    lv["A"f] = levelOf(pa, f)
    lv["B"f] = levelOf(pb, f)
  end
  /* low pass: both ways round (which picture is the closer one?)     */
  cands = .array~new
  do ord over .array~of("A B", "B A")
    parse var ord bk dk
    Bm = lv[bk"16"]
    Dm = lv[dk"16"]
    do k = 1.0 to 3.0 by 0.1
      S = resample(Dm, k)
      top = search(Bm, S, 1 - S[1]~length, length(Bm[1]) - 1, 1 - S~items, Bm~items - 1, 0.30)
      do t over top
        cands~append(t k bk dk)
      end
    end
  end
  cands = cands~sortWith(.ByScore~new)
  if dbg then do i = 1 to min(6, cands~items)
    say "    fit low:" cands[i]
  end
  /* cells of 4, near the 4 best                                      */
  mids = .array~new
  do i = 1 to min(4, cands~items)
    parse value cands[i] with sc tx ty k bk dk
    Bm = lv[bk"4"]
    Dm = lv[dk"4"]
    do kk = k - 0.08 to k + 0.08 by 0.02
      S = resample(Dm, kk)
      top = search(Bm, S, tx * 4 - 6, tx * 4 + 6, ty * 4 - 6, ty * 4 + 6, 0.25)
      do t over top
        mids~append(t kk bk dk)
      end
    end
  end
  mids = mids~sortWith(.ByScore~new)
  if dbg then do i = 1 to min(4, mids~items)
    say "    fit mid:" mids[i]
  end
  /* cells of 1 (the working picture), near the best                  */
  parse value mids[1] with sc tx ty k bk dk
  Bm = lv[bk"1"]
  Dm = lv[dk"1"]
  fine = .array~new
  do kk = k - 0.02 to k + 0.02 by 0.005
    S = resample(Dm, kk)
    top = search(Bm, S, tx * 4 - 5, tx * 4 + 5, ty * 4 - 5, ty * 4 + 5, 0.25)
    do t over top
      fine~append(t kk bk dk)
    end
  end
  fine = fine~sortWith(.ByScore~new)
  parse value fine[1] with sc tx ty k bk dk
  fit = .directory~new
  if bk == "A" then do
    fit~base = pa
    fit~det = pb
  end
  else do
    fit~base = pb
    fit~det = pa
  end
  fit~k = k
  fit~tx = tx
  fit~ty = ty
  fit~score = sc
  say "   fit:" fit~det~name "is" format(k, , 3) "times closer than" fit~base~name";",
      "its top left is at" tx ty "in" fit~base~name "(agree" format(sc * 100, , 1)"%)"
  return fit

/* the map in cells of f: each row a string, "01"x land, "02"x water  */
::routine levelOf
  use arg pc, f
  WW = pc~W
  cls = pc~cls
  cw = pc~W % f
  ch = pc~H % f
  rows = .array~new
  half = f * f / 2
  do cy = 0 to ch - 1
    row = ""
    do cx = 0 to cw - 1
      n = 0
      do yy = cy * f to cy * f + f - 1
        b = yy * WW + cx * f
        do xx = 1 to f
          if cls[b + xx] == "w" then n = n + 1
        end
      end
      if n >= half then row = row || "02"x
      else row = row || "01"x
    end
    rows~append(row)
  end
  return rows

/* the closer picture seen k times smaller                            */
::routine resample
  use arg D, k
  dh = D~items
  dw = length(D[1])
  sh = trunc(dh / k)
  sw = trunc(dw / k)
  xs = .array~new(sw)
  do i = 1 to sw
    xs[i] = min(dw, trunc((i - 0.5) * k) + 1)
  end
  rows = .array~new
  do j = 1 to sh
    src = D[min(dh, trunc((j - 0.5) * k) + 1)]
    row = ""
    do i = 1 to sw
      row = row || substr(src, xs[i], 1)
    end
    rows~append(row)
  end
  return rows

/* slide S over B; agree = places of the same kind / places that both */
/* see. Gives the 2 best as "agree tx ty"                             */
::routine search
  use arg Bm, S, tx0, tx1, ty0, ty1, minFrac
  hb = Bm~items
  wb = length(Bm[1])
  hs = S~items
  ws = length(S[1])
  need = minFrac * ws * hs
  b1 = -1
  b2 = -1
  r1 = ""
  r2 = ""
  do ty = ty0 to ty1
    jl = max(1, 1 - ty)
    jh = min(hs, hb - ty)
    if jh < jl then iterate
    oh = jh - jl + 1
    do tx = tx0 to tx1
      il = max(1, 1 - tx)
      ih = min(ws, wb - tx)
      if ih < il then iterate
      ow = ih - il + 1
      area = ow * oh
      if area < need then iterate
      /* kappa: how much better than chance, for this much water      */
      m = 0
      ws1 = 0
      wb1 = 0
      do j = jl to jh
        sa = substr(S[j], il, ow)
        sb = substr(Bm[j + ty], il + tx, ow)
        m = m + ow - countstr("00"x, bitand(sa, sb))
        ws1 = ws1 + countstr("02"x, sa)
        wb1 = wb1 + countstr("02"x, sb)
      end
      ps = ws1 / area
      pq = wb1 / area
      pe = ps * pq + (1 - ps) * (1 - pq)
      if pe >= 0.999 then iterate
      sc = (m / area - pe) / (1 - pe)
      if sc > b1 then do
        if r1 \== "" then if abs(word(r1, 2) - tx) + abs(word(r1, 3) - ty) > 2 then do
          b2 = b1
          r2 = r1
        end
        b1 = sc
        r1 = format(sc, , 5) tx ty
      end
      else if sc > b2 then if abs(word(r1, 2) - tx) + abs(word(r1, 3) - ty) > 2 then do
        b2 = sc
        r2 = format(sc, , 5) tx ty
      end
    end
  end
  out = .array~new
  if r1 \== "" then out~append(r1)
  if r2 \== "" then out~append(r2)
  return out

::class ByScore
::method compare
  use arg a, b
  if word(a, 1) > word(b, 1) then return -1
  if word(a, 1) < word(b, 1) then return 1
  return 0

/* ================================================================== */
/* 4  merge the shapes                                                */
/* ================================================================== */
::routine mergePieces
  use arg fit
  B = fit~base
  D = fit~det
  k = fit~k
  /* the closer picture's place (0,0) is at (tx,ty) in the base       */
  tx = fit~tx
  ty = fit~ty
  sc = min(k, 1.5)
  minX = min(0, tx)
  minY = min(0, ty)
  maxX = max(B~W, tx + D~W / k)
  maxY = max(B~H, ty + D~H / k)
  MW = trunc((maxX - minX) * sc + 0.999)
  MH = trunc((maxY - minY) * sc + 0.999)
  bEdges = edgesOf(B)
  dEdges = edgesOf(D)
  cls = .array~new(MW * MH)
  gss = .array~new(MW * MH)
  fromD = 0
  fromB = 0
  do Y = 0 to MH - 1
    yb = (Y + 0.5) / sc + minY
    yd = (yb - ty) * k
    rowB = .nil
    rowD = .nil
    if yb >= 0.5 & yb <= B~H - 0.5 then rowB = spansAt(bEdges, yb - 0.5)
    if yd >= 0.5 & yd <= D~H - 0.5 then rowD = spansAt(dEdges, yd - 0.5)
    do X = 0 to MW - 1
      xb = (X + 0.5) / sc + minX
      xd = (xb - tx) * k
      c = "."
      inD = rowD \== .nil & xd >= 0.5 & xd <= D~W - 0.5
      inB = rowB \== .nil & xb >= 0.5 & xb <= B~W - 0.5
      if inD then if D~guess[trunc(yd) * D~W + trunc(xd) + 1] = -1 then inD = .false
      if inB then if B~guess[trunc(yb) * B~W + trunc(xb) + 1] = -1 then inB = .false
      useD = inD
      if inD & inB then do
        /* the closer picture did not see this place (a pin, a button) */
        /* and the other one did: take the other one                  */
        gd = D~guess[trunc(yd) * D~W + trunc(xd) + 1]
        gb = B~guess[trunc(yb) * B~W + trunc(xb) + 1]
        if gd > 3 & gb <= 3 then useD = .false
        /* the edge of the closer picture: the other one is better    */
        if xd < 3 | yd < 3 | xd > D~W - 3 | yd > D~H - 3 then useD = .false
      end
      g = 0
      if useD then do
        c = inside(rowD, xd - 0.5)
        g = D~guess[trunc(yd) * D~W + trunc(xd) + 1]
        fromD = fromD + 1
      end
      else if inB then do
        c = inside(rowB, xb - 0.5)
        g = B~guess[trunc(yb) * B~W + trunc(xb) + 1]
        fromB = fromB + 1
      end
      cls[Y * MW + X + 1] = c
      gss[Y * MW + X + 1] = g
    end
  end
  mg = .directory~new
  mg~W = MW
  mg~H = MH
  mg~cls = cls
  mg~guess = gss
  mg~scale = sc
  mg~minX = minX
  mg~minY = minY
  mg~name = "merged"
  say "   merged:" MW "by" MH";" format(fromD * 100 / (MW * MH), , 1)"% from" D~name"," ,
      format(fromB * 100 / (MW * MH), , 1)"% from" B~name
  call shapesOf mg, 2.0, 60, 10
  if pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do
    call debugMap mg, "/tmp/harbour_merged.pgm"
    f = "/tmp/harbour_polys.txt"
    call SysFileDelete f
    call lineout f, sc minX minY tx ty k B~y0 D~y0
    do sh over mg~shapes
      call lineout f, "W" sh~makeString("L", ",")
    end
    do sh over mg~islands
      call lineout f, "I" sh~makeString("L", ",")
    end
    call lineout f
  end
  return mg

/* the sides of every outline of a picture (water and islands), kept  */
/* by row so a row finds them fast. Places are in the middle of each  */
/* square, so the outline is at x+0.5, y+0.5 -- we take 0.5 off the   */
/* row we ask for instead                                             */
::routine edgesOf
  use arg pc
  rows = .array~new
  all = .array~new
  do pts over pc~shapes
    all~append(pts)
  end
  do pts over pc~islands
    all~append(pts)
  end
  do pts over all
    n = pts~items
    do i = 1 to n
      parse value pts[i] with xa ya
      j = i // n + 1
      parse value pts[j] with xb yb
      if ya = yb then iterate
      lo = min(ya, yb)
      hi = max(ya, yb)
      do r = trunc(lo) to trunc(hi)
        if rows[r + 1] == .nil then rows[r + 1] = .array~new
        rows[r + 1]~append(xa ya xb yb)
      end
    end
  end
  return rows

/* where a row crosses the outlines: a sorted list of x               */
::routine spansAt
  use arg rows, y
  xs = .array~new
  lst = rows[trunc(y) + 1]
  if lst == .nil then return xs
  do e over lst
    parse var e xa ya xb yb
    if (ya <= y & y < yb) | (yb <= y & y < ya) then xs~append(xa + (y - ya) * (xb - xa) / (yb - ya))
  end
  return xs~sortWith(.ByNumber~new)

/* odd number of crossings to the left: inside water (islands are     */
/* outlines inside water outlines, so odd-even makes them land)       */
::routine inside
  use arg xs, x
  n = 0
  do v over xs
    if v < x then n = n + 1
    else leave
  end
  if n // 2 = 1 then return "w"
  return "l"

::class ByNumber
::method compare
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0

::routine debugMap
  use arg mg, file
  s = .stream~new(file)
  s~open("write replace")
  s~charout("P5" mg~W mg~H "255" || "0a"x)
  cls = mg~cls
  do y = 0 to mg~H - 1
    row = ""
    do x = 1 to mg~W
      c = cls[y * mg~W + x]
      if c == "w" then row = row || "a0"x
      else if c == "l" then row = row || "f0"x
      else row = row || "40"x
    end
    s~charout(row)
  end
  s~close
  return

/* ================================================================== */
/* 5  on the earth                                                    */
/* ================================================================== */
::routine placeOnEarth
  use arg mg
  /* known places (Wikipedia, NSW heritage register):                 */
  /*   Goat Island      33.8521 S 151.1966 E                          */
  /*   Fort Denison     33.8548 S 151.2256 E                          */
  /*   Bradleys Head Lt 33.8535 S 151.2467 E   (the check)            */
  gLat = -33.8521
  gLon = 151.1966
  fLat = -33.8548
  fLon = 151.2256
  cosL = RxCalcCos(33.853, 9, "D")
  /* on a map that keeps north up (Mercator), east and south          */
  wantX = fLon - gLon
  wantY = -(fLat - gLat) / cosL
  wantA = atan2(wantY, wantX)
  wantL = RxCalcSqrt(wantX ** 2 + wantY ** 2, 9)
  /* islands: middle and size                                         */
  WW = mg~W
  isl = .array~new
  want = .directory~new
  do id = 1 to mg~info~items
    parse value mg~info[id] with kind size edge first
    if kind == "l" & edge = 0 then want[id] = 0 0
  end
  comp = mg~comp
  do i = 1 to WW * mg~H
    v = want[comp[i]]
    if v == .nil then iterate
    parse var v sx sy
    want[comp[i]] = (sx + (i - 1) // WW) (sy + (i - 1) % WW)
  end
  do id over want
    parse value want[id] with sx sy
    size = word(mg~info[id], 2)
    isl~append(format(sx / size + 0.5, , 2) format(sy / size + 0.5, , 2) size)
  end
  say "   islands:" isl~items
  if pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do a over isl
    say "     island" a
  end
  /* Goat Island is 5.4 hectares: its size says how many metres one  */
  /* place is, and the way to Fort Denison must say the same. The two */
  /* must also lie the right way round (east, a little south)         */
  best = 999
  pick = ""
  biggest = 0
  do a over isl
    biggest = max(biggest, word(a, 3))
  end
  do a over isl
    parse var a ax ay an
    if an < biggest / 2 then iterate
    mArea = RxCalcSqrt(54000 / an, 9)
    do b over isl
      parse var b bx by bn
      if a == b then iterate
      if an <= bn then iterate
      err = abs(atan2(by - ay, bx - ax) - wantA) * 180 / RxCalcPi(9)
      if err > 10 then iterate
      mWay = wantL * 111320 * cosL / RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9)
      off = abs(RxCalcLog(mWay / mArea, 9))
      if off > 0.5 then iterate
      cost = err + 20 * off
      if cost < best then do
        best = cost
        pick = a "|" b
      end
    end
  end
  if pick == "" then raise syntax 98.900 array ("I can not find two islands to fix the map on the earth.")
  parse var pick ax ay an "|" bx by bn
  pxPerDeg = RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9) / wantL
  geo = .directory~new
  geo~ax = ax
  geo~ay = ay
  geo~bx = bx
  geo~by = by
  geo~lat0 = gLat
  geo~lon0 = gLon
  geo~cosL = cosL
  geo~ppd = pxPerDeg
  geo~turnErr = abs(atan2(by - ay, bx - ax) - wantA) * 180 / RxCalcPi(9)
  /* metres across one place of the merged map                        */
  geo~metres = 111320 * cosL / pxPerDeg
  say "   Goat Island at" ax ay "(" an "places), Fort Denison at" bx by "(" bn "places);",
      "the line between them is" format(geo~turnErr, , 1) "degrees off; one place is" format(geo~metres, , 1) "m"
  /* check: Bradleys Head Light should be on land, at the water       */
  hx = ax + (151.2467 - gLon) * pxPerDeg
  hy = ay - (-33.8535 - gLat) * pxPerDeg / cosL
  near = 999
  do yy = max(0, trunc(hy) - 15) to min(mg~H - 1, trunc(hy) + 15)
    do xx = max(0, trunc(hx) - 15) to min(WW - 1, trunc(hx) + 15)
      if mg~cls[yy * WW + xx + 1] == "w" then do
        d = RxCalcSqrt((xx - hx) ** 2 + (yy - hy) ** 2, 6)
        if d < near then near = d
      end
    end
  end
  geo~check = "Bradleys Head Light falls at" format(hx, , 1) format(hy, , 1)";",
              "nearest water" format(near * geo~metres, , 0) "m away"
  if hx < 0 | hy < 0 | hx >= WW | hy >= mg~H then geo~check = "Bradleys Head Light is outside the map: no check."
  say "  " geo~check
  return geo

::routine atan2
  use arg y, x
  if x = 0 then do
    if y >= 0 then return RxCalcPi(9) / 2
    return -RxCalcPi(9) / 2
  end
  a = RxCalcArcTan(y / x, 9, "R")
  if x < 0 then do
    if y >= 0 then a = a + RxCalcPi(9)
    else a = a - RxCalcPi(9)
  end
  return a

/* ================================================================== */
/* 6  SLAM words                                                      */
/* ================================================================== */
::routine writeWords
  use arg outFile, mg, geo, fit, pieces
  s = .stream~new(outFile)
  s~open("write replace")
  WW = mg~W
  HH = mg~H
  /* the corners of the map on the earth                              */
  parse value earth(geo, 0, 0) with nLat wLon
  parse value earth(geo, WW, HH) with sLat eLon
  kmX = (eLon - wLon) * 111.320 * geo~cosL
  kmY = (nLat - sLat) * 111.320
  call lineout outFile, "-- Sydney Harbour: where the water is, read by Top Rope Slam from two map pictures."
  call lineout outFile, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5). Reader: Top Rope Slam (SLAM family)."
  call lineout outFile, "-- Pictures:" fit~base~name "and" fit~det~name "(the closer one," format(fit~k, , 3) "times the zoom)."
  call lineout outFile, "-- Fitted at low resolution first, then in detail (V5V dual mode): they agree" format(fit~score * 100, , 1)"% where both see."
  call lineout outFile, "-- On the earth: fixed by the middles of Goat Island and Fort Denison. Rough: one place of the"
  call lineout outFile, "-- merged map is" format(geo~metres, , 1) "m; take the places as good to about" format(geo~metres * 3, , 0) "m."
  call lineout outFile, "--" geo~check
  call lineout outFile, "-- A side on the edge of the map is where the pictures stop, not the shore."
  call lineout outFile, ""
  call lineout outFile, "colour water is #8fdaed"
  call lineout outFile, "colour land is #f4f3f1"
  call lineout outFile, ""
  call lineout outFile, "map sydney harbour water"
  call lineout outFile, "  from" place(nLat, wLon) "to" place(sLat, eLon)
  n = 0
  pts = 0
  do sh over mg~shapes
    n = n + 1
    pts = pts + sh~items
    call lineout outFile, ""
    call lineout outFile, "  -- water" n":" sh~items "places"
    call geoLines outFile, "water", geo, sh, mg
  end
  m = 0
  do sh over mg~islands
    m = m + 1
    pts = pts + sh~items
    sx = 0
    sy = 0
    do p over sh
      sx = sx + word(p, 1)
      sy = sy + word(p, 2)
    end
    sx = sx / sh~items
    sy = sy / sh~items
    nm = "island" m
    if abs(sx - geo~ax) + abs(sy - geo~ay) < 12 then nm = "Goat Island (fixes the map)"
    else if abs(sx - geo~bx) + abs(sy - geo~by) < 12 then nm = "Fort Denison (fixes the map)"
    else if sh~items <= 6 then nm = nm "(a rock or a mark: small)"
    call lineout outFile, ""
    call lineout outFile, "  --" nm":" sh~items "places"
    call geoLines outFile, "land", geo, sh, mg
  end
  call lineout outFile, "end"
  call lineout outFile, ""
  /* the same, in kilometres east and south of the top left corner,   */
  /* so SLAM Draw can draw it as a check                              */
  call lineout outFile, "-- The same map in kilometres (east, south of the top left corner), for SLAM Draw."
  call lineout outFile, "make sydney harbour"
  call lineout outFile, "  size" format(kmX, , 3) "by" format(kmY, , 3)
  call lineout outFile, "  paint all land"
  do sh over mg~shapes
    call lineout outFile, "  shape water" kmList(geo, sh, nLat, wLon)
  end
  do sh over mg~islands
    call lineout outFile, "  shape land" kmList(geo, sh, nLat, wLon)
  end
  call lineout outFile, "end"
  call lineout outFile, ""
  call lineout outFile, "page 1200 wide"
  call lineout outFile, "draw sydney harbour"
  call lineout outFile
  say "   words:" n "water shapes," m "islands," pts "places, map" format(kmX, , 2) "km by" format(kmY, , 2) "km ->" outFile
  return

::routine earth
  use arg geo, x, y
  lon = geo~lon0 + (x - geo~ax) / geo~ppd
  lat = geo~lat0 - (y - geo~ay) * geo~cosL / geo~ppd
  return lat lon

::routine place
  use arg lat, lon
  return format(abs(lat), , 5) "south" format(lon, , 5) "east"

/* one place on each line; a place on the edge of what the pictures */
/* saw is marked, as that side is not shore                          */
::routine geoLines
  use arg outFile, colour, geo, sh, mg
  call lineout outFile, "  shape" colour
  first = 1
  do p over sh
    parse var p x y
    parse value earth(geo, x + 0.5, y + 0.5) with lat lon
    t = "    to"
    if first then t = "    from"
    first = 0
    if seenEdge(mg, x, y) then call lineout outFile, left(t place(lat, lon), 42) "-- edge of the pictures"
    else if guessed(mg, x, y) then call lineout outFile, left(t place(lat, lon), 42) "-- guessed: under writing or a pin"
    else call lineout outFile, t place(lat, lon)
  end
  return

/* the shore here was not seen: writing, a pin or a button was on it */
::routine guessed
  use arg mg, x, y
  x = trunc(x)
  y = trunc(y)
  n = 0
  do yy = max(0, y - 1) to min(mg~H - 1, y + 1)
    do xx = max(0, x - 1) to min(mg~W - 1, x + 1)
      if mg~guess[yy * mg~W + xx + 1] > 3 then n = n + 1
    end
  end
  return n >= 5

::routine seenEdge
  use arg mg, x, y
  x = trunc(x)
  y = trunc(y)
  do yy = y - 2 to y + 2
    do xx = x - 2 to x + 2
      if xx < 0 | yy < 0 | xx >= mg~W | yy >= mg~H then return 1
      if mg~cls[yy * mg~W + xx + 1] == "." then return 1
    end
  end
  return 0

::routine geoList
  use arg geo, sh
  out = ""
  do p over sh
    parse var p x y
    parse value earth(geo, x + 0.5, y + 0.5) with lat lon
    if out == "" then out = "from" place(lat, lon)
    else out = out "to" place(lat, lon)
  end
  return out

::routine kmList
  use arg geo, sh, nLat, wLon
  out = ""
  do p over sh
    parse var p x y
    parse value earth(geo, x + 0.5, y + 0.5) with lat lon
    e = (lon - wLon) * 111.320 * geo~cosL
    so = (nLat - lat) * 111.320
    if out == "" then out = "from" format(e, , 3) format(so, , 3)
    else out = out "to" format(e, , 3) format(so, , 3)
  end
  return out
