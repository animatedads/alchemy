/* ------------------------------------------------------------------ */
/* stitch.cls -- SLAM's stitching tools                                */
/*                                                                    */
/* Architecture : Tom Dyer (make the shapes in each picture first,    */
/*                then fit, then merge; V5V dual mode: low resolution */
/*                first, detail only where asked; SLAM learns from    */
/*                what worked)                                        */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* The tools                                                          */
/*   readPicture  a picture as kinds (water "w", land "l") in cells   */
/*   cleanKinds   small specks (boats, pools) take the kind round them*/
/*   blobsOf      the islands and lakes: size, middle, shape print    */
/*   blobPairs    islands that look alike give a guess: zoom and move */
/*   levelOf      the kinds in bigger cells (for the low pass)        */
/*   resample     a closer picture seen k times smaller               */
/*   search       slide one over the other; kappa says how well       */
/*   fitAt        check one guess and make it better close by         */
/*   readLessons / writeLessons   what SLAM learned last time         */
/* ------------------------------------------------------------------ */

::requires "rxmath" LIBRARY
::requires "master.cls"

/* ================================================================== */
/* a picture as kinds                                                 */
/* ================================================================== */
::routine readPicture public
  use arg file, wide, lesson
  m = .Master~new(file)
  f = max(1, m~W % wide)
  WW = m~W % f
  /* screen furniture: rows at the bottom that are not the earth      */
  cutBottom = lesson~bottom
  if cutBottom == .nil then cutBottom = 0
  HH = (m~H - cutBottom) % f
  rgb = m~rgb
  FW = m~W
  half = max(1, f % 2)
  /* learn this picture's water: the most common bluish colour (blue  */
  /* above red, not greener than blue) is the water; its brightness   */
  /* tells water from other blue things. Navy from the sky, cyan on   */
  /* Google's map, pale blue on the NSW map: one rule, learned        */
  tally = .directory~new
  exact = .directory~new
  nBlue = 0
  do p = 1 to FW * (HH * f) * 3 by 3 * 7
    r = c2d(substr(rgb, p, 1))
    g = c2d(substr(rgb, p + 1, 1))
    b = c2d(substr(rgb, p + 2, 1))
    if b - r >= 8 & g - r >= 6 & b >= g - 8 then do
      q = (r % 16) (g % 16) (b % 16)
      if tally[q] == .nil then tally[q] = 0
      tally[q] = tally[q] + 1
      e = r g b
      if exact[e] == .nil then exact[e] = 0
      exact[e] = exact[e] + 1
      nBlue = nBlue + 1
    end
  end
  /* a flat map (the NSW Planning Portal, Google's map) paints all its */
  /* water one colour: when one exact colour is half the bluish places */
  /* or more, that colour is the water, and other blues (lavender and  */
  /* pale blue zones) are land. Pictures of the earth (satellite) have */
  /* no such colour and keep the brightness rule                       */
  lesson~waterRGB = .nil
  en = 0
  ek = ""
  do e over exact
    if exact[e] > en then do
      en = exact[e]
      ek = e
    end
  end
  if nBlue > 0 then if en / nBlue >= 0.5 then lesson~waterRGB = ek
  top = ""
  tn = 0
  do q over tally
    if tally[q] > tn then do
      tn = tally[q]
      top = q
    end
  end
  if top \== "" then do
    parse var top qr qg qb
    lesson~waterLuma = (0.299 * qr + 0.587 * qg + 0.114 * qb) * 16 + 8
  end
  else lesson~waterLuma = .nil
  memo = .directory~new
  kinds = .array~new(WW * HH)
  grey = .array~new(WW * HH)
  i = 0
  do y = 0 to HH - 1
    do x = 0 to WW - 1
      nw = 0
      gs = 0
      do dy = 0 to f - 1 by half
        do dx = 0 to f - 1 by half
          k = substr(rgb, ((y * f + dy) * FW + x * f + dx) * 3 + 1, 3)
          c = memo[k]
          if c == .nil then do
            r = c2d(substr(k, 1, 1))
            g = c2d(substr(k, 2, 1))
            b = c2d(substr(k, 3, 1))
            c = waterRule(r, g, b, lesson) ((r + g + b) % 3)
            memo[k] = c
          end
          if word(c, 1) == "w" then nw = nw + 1
          gs = gs + word(c, 2)
        end
      end
      n = ((f - 1) % half + 1) ** 2
      i = i + 1
      if nw * 2 >= n then kinds[i] = "w"
      else kinds[i] = "l"
      grey[i] = gs % n
    end
  end
  pc = .directory~new
  pc~file = file
  pc~name = filespec("name", file)
  pc~f = f
  pc~W = WW
  pc~H = HH
  pc~fullW = m~W
  pc~fullH = m~H - cutBottom
  pc~kinds = kinds
  pc~grey = grey
  pc~waterLuma = lesson~waterLuma
  pc~waterRGB = lesson~waterRGB
  /* busy: how much the land changes from one place to the next. A    */
  /* wider picture has more things in each place, so its land is      */
  /* busier: this says which of two pictures is the wider one         */
  bs = 0
  nb = 0
  do y = 0 to HH - 1
    do x = 0 to WW - 2
      i = y * WW + x + 1
      if kinds[i] == "l" then if kinds[i + 1] == "l" then do
        bs = bs + abs(grey[i + 1] - grey[i])
        nb = nb + 1
      end
    end
  end
  if nb = 0 then pc~busy = 0
  else pc~busy = bs / nb
  return pc

/* water: blue and green above red, and not greener than blue. Navy   */
/* and teal shallows both pass; trees (green) and towns (grey) do not */
::routine waterRule public
  use arg r, g, b, lesson
  /* water is above red in green as well as blue: teal harbour water  */
  /* in the NSW aerials (42 50 53), navy and teal from satellites, the */
  /* Planning Portal's 179 230 228. Shadows are blue-black, hardly     */
  /* greener than red (29 32 41); the portal's lavender likewise        */
  if b - r < 8 | g - r < 6 | b < g - 8 then return "l"
  wc = lesson~waterRGB
  if wc \== .nil then do
    parse var wc wr wg wb
    if abs(r - wr) + abs(g - wg) + abs(b - wb) <= 30 then return "w"
    return "l"
  end
  wl = lesson~waterLuma
  if wl == .nil then do
    if r < 130 then return "w"
    return "l"
  end
  /* dark water (aerials) gets a tighter brightness band, so blue-grey */
  /* roofs do not pass for it                                          */
  tol = 60
  if wl < 90 then tol = 35
  if abs(0.299 * r + 0.587 * g + 0.114 * b - wl) <= tol then return "w"
  return "l"

/* ================================================================== */
/* parts that touch (4 ways); each "kind size edge first"             */
/* ================================================================== */
::routine labels public
  use arg cls, WW, HH
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
        if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if x < WW - 1 then do
        q = p + 1
        if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if p > WW then do
        q = p - WW
        if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
      if p + WW <= N then do
        q = p + WW
        if comp[q] == .nil then if cls[q] == c then do; comp[q] = id; st~append(q); end
      end
    end
    info~append(c size edge i)
  end
  return .array~of(comp, info)

/* small specks take the kind round them: a boat on the water, a pool */
/* or a shadow on the land                                            */
::routine cleanKinds public
  use arg pc, minSpeck
  WW = pc~W
  HH = pc~H
  kinds = pc~kinds
  lab = labels(kinds, WW, HH)
  comp = lab[1]
  info = lab[2]
  flipTo = .directory~new
  do id = 1 to info~items
    parse value info[id] with kind size edge first
    if size < minSpeck & edge = 0 then do
      if kind == "w" then flipTo[id] = "l"
      else flipTo[id] = "w"
    end
  end
  if flipTo~items > 0 then do i = 1 to WW * HH
    t = flipTo[comp[i]]
    if t \== .nil then kinds[i] = t
  end
  lab = labels(kinds, WW, HH)
  pc~comp = lab[1]
  pc~info = lab[2]
  return flipTo~items

/* ================================================================== */
/* blobs: islands (land in water) and lakes, not cut by the frame     */
/* each: kind area cx cy n20 n02 n11 n30 n03 n21 n12                  */
/* the n are moments that do not change with the size of the blob,    */
/* so the same island seen at two zooms has the same print            */
/* ================================================================== */
::routine blobsOf public
  use arg pc, minArea
  numeric digits 18
  WW = pc~W
  comp = pc~comp
  info = pc~info
  want = .directory~new
  do id = 1 to info~items
    parse value info[id] with kind size edge first
    if edge = 0 & size >= minArea then want[id] = .array~of(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  end
  do i = 1 to WW * pc~H
    a = want[comp[i]]
    if a == .nil then iterate
    x = (i - 1) // WW + 0.5
    y = (i - 1) % WW + 0.5
    a[1] = a[1] + 1
    a[2] = a[2] + x
    a[3] = a[3] + y
    a[4] = a[4] + x * x
    a[5] = a[5] + y * y
    a[6] = a[6] + x * y
    a[7] = a[7] + x * x * x
    a[8] = a[8] + y * y * y
    a[9] = a[9] + x * x * y
    a[10] = a[10] + x * y * y
  end
  out = .array~new
  do id over want
    a = want[id]
    m00 = a[1]
    cx = a[2] / m00
    cy = a[3] / m00
    u20 = a[4] / m00 - cx * cx
    u02 = a[5] / m00 - cy * cy
    u11 = a[6] / m00 - cx * cy
    u30 = a[7] / m00 - 3 * cx * a[4] / m00 + 2 * cx ** 3
    u03 = a[8] / m00 - 3 * cy * a[5] / m00 + 2 * cy ** 3
    u21 = a[9] / m00 - 2 * cx * a[6] / m00 - cy * a[4] / m00 + 2 * cx * cx * cy
    u12 = a[10] / m00 - 2 * cy * a[6] / m00 - cx * a[5] / m00 + 2 * cx * cy * cy
    /* the moments above are per place; n = mu / m00 ** ((p+q)/2)     */
    s2 = m00
    s3 = m00 * RxCalcSqrt(m00, 18)
    kind = word(info[id], 1)
    out~append(kind m00 fmt(cx) fmt(cy) fmt(u20 / s2) fmt(u02 / s2) fmt(u11 / s2) ,
               fmt(u30 / s3) fmt(u03 / s3) fmt(u21 / s3) fmt(u12 / s3))
  end
  return out

::routine fmt
  return format(arg(1), , 5)

/* how unlike two shape prints are (0 = the same)                     */
::routine printGap public
  use arg a, b
  parse var a . . . . a20 a02 a11 a30 a03 a21 a12
  parse var b . . . . b20 b02 b11 b30 b03 b21 b12
  s = a20 + a02 + b20 + b02
  if s <= 0 then return 9
  d2 = (abs(a20 - b20) + abs(a02 - b02) + abs(a11 - b11)) * 2 / s
  d3 = (abs(a30 - b30) + abs(a03 - b03) + abs(a21 - b21) + abs(a12 - b12)) * 4
  return d2 + d3

/* islands that look alike give a guess. For blob a in A and b in B:  */
/* zoom k = sqrt(area a / area b); the closer picture is the "det",   */
/* the other the "base"; place: u(base) = u(det) / k + t              */
/* gives "votes k tx ty base det" (base and det: "A" or "B")          */
::routine blobPairs public
  use arg blobsA, blobsB, maxGap, kMax
  hyps = .array~new
  do a over blobsA
    do b over blobsB
      if word(a, 1) \== word(b, 1) then iterate
      if printGap(a, b) > maxGap then iterate
      k = RxCalcSqrt(word(a, 2) / word(b, 2), 9)
      if k >= 1 then do
        kk = k
        tx = word(b, 3) - word(a, 3) / kk
        ty = word(b, 4) - word(a, 4) / kk
        bd = "B A"
      end
      else do
        kk = 1 / k
        tx = word(a, 3) - word(b, 3) / kk
        ty = word(a, 4) - word(b, 4) / kk
        bd = "A B"
      end
      if kk > kMax then iterate
      hyps~append(format(kk, , 4) format(tx, , 2) format(ty, , 2) bd)
    end
  end
  /* votes: guesses that agree with each other                        */
  out = .array~new
  do h over hyps
    parse var h k tx ty bd
    v = 0
    do g over hyps
      parse var g k2 tx2 ty2 bd2
      if bd2 \== bd then iterate
      if abs(k2 - k) / k > 0.08 then iterate
      if abs(tx2 - tx) + abs(ty2 - ty) > 6 then iterate
      v = v + 1
    end
    out~append(v h)
  end
  return out~sortWith(.ByFirst~new)

::class ByFirst public
::method compare
  use arg a, b
  if word(a, 1) > word(b, 1) then return -1
  if word(a, 1) < word(b, 1) then return 1
  return 0

/* ================================================================== */
/* the kinds in cells of f: each row a string, "01"x land, "02"x water*/
/* ================================================================== */
::routine levelOf public
  use arg pc, f
  WW = pc~W
  kinds = pc~kinds
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
          if kinds[b + xx] == "w" then n = n + 1
        end
      end
      if n >= half then row = row || "02"x
      else row = row || "01"x
    end
    rows~append(row)
  end
  return rows

::routine resample public
  use arg D, k
  dh = D~items
  dw = length(D[1])
  sh = trunc(dh / k)
  sw = trunc(dw / k)
  if sh < 1 | sw < 1 then return .array~new
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

/* slide S over B. kappa: how much better than chance the two agree,  */
/* for this much water. Gives the 2 best as "kappa tx ty overlap"     */
::routine search public
  use arg Bm, S, tx0, tx1, ty0, ty1, minFrac
  out = .array~new
  if S~items = 0 then return out
  hb = Bm~items
  wb = length(Bm[1])
  hs = S~items
  ws = length(S[1])
  need = minFrac * ws * hs
  b1 = -9
  b2 = -9
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
      if pe >= 0.98 then iterate
      sc = (m / area - pe) / (1 - pe)
      if sc > b1 then do
        if r1 \== "" then if abs(word(r1, 2) - tx) + abs(word(r1, 3) - ty) > 2 then do
          b2 = b1
          r2 = r1
        end
        b1 = sc
        r1 = format(sc, , 4) tx ty format(area / (ws * hs), , 3)
      end
      else if sc > b2 then if abs(word(r1, 2) - tx) + abs(word(r1, 3) - ty) > 2 then do
        b2 = sc
        r2 = format(sc, , 4) tx ty format(area / (ws * hs), , 3)
      end
    end
  end
  if r1 \== "" then out~append(r1)
  if r2 \== "" then out~append(r2)
  return out

/* check one guess and make it better close by: zoom within a few in  */
/* a hundred, place within a few cells. Gives "kappa k tx ty overlap" */
::routine fitAt public
  use arg Bm, Dm, k, tx, ty, kStep, kSpan, tSpan, minFrac
  best = ""
  bs = -9
  do i = -kSpan to kSpan
    kk = k * (1 + i * kStep)
    if kk < 0.99 then iterate
    S = resample(Dm, kk)
    top = search(Bm, S, round(tx) - tSpan, round(tx) + tSpan, round(ty) - tSpan, round(ty) + tSpan, minFrac)
    if top~items = 0 then iterate
    parse value top[1] with sc x y ov
    if sc > bs then do
      bs = sc
      best = sc format(kk, , 4) x y ov
    end
  end
  return best

::routine round public
  use arg v
  if v >= 0 then return trunc(v + 0.5)
  return -trunc(-v + 0.5)

/* ================================================================== */
/* lessons: what worked before. One line each:                        */
/*   zoom <k> <times>     a zoom step seen between two pictures       */
/*   way <islands|search> <times>   how links were found              */
/* ================================================================== */
::routine readLessons public
  use arg file
  ls = .directory~new
  ls~zooms = .directory~new
  ls~ways = .directory~new
  if \SysFileExists(file) then return ls
  s = .stream~new(file)
  s~open("read")
  do while s~lines > 0
    parse value s~linein with what key n .
    if what = "zoom" then ls~zooms[key] = n
    else if what = "way" then ls~ways[key] = n
  end
  s~close
  return ls

::routine writeLessons public
  use arg file, ls
  call SysFileDelete file
  call lineout file, "-- What SLAM learned about stitching. Written by stitch.rex; read the next time."
  call lineout file, "-- zoom <k> <times>: zoom steps seen between two pictures that fit (tried first next time)"
  call lineout file, "-- way <how> <times>: how the fits were found"
  keys = .array~new
  do k over ls~zooms
    keys~append(k)
  end
  do k over keys~sortWith(.ByNumber~new)
    call lineout file, "zoom" k ls~zooms[k]
  end
  do k over ls~ways
    call lineout file, "way" k ls~ways[k]
  end
  call lineout file
  return

::class ByNumber public
::method compare
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0
