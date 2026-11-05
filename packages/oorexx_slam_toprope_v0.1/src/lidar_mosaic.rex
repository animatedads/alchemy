/* ------------------------------------------------------------------ */
/* lidar_mosaic.rex -- join LiDAR tile grids into one grid             */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx lidar_mosaic.rex out.words grid.words [grid.words ...]        */
/*                                                                    */
/* Buildings cross the 1 km tile edges, and two surveys (Sydney        */
/* Harbour, Sydney Eastern Beaches) each cover parts of the same      */
/* tiles. So the grids (las_grid.rex, all with the same cell, edges on */
/* whole cells) are joined first. In each cell: the higher top and    */
/* its kind; the mean of the grounds the grids have; water if either  */
/* saw water.                                                         */
/* Rexx names ignore case: the mosaic's size is mosCols, mosRows, never */
/* NC, NR (each tile's nc, nr would overwrite them).                  */
/* ------------------------------------------------------------------ */
parse arg out grids
if grids = "" then do
  say "usage: rexx lidar_mosaic.rex out.words grid.words [grid.words ...]"
  exit 2
end
numeric digits 12
files = grids~makeArray(" ")
/* the extent of all the grids                                         */
gx0 = 1e12; gy0 = 1e12; gx1 = -1e12; gy1 = -1e12; cell = ""
do f over files
  if f = "" then iterate
  do while lines(f) > 0
    l = linein(f)~strip
    if word(l, 1) == "grid" then do
      parse var l "south west" x0 y0 "cell" c "across" nc "up" nr .
      leave
    end
  end
  call stream f, "c", "close"
  if cell == "" then cell = c
  if c \= cell then raise syntax 88.900 array(f "has cell" c "not" cell)
  gx0 = min(gx0, x0); gy0 = min(gy0, y0)
  gx1 = max(gx1, x0 + nc * c); gy1 = max(gy1, y0 + nr * c)
end
mosCols = (gx1 - gx0) % cell; mosRows = (gy1 - gy0) % cell
say "mosaic: E" gx0 "to" gx1", N" gy0 "to" gy1", cells of" cell "m:" mosCols "by" mosRows
top = .array~new(mosCols * mosRows); kind = .mutableBuffer~new(copies(".", mosCols * mosRows))
gs = .array~new(mosCols * mosRows); gn = .array~new(mosCols * mosRows); wet = .mutableBuffer~new(copies(".", mosCols * mosRows))
do f over files
  if f = "" then iterate
  rowsT = .array~new; rowsG = .array~new; rowsW = .array~new; rowsK = .array~new
  do while lines(f) > 0
    l = linein(f)~strip
    w1 = word(l, 1)
    select
      when w1 == "grid" then parse var l "south west" x0 y0 "cell" . "across" nc "up" nr .
      when w1 == "top" then rowsT~append(subword(l, 2))
      when w1 == "ground" then rowsG~append(subword(l, 2))
      when w1 == "water" then rowsW~append(word(l, 2))
      when w1 == "kind" then rowsK~append(word(l, 2))
      otherwise nop
    end
  end
  call stream f, "c", "close"
  /* the grid's rows go north to south; its row 1 is the top          */
  dc = (x0 - gx0) % cell; dr = (gy1 - (y0 + nr * cell)) % cell
  do r = 1 to nr
    tr = rowsT[r]; gr = rowsG[r]; wr = rowsW[r]; kr = rowsK[r]
    base = (dr + r - 1) * mosCols + dc
    do c = 1 to nc
      i = base + c
      v = word(tr, c)
      if datatype(v, "N") then do
        t = top[i]
        if t == .nil then do; top[i] = v; kind~replaceAt(substr(kr, c, 1), i, 1); end
        else if v > t then do; top[i] = v; kind~replaceAt(substr(kr, c, 1), i, 1); end
      end
      v = word(gr, c)
      if datatype(v, "N") then do
        if gs[i] == .nil then do; gs[i] = v; gn[i] = 1; end
        else do; gs[i] = gs[i] + v; gn[i] = gn[i] + 1; end
      end
      if substr(wr, c, 1) == "w" then wet~replaceAt("w", i, 1)
    end
  end
  say "  joined" filespec("name", f)
end
call SysFileDelete out
call lineout out, "-- Roof and ground grids joined by lidar_mosaic.rex (Claude, Opus 5.5; architecture Tom Dyer)."
call lineout out, "-- From:" grids~space
call lineout out, "-- LiDAR: NSW Government (DCCEEW Marine LiDAR 2018), CC BY 4.0. GDA2020 MGA zone 56, AHD."
call lineout out, ""
call lineout out, "lidar grid mosaic"
call lineout out, "  grid mga 56 gda2020 south west" gx0 gy0 "cell" cell "across" mosCols "up" mosRows
do r = 1 to mosRows
  mt = .mutableBuffer~new; mg = .mutableBuffer~new
  base = (r - 1) * mosCols
  do c = 1 to mosCols
    i = base + c
    if top[i] == .nil then mt~append(" -"); else mt~append(" " || top[i])
    if gn[i] == .nil then mg~append(" -"); else mg~append(" " || format(gs[i] / gn[i], , 2))
  end
  call lineout out, "  top" strip(mt~string)
  call lineout out, "  ground" strip(mg~string)
  call lineout out, "  water" wet~substr(base + 1, mosCols)
  call lineout out, "  kind" kind~substr(base + 1, mosCols)
end
call lineout out, "end"
call stream out, "c", "close"
say "wrote" out
