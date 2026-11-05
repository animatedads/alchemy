#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* height_map.rex -- SLAM reads a height grid (ELVIS / NSW Spatial    */
/*                   Services DEM) into a height layer, and draws a   */
/*                   rough 3D model with fixed places                 */
/*                                                                    */
/* Architecture : Tom Dyer (a height layer under the map layers;      */
/*                known fixed places for other services; a rough 3D   */
/*                model as an SVG)                                    */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Make the height words and the 3D words:                            */
/*   rexx height_map.rex make <grid .asc> <height words> <3d words>   */
/*        <north lat> <west lon> <south lat> <east lon> <step m>      */
/* How high is a place (from the height words alone):                 */
/*   rexx height_map.rex at <height words> <lat> <lon>                */
/* ------------------------------------------------------------------ */
  parse arg mode rest
  signal on syntax name seeError
  call time "R"
  select
    when mode = "make" then do
      parse var rest asc hFile dFile nLat wLon sLat eLon step "water" wFile .
      if step = "" then call fail "Use: rexx height_map.rex make <grid> <height words> <3d words> <n lat> <w lon> <s lat> <e lon> <step>"
      call makeHeights asc, hFile, dFile, nLat, wLon, sLat, eLon, step, wFile
    end
    when mode = "at" then do
      parse var rest hFile lat lon .
      if lon = "" then call fail "Use: rexx height_map.rex at <height words> <lat> <lon>"
      say heightAt(hFile, lat, lon)
    end
    otherwise call fail "Use: rexx height_map.rex make ... | at ..."
  end
  exit 0

fail:
  raise syntax 98.900 array (arg(1))

seeError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM height map stopped." co["ADDITIONAL"][1]
  else say "SLAM height map broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  exit 2

::requires "rxmath" LIBRARY
::requires "mga.cls"

/* the fixed places: name, lat, lon (other services find them here)   */
::routine fixedPlaces
  return .array~of("goat island|-33.8521|151.1966", "fort denison|-33.8548|151.2256", ,
                   "bradleys head light|-33.8535|151.2467", "sydney opera house|-33.8568|151.2153", ,
                   "sydney harbour bridge|-33.8523|151.2108", "observatory hill|-33.8597|151.2045")

/* ================================================================== */
/* make                                                               */
/* ================================================================== */
::routine makeHeights
  use arg asc, hFile, dFile, nLat, wLon, sLat, eLon, step, wFile
  s = .stream~new(asc)
  if s~open("read") \= "READY:" then raise syntax 98.900 array ("I can not read" asc".")
  hdr = .directory~new
  do 6
    parse value s~linein with k v .
    hdr[k~upper] = v
  end
  cell = hdr~CELLSIZE
  topN = hdr~YLLCORNER + hdr~NROWS * cell
  leftE = hdr~XLLCORNER
  /* the box on the earth, in MGA metres (all four corners)            */
  minE = 1e12; maxE = -1e12; minN = 1e12; maxN = -1e12
  do c over .array~of(nLat wLon, nLat eLon, sLat wLon, sLat eLon)
    parse value mgaOf(word(c, 1), word(c, 2)) with E N
    minE = min(minE, E); maxE = max(maxE, E)
    minN = min(minN, N); maxN = max(maxN, N)
  end
  every = max(1, step % cell)
  step = every * cell
  r0 = trunc((topN - maxN) / cell)
  r1 = trunc((topN - minN) / cell)
  c0 = trunc((minE - leftE) / cell)
  c1 = trunc((maxE - leftE) / cell)
  r0 = max(0, r0); c0 = max(0, c0)
  r1 = min(hdr~NROWS - 1, r1); c1 = min(hdr~NCOLS - 1, c1)
  cols = (c1 - c0) % every + 1
  say "   grid" hdr~NCOLS "by" hdr~NROWS "at" cell "m; box rows" r0"-"r1", columns" c0"-"c1"; every" every "->" cols "across"
  rows = .array~new
  row = 0
  do while s~lines > 0 & row <= r1
    l = s~linein
    if row >= r0 & (row - r0) // every = 0 then do
      vals = l~subword(c0 + 1, c1 - c0 + 1)~makeArray(" ")
      mb = .mutableBuffer~new
      do i = 1 to vals~items by every
        v = vals[i]
        if v = hdr~NODATA_VALUE then mb~append(" -")
        else mb~append(" " || format(v, , 1))
      end
      rows~append(strip(mb~string))
    end
    row = row + 1
  end
  s~close
  E0 = leftE + (c0 + 0.5) * cell
  N0 = topN - (r0 + 0.5) * cell
  say "   read" rows~items "rows of" cols "heights"

  /* the height words                                                  */
  call SysFileDelete hFile
  call lineout hFile, "-- Heights of Sydney Harbour, read by SLAM (height_map.rex) from the ELVIS grid."
  call lineout hFile, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5)."
  call lineout hFile, "-- Source:" filespec("name", asc) "(NSW Spatial Services 5 m DEM, AHD71, GDA94 MGA zone 56;"
  call lineout hFile, "-- vertical +/-0.9 m at 95%). Water is flattened near 0 m in the grid."
  call lineout hFile, "-- Height data: NSW Government, NSW Spatial Services via ELVIS, (c) State of New South Wales, CC BY 4.0."
  call lineout hFile, ""
  call lineout hFile, "height map sydney harbour"
  call lineout hFile, "  grid mga 56 top left" format(E0, , 1) format(N0, , 1) "step" step "across" cols "down" rows~items
  do p over fixedPlaces()
    parse var p nm "|" la "|" lo
    call lineout hFile, "  place" nm "at" la lo "height" format(sample(rows, E0, N0, step, la, lo), , 1)
  end
  do r over rows
    call lineout hFile, "  row" r
  end
  call lineout hFile, "end"
  call lineout hFile
  say "   height words ->" hFile

  /* the water: a map layer says where water is, where it saw; the     */
  /* height grid says it (under 1 m) only where no map layer saw       */
  wet = .nil
  if wFile \= "" then wet = waterLayer(wFile, rows~items, cols, E0, N0, step)

  /* the 3D words                                                      */
  call model3d dFile, rows, E0, N0, step, cols, wet
  return

/* height at a place, from rows of heights (bilinear)                 */
::routine sample
  use arg rows, E0, N0, step, lat, lon
  parse value mgaOf(lat, lon) with E N
  fx = (E - E0) / step
  fy = (N0 - N) / step
  x0 = trunc(fx); y0 = trunc(fy)
  if x0 < 0 | y0 < 0 | y0 + 2 > rows~items then return "-"
  a = rows[y0 + 1]~makeArray(" ")
  b = rows[y0 + 2]~makeArray(" ")
  if x0 + 2 > a~items then return "-"
  h00 = a[x0 + 1]; h10 = a[x0 + 2]; h01 = b[x0 + 1]; h11 = b[x0 + 2]
  if h00 = "-" | h10 = "-" | h01 = "-" | h11 = "-" then return "-"
  tx = fx - x0
  ty = fy - y0
  return (h00 * (1 - tx) + h10 * tx) * (1 - ty) + (h01 * (1 - tx) + h11 * tx) * ty

/* ================================================================== */
/* the rough 3D model: seen from the south, up in the air; the hills  */
/* stand up out of the grid (made 4 times higher, so you see them).   */
/* Far (north) is drawn first, near (south) last, so near hills hide  */
/* what is behind them. Water is one flat sheet under all.            */
/* ================================================================== */
::routine model3d
  use arg dFile, rows, E0, N0, step, cols, wet
  R = rows~items
  grid = .array~new(R)
  do i = 1 to R
    grid[i] = rows[i]~makeArray(" ")
  end
  across = 1600                      /* the page, wide              */
  sx = across / cols                 /* one cell across             */
  sy = sx * 0.55                     /* one cell down (seen at a slant) */
  up = sx / step * 4                 /* one metre up, 4 times more   */
  topPad = 140 * up / (sx / step * 4)
  topPad = 160
  pageW = across + 40
  pageH = trunc(R * sy + topPad + 40)
  /* colours: height bands, each in 4 lights                           */
  bands = .array~of("5 8a9a5b", "15 a3b16b", "30 b9b97a", "50 c8b07e", "70 b89a6c", "90 a5845c", "999 917055")
  call SysFileDelete dFile
  call lineout dFile, "-- A rough 3D model of Sydney Harbour from the ELVIS height grid, by SLAM (height_map.rex)."
  call lineout dFile, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5)."
  call lineout dFile, "-- Seen from the south, at a slant; heights made 4 times bigger; one cell is" step "m."
  call lineout dFile, "-- Height data: NSW Government, NSW Spatial Services via ELVIS, (c) State of New South Wales, CC BY 4.0."
  call lineout dFile, "colour sea is #2f6f9f"
  call lineout dFile, "colour pin is #d62828"
  call lineout dFile, "colour ink is #111111"
  do b = 1 to bands~items
    parse value bands[b] with top hex
    do lv = 1 to 4
      call lineout dFile, "colour h" || b || "l" || lv "is #" || shade(hex, 0.55 + 0.15 * lv)
    end
  end
  call lineout dFile, "make harbour heights"
  call lineout dFile, "  size" pageW "by" pageH
  call lineout dFile, "  paint all white"
  /* the water: one flat sheet at 0 m                                  */
  call lineout dFile, "  shape sea from" pt(0, 0, 0) "to" pt(cols - 1, 0, 0) "to" pt(cols - 1, R - 1, 0) "to" pt(0, R - 1, 0)
  quads = 0
  do r = 1 to R - 1
    a = grid[r]
    b = grid[r + 1]
    do c = 1 to cols - 1
      h1 = a[c]; h2 = a[c + 1]; h3 = b[c + 1]; h4 = b[c]
      if h1 = "-" | h2 = "-" | h3 = "-" | h4 = "-" then iterate
      /* water: under 1 m. The grid sets water near 0 m, from -0.5 to  */
      /* about 1 m by tile; land under 1 m AHD is rare here (counted:  */
      /* heights thin out above 1 m)                                   */
      if isWet(wet, r, c, h1) & isWet(wet, r, c + 1, h2) & isWet(wet, r + 1, c + 1, h3) & isWet(wet, r + 1, c, h4) then iterate
      hm = (h1 + h2 + h3 + h4) / 4
      /* light from the north-west: a slope that rises to the south-   */
      /* east faces the light                                          */
      rise = (h3 - h1) / (step * 1.414)
      lv = trunc(2.5 + rise * 12)
      lv = max(1, min(4, lv))
      bd = 1
      do while hm > word(bands[bd], 1)
        bd = bd + 1
      end
      call lineout dFile, "  shape h" || bd || "l" || lv "from" pt(c - 1, r - 1, max(0, h1)) "to" pt(c, r - 1, max(0, h2)) ,
                          "to" pt(c, r, max(0, h3)) "to" pt(c - 1, r, max(0, h4))
      quads = quads + 1
    end
  end
  /* the fixed places, where they stand                                */
  k = 0
  do p over fixedPlaces()
    k = k + 1
    parse var p nm "|" la "|" lo
    parse value mgaOf(la, lo) with E N
    fx = (E - E0) / step
    fy = (N0 - N) / step
    h = sample(rows, E0, N0, step, la, lo)
    if h = "-" then iterate
    parse value pt(fx, fy, max(0, h)) with x y
    call lineout dFile, "  circle pin size 9 at" x y
    /* the words stand above the pin, every other one higher, on a    */
    /* white line so they can be read                                 */
    ty = y - 24 - 26 * (k // 3)
    call lineout dFile, "  band white from" (x) (y - 6) "to" (x) (ty + 8) "thick 2"
    call lineout dFile, "  write ink size 18 at" x ty "saying" nm format(h, , 0) "m"
  end
  call lineout dFile, "end"
  call lineout dFile, ""
  call lineout dFile, "page" pageW "wide"
  call lineout dFile, "draw harbour heights"
  call lineout dFile
  say "   3d words:" quads "pieces of land ->" dFile
  return

/* a grid point is water: the map layer says so where it saw ("w" or */
/* "l"); else the height grid (under 1 m)                             */
pt:
  use arg gx, gy, gh
  return format(20 + gx * sx, , 1) format(topPad + gy * sy - gh * up, , 1)

/* the map layer's water on the height grid: for each grid point,    */
/* "w" water, "l" land, "." the layer did not see it. The layer:      */
/* SLAM words with a "map" block of "shape water/land" outlines, each */
/* place "<lat> south <lon> east"                                     */
::routine waterLayer
  use arg wFile, nRows, nCols, E0, N0, step
  s = .stream~new(wFile)
  s~open("read")
  edges = .array~new
  inMap = 0
  pts = .array~new
  bx0 = ""
  do while s~lines > 0
    l = strip(s~linein)
    if word(l, 1) = "map" then do
      inMap = 1
      iterate
    end
    if \inMap then iterate
    if word(l, 1) = "from" & bx0 == "" & word(l, 5) = "east" & word(l, 6) = "to" then do
      /* the box the layer saw                                         */
      parse var l "from" la1 "south" lo1 "east to" la2 "south" lo2 "east" .
      parse value mgaOf(-la1, lo1) with bx0 by0
      parse value mgaOf(-la2, lo2) with bx1 by1
      iterate
    end
    if word(l, 1) = "shape" | l = "end" then do
      call addEdges
      pts = .array~new
      if l = "end" then leave
      iterate
    end
    if word(l, 1) = "from" | word(l, 1) = "to" then do
      parse var l . la "south" lo "east" .
      pts~append(mgaOf(-la, lo))
    end
  end
  s~close
  wet = .array~new(nRows)
  do r = 1 to nRows
    N = N0 - (r - 1) * step
    xs = .array~new
    do edge over edges
      parse var edge ea na eb nb
      if (na > N) \= (nb > N) then xs~append(ea + (N - na) * (eb - ea) / (nb - na))
    end
    xs = xs~sortWith(.NumOrder~new)
    mb = .mutableBuffer~new
    do c = 1 to nCols
      E = E0 + (c - 1) * step
      if E < min(bx0, bx1) | E > max(bx0, bx1) | N < min(by0, by1) | N > max(by0, by1) then do
        mb~append(".")
        iterate
      end
      cut = 0
      do x over xs
        if x < E then cut = cut + 1
        else leave
      end
      if cut // 2 = 1 then mb~append("w")
      else mb~append("l")
    end
    wet[r] = mb~string
  end
  say "   water layer" filespec("name", wFile)":" edges~items "sides; box" format(bx0, , 0) format(by0, , 0) format(bx1, , 0) format(by1, , 0)
  if pos("height", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then do r = 125 to 145 by 5
    say "    wet row" r":" wet[r]
  end
  return wet

addEdges:
  n = pts~items
  do i = 1 to n
    j = i // n + 1
    edges~append(pts[i] pts[j])
  end
  return

::class NumOrder
::method compare
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0

/* a grid point is water when the map layer saw water there, or the  */
/* height grid is under 1 m (it keeps water from -0.5 to 1 m; land    */
/* under 1 m AHD is rare here). The map layer only adds water: where  */
/* the grid holds water higher (round Fort Denison, 2.5 to 3.3 m), and*/
/* its "land" is not trusted, as a part it did not see (a photo card  */
/* on the screen) reads as land in its outlines                       */
::routine isWet
  use arg wet, r, c, h
  if wet \== .nil then if substr(wet[r], c, 1) == "w" then return 1
  return h < 1.0

::routine shade
  use arg hex, f
  out = ""
  do i = 1 to 5 by 2
    v = min(255, trunc(x2d(substr(hex, i, 2)) * f))
    out = out || d2x(v, 2)
  end
  return out~lower

/* ================================================================== */
/* at: how high is a place, from the height words alone               */
/* ================================================================== */
::routine heightAt
  use arg hFile, lat, lon
  s = .stream~new(hFile)
  s~open("read")
  rows = .array~new
  do while s~lines > 0
    l = strip(s~linein)
    if word(l, 1) = "grid" then parse var l "top left" E0 N0 "step" step .
    if word(l, 1) = "row" then rows~append(subword(l, 2))
  end
  s~close
  h = sample(rows, E0, N0, step, lat, lon)
  if h = "-" then return "not in the height map:" lat lon
  return format(h, , 1) "m above AHD (height layer," step "m grid)"
