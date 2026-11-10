#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* top_rope.rex -- Top Rope Slam: look at a picture, and say how to  */
/*                 draw it, in SLAM Draw words                        */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:                                                               */
/*   rexx top_rope.rex <picture> <words out> [height]                 */
/*                                                                    */
/* Needs ImageMagick (convert, identify) to turn the picture into     */
/* plain RGB (PPM), and rsvg-convert or convert for the check.        */
/*                                                                    */
/* How I see:                                                         */
/*  1. colours: a colour is one I see in the middle of a part, not    */
/*     only at an edge. A place between two colours can be either.    */
/*  2. parts: places of one colour that touch.                        */
/*  3. from the top down: a shape is on top when, if I draw it, it    */
/*     covers only its own colour, and shapes I took off before.      */
/*     I take it off, and look again. So a band under a cross is one  */
/*     band, not ten bits.                                            */
/*  4. kinds: star (N points), circle, box (round, or only an edge),  */
/*     band (angle, thick, cut by the frame), writing, and last of    */
/*     all a shape with straight sides.                               */
/*  5. test: I draw my words again and count the places that are the  */
/*     same colour as the picture.                                    */
/* ------------------------------------------------------------------ */

  parse arg inPic outWords workH .
  if outWords = "" then do
    say "Use: rexx top_rope.rex <picture> <words out> [height]"
    exit 1
  end
  if workH = "" then workH = 360
  parse source . . me
  home = filespec("location", me)

  signal on syntax name seeError
  if \SysFileExists(inPic) then call fail "I can not find the picture" inPic"."
  call time "R"
  /* the master: read one time, kept in memory; all else is made from it */
  master = .Master~new(inPic)
  origW = master~W
  origH = master~H
  /* grey when it can be grey; colour only when the picture needs it */
  bpp = 3
  if master~isGrey then bpp = 1
  nh = min(workH, origH)
  nw = max(1, trunc(origW * nh / origH + 0.5))
  see = .SlamSee~new
  see~loadData(master~shrink(nw, nh, bpp), nw, nh, bpp)
  call phase "loadData"
  see~palette
  call phase "palette"
  see~pieces
  call phase "pieces"
  see~findFrame
  call phase "findFrame"
  see~writing
  call phase "writing"
  see~inkWriting(master)
  call phase "inkWriting"
  see~candidates
  call phase "candidates"
  see~peel
  call phase "peel"
  if value("TOPROPE_DEBUG", , "ENVIRONMENT") \== "" then see~debugBands(value("TOPROPE_DEBUG", , "ENVIRONMENT"))
  see~extendAll
  call phase "extendAll"
  reader = .GlyphReader~new
  if reader~load(home || "glyphs.txt") then see~readWriting(master, origW, origH, reader, value("WORD_HINT", , "ENVIRONMENT"), home || "top_rope_lessons.txt")
  call phase "readWriting"
  lines = see~words(inPic, origW)
  s = .stream~new(outWords)
  s~open("write replace")
  do line over lines
    s~lineout(line)
  end
  s~close
  secs = time("E")
  score = see~verifyV5V(outWords, home || "slam_draw.rex", master, inPic)
  call phase "verifyV5V"
  mode = "colour"
  if bpp = 1 then mode = "grey"
  say "I looked at" inPic "("origW "by" origH", seen at" see~W "by" see~H", in" mode")."
  say "I see" see~colourCount "colours and" see~shapeCount "shapes; I can not say what" see~leftOver "places are."
  say "I wrote" outWords "in" format(secs, , 1) "seconds."
  say "Test (V5V, low then high resolution):" score
  exit 0

fail:
  raise syntax 98.900 array (arg(1))

/* how long each step took, when TOPROPE_DEBUG has "time" */
phase:
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "  time:" left(arg(1), 14) format(time("E"), , 1) "s"
  return

seeError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "Top Rope Slam stopped." co["ADDITIONAL"][1]
  else say "Top Rope Slam broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  say "  (rc="rc "sigl="sigl "condition="condition("C") "description="condition("D")")"
  exit 2


/* ================================================================== */
::class SlamSee public
/* ================================================================== */
::attribute W get
::attribute H get

::method init
  expose W H pix stepOf pal comp comps remain bg cands shapes writes data cache fx0 fy0 fx1 fy1 inner bpp
  W = 0
  H = 0
  bpp = 3
  pal = .array~new
  comps = .array~new
  remain = .array~new
  cands = .array~new
  shapes = .array~new
  writes = .array~new
  cache = .directory~new
  bg = ""
  fx0 = 0
  fy0 = 0
  fx1 = 0
  fy1 = 0
  inner = ""

/* ---------------- 1. the picture ---------------------------------- */
/* the working copy, from the master: bpp 1 (grey) or 3 (colour) */
::method loadData
  expose W H data bpp
  use arg data, W, H, bpp

::attribute bpp get

::method loadPpm
  expose W H data
  use arg f
  s = .stream~new(f)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  toks = .array~new
  p = 1
  do while toks~items < 4
    ch = substr(data, p, 1)
    if ch = "#" then do
      p = pos("0a"x, data, p) + 1
      iterate
    end
    if verify(ch, "200a0d09"x) = 0 then do
      p = p + 1
      iterate
    end
    q = verify(data, "200a0d09"x, "M", p)
    toks~append(substr(data, p, q - p))
    p = q
  end
  if toks[1] \== "P6" then call fail "the picture is not a P6 PPM."
  W = toks[2]
  H = toks[3]
  data = substr(data, p + 1, W * H * 3)

/* colours I see in the middle of a part (all four next places the same) */
::method palette
  expose W H data pal pix bg cache bpp
  counts = .directory~new
  row = W * bpp
  do y = 1 to H - 2
    base = y * row
    do x = 1 to W - 2
      p = base + x * bpp + 1
      k = substr(data, p, bpp)
      if k == substr(data, p - bpp, bpp) then if k == substr(data, p + bpp, bpp) then if k == substr(data, p - row, bpp) then if k == substr(data, p + row, bpp) then do
        n = counts[k]
        if n == .nil then counts[k] = 1
        else counts[k] = n + 1
      end
    end
  end
  least = max(6, trunc(W * H * 0.00004))
  keys = .array~new
  do k over counts
    if counts[k] >= least then keys~append(k)
  end
  /* most first */
  do i = 1 to keys~items
    best = i
    do j = i + 1 to keys~items
      if counts[keys[j]] > counts[keys[best]] then best = j
    end
    t = keys[i]
    keys[i] = keys[best]
    keys[best] = t
  end
  do k over keys
    parse value rgbOf(k) with r g b
    near = .false
    do e over pal
      parse var e r2 g2 b2
      if (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2 <= 24 ** 2 then near = .true
    end
    if \near then pal~append(r g b)
    if pal~items >= 30 then leave
  end
  if pal~items = 0 then call fail "I see no colour that fills a part of the picture."
  /* each place: the colour it is near, or 0 (between two colours) */
  mb = .mutableBuffer~new(, W * H)
  do p = 1 to W * H * bpp by bpp
    k = substr(data, p, bpp)
    v = cache[k]
    if v == .nil then do
      v = self~nearest(k)
      cache[k] = v
    end
    mb~append(v)
  end
  pix = mb~string
  /* the background: the colour at the most places on the frame */
  frame = .array~new(pal~items)
  do i = 1 to pal~items
    frame[i] = 0
  end
  do x = 0 to W - 1
    call countFrame frame, substr(pix, x + 1, 1)
    call countFrame frame, substr(pix, (H - 1) * W + x + 1, 1)
  end
  do y = 0 to H - 1
    call countFrame frame, substr(pix, y * W + 1, 1)
    call countFrame frame, substr(pix, y * W + W, 1)
  end
  best = 1
  do i = 2 to pal~items
    if frame[i] > frame[best] then best = i
  end
  bg = d2c(best)

::method nearest
  expose pal
  use arg k
  parse value rgbOf(k) with r g b
  best = 0
  bestD = 45 ** 2 + 1
  do i = 1 to pal~items
    parse value pal[i] with r2 g2 b2
    d = (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2
    if d < bestD then do
      bestD = d
      best = i
    end
  end
  return d2c(best)

/* ---------------- 2. parts ---------------------------------------- */
::method pieces
  expose W H pix comp comps remain stepOf coverOf
  comp = .array~new(W * H)
  stepOf = .array~new(W * H)
  coverOf = .array~new(W * H)
  stack = .array~new
  do p = 1 to W * H
    if comp[p] \== .nil then iterate
    c = substr(pix, p, 1)
    if c == "00"x then iterate
    id = comps~items + 1
    comp[p] = id
    sp = 1
    stack[1] = p
    cnt = 0
    minx = W
    maxx = -1
    miny = H
    maxy = -1
    sx = 0
    sy = 0
    do while sp > 0
      q = stack[sp]
      sp = sp - 1
      cnt = cnt + 1
      y = (q - 1) % W
      x = (q - 1) // W
      sx = sx + x
      sy = sy + y
      if x < minx then minx = x
      if x > maxx then maxx = x
      if y < miny then miny = y
      if y > maxy then maxy = y
      if x > 0 then do
        r = q - 1
        if comp[r] == .nil then if substr(pix, r, 1) == c then do
          comp[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
      if x < W - 1 then do
        r = q + 1
        if comp[r] == .nil then if substr(pix, r, 1) == c then do
          comp[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
      if y > 0 then do
        r = q - W
        if comp[r] == .nil then if substr(pix, r, 1) == c then do
          comp[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
      if y < H - 1 then do
        r = q + W
        if comp[r] == .nil then if substr(pix, r, 1) == c then do
          comp[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
    end
    d = .directory~new
    d["ID"] = id
    d["C"] = c
    d["N"] = cnt
    d["START"] = p
    d["BOX"] = minx miny maxx maxy
    d["CX"] = sx / cnt + 0.5
    d["CY"] = sy / cnt + 0.5
    comps~append(d)
    remain[id] = cnt
  end

/* the outline of a part (Moore), as pixel places "x y" */
::method trace
  expose W H comp
  use arg id, start
  dx = .array~of(-1, -1, 0, 1, 1, 1, 0, -1)
  dy = .array~of(0, -1, -1, -1, 0, 1, 1, 1)
  sx = (start - 1) // W
  sy = (start - 1) % W
  pts = .array~new
  pts~append(sx sy)
  cx = sx
  cy = sy
  back = 1
  firstDir = 0
  limit = 4 * (W + H) * 4
  do steps = 1 to limit
    found = 0
    do k = 1 to 8
      d = (back - 1 + k) // 8 + 1
      nx = cx + dx[d]
      ny = cy + dy[d]
      if nx < 0 | ny < 0 | nx >= W | ny >= H then iterate
      if comp[ny * W + nx + 1] == id then do
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

/* fewer points, the same outline (Douglas-Peucker on a closed line) */
::method simplify
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

/* ---------------- an inner frame ---------------------------------- */
/* a long straight line where two or more colours stop at the         */
/* background, and no colour goes on over it, is the edge of a frame  */
/* (as a canton): the shapes in it are cut there                      */
::method findFrame
  expose W H pix bg fx0 fy0 fx1 fy1 inner
  fx0 = 0
  fy0 = 0
  fx1 = W
  fy1 = H
  inner = ""
  bestY = 0
  bestYn = 0
  sideY = ""
  do y = 2 to H - 2
    parse value self~cutRow(y) with na nb same cols
    n = max(na, nb)
    if n < 0.15 * H then iterate
    if same > 0.02 * W then iterate
    if cols < 2 then iterate
    if n > bestYn then do
      bestYn = n
      bestY = y
      if na >= nb then sideY = "ABOVE"
      else sideY = "BELOW"
    end
  end
  bestX = 0
  bestXn = 0
  sideX = ""
  do x = 2 to W - 2
    parse value self~cutCol(x) with na nb same cols
    n = max(na, nb)
    if n < 0.15 * H then iterate
    if same > 0.02 * H then iterate
    if cols < 2 then iterate
    if n > bestXn then do
      bestXn = n
      bestX = x
      if na >= nb then sideX = "LEFT"
      else sideX = "RIGHT"
    end
  end
  if bestYn = 0 then if bestXn = 0 then return
  x0 = 0
  y0 = 0
  x1 = W
  y1 = H
  if sideY = "ABOVE" then y1 = bestY
  if sideY = "BELOW" then y0 = bestY
  if sideX = "LEFT" then x1 = bestX
  if sideX = "RIGHT" then x0 = bestX
  if (x1 - x0) * (y1 - y0) > 0.6 * W * H then return
  inner = x0 y0 x1 y1

/* between row y-1 and row y: places with colour above and background below (na), the other way (nb), one colour over the line (same), and how many colours stop there */
::method cutRow
  expose W pix bg
  use arg y
  na = 0
  nb = 0
  same = 0
  seen = .directory~new
  do x = 0 to W - 1
    a = substr(pix, (y - 1) * W + x + 1, 1)
    b = substr(pix, y * W + x + 1, 1)
    if a == "00"x | b == "00"x then iterate
    if a == bg then do
      if b \== bg then do
        nb = nb + 1
        seen[b] = 1
      end
      iterate
    end
    if b == bg then do
      na = na + 1
      seen[a] = 1
      iterate
    end
    if a == b then same = same + 1
  end
  return na nb same seen~items

::method cutCol
  expose W H pix bg
  use arg x
  na = 0
  nb = 0
  same = 0
  seen = .directory~new
  do y = 0 to H - 1
    a = substr(pix, y * W + x, 1)
    b = substr(pix, y * W + x + 1, 1)
    if a == "00"x | b == "00"x then iterate
    if a == bg then do
      if b \== bg then do
        nb = nb + 1
        seen[b] = 1
      end
      iterate
    end
    if b == bg then do
      na = na + 1
      seen[a] = 1
      iterate
    end
    if a == b then same = same + 1
  end
  return na nb same seen~items

/* the frame a part is in: the inner frame when it is all in it */
::method frameOf
  expose W H inner
  use arg d
  if inner \== "" then do
    parse var inner x0 y0 x1 y1
    parse value d["BOX"] with bx0 by0 bx1 by1
    if bx0 >= x0 then if by0 >= y0 then if bx1 < x1 then if by1 < y1 then return inner
  end
  return 0 0 W H

::method useFrame
  expose fx0 fy0 fx1 fy1 W H
  use arg fr
  if fr == .nil then fr = 0 0 W H
  parse var fr fx0 fy0 fx1 fy1

::method innerFrame
  expose inner
  return inner

/* ---------------- writing ----------------------------------------- */
/* small parts of one colour, in a line, close together               */
::method writing
  expose W H comps writes stepOf remain comp bg pix
  use arg given = .nil
  smalls = .array~new
  if given \== .nil then smalls = given
  if given == .nil then do d over comps
    if d["C"] == bg then iterate
    parse value d["BOX"] with x0 y0 x1 y1
    pw = x1 - x0 + 1
    ph = y1 - y0 + 1
    if d["N"] < 3 then iterate
    if ph > 0.045 * H then iterate
    if pw > 0.07 * H then iterate
    fill = d["N"] / (pw * ph)
    /* a thin upright part (l, 1, I) fills its box: it can still be a letter */
    if fill > 0.8 then if pw > max(2, 0.25 * ph) then iterate
    smalls~append(d)
  end
  n = smalls~items
  if n < 2 then return
  inkMode = (given \== .nil)
  up = .array~new(n)
  upD = .array~new(n)
  do i = 1 to n
    up[i] = i
    upD[i] = i
  end
  do i = 1 to n
    parse value smalls[i]["BOX"] with ax0 ay0 ax1 ay1
    do j = i + 1 to n
      if smalls[i]["C"] \== smalls[j]["C"] then iterate
      parse value smalls[j]["BOX"] with bx0 by0 bx1 by1
      ha = ay1 - ay0 + 1
      hb = by1 - by0 + 1
      hm = max(ha, hb)
      wa = ax1 - ax0 + 1
      wb = bx1 - bx0 + 1
      wm = max(wa, wb)
      across = .true
      if max(ha, hb) / min(ha, hb) > 3 then across = .false
      else if abs((ay0 + ay1) / 2 - (by0 + by1) / 2) > 0.6 * hm then across = .false
      else if max(ax0, bx0) - min(ax1, bx1) > 0.8 * hm then across = .false
      /* or up and down (writing turned 90 degrees): the same, with across and down changed */
      down = .true
      if max(wa, wb) / min(wa, wb) > 3 then down = .false
      else if abs((ax0 + ax1) / 2 - (bx0 + bx1) / 2) > 0.6 * wm then down = .false
      else if max(ay0, by0) - min(ay1, by1) > 0.8 * wm then down = .false
      if across then do
        ri = findRoot(up, i)
        rj = findRoot(up, j)
        if ri \= rj then up[rj] = ri
      end
      if down then do
        ri = findRoot(upD, i)
        rj = findRoot(upD, j)
        if ri \= rj then upD[rj] = ri
      end
    end
  end
  /* a group is all across, or all up and down: a part goes across when it can */
  sizeA = .directory~new
  do i = 1 to n
    r = findRoot(up, i)
    if sizeA[r] == .nil then sizeA[r] = 0
    sizeA[r] = sizeA[r] + 1
  end
  groups = .directory~new
  do i = 1 to n
    r = findRoot(up, i)
    if sizeA[r] >= 2 then key = "A" r
    else key = "D" findRoot(upD, i)
    if \groups~hasIndex(key) then groups[key] = .array~new
    groups[key]~append(smalls[i])
  end
  /* 1. words on one line, a word-gap apart, are one piece of writing */
  groups = self~joinLines(groups)
  do r over groups
    g = groups[r]
    if g~items < 2 then iterate
    gx0 = W
    gy0 = H
    gx1 = -1
    gy1 = -1
    ids = .directory~new
    do d over g
      parse value d["BOX"] with x0 y0 x1 y1
      gx0 = min(gx0, x0)
      gy0 = min(gy0, y0)
      gx1 = max(gx1, x1)
      gy1 = max(gy1, y1)
      ids[d["ID"]] = 1
    end
    if \inkMode then do y = gy0 to gy1
      do x = gx0 to gx1
        p = y * W + x + 1
        id = comp[p]
        if id \== .nil then do
          if ids~hasIndex(id) then do
            stepOf[p] = 0
            remain[id] = remain[id] - 1
          end
        end
        else if substr(pix, p, 1) == "00"x then stepOf[p] = 0
      end
    end
    /* writing found as ink: not where writing is found already */
    if inkMode then do
      skip = .false
      do o over writes
        parse value o["BOX"] with ox0 oy0 ox1 oy1
        if gx0 <= ox1 then if gx1 >= ox0 then if gy0 <= oy1 then if gy1 >= oy0 then skip = .true
      end
      if skip then iterate
    end
    wr = .directory~new
    wr["C"] = g[1]["C"]
    wr["X"] = (gx0 + gx1 + 1) / 2
    wr["Y"] = (gy0 + gy1 + 1) / 2
    wr["BOX"] = gx0 gy0 gx1 gy1
    wr["UP"] = (gy1 - gy0) > 1.5 * (gx1 - gx0)
    if wr["UP"] then wr["S"] = (gx1 - gx0 + 1) / 0.72
    else wr["S"] = (gy1 - gy0 + 1) / 0.72
    wr["TEXT"] = "?"
    wr["TURN"] = 0
    wr["N"] = g~items
    writes~append(wr)
  end

/* Writing found as ink: thin dark letters fill no part with one colour, so the colours do not
   see them. On the grey picture: a place is ink when it is darker than the paper by more than
   half of the way to the darkest place, and darker than every colour that fills parts. Small
   parts of ink, in lines, are writing (as for the colours). */
::method inkWriting
  expose W H data bpp pal writes
  use arg master
  if bpp = 1 then g = data
  else g = master~shrink(W, H, 1)
  /* the paper: the grey seen most; the darkest grey */
  counts = .array~new(256)
  do i = 1 to 256
    counts[i] = 0
  end
  dark = 255
  do p = 1 to W * H by 3
    v = c2d(substr(g, p, 1))
    counts[v + 1] = counts[v + 1] + 1
    dark = min(dark, v)
  end
  paper = 0
  do i = 1 to 256
    if counts[i] > counts[paper + 1] then paper = i - 1
  end
  /* darker than half way to the darkest, and darker than each filled colour but the darkest one */
  limit = paper - (paper - dark) / 2
  do e over pal
    parse var e r gg b
    gv = 0.299 * r + 0.587 * gg + 0.114 * b
    if gv > dark + 40 then limit = min(limit, gv - 30)
  end
  if limit <= dark then return
  ink = .array~new(W * H)
  do p = 1 to W * H
    ink[p] = (c2d(substr(g, p, 1)) <= limit)
  end
  lab = .array~new(W * H)
  parts = .array~new
  stack = .array~new
  do p = 1 to W * H
    if \ink[p] then iterate
    if lab[p] \== .nil then iterate
    id = parts~items + 1
    lab[p] = id
    sp = 1
    stack[1] = p
    mx0 = W
    mx1 = -1
    my0 = H
    my1 = -1
    n = 0
    do while sp > 0
      q = stack[sp]
      sp = sp - 1
      n = n + 1
      y = (q - 1) % W
      x = (q - 1) // W
      mx0 = min(mx0, x)
      mx1 = max(mx1, x)
      my0 = min(my0, y)
      my1 = max(my1, y)
      do dy = -1 to 1
        do dx = -1 to 1
          nx = x + dx
          ny = y + dy
          if nx < 0 | ny < 0 | nx >= W | ny >= H then iterate
          r = ny * W + nx + 1
          if \ink[r] then iterate
          if lab[r] \== .nil then iterate
          lab[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
    end
    pw = mx1 - mx0 + 1
    ph = my1 - my0 + 1
    if n < 3 then iterate
    if max(pw, ph) > 0.045 * H then iterate
    d = .directory~new
    d["ID"] = -id
    d["C"] = "INK"
    d["N"] = n
    d["BOX"] = mx0 my0 mx1 my1
    parts~append(d)
  end
  if parts~items < 2 then return
  before = writes~items
  self~writing(parts)
  /* the colour of ink writing: the darkest colour I have, or black */
  inkC = ""
  best = 1e9
  do i = 1 to pal~items
    parse value pal[i] with r gg b
    gv = 0.299 * r + 0.587 * gg + 0.114 * b
    if gv < best then do
      best = gv
      inkC = d2c(i)
    end
  end
  if best > dark + 60 then do
    pal~append(dark dark dark)
    inkC = d2c(pal~items)
  end
  do i = before + 1 to writes~items
    writes[i]["C"] = inkC
  end

/* groups of one colour, across, on one line, with a gap less than 1.2 times their height: one */
::method joinLines
  use arg groups
  list = .array~new
  do k over groups
    g = groups[k]
    if g~items < 2 then iterate
    x0 = 1e9
    y0 = 1e9
    x1 = -1
    y1 = -1
    do d over g
      parse value d["BOX"] with a0 b0 a1 b1
      x0 = min(x0, a0)
      y0 = min(y0, b0)
      x1 = max(x1, a1)
      y1 = max(y1, b1)
    end
    e = .directory~new
    e["G"] = g
    e["BOX"] = x0 y0 x1 y1
    e["ACROSS"] = (left(k, 1) == "A")
    list~append(e)
  end
  changed = .true
  do while changed
    changed = .false
    do i = 1 to list~items
      if list[i] == .nil then iterate
      do j = 1 to list~items
        if i = j then iterate
        if list[j] == .nil then iterate
        a = list[i]
        b = list[j]
        if \a["ACROSS"] | \b["ACROSS"] then iterate
        if a["G"][1]["C"] \== b["G"][1]["C"] then iterate
        parse value a["BOX"] with ax0 ay0 ax1 ay1
        parse value b["BOX"] with bx0 by0 bx1 by1
        if bx0 < ax0 then iterate
        h = max(ay1 - ay0, by1 - by0) + 1
        if abs((ay0 + ay1) / 2 - (by0 + by1) / 2) > 0.5 * h then iterate
        if bx0 - ax1 > 1.2 * h then iterate
        do d over b["G"]
          a["G"]~append(d)
        end
        a["BOX"] = min(ax0, bx0) min(ay0, by0) max(ax1, bx1) max(ay1, by1)
        list[j] = .nil
        changed = .true
      end
    end
  end
  out = .directory~new
  k = 0
  do e over list
    if e == .nil then iterate
    k = k + 1
    out[k] = e["G"]
  end
  return out

/* ---------------- 4. kinds: what each part could be --------------- */
::method candidates
  expose W H comps cands bg remain
  minLen = 8
  seen = .directory~new
  do d over comps
    if d["C"] == bg then iterate
    if d["N"] < 6 then iterate
    if remain[d["ID"]] < 4 then iterate
    pts = self~trace(d["ID"], d["START"])
    parse value d["BOX"] with x0 y0 x1 y1
    pw = x1 - x0 + 1
    ph = y1 - y0 + 1
    fill = d["N"] / (pw * ph)
    /* a box, or a box with round corners */
    rnd = self~roundOf(d)
    fr = self~frameOf(d)
    self~useFrame(fr)
    bx = .directory~new
    bx["KIND"] = "BOX"
    bx["C"] = d["C"]
    bx["COMP"] = d["ID"]
    bx["BOX"] = x0 y0 (x1 + 1) (y1 + 1)
    bx["ROUND"] = rnd
    bx["FRAME"] = fr
    cands~append(bx)
    /* a box that is only an edge */
    if fill < 0.5 then do
      t = self~ringThick(d)
      if t > 0 then do
        rg = .directory~new
        rg["KIND"] = "RING"
        rg["C"] = d["C"]
        rg["COMP"] = d["ID"]
        rg["BOX"] = x0 y0 (x1 + 1) (y1 + 1)
        rg["T"] = t
        rg["ROUND"] = rnd
        rg["FRAME"] = fr
        cands~append(rg)
      end
    end
    /* a star or a circle */
    starLike = .false
    touches = (x0 <= 0) | (y0 <= 0) | (x1 >= self~W - 1) | (y1 >= self~H - 1)
    /* a star or circle is round-ish: not a tiny part, and not long and thin */
    roundish = (d["N"] >= 30) & (max(pw, ph) <= 3 * min(pw, ph))
    if fill < 0.95 then if \touches then if roundish then do
      sc = self~starFit(d, pts)
      if sc \== .nil then do
        sc["FRAME"] = fr
        cands~append(sc)
        starLike = .true
      end
    end
    /* bands: from each long straight side */
    if \starLike then do
      simple = self~simplify(pts, 1.2)
      n = simple~items
      do i = 1 to n
        parse value simple[i] with ax ay
        parse value simple[i // n + 1] with bx2 by2
        L = RxCalcSqrt((bx2 - ax) ** 2 + (by2 - ay) ** 2, 9)
        if L < minLen then iterate
        if self~onFrame(ax, ay, bx2, by2) then iterate
        seed = self~fitSide(pts, ax + 0.5, ay + 0.5, bx2 + 0.5, by2 + 0.5)
        parse var seed sax say sbx sby
        /* one seed for one line of one colour */
        ang = atan2(sby - say, sbx - sax)
        if ang < 0 then ang = ang + 180
        if ang >= 180 then ang = ang - 180
        rho = sax * RxCalcSin(ang, 9) - say * RxCalcCos(ang, 9)
        along = (sax + sbx) / 2 * RxCalcCos(ang, 9) + (say + sby) / 2 * RxCalcSin(ang, 9)
        key = c2d(d["C"]) format(ang / 2, , 0) format(rho / 3, , 0) format(along / (0.25 * H), , 0)
        if seen~hasIndex(key) then iterate
        seen[key] = 1
        sd = .directory~new
        sd["KIND"] = "BAND"
        sd["C"] = d["C"]
        sd["COMP"] = d["ID"]
        sd["SEED"] = seed
        sd["FRAME"] = fr
        cands~append(sd)
      end
    end
    /* more seeds: long straight edges inside a part too (walls inside a ring of walls) */
    if \starLike then if d["N"] >= 400 then do
      do e over self~edgeRuns(d, max(12, 0.03 * H))
        parse var e sax say sbx sby
        ang = atan2(sby - say, sbx - sax)
        if ang < 0 then ang = ang + 180
        if ang >= 180 then ang = ang - 180
        rho = sax * RxCalcSin(ang, 9) - say * RxCalcCos(ang, 9)
        along = (sax + sbx) / 2 * RxCalcCos(ang, 9) + (say + sby) / 2 * RxCalcSin(ang, 9)
        key = c2d(d["C"]) format(ang / 2, , 0) format(rho / 3, , 0) format(along / (0.25 * H), , 0)
        if seen~hasIndex(key) then iterate
        seen[key] = 1
        sd = .directory~new
        sd["KIND"] = "BAND"
        sd["C"] = d["C"]
        sd["COMP"] = d["ID"]
        sd["SEED"] = e
        sd["FRAME"] = fr
        cands~append(sd)
      end
    end
    /* last of all: a shape with straight sides */
    simple = self~simplify(pts, 1.0)
    if simple~items >= 3 then do
      pl = .directory~new
      pl["KIND"] = "SHAPE"
      pl["C"] = d["C"]
      pl["COMP"] = d["ID"]
      pl["N"] = d["N"]
      poly = .array~new
      do e over simple
        parse var e x y
        poly~append(x + 0.5)
        poly~append(y + 0.5)
      end
      pl["PTS"] = poly
      pl["FRAME"] = fr
      cands~append(pl)
    end
  end

/* the best straight line through the outline places of one side; level or upright when near */
::method fitSide
  use arg pts, ax, ay, bx, by
  L = RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9)
  ux = (bx - ax) / L
  uy = (by - ay) / L
  n = 0
  sx = 0
  sy = 0
  sxx = 0
  syy = 0
  sxy = 0
  do e over pts
    parse var e x y
    x = x + 0.5
    y = y + 0.5
    t = (x - ax) * ux + (y - ay) * uy
    if t < 0.1 * L then iterate
    if t > 0.9 * L then iterate
    if abs((x - ax) * uy - (y - ay) * ux) > 1.6 then iterate
    n = n + 1
    sx = sx + x
    sy = sy + y
    sxx = sxx + x * x
    syy = syy + y * y
    sxy = sxy + x * y
  end
  if n < 4 then return ax ay bx by
  mx = sx / n
  my = sy / n
  cxx = sxx / n - mx * mx
  cyy = syy / n - my * my
  cxy = sxy / n - mx * my
  a = atan2(2 * cxy, cxx - cyy) / 2
  vx = RxCalcCos(a, 9)
  vy = RxCalcSin(a, 9)
  if vx * ux + vy * uy < 0 then do
    vx = -vx
    vy = -vy
  end
  /* level or upright when it is less than 0.6 degrees from it */
  if abs(vy) < 0.0105 then do
    vy = 0
    vx = sign(vx)
    my = format(my * 2, , 0) / 2
  end
  if abs(vx) < 0.0105 then do
    vx = 0
    vy = sign(vy)
    mx = format(mx * 2, , 0) / 2
  end
  ta = (ax - mx) * vx + (ay - my) * vy
  tb = (bx - mx) * vx + (by - my) * vy
  return (mx + ta * vx) (my + ta * vy) (mx + tb * vx) (my + tb * vy)

/* long runs, level or upright, where the part meets an other colour: each is a side of a band */
::method edgeRuns
  expose W H comp
  use arg d, minRun
  id = d["ID"]
  parse value d["BOX"] with x0 y0 x1 y1
  out = .array~new
  do side over .array~of(-1, 1)
    do y = y0 to y1
      run = 0
      do x = x0 to x1 + 1
        edge = .false
        if x <= x1 then do
          p = y * W + x + 1
          if comp[p] == id then do
            q = p + side * W
            if y + side < 0 | y + side >= H then edge = .false
            else if comp[q] \== id then edge = .true
          end
        end
        if edge then do
          if run = 0 then rs = x
          run = run + 1
        end
        else do
          if run >= minRun then out~append((rs + 0.5) (y + 0.5) (x - 0.5) (y + 0.5))
          run = 0
        end
      end
    end
    do x = x0 to x1
      run = 0
      do y = y0 to y1 + 1
        edge = .false
        if y <= y1 then do
          p = y * W + x + 1
          if comp[p] == id then do
            if x + side < 0 | x + side >= W then edge = .false
            else if comp[p + side] \== id then edge = .true
          end
        end
        if edge then do
          if run = 0 then rs = y
          run = run + 1
        end
        else do
          if run >= minRun then out~append((x + 0.5) (rs + 0.5) (x + 0.5) (y - 0.5))
          run = 0
        end
      end
    end
  end
  return out

::method onFrame
  expose W H fx0 fy0 fx1 fy1
  use arg ax, ay, bx, by
  if ax <= fx0 + 1 then if bx <= fx0 + 1 then return .true
  if ay <= fy0 + 1 then if by <= fy0 + 1 then return .true
  if ax >= fx1 - 2 then if bx >= fx1 - 2 then return .true
  if ay >= fy1 - 2 then if by >= fy1 - 2 then return .true
  return .false

/* round corners: what is missing from the four corners of the box */
::method roundOf
  expose W comp
  use arg d
  parse value d["BOX"] with x0 y0 x1 y1
  q = trunc(min(x1 - x0 + 1, y1 - y0 + 1) / 4)
  if q < 3 then return 0
  id = d["ID"]
  if comp[y0 * W + x0 + 1] == id then return 0
  if comp[y0 * W + x1 + 1] == id then return 0
  if comp[y1 * W + x0 + 1] == id then return 0
  if comp[y1 * W + x1 + 1] == id then return 0
  miss = .array~new
  do cy over .array~of(y0, y1 - q + 1)
    do cx over .array~of(x0, x1 - q + 1)
      m = 0
      do y = cy to cy + q - 1
        do x = cx to cx + q - 1
          if comp[y * W + x + 1] \== d["ID"] then m = m + 1
        end
      end
      miss~append(m)
    end
  end
  lo = min(miss[1], miss[2], miss[3], miss[4])
  hi = max(miss[1], miss[2], miss[3], miss[4])
  if lo < 3 then return 0
  if hi > 1.6 * lo + 2 then return 0
  avg = (miss[1] + miss[2] + miss[3] + miss[4]) / 4
  r = RxCalcSqrt(avg / (1 - RxCalcPi(9) / 4), 9)
  if r > q then return 0
  return r

/* how thick the edge is, when a part is only the edge of a box */
::method ringThick
  expose W comp
  use arg d
  parse value d["BOX"] with x0 y0 x1 y1
  id = d["ID"]
  got = .array~new
  do f over .array~of(0.2, 0.35, 0.65, 0.8)
    y = trunc(y0 + f * (y1 - y0))
    x = trunc(x0 + f * (x1 - x0))
    got~append(self~runFrom(x0, y, 1, 0, id))
    got~append(self~runFrom(x1, y, -1, 0, id))
    got~append(self~runFrom(x, y0, 0, 1, id))
    got~append(self~runFrom(x, y1, 0, -1, id))
  end
  vals = .array~new
  do v over got
    if v > 0 then vals~append(v)
  end
  if vals~items < 8 then return 0
  vals = vals~sortWith(.NumericComparator~new)
  t = vals[(vals~items + 1) % 2]
  /* nothing of the part inside */
  inside = 0
  area = 0
  do y = y0 + t + 2 to y1 - t - 2 by 2
    do x = x0 + t + 2 to x1 - t - 2 by 2
      area = area + 1
      if comp[y * W + x + 1] == id then inside = inside + 1
    end
  end
  if area < 4 then return 0
  if inside > 0.01 * area then return 0
  return t

::method runFrom
  expose W H comp
  use arg x, y, sx, sy, id
  n = 0
  do forever
    if x < 0 | y < 0 | x >= W | y >= H then leave
    if comp[y * W + x + 1] \== id then leave
    n = n + 1
    x = x + sx
    y = y + sy
  end
  return n

/* a star: the length from the middle goes up and down N times.  N is the  */
/* wave that is strongest in the lengths (one term of a Fourier sum), and  */
/* where that wave is high, the points are                                  */
::method starFit
  expose W H comp
  use arg d, pts
  cx = d["CX"]
  cy = d["CY"]
  nb = 72
  r = .array~new(nb)
  do e over pts
    parse var e x y
    px = x + 0.5 - cx
    py = y + 0.5 - cy
    rr = RxCalcSqrt(px * px + py * py, 9) + 0.5
    a = atan2(py, px)
    b = trunc((a + 360) / 5) // nb + 1
    if r[b] == .nil then r[b] = rr
    else if rr > r[b] then r[b] = rr
  end
  have = 0
  do b = 1 to nb
    if r[b] \== .nil then have = have + 1
  end
  if have < nb / 3 then return .nil
  full = r~copy
  do b = 1 to nb
    if full[b] \== .nil then iterate
    do k = 1 to nb
      j1 = (b - 1 + k) // nb + 1
      j2 = (b - 1 - k + nb * 2) // nb + 1
      if full[j1] \== .nil then do
        r[b] = full[j1]
        leave
      end
      if full[j2] \== .nil then do
        r[b] = full[j2]
        leave
      end
    end
  end
  rmax = 0
  rmin = 1e9
  sum = 0
  do b = 1 to nb
    rmax = max(rmax, r[b])
    rmin = min(rmin, r[b])
    sum = sum + r[b]
  end
  mean = sum / nb
  if rmax < 3 then return .nil
  /* the strongest wave, from 2 to 12 times round */
  bestN = 0
  bestM = 0
  bestC = 0
  bestS = 0
  do n = 2 to 12
    cs = 0
    sn = 0
    do b = 1 to nb
      a = (b - 0.5) * 5
      cs = cs + r[b] * RxCalcCos(n * a, 9)
      sn = sn + r[b] * RxCalcSin(n * a, 9)
    end
    m = RxCalcSqrt(cs * cs + sn * sn, 9) / nb
    if m > bestM then do
      bestM = m
      bestN = n
      bestC = cs
      bestS = sn
    end
  end
  /* a circle: no wave */
  if bestM / mean < 0.04 then do
    if rmin / rmax < 0.85 then return .nil
    sd = .directory~new
    sd["KIND"] = "CIRCLE"
    sd["C"] = d["C"]
    sd["COMP"] = d["ID"]
    sd["X"] = cx
    sd["Y"] = cy
    sd["R"] = mean
    sd["PTS"] = circlePoly(cx, cy, mean, 48)
    if self~iou(d, sd["PTS"]) < 0.9 then return .nil
    return sd
  end
  n = bestN
  if n < 3 then return .nil
  /* the wave is high at angle ph: a point is there */
  ph = atan2(bestS, bestC) / n
  span = 360 / n
  turn = (ph + 90) // span
  if turn < 0 then turn = turn + span
  if turn > span / 2 then turn = turn - span
  big = rmax
  inner = rmin / rmax
  /* the tips are thin, and places between colours are lost there: try a little bigger, then the inner part */
  bestQ = -1
  bestF = 1
  do f over .array~of(0.97, 1, 1.03, 1.06, 1.09, 1.12, 1.15)
    q = self~iou(d, starPoly(cx, cy, big * f, inner / f, n, turn))
    if q >= bestQ - 0.002 then do
      bestQ = q
      bestF = f
    end
  end
  inner = inner / bestF
  big = big * bestF
  bestI = inner
  do di over .array~of(-0.06, -0.03, 0.03, 0.06)
    if inner + di <= 0.1 then iterate
    q = self~iou(d, starPoly(cx, cy, big, inner + di, n, turn))
    if q > bestQ then do
      bestQ = q
      bestI = inner + di
    end
  end
  inner = bestI
  need = 0.88
  if big < 15 then need = 0.8
  if value("TOPROPE_DEBUG", , "ENVIRONMENT") == "star" then say "star fit at" format(cx, , 1) format(cy, , 1) "n" n "R" format(big, , 1) "inner" format(inner, , 2) "match" format(bestQ, , 3)
  if bestQ < need then return .nil
  sd = .directory~new
  sd["KIND"] = "STAR"
  sd["C"] = d["C"]
  sd["COMP"] = d["ID"]
  sd["X"] = cx
  sd["Y"] = cy
  sd["N"] = n
  sd["R"] = big
  sd["INNER"] = inner
  sd["TURN"] = turn
  sd["PTS"] = starPoly(cx, cy, big, inner, n, turn)
  return sd

/* how much the shape and the part are the same (places between two colours do not count) */
::method iou
  expose W H comp pix
  use arg d, poly
  parse value d["BOX"] with x0 y0 x1 y1
  both = 0
  either = 0
  do y = max(0, y0 - 2) to min(H - 1, y1 + 2)
    do x = max(0, x0 - 2) to min(W - 1, x1 + 2)
      p = y * W + x + 1
      inC = (comp[p] == d["ID"])
      inP = inPoly(x + 0.5, y + 0.5, poly)
      if \inC then if \inP then iterate
      if \inC then if substr(pix, p, 1) == "00"x then iterate
      either = either + 1
      if inC then if inP then both = both + 1
    end
  end
  if either = 0 then return 0
  return both / either

/* ---------------- 3. from the top down ---------------------------- */
::method peel
  expose cands shapes remain
  big = 1e9
  minNew = 4
  bigNew = max(minNew, trunc(0.0002 * self~W * self~H))
  do k = 1 to 400
    best = .nil
    bestN = 0
    defer = .nil
    deferN = 0
    poly = .nil
    polyN = 0
    self~orderCands
    do cd over cands
      if cd["USED"] == 1 then iterate
      if remain[cd["COMP"]] < minNew then iterate
      last = cd["LAST"]
      if last \== .nil then if best \== .nil then if last * 1.3 < bestN then leave
      reg = self~regionOf(cd, big)
      if reg == .nil then iterate
      parse value self~scan(reg, cd["C"], "COUNT", big, 0) with total allowed newc
      if total = 0 then do
        cd["LAST"] = 0
        iterate
      end
      cd["LAST"] = newc * newc / (total * st2(reg))
      if newc < minNew then iterate
      if cd["KIND"] = "SHAPE" then if remain[cd["COMP"]] < 0.25 * cd["N"] then iterate
      if wordpos(cd["KIND"], "BAND BOX RING SHAPE") > 0 then if newc < bigNew then iterate
      need = 0.985
      /* a band's two long edges can each be one fuzzy row (compression): allow that much, for its thickness */
      if cd["KIND"] = "BAND" then need = max(0.93, 0.985 - 0.6 / max(reg["T"], 1))
      if wordpos(cd["KIND"], "STAR CIRCLE") > 0 then need = 0.94
      if cd["KIND"] = "SHAPE" then need = 0.96
      if allowed / total < need then iterate
      if reg["BLOCK"] > max(2, 0.002 * total) then iterate
      if self~blocked(reg, cd["C"]) then iterate
      if cd["KIND"] = "SHAPE" then do
        if newc > polyN then do
          poly = cd
          polyN = newc
        end
        iterate
      end
      score = newc * newc / (total * st2(reg))
      if reg["DEFER"] == 1 then do
        if score > deferN then do
          defer = cd
          deferN = score
        end
        iterate
      end
      if score > bestN then do
        best = cd
        bestN = score
      end
    end
    if best == .nil then best = defer
    if best == .nil then best = poly
    if best == .nil then leave
    reg = self~regionOf(best, big)
    self~scan(reg, best["C"], "MARK", big, k)
    if wordpos(best["KIND"], "STAR CIRCLE SHAPE") > 0 then self~markComp(best["COMP"], k)
    /* a band or box of an other colour can be more now: look at it again */
    do cd over cands
      if cd["C"] == best["C"] then iterate
      if wordpos(cd["KIND"], "BAND BOX") > 0 then cd["LAST"] = .nil
    end
    if best["KIND"] \== "BAND" then best["USED"] = 1
    if value("TOPROPE_DEBUG", , "ENVIRONMENT") \== "" then say "pick" k best["KIND"] c2d(best["C"]) "new" bestN "seed" best["SEED"] "T" reg["T"] "P" reg["P"] "Q" reg["Q"] "defer" reg["DEFER"]
    sh = .directory~new
    sh["CAND"] = best
    sh["REG"] = reg
    sh["STEP"] = k
    shapes~append(sh)
  end

/* a part of an other colour, not said yet, with its middle inside the region: it is on top, so the region waits.
   (Each part, not samples: a small star can fall between samples.) */
::method blocked
  expose comps remain bg
  use arg reg, c
  pts = reg["PTS"]
  ring = reg["KIND"] = "RING"
  if ring then parse value reg["INNER"] with ix0 iy0 ix1 iy1
  do d over comps
    if d["C"] == c then iterate
    if d["C"] == bg then iterate
    if d["N"] < 20 then iterate
    if remain[d["ID"]] < 0.5 * d["N"] then iterate
    x = d["CX"]
    y = d["CY"]
    if \inPoly(x, y, pts) then iterate
    if ring then if x > ix0 then if x < ix1 then if y > iy0 then if y < iy1 then iterate
    return .true
  end
  return .false

/* all places of a part are said (the thin tips of a star, lost between colours) */
::method markComp
  expose W H comp stepOf remain comps
  use arg id, k
  parse value comps[id]["BOX"] with x0 y0 x1 y1
  do y = y0 to y1
    do x = x0 to x1
      p = y * W + x + 1
      if comp[p] == id then if stepOf[p] == .nil then stepOf[p] = k
    end
  end
  remain[id] = 0

/* the candidates with the most places last time first (a band can grow a little) */
::method orderCands
  expose cands
  keep = .array~new
  do cd over cands
    if cd["USED"] \== 1 then keep~append(cd)
  end
  cands = keep~sortWith(.LastFirst~new)

::method debugBands
  expose cands
  use arg col
  do cd over cands
    if cd["KIND"] \== "BAND" then iterate
    if c2d(cd["C"]) \= col then iterate
    reg = self~regionOf(cd, 1e9)
    if reg == .nil then do
      say "band seed" cd["SEED"] "-> nil"
      iterate
    end
    parse value self~scan(reg, cd["C"], "COUNT", 1e9, 0) with total allowed newc
    say "band seed" cd["SEED"] "T" reg["T"] "P" reg["P"] "Q" reg["Q"] "defer" reg["DEFER"] "clean" format(allowed / max(total, 1), , 3) "new" newc "used" cd["USED"] "last" cd["LAST"]
  end

/* after all: a band or a box can go on under shapes on top of it, to the frame */
::method extendAll
  expose shapes
  do sh over shapes
    cd = sh["CAND"]
    if wordpos(cd["KIND"], "BAND BOX") = 0 then iterate
    reg = self~regionOf(cd, sh["STEP"])
    if reg == .nil then iterate
    parse value self~scan(reg, cd["C"], "COUNT", sh["STEP"], 0) with total allowed newc
    if total = 0 then iterate
    if allowed / total >= 0.985 then sh["REG"] = reg
  end

/* the region a candidate covers now; limit: which shapes are on top */
::method regionOf
  use arg cd, limit
  self~useFrame(cd["FRAME"])
  kind = cd["KIND"]
  if kind = "BAND" then return self~bandGeom(cd, limit)
  if kind = "BOX" then return self~boxGeom(cd, limit)
  reg = .directory~new
  reg["KIND"] = kind
  if kind = "RING" then do
    parse value cd["BOX"] with x0 y0 x1 y1
    t = cd["T"]
    reg["PTS"] = .array~of(x0, y0, x1, y0, x1, y1, x0, y1)
    reg["CONVEX"] = .true
    reg["INNER"] = (x0 + t) (y0 + t) (x1 - t) (y1 - t)
    return reg
  end
  reg["PTS"] = cd["PTS"]
  reg["CONVEX"] = (kind = "CIRCLE")
  return reg

::method boxGeom
  expose W H fx0 fy0 fx1 fy1
  use arg cd, limit
  parse value cd["BOX"] with x0 y0 x1 y1
  defer = 0
  if cd["ROUND"] = 0 then do
    /* go on to the frame, if all on the way is on top */
    if x0 > fx0 then if self~clear(fx0, y0, x0, y1, cd["C"], limit) then x0 = fx0
    if x1 < fx1 then if self~clear(x1, y0, fx1, y1, cd["C"], limit) then x1 = fx1
    if y0 > fy0 then if self~clear(x0, fy0, x1, y0, cd["C"], limit) then y0 = fy0
    if y1 < fy1 then if self~clear(x0, y1, x1, fy1, cd["C"], limit) then y1 = fy1
    if x0 > fx0 then if self~noBack(fx0, y0, x0, y1) then defer = 1
    if x1 < fx1 then if self~noBack(x1, y0, fx1, y1) then defer = 1
    if y0 > fy0 then if self~noBack(x0, fy0, x1, y0) then defer = 1
    if y1 < fy1 then if self~noBack(x0, y1, x1, fy1) then defer = 1
  end
  reg = .directory~new
  reg["KIND"] = "BOX"
  reg["DEFER"] = defer
  reg["PTS"] = .array~of(x0, y0, x1, y0, x1, y1, x0, y1)
  reg["CONVEX"] = .true
  reg["BOX"] = x0 y0 x1 y1
  return reg

/* no background between the box and the frame: other colours may be on top of my box */
::method noBack
  expose W pix bg stepOf
  use arg x0, y0, x1, y1
  if x1 - x0 < 1 then return .false
  if y1 - y0 < 1 then return .false
  n = 0
  do y = trunc(y0) to trunc(y1) - 1 by 2
    do x = trunc(x0) to trunc(x1) - 1 by 2
      p = y * W + x + 1
      if substr(pix, p, 1) == bg then if stepOf[p] == .nil then return .false
      n = n + 1
    end
  end
  return n > 0

::method clear
  use arg x0, y0, x1, y1, c, limit
  reg = .directory~new
  reg["PTS"] = .array~of(x0, y0, x1, y0, x1, y1, x0, y1)
  reg["CONVEX"] = .true
  reg["KIND"] = "BOX"
  parse value self~scan(reg, c, "COUNT", limit, 0) with total allowed newc
  if total = 0 then return .false
  return allowed = total

/* a band from one long straight side: how thick, and how far each way */
::method bandGeom
  expose W H
  use arg cd, limit
  c = cd["C"]
  parse value cd["SEED"] with ax ay bx by
  L = RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9)
  ux = (bx - ax) / L
  uy = (by - ay) / L
  nx = -uy
  ny = ux
  mx = (ax + bx) / 2
  my = (ay + by) / 2
  if self~pt(mx + nx * 1.5, my + ny * 1.5, c, limit) == "C" then sg = 1
  else do
    if self~pt(mx - nx * 1.5, my - ny * 1.5, c, limit) == "C" then sg = -1
    else return .nil
  end
  nx = nx * sg
  ny = ny * sg
  ox = ax - nx * 0.5
  oy = ay - ny * 0.5
  lastC = 0
  defer = 0
  maxD = W + H
  do d = 1 to maxD
    parse value self~across(ox, oy, ux, uy, nx, ny, L, d, c, limit) with cnt al cc bgc
    if cnt = 0 then leave
    /* a gap of other colours wider than my colour so far: the next of my colour is an other band */
    if d - lastC > max(lastC, 3) then leave
    if al / cnt < 0.7 then do
      /* stopped by an other colour: is my colour on the other side of it? */
      if bgc / cnt < 0.5 then do
        do d2 = d + 1 to d + 2 * max(lastC, 4) + 10
          parse value self~across(ox, oy, ux, uy, nx, ny, L, d2, c, limit) with cnt2 al2 cc2 bgc2
          if cnt2 = 0 then leave
          if cc2 / cnt2 >= 0.5 then do
            defer = 1
            leave
          end
          if bgc2 / cnt2 >= 0.5 then leave
        end
      end
      leave
    end
    if cc / cnt >= 0.5 then lastC = d
  end
  if lastC < 1 then return .nil
  T = lastC
  /* behind the side: an other colour, then my colour again? then I am under it, wait */
  if defer = 0 then do
    do d = 1 to 2 * max(T, 4) + 10
      parse value self~across(ox, oy, ux, uy, -nx, -ny, L, d, c, limit) with cnt al cc bgc
      if cnt = 0 then leave
      if bgc / cnt >= 0.5 then leave
      if cc / cnt >= 0.5 then do
        if d > 2 then defer = 1
        leave
      end
    end
  end
  cx = ox + nx * T / 2 + ux * L / 2
  cy = oy + ny * T / 2 + uy * L / 2
  ends = .array~new
  offs = .array~of(-0.4, -0.2, 0, 0.2, 0.4)
  do sg over .array~of(1, -1)
    lastS = 0
    reached = .false
    s = 0
    do s = 1 to maxD by 2
      bad = .false
      out = .false
      anyC = .false
      do o over offs
        k = self~pt(cx + ux * sg * s + nx * o * T, cy + uy * sg * s + ny * o * T, c, limit)
        if k == "O" then out = .true
        else if k == "C" then anyC = .true
        else if k \== "A" then bad = .true
      end
      if out then do
        reached = .true
        leave
      end
      if bad then do
        /* my colour on the other side of it? then it may be on top of me: wait */
        if defer = 0 then do
          do s3 = s + 2 to s + max(3 * T, 0.3 * H) by 2
            k = self~pt(cx + ux * sg * s3, cy + uy * sg * s3, c, limit)
            if k == "O" | k == "B" then leave
            if k == "C" then do
              defer = 1
              leave
            end
          end
        end
        leave
      end
      if anyC then lastS = s
    end
    if \reached then do
      /* the last place with my colour, to one place */
      do s2 = lastS + 1 to lastS + 2
        anyC = .false
        do o over offs
          if self~pt(cx + ux * sg * s2 + nx * o * T, cy + uy * sg * s2 + ny * o * T, c, limit) == "C" then anyC = .true
        end
        if anyC then lastS = s2
      end
    end
    if reached then ends~append(s + T)
    else ends~append(lastS + 0.5)
  end
  if ends[1] + ends[2] < 2.5 * T then return .nil
  px = cx - ux * ends[2]
  py = cy - uy * ends[2]
  qx = cx + ux * ends[1]
  qy = cy + uy * ends[1]
  half = T / 2
  reg = .directory~new
  reg["KIND"] = "BAND"
  reg["PTS"] = .array~of(px + nx * half, py + ny * half, qx + nx * half, qy + ny * half, qx - nx * half, qy - ny * half, px - nx * half, py - ny * half)
  reg["CONVEX"] = .true
  reg["P"] = px py
  reg["Q"] = qx qy
  reg["T"] = T
  reg["DEFER"] = defer
  return reg

/* 7 places across the side, d places in from it */
::method across
  use arg ox, oy, ux, uy, nx, ny, L, d, c, limit
  cnt = 0
  al = 0
  cc = 0
  bgc = 0
  do i = 0 to 6
    t = 0.15 + i * 0.7 / 6
    k = self~pt(ox + ux * t * L + nx * (d - 0.5), oy + uy * t * L + ny * (d - 0.5), c, limit)
    if k == "O" then iterate
    cnt = cnt + 1
    if k == "C" then do
      cc = cc + 1
      al = al + 1
    end
    else if k == "A" then al = al + 1
    else if k == "B" then bgc = bgc + 1
  end
  return cnt al cc bgc

/* one place: O out of the picture, C my colour, A can be under (between, or on top), B background, X an other colour */
::method pt
  expose W H pix stepOf bg fx0 fy0 fx1 fy1
  use arg x, y, c, limit
  if x < fx0 | y < fy0 | x >= fx1 | y >= fy1 then return "O"
  p = trunc(y) * W + trunc(x) + 1
  ch = substr(pix, p, 1)
  if ch == c then return "C"
  if ch == "00"x then return "A"
  s = stepOf[p]
  if s \== .nil then if s < limit then return "A"
  if ch == bg then return "B"
  return "X"

/* count (or mark) the places in a region */
::method scan
  expose W H pix stepOf comp remain fx0 fy0 fx1 fy1 coverOf comps
  use arg reg, c, mode, limit, mark
  pts = reg["PTS"]
  n = pts~items % 2
  xmin = 1e9
  xmax = -1e9
  ymin = 1e9
  ymax = -1e9
  do i = 1 to n
    xmin = min(xmin, pts[2 * i - 1])
    xmax = max(xmax, pts[2 * i - 1])
    ymin = min(ymin, pts[2 * i])
    ymax = max(ymax, pts[2 * i])
  end
  y0 = max(fy0, fl(ymin))
  y1 = min(fy1 - 1, fl(ymax))
  x0 = max(fx0, fl(xmin))
  x1 = min(fx1 - 1, fl(xmax))
  if y1 < y0 | x1 < x0 then return 0 0 0
  st = 1
  if mode \== "MARK" then do
    area = (x1 - x0 + 1) * (y1 - y0 + 1)
    do while area / (st * st) > 1000
      st = st + 1
    end
  end
  reg["ST"] = st
  convex = reg["CONVEX"]
  ring = reg["KIND"] = "RING"
  if ring then parse value reg["INNER"] with ix0 iy0 ix1 iy1
  marking = (mode == "MARK")
  total = 0
  allowed = 0
  newc = 0
  block = 0
  do y = y0 to y1 by st
    yc = y + 0.5
    xs = x0
    xe = x1
    if convex then do
      lo = 1e9
      hi = -1e9
      do i = 1 to n
        j = i // n + 1
        xa = pts[2 * i - 1]
        ya = pts[2 * i]
        xb = pts[2 * j - 1]
        yb = pts[2 * j]
        if ya = yb then do
          if ya = yc then do
            lo = min(lo, xa, xb)
            hi = max(hi, xa, xb)
          end
          iterate
        end
        if yc < min(ya, yb) then iterate
        if yc > max(ya, yb) then iterate
        xi = xa + (yc - ya) * (xb - xa) / (yb - ya)
        lo = min(lo, xi)
        hi = max(hi, xi)
      end
      if lo > hi then iterate
      xs = max(x0, ce(lo - 0.5))
      xe = min(x1, fl(hi - 0.5))
    end
    base = y * W
    do x = xs to xe by st
      if \convex then do
        if \inPoly(x + 0.5, yc, pts) then iterate
      end
      if ring then do
        if x + 0.5 > ix0 then if x + 0.5 < ix1 then if yc > iy0 then if yc < iy1 then iterate
      end
      p = base + x + 1
      total = total + 1
      ch = substr(pix, p, 1)
      s = stepOf[p]
      cov = coverOf[p]
      if marking then if cov == .nil then coverOf[p] = mark
      if ch == c then do
        allowed = allowed + 1
        /* a place under a shape on top of me is not mine to say: it can not be seen */
        if s == .nil then if cov == .nil then do
          newc = newc + 1
          if marking then do
            stepOf[p] = mark
            id = comp[p]
            remain[id] = remain[id] - 1
          end
        end
      end
      else if ch == "00"x then do
        allowed = allowed + 1
        if marking then if s == .nil then stepOf[p] = mark
      end
      else if s \== .nil then do
        if s < limit then allowed = allowed + 1
      end
      else do
        /* a part of an other colour, not said yet: it is on top of me */
        id = comp[p]
        if id \== .nil then if comps[id]["N"] >= 20 then block = block + 1
      end
    end
  end
  reg["BLOCK"] = block
  return total allowed (newc * st * st)

/* ---------------- words ------------------------------------------- */
::method colourCount
  expose pal
  return pal~items

::method shapeCount
  expose shapes writes
  return shapes~items + writes~items

::method leftOver
  expose W H pix stepOf bg
  n = 0
  do p = 1 to W * H
    ch = substr(pix, p, 1)
    if ch == "00"x then iterate
    if ch == bg then iterate
    if stepOf[p] == .nil then n = n + 1
  end
  return n

::method words
  expose W H pal bg shapes writes names inner
  use arg inPic, origW
  names = self~nameColours
  out = .array~new
  out~append("-- Top Rope Slam looked at" filespec("name", inPic) "and says how to draw it.")
  out~append("-- Architecture: Tom Dyer.  Code: Claude (Opus 5.5).")
  out~append("size" unit(W, H) "by 1")
  out~append("page" origW "wide")
  do i = 1 to pal~items
    parse value pal[i] with r g b
    out~append("colour" names[i] "is #" || (d2x(r, 2) || d2x(g, 2) || d2x(b, 2))~lower)
  end
  /* the inner frame: its shapes are a picture of their own */
  ins = .array~new
  if inner \== "" then do
    parse var inner ix0 iy0 ix1 iy1
    out~append("make seen part")
    out~append("  size" unit(ix1 - ix0, iy1 - iy0) "by 1")
    do i = shapes~items to 1 by -1
      if shapes[i]["CAND"]["FRAME"] == inner then out~append("  " || self~lineOf(shapes[i], inner))
    end
    out~append("end")
  end
  out~append("paint all" names[c2d(bg)])
  /* bottom first: the last shape I took off is at the bottom */
  placed = (inner == "")
  do i = shapes~items to 1 by -1
    if shapes[i]["CAND"]["FRAME"] == inner then do
      if \placed then do
        out~append("draw seen part in from" unit(ix0, H) unit(iy0, H) "to" unit(ix1, H) unit(iy1, H))
        placed = .true
      end
      iterate
    end
    out~append(self~lineOf(shapes[i], 0 0 W H))
  end
  do wr over writes
    t = ""
    if wr["TURN"] \= 0 then t = " turn" wr["TURN"]
    out~append("write" names[c2d(wr["C"])] "size" unit(wr["S"], H) "at" unit(wr["X"], H) unit(wr["Y"], H) || t "saying" wr["TEXT"])
  end
  return out

::method lineOf
  expose names
  use arg sh, fr
  parse var fr ox oy ox1 oy1
  W = ox1 - ox
  H = oy1 - oy
  cd = sh["CAND"]
  reg = sh["REG"]
  col = names[c2d(cd["C"])]
  kind = cd["KIND"]
  select
    when kind = "BAND" then do
      parse value reg["P"] with px py
      parse value reg["Q"] with qx qy
      px = px - ox
      qx = qx - ox
      py = py - oy
      qy = qy - oy
      t = reg["T"]
      dx = qx - px
      dy = qy - py
      if abs(dy) <= 0.01 * abs(dx) then do
        if min(px, qx) <= 0 then if max(px, qx) >= W then return "band" col "across at" unit((py + qy) / 2, H) "thick" unit(t, H)
      end
      if abs(dx) <= 0.01 * abs(dy) then do
        if min(py, qy) <= 0 then if max(py, qy) >= H then return "band" col "down at" unit((px + qx) / 2, H) "thick" unit(t, H)
      end
      return "band" col "from" unit(px, H) unit(py, H) "to" unit(qx, H) unit(qy, H) "thick" unit(t, H)
    end
    when kind = "BOX" then do
      parse value reg["BOX"] with x0 y0 x1 y1
      x0 = x0 - ox
      x1 = x1 - ox
      y0 = y0 - oy
      y1 = y1 - oy
      r = cd["ROUND"]
      if r = 0 then do
        if x0 <= 0 then if x1 >= W then return "band" col "across at" unit((y0 + y1) / 2, H) "thick" unit(y1 - y0, H)
        if y0 <= 0 then if y1 >= H then return "band" col "down at" unit((x0 + x1) / 2, H) "thick" unit(x1 - x0, H)
        return "box" col "from" unit(x0, H) unit(y0, H) "to" unit(x1, H) unit(y1, H)
      end
      return "box" col "from" unit(x0, H) unit(y0, H) "to" unit(x1, H) unit(y1, H) "round" unit(r, H)
    end
    when kind = "RING" then do
      parse value cd["BOX"] with x0 y0 x1 y1
      x0 = x0 - ox
      x1 = x1 - ox
      y0 = y0 - oy
      y1 = y1 - oy
      t = cd["T"]
      half = t / 2
      s = "box none from" unit(x0 + half, H) unit(y0 + half, H) "to" unit(x1 - half, H) unit(y1 - half, H)
      if cd["ROUND"] > 0 then s = s "round" unit(max(cd["ROUND"] - half, 0), H)
      return s "edge" col "thick" unit(t, H)
    end
    when kind = "STAR" then do
      s = "star" cd["N"] "points" col "size" unit(2 * cd["R"], H) "inner" frac(cd["INNER"], 0.02) "at" unit(cd["X"] - ox, H) unit(cd["Y"] - oy, H)
      if abs(cd["TURN"]) >= 1.5 then s = s "turn" format(cd["TURN"], , 0)
      return s
    end
    when kind = "CIRCLE" then return "circle" col "size" unit(2 * cd["R"], H) "at" unit(cd["X"] - ox, H) unit(cd["Y"] - oy, H)
    otherwise do
      pts = cd["PTS"]
      s = "shape" col "from" unit(pts[1] - ox, H) unit(pts[2] - oy, H)
      do i = 3 to pts~items by 2
        s = s "to" unit(pts[i] - ox, H) unit(pts[i + 1] - oy, H)
      end
      return s
    end
  end

/* each colour gets the name of the plain colour it is nearest to */
::method nameColours
  expose pal
  book = .array~of("white 255 255 255", "black 0 0 0", "red 200 16 46", "navy 1 33 105", "blue 0 87 184", "sky 142 202 230", "green 0 155 58", "gold 255 184 28", "yellow 255 205 0", "orange 255 130 0", "grey 138 141 143", "cream 253 246 227", "brown 120 80 40", "purple 110 40 140", "pink 240 150 180")
  used = .directory~new
  names = .array~new
  do e over pal
    parse var e r g b
    best = ""
    bestD = 1e9
    do bk over book
      parse var bk nm r2 g2 b2
      d = (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2
      if d < bestD then do
        bestD = d
        best = nm
      end
    end
    if used~hasIndex(best) then do
      used[best] = used[best] + 1
      best = best || used[best]
    end
    else used[best] = 1
    names~append("seen" || best)
  end
  return names

/* ---------------- reading the writing ----------------------------- */
/* As V5V: the writing was found in the small picture; now only those */
/* squares are fetched from the picture at its own size, and read.    */
/* Jiggle: each square is read turned a few ways; the way with the    */
/* nearest glyphs wins. The ways that win most are tried first next   */
/* time (lessons: a count for each way, as a prior).                  */
::method readWriting
  expose W H writes
  use arg master, origW, origH, reader, hintCall, lessonsFile
  if writes~items = 0 then return
  wins = .directory~new
  if SysFileExists(lessonsFile) then do
    s = .stream~new(lessonsFile)
    rows = s~arrayIn
    s~close
    do r over rows
      if left(r, 1) = "#" then iterate
      parse var r a n .
      if datatype(n, "W") then wins[a] = n
    end
  end
  sx = origW / W
  sy = origH / H
  do wr over writes
    parse value wr["BOX"] with gx0 gy0 gx1 gy1
    pad = 0.35 * min(gx1 - gx0 + 1, gy1 - gy0 + 1)
    x0 = max(0, trunc((gx0 - pad) * sx))
    y0 = max(0, trunc((gy0 - pad) * sy))
    x1 = min(origW - 1, trunc((gx1 + 1 + pad) * sx))
    y1 = min(origH - 1, trunc((gy1 + 1 + pad) * sy))
    if wr["UP"] then do
      base = .array~of(90, 270)
      ways = .array~of(88, 92, 268, 272)
    end
    else do
      base = .array~of(0)
      ways = .array~of(2, -2, 4, -4, 180)
    end
    base = base~sortWith(.MostWins~new(wins))
    ways = ways~sortWith(.MostWins~new(wins))
    best = 1e9
    bestText = "?"
    bestWay = 0
    bestWords = .nil
    baseBest = 1e9
    all = base~copy
    do a over ways
      all~append(a)
    end
    do a over all
      /* the square from the master in memory (grey), turned: no picture read again */
      parse value master~square(x0, y0, x1, y1, a) with tw th .
      if tw = 0 then iterate
      wordsIn = reader~readWords(.local~squareData, tw, 0, 0, tw - 1, th - 1, 1)
      n = 0
      sum = 0
      unsure = 0
      do wd over wordsIn
        do m over wd
          n = n + 1
          sum = sum + m["ANYD"]
          if m["ANYD"] > 0.35 then unsure = unsure + 1
        end
      end
      if n = 0 then iterate
      score = sum / n + 0.5 * unsure / n
      isBase = (base~index(a) \== .nil)
      if isBase then baseBest = min(baseBest, score)
      /* upright (or the base turn) reads well: no tilt is needed; reads very badly: it is not writing */
      if \isBase then if baseBest < 0.08 then leave
      if \isBase then if baseBest >= 0.25 then leave
      /* an other way must be clearly better than the way writing is most often: not by chance */
      if \isBase then if score >= 0.7 * baseBest then iterate
      if a = 180 then if baseBest < 0.15 then iterate
      if score < best then do
        best = score
        bestWay = a
        bestWords = wordsIn
      end
      if best < 0.04 then leave
    end
    if bestWords == .nil then iterate
    /* glyphs not near any letter learned: this is not writing I can read; say ? */
    if best > 0.2 then iterate
    text = ""
    do wd over bestWords
      if text \== "" then text = text || " "
      text = text || reader~wordText(wd)
    end
    /* the hint is one call for the whole picture: keep this square's words for it */
    wr["WORDS"] = bestWords
    wr["BEST"] = best
    wr["WAY"] = bestWay
    wr["RAW"] = text
  end
  /* the word hint: one call, all the squares (the word list is read one time) */
  answers = .array~new
  if hintCall \== "" then answers = hintAll(reader, writes, hintCall)
  ai = 0
  do wr over writes
    bestWords = wr["WORDS"]
    if bestWords == .nil then iterate
    best = wr["BEST"]
    bestWay = wr["WAY"]
    text = wr["RAW"]
    known = 0
    if hintCall \== "" then do
      out = ""
      do wd over bestWords
        ai = ai + 1
        a = ""
        if ai <= answers~items then a = answers[ai]
        if out \== "" then out = out || " "
        if word(a, 1) == "HINT" then out = out || word(a, 2)
        else out = out || reader~wordText(wd)
        if wordpos(word(a, 1), "HINT WORD") > 0 then known = known + 1
      end
      text = out
    end
    if value("TOPROPE_DEBUG", , "ENVIRONMENT") == "read" then say "read" format(best, , 3) "way" bestWay "known" known "of" bestWords~items ":" text
    /* writing, when the glyphs are very near; or near, and the word list knows half the words */
    /* one or two glyphs can be a shape that looks like a letter: the word list must know it */
    glyphCount = 0
    do wd over bestWords
      glyphCount = glyphCount + wd~items
    end
    sure = (best < 0.08) & (glyphCount >= 3)
    if \sure then if best < 0.2 then if hintCall \== "" then if known >= max(1, bestWords~items / 2) then sure = .true
    if \sure then iterate
    wr["TEXT"] = text
    /* read turned by a, so it is drawn turned by -a */
    t = (360 - bestWay) // 360
    if t > 180 then t = t - 360
    wr["TURN"] = t
    /* a lesson only from a reading that is sure */
    if best < 0.08 then do
      if wins[bestWay] == .nil then wins[bestWay] = 0
      wins[bestWay] = wins[bestWay] + 1
    end
  end
  s = .stream~new(lessonsFile)
  s~open("write replace")
  s~lineout("# Top Rope Slam lessons: how many times each way of turning writing read best")
  do a over wins
    s~lineout(a wins[a])
  end
  s~close

/* a square of the picture at its own size, turned by a degrees; its data is in .local~ropeData */
::method turnedSquare
  use arg inPic, x0, y0, x1, y1, a
  f = "/tmp/toprope_sq_" || random(1, 999999) || ".ppm"
  geom = (x1 - x0 + 1) || "x" || (y1 - y0 + 1) || "+" || x0 || "+" || y0
  address system 'convert "'inPic'" -background white -alpha remove -alpha off -crop' geom '+repage -rotate' a 'ppm:"'f'"'
  if \SysFileExists(f) then return 0 0
  sq = .SlamSee~new
  sq~loadPpm(f)
  call SysFileDelete f
  .local~ropeData = sq~rawData
  return sq~W sq~H

/* ---------------- 5. the test ------------------------------------- */
::method verify
  expose W H pix cache
  use arg wordsFile, drawer
  svg = "/tmp/toprope_check_" || random(1, 999999)
  address system 'rexx "'drawer'" "'wordsFile'" "'svg'.svg" > /dev/null'
  if \SysFileExists(svg".svg") then return "(I could not draw my words again)"
  address system 'command -v rsvg-convert > /dev/null'
  if rc = 0 then address system 'rsvg-convert -w' W '-h' H '-b white "'svg'.svg" -o "'svg'.png"'
  else address system 'convert -background white "'svg'.svg" -resize' W'x'H'! "'svg'.png"'
  address system 'convert "'svg'.png" -background white -alpha remove -alpha off ppm:"'svg'.ppm"'
  if \SysFileExists(svg".ppm") then return "(I could not turn my drawing into a PPM)"
  other = .SlamSee~new
  other~loadPpm(svg".ppm")
  data2 = other~rawData
  call SysFileDelete svg".svg"
  call SysFileDelete svg".png"
  call SysFileDelete svg".ppm"
  if other~W \= W | other~H \= H then return "(my drawing is" other~W "by" other~H", not" W "by" H")"
  same = 0
  all = 0
  do p = 1 to W * H
    a = substr(pix, p, 1)
    if a == "00"x then iterate
    k = substr(data2, p * 3 - 2, 3)
    v = cache[k]
    if v == .nil then do
      v = self~nearest(k)
      cache[k] = v
    end
    if v == "00"x then iterate
    all = all + 1
    if v == a then same = same + 1
  end
  if all = 0 then return "0%"
  return format(100 * same / all, , 2) || "%"

::method rawData
  expose data
  return data

/* The test, in V5V (Tom Dyer's codec), as it is made to be used: two modes.
   Low resolution: the picture and my drawing, each a V5V frame at half the working size; the
   delta between them says how many points changed, and where (change regions).
   High quality, only for detail: each change region of 3 points or more is a high-resolution
   request on the master; my drawing is drawn at the master's size there, and the places are
   counted one by one.  Regions of 1 or 2 points are the edge moving by a place: said as such. */
::method verifyV5V
  expose W H pix cache pal bpp
  use arg wordsFile, drawer, master, inPic
  v5vDir = value("V5V_DIR", , "ENVIRONMENT")
  /* Tom's V5V codec beside this package in the repo, or V5V_DIR       */
  if v5vDir = "" then v5vDir = filespec("location", .context~package~name) || "../../oorexx_vision/src"
  if \SysFileExists(v5vDir"/V5VCodec.cls") then return "(no V5V codec in" v5vDir": set V5V_DIR) " || self~verify(wordsFile, drawer)
  .context~package~loadPackage(v5vDir"/V5VCodec.cls")
  .context~package~loadPackage(v5vDir"/VisionHighResolutionRequest.cls")
  lw = W % 2
  lh = H % 2
  svg = "/tmp/toprope_v5v_" || random(1, 999999)
  address system 'rexx "'drawer'" "'wordsFile'" "'svg'.svg" > /dev/null'
  if \SysFileExists(svg".svg") then return "(I could not draw my words again)"
  address system 'rsvg-convert -w' lw '-h' lh '-b white "'svg'.svg" -o "'svg'_low.png"'
  low = .Master~new(svg"_low.png")
  /* the values of a point: the colour it is near (1..n), or 0 between colours */
  values = pal~items + 1
  bits = 1
  do while 2 ** bits < values
    bits = bits + 1
  end
  key = .VisionSurface~new(lw, lh, bits, values)
  frame = .VisionSurface~new(lw, lh, bits, values)
  key~timestamp = 0
  frame~timestamp = 1
  key~sourceRef = inPic
  if bpp = 1 then lowData = low~grey
  else lowData = low~rgb
  counted = 0
  do y = 0 to lh - 1
    do x = 0 to lw - 1
      a = c2d(substr(pix, (2 * y) * W + 2 * x + 1, 1))
      if a = 0 then iterate
      k = substr(lowData, (y * lw + x) * bpp + 1, bpp)
      v = cache[k]
      if v == .nil then do
        v = self~nearest(k)
        cache[k] = v
      end
      i = y * lw + x
      key~packed~put(i, a)
      frame~packed~put(i, c2d(v))
      counted = counted + 1
    end
  end
  codec = .V5VTemporalCodec~new
  codec~encodeSurface(key)
  rec = codec~encodeSurface(frame)
  changed = rec~changedCount
  regions = .VisionChangeRegionExtractor~new(8, 1)~extract(rec~payload)
  /* high quality, only where there is detail to look at */
  big = .array~new
  jitter = 0
  do r over regions
    if r~cellCount < 3 then jitter = jitter + r~cellCount
    else big~append(r)
  end
  good = counted - changed
  hiSame = 0
  hiAll = 0
  requests = 0
  if big~items > 0 then do
    address system 'rsvg-convert -w' master~W '-h' master~H '-b white "'svg'.svg" -o "'svg'_full.png"'
    full = .Master~new(svg"_full.png")
    sx = master~W / lw
    sy = master~H / lh
    if bpp = 1 then do
      mData = master~grey
      fData = full~grey
    end
    else do
      mData = master~rgb
      fData = full~rgb
    end
    do r over big
      reg = .VisionRegion~new(trunc(r~x * sx), trunc(r~y * sy), max(1, trunc(r~width * sx)), max(1, trunc(r~height * sy)))
      req = .VisionHighResolutionRequest~new(inPic, reg, 0, 1, "TOP_ROPE_CHECK")
      requests = requests + 1
      same = 0
      all = 0
      do y = reg~y to min(master~H - 1, reg~y + reg~height - 1)
        do x = reg~x to min(master~W - 1, reg~x + reg~width - 1)
          k1 = substr(mData, (y * master~W + x) * bpp + 1, bpp)
          k2 = substr(fData, (y * master~W + x) * bpp + 1, bpp)
          v1 = cache[k1]
          if v1 == .nil then do
            v1 = self~nearest(k1)
            cache[k1] = v1
          end
          if v1 == "00"x then iterate
          v2 = cache[k2]
          if v2 == .nil then do
            v2 = self~nearest(k2)
            cache[k2] = v2
          end
          all = all + 1
          if v1 == v2 then same = same + 1
        end
      end
      req~markFulfilled(same "of" all)
      hiSame = hiSame + same
      hiAll = hiAll + all
      if hiAll > 0 then nop
      /* the region's points count as the part of them that is the same at high resolution */
      if all > 0 then good = good + r~cellCount * same / all
    end
    call SysFileDelete svg"_full.png"
  end
  call SysFileDelete svg".svg"
  call SysFileDelete svg"_low.png"
  if counted = 0 then return "0%"
  out = format(100 * good / counted, , 2) || "% the same."
  out = out "Low:" counted "points," changed "changed in" regions~items "regions;"
  out = out jitter "points are an edge moved by one place; high resolution asked for" requests "regions"
  if hiAll > 0 then out = out "(" || format(100 * hiSame / hiAll, , 1) || "% the same there)"
  return out || "."


/* ================================================================== */
::routine countFrame
  use arg frame, ch
  i = c2d(ch)
  if i > 0 then frame[i] = frame[i] + 1

::routine findRoot
  use arg up, i
  do while up[i] \= i
    i = up[i]
  end
  return i

::routine fl
  use arg v
  t = trunc(v)
  if v < 0 then if t \= v then t = t - 1
  return t

::routine ce
  use arg v
  t = trunc(v)
  if v > 0 then if t \= v then t = t + 1
  return t

::routine atan2
  use arg y, x
  if x = 0 then do
    if y > 0 then return 90
    if y < 0 then return -90
    return 0
  end
  a = RxCalcArcTan(y / x, 9)
  if x < 0 then do
    if y >= 0 then a = a + 180
    else a = a - 180
  end
  return a

::routine inPoly
  use arg x, y, pts
  n = pts~items % 2
  inside = .false
  j = n
  do i = 1 to n
    xi = pts[2 * i - 1]
    yi = pts[2 * i]
    xj = pts[2 * j - 1]
    yj = pts[2 * j]
    if (yi > y) \= (yj > y) then do
      xc = xi + (y - yi) * (xj - xi) / (yj - yi)
      if x < xc then inside = \inside
    end
    j = i
  end
  return inside

::routine starPoly
  use arg cx, cy, big, inner, n, turn
  out = .array~new
  do k = 0 to 2 * n - 1
    a = -90 + turn + k * 180 / n
    if k // 2 = 0 then r = big
    else r = big * inner
    out~append(cx + r * RxCalcCos(a, 9))
    out~append(cy + r * RxCalcSin(a, 9))
  end
  return out

::routine circlePoly
  use arg cx, cy, r, m
  out = .array~new
  do k = 0 to m - 1
    a = k * 360 / m
    out~append(cx + r * RxCalcCos(a, 9))
    out~append(cy + r * RxCalcSin(a, 9))
  end
  return out

/* a length in units (the height is 1): a plain fraction when one is close */
::routine unit
  use arg v, h
  return frac(v / h, 0.0025)

::routine frac
  use arg u, tol
  do q = 1 to 12
    p = format(u * q, , 0)
    if abs(u - p / q) <= tol then do
      if q = 1 then return p
      return p || "/" || q
    end
  end
  s = format(u, , 3)
  if pos(".", s) > 0 then s = strip(strip(s, "T", "0"), "T", ".")
  if s = "-0" then s = "0"
  return s

::requires "rxmath" LIBRARY


::class LastFirst
::method compare
  use arg a, b
  la = a["LAST"]
  lb = b["LAST"]
  if la == .nil then la = 1e9
  if lb == .nil then lb = 1e9
  if la > lb then return -1
  if la < lb then return 1
  return 0

/* how many places one sample stands for */
::routine st2
  use arg reg
  st = reg["ST"]
  if st == .nil then return 1
  return st * st

/* the ways that won most first */
::class MostWins
::method init
  expose wins
  use arg wins
::method compare
  expose wins
  use arg a, b
  na = wins[a]
  nb = wins[b]
  if na == .nil then na = 0
  if nb == .nil then nb = 0
  if na > nb then return -1
  if na < nb then return 1
  return 0

/* the words, with the word hint call (an other program) */
::routine hintWords
  use arg reader, wordsIn, hintCall
  f = "/tmp/toprope_hint_" || random(1, 999999)
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
    if wordpos(word(a, 1), "HINT WORD") > 0 then .local~ropeKnown = .local~ropeKnown + 1
  end
  return out

::requires "glyphs.cls"
::requires "master.cls"

/* the hint for all the squares of a picture: one call; one answer a word, in order */
::routine hintAll
  use arg reader, writes, hintCall
  f = "/tmp/toprope_hint_" || random(1, 999999)
  s = .stream~new(f".in")
  s~open("write replace")
  n = 0
  do wr over writes
    if wr["WORDS"] == .nil then iterate
    do wd over wr["WORDS"]
      s~lineout(reader~lattice(wd))
      n = n + 1
    end
  end
  s~close
  out = .array~new
  if n = 0 then return out
  address system hintCall '< "'f'.in"' with output stem ans.
  call SysFileDelete f".in"
  do i = 1 to ans.0
    out~append(ans.i)
  end
  return out
