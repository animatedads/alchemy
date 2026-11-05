/* ------------------------------------------------------------------ */
/* lidar_blocks.rex -- building blocks from LiDAR roof grids           */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* Data         : las_grid.rex words (NSW Government LiDAR, CC BY 4.0) */
/*                                                                    */
/* rexx lidar_blocks.rex blocks.words grid.words [grid.words ...]     */
/*                                                                    */
/* 1 Ground under every cell: the ground returns where there are any; */
/*   under a roof, the ground of the nearest cells that have it.      */
/* 2 A building cell: its top return is a structure and it stands     */
/*   RISE metres or more above the ground. A structure is a building  */
/*   (class 6, kind "b") or any class that is not ground, vegetation, */
/*   water or noise (kind "o"): the NSW 2018 survey leaves 43% of its */
/*   points unclassified (class 1), the tallest towers among them      */
/*   (class 6 stops at 277 m AHD, class 1 reaches 341 m).              */
/* 2a Five of the 2018 tiles (Surry Hills, Darlinghurst, Hyde Park,  */
/*   Redfern) are sorted only into ground, low noise and class 1, so  */
/*   trees there are class 1 too. A roof stops the laser; a tree, a   */
/*   wire or a roof edge lets some through to the ground. So a kind   */
/*   "o" cell that holds a ground return of its own is in no block,   */
/*   unless it touches a roof cell within STEP metres of its top (one */
/*   ring: the roof's edge). Class 6 (kind "b") cells are kept.        */
/* 3 A block: building cells joined side by side whose roofs differ   */
/*   by no more than STEP metres from one to the next, comparing each */
/*   cell's roof as the middle of its 3 by 3 patch (so a mast, a wall */
/*   return or plant does not cut a roof); so a tower on a podium is  */
/*   two blocks, a flat roof with plant on it is one. A piece under   */
/*   MERGE square metres joins the neighbour it shares the longest    */
/*   side with, if that roof is within REACH metres of its own.       */
/*   A cell also joins only if its roof is within DRIFT metres of the */
/*   block's mean so far, so small steps cannot chain across a suburb.*/
/* 3a Streets (optional, BLOCKS_STREETS = a street mask on the same   */
/*   grid, street_to_mga.rex): a cell under a street line is in no    */
/*   block, so city blocks do not join across a road; but not a cell */
/*   STREETH metres or more above ground: the aerials are renders in  */
/*   which towers lean over the street lines.                         */
/* 4 For each block of AREA square metres or more: an oriented box    */
/*   round it (the long side found from how its cells spread), its    */
/*   height (the 90th of 100 roof heights above ground, so a mast     */
/*   does not count), its roof level and ground level (AHD).          */
/* Coordinates: GDA2020 MGA zone 56, as the LiDAR gives them.          */
/* ------------------------------------------------------------------ */
parse arg out grids
if grids = "" then do
  say "usage: rexx lidar_blocks.rex blocks.words grid.words [grid.words ...]"
  exit 2
end
RISE = 3; STEP = 5; AREA = 24; MERGE = 150; REACH = 25; DRIFT = 6; STREETH = 15
streetFile = value("BLOCKS_STREETS", , "ENVIRONMENT")
numeric digits 16
blocks = .array~new
do gf over grids~makeArray(" ")
  if gf = "" then iterate
  call oneGrid gf
end
call SysFileDelete out
call lineout out, "-- Building blocks from LiDAR (NSW Government, CC BY 4.0), by lidar_blocks.rex."
call lineout out, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5)."
call lineout out, "-- A block: building returns" RISE "m or more above ground, joined where roofs step by" STEP "m or less;"
call lineout out, "-- at least" AREA "m2. at: middle (GDA2020 MGA 56). size: long by wide (m), bearing of the long side"
call lineout out, "-- (degrees from grid north). height: 90th of 100 roof heights above ground. roof, ground: AHD."
call lineout out, ""
call lineout out, "blocks sydney"
n = 0
do b over blocks
  n += 1
  call lineout out, "  block" n b
end
call lineout out, "end"
call stream out, "c", "close"
say "wrote" out":" n "blocks"
exit 0

oneGrid:
  use arg gf
  top = .array~new; grd = .array~new; knd = .array~new
  do while lines(gf) > 0
    l = linein(gf)~strip
    w1 = word(l, 1)
    if w1 == "grid" then parse var l "south west" x0 y0 "cell" cell "across" nc "up" nr .
    else if w1 == "top" then top~append(subword(l, 2))
    else if w1 == "ground" then grd~append(subword(l, 2))
    else if w1 == "kind" then knd~append(word(l, 2))
  end
  call stream gf, "c", "close"
  N = nr * nc
  /* cells as arrays, index (row from north) * nc + col + 1           */
  T = .array~new(N); G = .array~new(N); K = .mutableBuffer~new
  do r = 1 to nr
    tr = top[r]; gr = grd[r]
    do c = 1 to nc
      i = (r - 1) * nc + c
      v = word(tr, c); if datatype(v, "N") then T[i] = v
      v = word(gr, c); if datatype(v, "N") then G[i] = v
    end
    K~append(knd[r])
  end
  K = K~string
  /* which cells hold a ground return of their own (before filling)   */
  hasG = .mutableBuffer~new
  do i = 1 to N
    if G[i] == .nil then hasG~append("0"); else hasG~append("1")
  end
  hasG = hasG~string
  /* 1: ground everywhere, from the nearest cells that have it        */
  q = .queue~new
  do i = 1 to N; if G[i] \== .nil then q~queue(i); end
  do while q~items > 0
    i = q~pull
    c = (i - 1) // nc
    do d over .array~of(-1, 1, -nc, nc)
      j = i + d
      if j < 1 | j > N then iterate
      if abs(d) = 1 & (j - 1) % nc \= (i - 1) % nc then iterate
      if G[j] \== .nil then iterate
      G[j] = G[i]; q~queue(j)
    end
  end
  /* the street mask, if given, on the same grid                      */
  street = ""
  if streetFile \== "" then do
    smb = .mutableBuffer~new
    do while lines(streetFile) > 0
      l = linein(streetFile)~strip
      if word(l, 1) == "grid" then do
        parse var l "south west" sx0 sy0 . . "across" snc "up" snr .
        if sx0 \= x0 | sy0 \= y0 | snc \= nc | snr \= nr then raise syntax 88.900 array("street mask grid does not match")
      end
      if word(l, 1) == "row" then smb~append(word(l, 2))
    end
    call stream streetFile, "c", "close"
    street = smb~string
    say "  street mask:" countstr("s", street) "street cells"
  end
  /* 2: building cells                                                */
  isB = .array~new(N)
  nb = 0
  ring = .array~new
  do i = 1 to N
    kc = substr(K, i, 1)
    if pos(kc, "bo") = 0 | T[i] == .nil | G[i] == .nil then iterate
    if T[i] - G[i] < RISE then iterate
    if street \== "" then if substr(street, i, 1) == "s" then if T[i] - G[i] < STREETH then iterate
    if kc == "o" then if substr(hasG, i, 1) == "1" then do; ring~append(i); iterate; end
    isB[i] = 1; nb += 1
  end
  /* 2b: an unsorted cell with ground under it next to a roof cell is  */
  /*   that roof's edge (one ring, roof within STEP); the rest are     */
  /*   trees, wires and the like                                       */
  edge = .array~new
  do i over ring
    do d over .array~of(-1, 1, -nc, nc)
      j = i + d
      if j < 1 | j > N then iterate
      if abs(d) = 1 & (j - 1) % nc \= (i - 1) % nc then iterate
      if isB[j] == .nil then iterate
      if abs(T[j] - T[i]) > STEP then iterate
      edge~append(i); leave
    end
  end
  do i over edge; isB[i] = 1; nb += 1; end
  say "  " ring~items "unsorted cells over ground returns (trees, wires, edges):" edge~items "kept as roof edges"
  /* roof of each building cell as the middle of its 3 by 3 patch     */
  S = .array~new(N)
  do i = 1 to N
    if isB[i] == .nil then iterate
    c = (i - 1) // nc; r = (i - 1) % nc
    vals = .array~new
    do dr = -1 to 1
      do dc = -1 to 1
        if r + dr < 0 | r + dr >= nr | c + dc < 0 | c + dc >= nc then iterate
        j = (r + dr) * nc + c + dc + 1
        if isB[j] \== .nil then vals~append(T[j])
      end
    end
    vals = vals~sortWith(.NumOrder~new)
    S[i] = vals[(vals~items + 1) % 2]
  end
  /* 3: blocks                                                        */
  id = .array~new(N)
  nBlk = 0
  do i = 1 to N
    if isB[i] == .nil | id[i] \== .nil then iterate
    nBlk += 1
    cells = .array~new; q = .queue~new; q~queue(i); id[i] = nBlk
    runSum = S[i]; runN = 1
    do while q~items > 0
      a = q~pull; cells~append(a)
      do d over .array~of(-1, 1, -nc, nc)
        j = a + d
        if j < 1 | j > N then iterate
        if abs(d) = 1 & (j - 1) % nc \= (a - 1) % nc then iterate
        if isB[j] == .nil | id[j] \== .nil then iterate
        if abs(S[j] - S[a]) > STEP then iterate
        if abs(S[j] - runSum / runN) > DRIFT then iterate
        id[j] = nBlk; q~queue(j)
        runSum += S[j]; runN += 1
      end
    end
  end
  /* merge small pieces into the neighbour they share most side with  */
  cnt = .array~new(nBlk); sumS = .array~new(nBlk)
  do b = 1 to nBlk; cnt[b] = 0; sumS[b] = 0; end
  do i = 1 to N
    if id[i] == .nil then iterate
    cnt[id[i]] += 1; sumS[id[i]] += S[i]
  end
  owner = .array~new(nBlk)
  do b = 1 to nBlk; owner[b] = b; end
  side = .directory~new
  do i = 1 to N
    if id[i] == .nil then iterate
    do d over .array~of(1, nc)
      j = i + d
      if j > N then iterate
      if d = 1 & (j - 1) % nc \= (i - 1) % nc then iterate
      if id[j] == .nil | id[j] = id[i] then iterate
      key = min(id[i], id[j]) max(id[i], id[j])
      if side~hasIndex(key) then side[key] += 1; else side[key] = 1
    end
  end
  nMerged = 0
  do key over side~allIndexes
    nop
  end
  /* smallest first, so pieces gather into the big roofs              */
  order = .array~new
  do b = 1 to nBlk; order~append(right(cnt[b], 8, "0") b); end
  order = order~sortWith(.StrOrder~new)
  nbrs = .directory~new
  do key over side~allIndexes
    parse var key b1 b2
    if \nbrs~hasIndex(b1) then nbrs[b1] = .array~new
    if \nbrs~hasIndex(b2) then nbrs[b2] = .array~new
    nbrs[b1]~append(b2 side[key]); nbrs[b2]~append(b1 side[key])
  end
  do o over order
    parse var o . b
    if cnt[b] * cell * cell >= MERGE then iterate
    if \nbrs~hasIndex(b) then iterate
    best = ""; bestSide = 0
    myS = sumS[b] / cnt[b]
    do e over nbrs[b]
      parse var e nbk sd
      tb = rootOf(owner, nbk)
      if tb = b then iterate
      if abs(sumS[tb] / cnt[tb] - myS) > REACH then iterate
      if sd > bestSide then do; best = tb; bestSide = sd; end
    end
    if best \== "" then do
      owner[b] = best; cnt[best] += cnt[b]; sumS[best] += sumS[b]; nMerged += 1
    end
  end
  groups = .directory~new
  do i = 1 to N
    if id[i] == .nil then iterate
    rb = rootOf(owner, id[i])
    if \groups~hasIndex(rb) then groups[rb] = .array~new
    groups[rb]~append(i)
  end
  nKept = 0
  do rb over groups~allIndexes
    cells = groups[rb]
    if cells~items * cell * cell < AREA then iterate
    nKept += 1
    call describe cells
  end
  say filespec("name", gf)":" nb "building cells," nBlk "joined groups," nMerged "small pieces merged," nKept "blocks kept"
  return

/* 4: one block as words                                              */
describe:
  use arg cells
  m = cells~items
  sx = 0; sy = 0
  hs = .array~new; ts = .array~new; gs = .array~new
  do a over cells
    r = (a - 1) % nc; c = (a - 1) // nc
    ex = x0 + (c + 0.5) * cell; ny = y0 + (nr - r - 0.5) * cell
    sx += ex; sy += ny
    hs~append(T[a] - G[a]); ts~append(T[a]); gs~append(G[a])
  end
  mx = sx / m; my = sy / m
  sxx = 0; syy = 0; sxy = 0
  do a over cells
    r = (a - 1) % nc; c = (a - 1) // nc
    dx = x0 + (c + 0.5) * cell - mx; dy = y0 + (nr - r - 0.5) * cell - my
    sxx += dx * dx; syy += dy * dy; sxy += dx * dy
  end
  /* the long side: the direction the cells spread most               */
  ang = 0.5 * atan2(2 * sxy, sxx - syy)
  ux = RxCalcCos(ang, 12, "R"); uy = RxCalcSin(ang, 12, "R")
  a1 = 1e9; a2 = -1e9; b1 = 1e9; b2 = -1e9
  do a over cells
    r = (a - 1) % nc; c = (a - 1) // nc
    dx = x0 + (c + 0.5) * cell - mx; dy = y0 + (nr - r - 0.5) * cell - my
    p = dx * ux + dy * uy; across = -dx * uy + dy * ux
    a1 = min(a1, p); a2 = max(a2, p); b1 = min(b1, across); b2 = max(b2, across)
  end
  len = a2 - a1 + cell; wid = b2 - b1 + cell
  /* the box's middle along its own axes                              */
  cx = mx + ux * (a1 + a2) / 2 - uy * (b1 + b2) / 2
  cy = my + uy * (a1 + a2) / 2 + ux * (b1 + b2) / 2
  bear = 90 - ang * 180 / RxCalcPi(12)
  bear = bear // 180; if bear < 0 then bear += 180
  if len < wid then do; swapL = len; len = wid; wid = swapL; bear = (bear + 90) // 180; end
  hs = hs~sortWith(.NumOrder~new); ts = ts~sortWith(.NumOrder~new); gs = gs~sortWith(.NumOrder~new)
  h90 = hs[max(1, trunc(0.9 * m))]; tMed = ts[(m + 1) % 2]; gMed = gs[(m + 1) % 2]
  blocks~append("at" format(cx, , 1) format(cy, , 1) "size" format(len, , 0) "by" format(wid, , 0) ,
    "bearing" format(bear, , 0) "height" format(h90, , 1) "roof" format(tMed, , 1) "ground" format(gMed, , 1) ,
    "area" m * cell * cell)
  return

::routine atan2
  use arg y, x
  pi = RxCalcPi(12)
  if x > 0 then return RxCalcArcTan(y / x, 12, "R")
  if x < 0 & y >= 0 then return RxCalcArcTan(y / x, 12, "R") + pi
  if x < 0 & y < 0 then return RxCalcArcTan(y / x, 12, "R") - pi
  if y > 0 then return pi / 2
  if y < 0 then return -pi / 2
  return 0

::routine rootOf
  use arg owner, b
  do while owner[b] \= b
    b = owner[b]
  end
  return b

::class StrOrder
::method compare
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0

::class NumOrder
::method compare
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0

::requires "rxmath" LIBRARY
