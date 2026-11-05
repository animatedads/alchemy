#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* top_rope_chart.rex -- read a flow chart: its steps, its arrows,    */
/*                       and say the logic as steps                   */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:  rexx top_rope_chart.rex <picture> <steps out> [work width]   */
/*       WORD_HINT="rexx word_hint.rex <word list>" for the hint      */
/*                                                                    */
/* How I see a chart (line drawing, not filled shapes):               */
/*  1. paper: the grey seen most. Outside: all paper I can reach from */
/*     the edge of the picture without going over a line. Inside: all */
/*     else (a box is inside its edge, even when its fill is near the */
/*     colour of the paper).                                          */
/*  2. steps (nodes): the parts of inside that are thick (far from    */
/*     outside). Kind: box, round box (start or end), diamond (a      */
/*     question).                                                     */
/*  3. lines: the thin parts of inside. Where a line touches a step,  */
/*     it is joined to that step. The end with the most ink round it  */
/*     has the arrow head: the line goes to that step.                */
/*  4. labels: small thin parts that touch no step are writing (as    */
/*     Yes, No): each goes with the line nearest to it.               */
/*  5. writing: read from the master, at its own size, line by line.  */
/*  6. logic: from START (or a step with no line in), each step one   */
/*     number; a question says where each answer goes; a step with    */
/*     two ways out and no answer on them is said as not clear.      */
/* ------------------------------------------------------------------ */
  parse arg pic outFile workW .
  if outFile = "" then do
    say "Use: rexx top_rope_chart.rex <picture> <steps out> [work width]"
    exit 1
  end
  if workW = "" then workW = 900
  parse source . . me
  home = filespec("location", me)
  signal on syntax name chartError
  call time "R"

  master = .Master~new(pic)
  W0 = master~W
  H0 = master~H
  W = min(workW, W0)
  H = trunc(H0 * W / W0 + 0.5)
  sc = W0 / W
  g = master~shrink(W, H, 1)
  /* colour, only for one thing: is a place paper? (a box fill can be near the paper in grey, not in colour) */
  c = master~shrink(W, H, 3)
  call note "picture" W0 "by" H0", seen at" W "by" H

  /* ---------- 1. paper, outside, inside ---------- */
  counts = .array~new(256)
  do i = 1 to 256
    counts[i] = 0
  end
  do p = 1 to W * H
    v = c2d(substr(g, p, 1))
    counts[v + 1] = counts[v + 1] + 1
  end
  paper = 0
  do i = 1 to 256
    if counts[i] > counts[paper + 1] then paper = i - 1
  end
  ck = .directory~new
  do p = 1 to W * H * 3 by 3
    k = substr(c, p, 3)
    if ck[k] == .nil then ck[k] = 0
    ck[k] = ck[k] + 1
  end
  pk = ""
  pn = 0
  do k over ck
    if ck[k] > pn then do
      pn = ck[k]
      pk = k
    end
  end
  pr = c2d(substr(pk, 1, 1))
  pg = c2d(substr(pk, 2, 1))
  pb = c2d(substr(pk, 3, 1))
  /* how far each place is from the paper, in colour */
  far = .array~new(W * H)
  memo = .directory~new
  do i = 1 to W * H
    k = substr(c, i * 3 - 2, 3)
    v = memo[k]
    if v == .nil then do
      v = RxCalcSqrt((c2d(substr(k, 1, 1)) - pr) ** 2 + (c2d(substr(k, 2, 1)) - pg) ** 2 + (c2d(substr(k, 3, 1)) - pb) ** 2, 6)
      memo[k] = v
    end
    far[i] = v
  end
  tol = 12
  outside = .array~new(W * H)
  stack = .array~new
  sp = 0
  do x = 0 to W - 1
    do y over .array~of(0, H - 1)
      p = y * W + x + 1
      if far[p] <= tol then if outside[p] == .nil then do
        outside[p] = 1
        sp = sp + 1
        stack[sp] = p
      end
    end
  end
  do y = 0 to H - 1
    do x over .array~of(0, W - 1)
      p = y * W + x + 1
      if far[p] <= tol then if outside[p] == .nil then do
        outside[p] = 1
        sp = sp + 1
        stack[sp] = p
      end
    end
  end
  do while sp > 0
    q = stack[sp]
    sp = sp - 1
    y = (q - 1) % W
    x = (q - 1) // W
    do k = 1 to 4
      select
        when k = 1 then do
          if x = 0 then iterate
          r = q - 1
        end
        when k = 2 then do
          if x = W - 1 then iterate
          r = q + 1
        end
        when k = 3 then do
          if y = 0 then iterate
          r = q - W
        end
        otherwise do
          if y = H - 1 then iterate
          r = q + W
        end
      end
      if outside[r] \== .nil then iterate
      if far[r] > tol then iterate
      outside[r] = 1
      sp = sp + 1
      stack[sp] = r
    end
  end
  call note "paper grey" paper", outside found"
  if pos("chart", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do
    no = 0
    do p = 1 to W * H
      if outside[p] == 1 then no = no + 1
    end
    say "  outside" no "of" W * H "; box centre (450,100) outside:" outside[100 * W + 450 + 1] "grey" c2d(substr(g, 100 * W + 451, 1))
    /* the box edge along row 100 */
    t = ""
    do x = 340 to 380
      t = t || (outside[100 * W + x + 1] == 1)
    end
    say "  row 100, x 340..380 outside:" t
    t = ""
    do x = 340 to 380
      t = t c2d(substr(g, 100 * W + x + 1, 1))
    end
    say "  greys:" t
  end

  /* ---------- 2. steps: thick parts of inside (distance to outside, two passes) ---------- */
  /* thick: far from paper (outside, or paper closed in by lines), so a thin line is thin everywhere */
  fillTol = 9
  big = W + H
  dist = .array~new(W * H)
  do p = 1 to W * H
    if outside[p] == 1 then dist[p] = 0
    else if far[p] <= fillTol then dist[p] = 0
    else dist[p] = big
  end
  do y = 0 to H - 1
    do x = 0 to W - 1
      p = y * W + x + 1
      d = dist[p]
      if d = 0 then iterate
      if x > 0 then d = min(d, dist[p - 1] + 1)
      if y > 0 then do
        d = min(d, dist[p - W] + 1)
        if x > 0 then d = min(d, dist[p - W - 1] + 1)
        if x < W - 1 then d = min(d, dist[p - W + 1] + 1)
      end
      dist[p] = d
    end
  end
  do y = H - 1 to 0 by -1
    do x = W - 1 to 0 by -1
      p = y * W + x + 1
      d = dist[p]
      if d = 0 then iterate
      if x < W - 1 then d = min(d, dist[p + 1] + 1)
      if y < H - 1 then do
        d = min(d, dist[p + W] + 1)
        if x < W - 1 then d = min(d, dist[p + W + 1] + 1)
        if x > 0 then d = min(d, dist[p + W - 1] + 1)
      end
      dist[p] = d
    end
  end
  reach = 4
  node = .array~new(W * H)
  nodes = .array~new
  minArea = trunc(0.002 * W * H)
  /* a step is thick, and filled: paper closed in by lines (a loop of arrows) is not a step */
  do p = 1 to W * H
    if dist[p] < reach then iterate
    if node[p] \== .nil then iterate
    if far[p] <= fillTol then iterate
    id = nodes~items + 1
    node[p] = id
    sp = 1
    stack[1] = p
    n = 0
    list = .array~new
    do while sp > 0
      q = stack[sp]
      sp = sp - 1
      n = n + 1
      list~append(q)
      y = (q - 1) % W
      x = (q - 1) // W
      do dy = -1 to 1
        do dx = -1 to 1
          nx = x + dx
          ny = y + dy
          if nx < 0 | ny < 0 | nx >= W | ny >= H then iterate
          r = ny * W + nx + 1
          if dist[r] < reach then iterate
          if node[r] \== .nil then iterate
          if far[r] <= fillTol then iterate
          node[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
    end
    nd = .directory~new
    nd["ID"] = id
    nd["SEED"] = list
    nd["SMALL"] = (n < minArea)
    nodes~append(nd)
  end
  /* small thick bits (an arrow head, a dot) are not steps: let them go back to lines */
  do nd over nodes
    if \nd["SMALL"] then iterate
    do q over nd["SEED"]
      node[q] = .nil
    end
  end
  /* grow each step out to its edge (R + 1 places), only over inside */
  front = .array~new
  do nd over nodes
    if nd["SMALL"] then iterate
    do q over nd["SEED"]
      front~append(q)
    end
  end
  do ring = 1 to reach + 1
    next = .array~new
    do q over front
      id = node[q]
      y = (q - 1) % W
      x = (q - 1) // W
      do dy = -1 to 1
        do dx = -1 to 1
          nx = x + dx
          ny = y + dy
          if nx < 0 | ny < 0 | nx >= W | ny >= H then iterate
          r = ny * W + nx + 1
          if outside[r] == 1 then iterate
          if node[r] \== .nil then iterate
          node[r] = id
          next~append(r)
        end
      end
    end
    front = next
  end
  if pos("chart", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do
    mx = 0
    do p = 1 to W * H
      mx = max(mx, dist[p])
    end
    nsm = 0
    do nd over nodes
      if nd["SMALL"] then nsm = nsm + 1
    end
    say "  deepest" mx "; blobs" nodes~items "small" nsm "; minArea" minArea "; dist at box centre" dist[100 * W + 451]
  end
  if pos("chartmap", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do
    /* the steps (seeds) as a picture: each step a grey, lines and inside 60, outside 255 */
    mb = .mutableBuffer~new
    do p = 1 to W * H
      v = 255
      if outside[p] \== 1 then v = 60
      if node[p] \== .nil then v = 120 + (node[p] * 37) // 120
      mb~append(d2c(v))
    end
    o = .stream~new("/tmp/chart_nodes.pgm")
    o~open("write replace")
    o~charout("P5" W H "255" || "0a"x || mb~string)
    o~close
  end
  steps = .array~new
  do nd over nodes
    if nd["SMALL"] then iterate
    id = nd["ID"]
    x0 = W
    y0 = H
    x1 = -1
    y1 = -1
    n = 0
    do q over nd["SEED"]
      y = (q - 1) % W
      x = (q - 1) // W
      x0 = min(x0, x)
      y0 = min(y0, y)
      x1 = max(x1, x)
      y1 = max(y1, y)
      n = n + 1
    end
    /* the seed is the step less R places all round */
    x0 = max(0, x0 - reach)
    y0 = max(0, y0 - reach)
    x1 = min(W - 1, x1 + reach)
    y1 = min(H - 1, y1 + reach)
    bw = x1 - x0 + 1
    bh = y1 - y0 + 1
    area = 0
    do y = y0 to y1
      do x = x0 to x1
        if node[y * W + x + 1] == id then area = area + 1
      end
    end
    fill = area / (bw * bh)
    /* a corner square: how much of it is not the step */
    cs = max(2, trunc(min(bw, bh) / 4))
    miss = 0
    do y = y0 to y0 + cs - 1
      do x = x0 to x0 + cs - 1
        if node[y * W + x + 1] \== id then miss = miss + 1
      end
    end
    missF = miss / (cs * cs)
    select
      when fill < 0.7 then kind = "QUESTION"
      when missF > 0.5 then kind = "ROUND"
      otherwise kind = "BOX"
    end
    st = .directory~new
    st["ID"] = id
    st["BOX"] = x0 y0 x1 y1
    st["KIND"] = kind
    st["TEXT"] = ""
    st["OUT"] = .array~new
    st["IN"] = .array~new
    steps~append(st)
  end
  byId = .directory~new
  do st over steps
    byId[st["ID"]] = st
  end
  call note steps~items "steps"

  /* ---------- 3. lines: thin parts of inside, not steps ---------- */
  lab = .array~new(W * H)
  parts = .array~new
  do p = 1 to W * H
    if outside[p] == 1 then iterate
    if node[p] \== .nil then iterate
    if lab[p] \== .nil then iterate
    id = parts~items + 1
    lab[p] = id
    sp = 1
    stack[1] = p
    pix = .array~new
    x0 = W
    y0 = H
    x1 = -1
    y1 = -1
    touch = .directory~new
    do while sp > 0
      q = stack[sp]
      sp = sp - 1
      pix~append(q)
      y = (q - 1) % W
      x = (q - 1) // W
      x0 = min(x0, x)
      y0 = min(y0, y)
      x1 = max(x1, x)
      y1 = max(y1, y)
      do dy = -1 to 1
        do dx = -1 to 1
          nx = x + dx
          ny = y + dy
          if nx < 0 | ny < 0 | nx >= W | ny >= H then iterate
          r = ny * W + nx + 1
          if outside[r] == 1 then iterate
          nid = node[r]
          if nid \== .nil then do
            if byId~hasIndex(nid) then do
              t = touch[nid]
              if t == .nil then t = 0 0 0
              parse var t tx ty tn
              touch[nid] = (tx + x) (ty + y) (tn + 1)
            end
            iterate
          end
          if lab[r] \== .nil then iterate
          lab[r] = id
          sp = sp + 1
          stack[sp] = r
        end
      end
    end
    pt = .directory~new
    pt["ID"] = id
    pt["PIX"] = pix
    pt["BOX"] = x0 y0 x1 y1
    pt["TOUCH"] = touch
    parts~append(pt)
  end
  lines = .array~new
  bits = .array~new
  do pt over parts
    if pt["TOUCH"]~items > 0 then lines~append(pt)
    else bits~append(pt)
  end

  /* each line: its ends at steps; the end with the most ink round it has the head */
  edges = .array~new
  do ln over lines
    ends = .array~new
    touch = ln["TOUCH"]
    do nid over touch
      parse value touch[nid] with tx ty tn
      ax = tx / tn
      ay = ty / tn
      ink = 0
      do q over ln["PIX"]
        y = (q - 1) % W
        x = (q - 1) // W
        if (x - ax) ** 2 + (y - ay) ** 2 <= 64 then ink = ink + 1
      end
      e = .directory~new
      e["NODE"] = nid
      e["X"] = ax
      e["Y"] = ay
      e["INK"] = ink
      ends~append(e)
    end
    if ends~items < 2 then iterate
    most = 0
    least = 1e9
    do e over ends
      most = max(most, e["INK"])
      least = min(least, e["INK"])
    end
    heads = .array~new
    tails = .array~new
    /* a head: much more ink than the thinnest end, and near the most */
    do e over ends
      isHead = .false
      if e["INK"] >= 1.4 * least then if e["INK"] >= 0.75 * most then isHead = .true
      if isHead then heads~append(e)
      else tails~append(e)
    end
    if heads~items = ends~items then do
      /* all the same: no head seen */
      ed = .directory~new
      ed["FROM"] = ends[1]["NODE"]
      ed["TO"] = ends[2]["NODE"]
      ed["ARROW"] = .false
      ed["LINE"] = ln
      ed["LABEL"] = ""
      edges~append(ed)
      iterate
    end
    do tl over tails
      do hd over heads
        ed = .directory~new
        ed["FROM"] = tl["NODE"]
        ed["TO"] = hd["NODE"]
        ed["ARROW"] = .true
        ed["LINE"] = ln
        ed["LABEL"] = ""
        edges~append(ed)
      end
    end
  end
  call note lines~items "lines," edges~items "arrows"

  /* ---------- 4. labels: small bits that touch no step, in groups on a line ---------- */
  groups = .array~new
  do b over bits
    parse value b["BOX"] with x0 y0 x1 y1
    if y1 - y0 + 1 > 0.06 * H then iterate
    if x1 - x0 + 1 > 0.2 * W then iterate
    placed = .false
    do gp over groups
      parse value gp["BOX"] with a0 b0 a1 b1
      hgt = max(b1 - b0, y1 - y0) + 1
      if min(b1, y1) - max(b0, y0) < -1 then iterate
      if max(a0, x0) - min(a1, x1) > 0.8 * hgt then iterate
      gp["BOX"] = min(a0, x0) min(b0, y0) max(a1, x1) max(b1, y1)
      placed = .true
      leave
    end
    if \placed then do
      gp = .directory~new
      gp["BOX"] = x0 y0 x1 y1
      groups~append(gp)
    end
  end

  /* ---------- 5. read: each step's writing, line by line, and each label ---------- */
  reader = .GlyphReader~new
  if \reader~load(home || "glyphs.txt") then call fail "I need glyphs.txt: run train_glyphs.rex."
  jobs = .array~new
  do st over steps
    parse value st["BOX"] with x0 y0 x1 y1
    mx = trunc((x1 - x0 + 1) * sc * 0.08)
    my = trunc((y1 - y0 + 1) * sc * 0.12)
    if st["KIND"] = "QUESTION" then do
      mx = trunc((x1 - x0 + 1) * sc * 0.2)
      my = trunc((y1 - y0 + 1) * sc * 0.2)
    end
    rx0 = trunc(x0 * sc) + mx
    ry0 = trunc(y0 * sc) + my
    rx1 = min(W0 - 1, trunc((x1 + 1) * sc) - mx)
    ry1 = min(H0 - 1, trunc((y1 + 1) * sc) - my)
    do ln over textLines(master, rx0, ry0, rx1, ry1)
      parse var ln ly0 ly1
      parse value master~square(rx0, ly0, rx1, ly1, 0) with tw th
      wds = reader~readWords(.local~squareData, tw, 0, 0, tw - 1, th - 1, 1)
      j = .directory~new
      j["FOR"] = st
      j["WORDS"] = wds
      jobs~append(j)
    end
  end
  do gp over groups
    parse value gp["BOX"] with x0 y0 x1 y1
    pad = 2
    rx0 = max(0, trunc((x0 - pad) * sc))
    ry0 = max(0, trunc((y0 - pad) * sc))
    rx1 = min(W0 - 1, trunc((x1 + 1 + pad) * sc))
    ry1 = min(H0 - 1, trunc((y1 + 1 + pad) * sc))
    parse value master~square(rx0, ry0, rx1, ry1, 0) with tw th
    wds = reader~readWords(.local~squareData, tw, 0, 0, tw - 1, th - 1, 1)
    j = .directory~new
    j["FOR"] = gp
    j["WORDS"] = wds
    jobs~append(j)
  end
  /* the word hint: one call for the chart */
  hintCall = value("WORD_HINT", , "ENVIRONMENT")
  answers = .array~new
  if hintCall \== "" then do
    f = "/tmp/chart_hint_" || random(1, 999999)
    s = .stream~new(f".in")
    s~open("write replace")
    do j over jobs
      do wd over j["WORDS"]
        s~lineout(reader~lattice(wd))
      end
    end
    s~close
    address system hintCall '< "'f'.in"' with output stem ans.
    call SysFileDelete f".in"
    do i = 1 to ans.0
      answers~append(ans.i)
    end
  end
  ai = 0
  do j over jobs
    text = ""
    do wd over j["WORDS"]
      ai = ai + 1
      a = ""
      if ai <= answers~items then a = answers[ai]
      if word(a, 1) == "HINT" then w1 = word(a, 2)
      else w1 = reader~wordText(wd)
      /* a word of only ? is a shadow or an edge, not writing */
      if verify(w1, "?") = 0 then iterate
      if text \== "" then text = text || " "
      text = text || w1
    end
    who = j["FOR"]
    if who["TEXT"] == .nil | who["TEXT"] == "" then who["TEXT"] = text
    else who["TEXT"] = who["TEXT"] text
  end

  /* labels go with the nearest line */
  do gp over groups
    if gp["TEXT"] == .nil then iterate
    if gp["TEXT"]~space(0) = "" then iterate
    parse value gp["BOX"] with x0 y0 x1 y1
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    best = .nil
    bestD = 1e9
    do ed over edges
      ln = ed["LINE"]
      do q over ln["PIX"]
        y = (q - 1) % W
        x = (q - 1) // W
        d = (x - cx) ** 2 + (y - cy) ** 2
        if d < bestD then do
          bestD = d
          best = ed
        end
      end
    end
    if best \== .nil then if bestD <= (0.12 * H) ** 2 then best["LABEL"] = gp["TEXT"]
  end
  do ed over edges
    byId[ed["FROM"]]["OUT"]~append(ed)
    byId[ed["TO"]]["IN"]~append(ed)
  end

  if pos("chart", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do
    dbg = "convert" pic "-fill none -strokewidth 6"
    do st over steps
      parse value st["BOX"] with x0 y0 x1 y1
      dbg = dbg "-stroke red -draw ""rectangle" trunc(x0 * sc) trunc(y0 * sc) trunc(x1 * sc) trunc(y1 * sc)""""
      say "  step" st["ID"] st["KIND"] "box" trunc(x0 * sc) trunc(y0 * sc) trunc(x1 * sc) trunc(y1 * sc) ":" st["TEXT"]
    end
    do ed over edges
      say "  edge" ed["FROM"] "->" ed["TO"] "arrow" ed["ARROW"] "label" ed["LABEL"]
    end
    do ln over lines
      touch = ln["TOUCH"]
      t = ""
      do nid over touch
        parse value touch[nid] with tx ty tn
        t = t nid"@"trunc(tx / tn * sc)","trunc(ty / tn * sc)
      end
      parse value ln["BOX"] with x0 y0 x1 y1
      say "  line box" trunc(x0 * sc) trunc(y0 * sc) trunc(x1 * sc) trunc(y1 * sc) "touches" t
    end
    address system dbg "/tmp/chart_debug.png"
  end
  /* ---------- 6. the logic ---------- */
  start = .nil
  do st over steps
    if pos("START", st["TEXT"]~upper) > 0 then do
      start = st
      leave
    end
  end
  if start == .nil then do st over steps
    if st["IN"]~items = 0 then if st["OUT"]~items > 0 then do
      start = st
      leave
    end
  end
  if start == .nil then call fail "I can not find where the chart starts: no START, and each step has a line in."
  order = .array~new
  num = .directory~new
  todo = .array~of(start)
  do while todo~items > 0
    st = todo[todo~items]
    todo~remove(todo~items)
    if num~hasIndex(st["ID"]) then iterate
    order~append(st)
    num[st["ID"]] = order~items
    outs = sortOut(st["OUT"], byId)
    do i = outs~items to 1 by -1
      t = byId[outs[i]["TO"]]
      if \num~hasIndex(t["ID"]) then todo~append(t)
    end
  end
  out = .array~new
  out~append("Logic steps read from" filespec("name", pic) "by Top Rope Slam (chart).")
  out~append("Architecture: Tom Dyer.  Code: Claude (Opus 5.5).")
  out~append("")
  do st over order
    n = num[st["ID"]]
    text = st["TEXT"]~strip
    if text = "" then text = "(no writing I can read)"
    outs = sortOut(st["OUT"], byId)
    labelled = 0
    do ed over outs
      if ed["LABEL"] \== "" then labelled = labelled + 1
    end
    if st["KIND"] = "QUESTION" | labelled > 0 then do
      out~append(n". IF" text)
      do ed over outs
        lbl = ed["LABEL"]
        if lbl = "" then lbl = "(no answer written)"
        out~append("     " || lbl": go to step" num[ed["TO"]])
      end
      iterate
    end
    out~append(n"." text)
    select
      when outs~items = 0 then out~append("     (the end: no line goes out)")
      when outs~items = 1 then do
        m = num[outs[1]["TO"]]
        if m \= n + 1 then out~append("     then go to step" m)
      end
      otherwise do
        list = ""
        do ed over outs
          list = list num[ed["TO"]]
        end
        out~append("     then go to step" strip(list)~changeStr(" ", " AND step") "-- NOT CLEAR: two ways out, and no answer is written on them")
      end
    end
  end
  do ed over edges
    if \ed["ARROW"] then out~append("Note: a line with no arrow head joins step" num[ed["FROM"]] "and step" num[ed["TO"]]".")
  end
  do st over steps
    if \num~hasIndex(st["ID"]) then out~append("Note: a step I can not reach from the start:" st["TEXT"])
  end
  s = .stream~new(outFile)
  s~open("write replace")
  do line over out
    s~lineout(line)
    say line
  end
  s~close
  call note "done"
  exit 0

note:
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "  time:" format(time("E"), , 1) "s:" arg(1)
  return

fail:
  raise syntax 98.900 array (arg(1))

chartError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "Top Rope Slam (chart) stopped." co["ADDITIONAL"][1]
  else say "Top Rope Slam (chart) broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  say "  (rc="rc "sigl="sigl "condition="condition("C") "description="condition("D")")"
  exit 2

/* the lines of writing in a box of the master: rows with ink, split by rows with none */
::routine textLines
  use arg master, x0, y0, x1, y1
  g = master~grey
  W = master~W
  counts = .directory~new
  do y = y0 to y1 by 2
    do x = x0 to x1 by 2
      v = c2d(substr(g, y * W + x + 1, 1))
      if counts[v] == .nil then counts[v] = 0
      counts[v] = counts[v] + 1
    end
  end
  bgv = 0
  bn = -1
  do v over counts
    if counts[v] > bn then do
      bn = counts[v]
      bgv = v
    end
  end
  out = .array~new
  inLine = .false
  do y = y0 to y1
    n = 0
    do x = x0 to x1
      if abs(c2d(substr(g, y * W + x + 1, 1)) - bgv) > 60 then n = n + 1
    end
    full = (n > 0)
    if full then if \inLine then do
      a = y
      inLine = .true
    end
    if \full then if inLine then do
      if y - a >= 4 then out~append(max(y0, a - 2) min(y1, y + 1))
      inLine = .false
    end
  end
  if inLine then if y1 - a >= 4 then out~append(max(y0, a - 2) y1)
  return out

/* the ways out of a step: Yes first, then by where they go (top down, then left to right) */
::routine sortOut
  use arg outs, byId
  list = outs~copy
  do i = 1 to list~items
    do j = i + 1 to list~items
      if before(list[j], list[i], byId) then do
        t = list[i]
        list[i] = list[j]
        list[j] = t
      end
    end
  end
  return list

::routine before
  use arg a, b, byId
  la = a["LABEL"]~lower
  lb = b["LABEL"]~lower
  if la = "yes" then if lb \= "yes" then return .true
  if lb = "yes" then return .false
  parse value byId[a["TO"]]["BOX"] with . ay .
  parse value byId[b["TO"]]["BOX"] with . bY .
  return ay < bY

::requires "master.cls"
::requires "glyphs.cls"
