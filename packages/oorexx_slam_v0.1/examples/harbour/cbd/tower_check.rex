/* ------------------------------------------------------------------ */
/* tower_check.rex -- the LiDAR blocks against published towers       */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx tower_check.rex towers.words blocks.words mosaic.words        */
/*                                                                    */
/* For each published tower (place from Wikipedia, height from the     */
/* list of tallest buildings):                                         */
/*   peak   the highest return within SEARCH m of the published point:*/
/*          the tower is taken to stand there ("moved": how far);     */
/*          less the block's ground: the true top, spires and masts   */
/*          in, set against the published top;                        */
/*   block  the tallest block whose box holds the peak (3 m spare),   */
/*          or whose middle is within REACH m of it: its height (90th */
/*          of 100 roof cells, masts left out), set against the       */
/*          published roof (else top).                                */
/* Places: lat/long to MGA by mga.cls (GDA94); the LiDAR is GDA2020,  */
/* the same ground under 2 m apart: inside one cell, not moved.        */
/* ------------------------------------------------------------------ */
parse arg tFile bFile mFile .
REACH = 15; SEARCH = 90
numeric digits 16
towers = .array~new
do while lines(tFile) > 0
  l = linein(tFile)~strip
  if word(l, 1) \== "tower" then iterate
  parse var l 'tower "' nm '" at' la lo rest
  roof = ""; top = ""; after = pos("after survey", rest) > 0
  if wordpos("roof", rest) > 0 then roof = word(rest, wordpos("roof", rest) + 1)
  if wordpos("top", rest) > 0 then top = word(rest, wordpos("top", rest) + 1)
  parse value mgaOf(la, lo) with e n
  towers~append(.array~of(nm, e, n, roof, top, after, "", "", "", -1e9, "", ""))
end
call stream tFile, "c", "close"
/* the highest return within SEARCH m of each tower, from the mosaic: */
/* the tower is taken to stand there (the published points can be a   */
/* street frontage or a plaza 70 m off the tower itself)              */
r = 0
do while lines(mFile) > 0
  l = linein(mFile)~strip
  w1 = word(l, 1)
  if w1 == "grid" then do
    parse var l "south west" x0 y0 "cell" cell "across" nc "up" nr .
    iterate
  end
  if w1 \== "top" then iterate
  r += 1
  ny = y0 + (nr - r + 0.5) * cell
  do t over towers
    if abs(ny - t[3]) > SEARCH then iterate
    c0 = max(1, trunc((t[2] - SEARCH - x0) / cell) + 1); c1 = min(nc, trunc((t[2] + SEARCH - x0) / cell) + 1)
    do c = c0 to c1
      v = word(l, c + 1)
      if \datatype(v, "N") then iterate
      ex = x0 + (c - 0.5) * cell
      if (ex - t[2]) ** 2 + (ny - t[3]) ** 2 > SEARCH ** 2 then iterate
      if v > t[10] then do; t[10] = v; t[11] = ex; t[12] = ny; end
    end
  end
end
call stream mFile, "c", "close"
/* the block standing on each tower's peak                             */
do while lines(bFile) > 0
  l = linein(bFile)~strip
  if word(l, 1) \== "block" then iterate
  parse var l "block" id "at" e n "size" len "by" wid "bearing" bb "height" h "roof" rf "ground" g .
  ub = RxCalcSin(bb, 12, "D"); vb = RxCalcCos(bb, 12, "D")
  do t over towers
    if t[11] == "" then iterate
    dx = t[11] - e; dy = t[12] - n
    along = dx * ub + dy * vb; across = dx * vb - dy * ub
    inside = abs(along) <= len / 2 + 3 & abs(across) <= wid / 2 + 3
    if \inside then if dx * dx + dy * dy > REACH ** 2 then iterate
    if t[7] == "" | h > t[7] then do; t[7] = h; t[8] = g; t[9] = len "x" wid; end
  end
end
call stream bFile, "c", "close"
say left("tower", 24) right("moved", 6) right("block", 7) right("published", 10) right("off", 6) "   " right("peak", 6) right("published", 10) right("off", 6) "  footprint"
do t over towers
  pub = t[4]; kind = "roof"
  if pub == "" then do; pub = t[5]; kind = "top "; end
  if t[7] == "" then do
    say left(t[1], 24) right("", 6) right("none", 7) right(pub kind, 10) "      " "   (no block on the peak)" word("", 1) || copies(" ", 0) || ,
        word("after-survey", 1 + \t[6])
    iterate
  end
  peak = t[10] - t[8]
  d1 = t[7] - pub; d2 = peak - t[5]
  note = ""; if t[6] then note = "  built after the survey (Aug 2018)"
  moved = RxCalcSqrt((t[11] - t[2]) ** 2 + (t[12] - t[3]) ** 2, 8)
  say left(t[1], 24) right(format(moved, , 0), 6) right(format(t[7], , 1), 7) right(pub kind, 10) right(format(d1, , 0), 6) "   " ,
      right(format(peak, , 1), 6) right(t[5] "top ", 10) right(format(d2, , 0), 6) "  " t[9] || note
end
exit 0
::requires "mga.cls"
::requires "rxmath" LIBRARY
