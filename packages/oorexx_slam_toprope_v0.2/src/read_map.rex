#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* read_map.rex -- SLAM reads a map in layers                         */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/*   - a map is layers, as layered sound: each picture is a layer     */
/*     with its own detail (metres in one place). Layers are not      */
/*     joined into one: at a place, the layer with the most detail    */
/*     that saw it is the one to use; a layer that saw only a part    */
/*     still wins in that part                                        */
/*   - fixed known places on the earth, for other services            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Make the map words from a stitch (stitch.rex wrote it):            */
/*   rexx read_map.rex make <stitch words> <map words out> [bottom n] */
/* Read the map words at a place:                                     */
/*   rexx read_map.rex at <map words> <lat> <lon>                     */
/*     (lat south is less than 0: -33.8568 151.2153)                  */
/* ------------------------------------------------------------------ */
  parse arg mode rest
  signal on syntax name seeError
  call time "R"
  select
    when mode = "make" then do
      parse var rest stitchFile outFile "bottom" bottom .
      if outFile = "" then call fail "Use: rexx read_map.rex make <stitch words> <map words out> [bottom n]"
      if bottom = "" then bottom = 0
      call makeMap stitchFile, outFile, bottom
    end
    when mode = "at" then do
      parse var rest mapFile lat lon .
      if lon = "" then call fail "Use: rexx read_map.rex at <map words> <lat> <lon>"
      say readAt(mapFile, lat, lon)
    end
    otherwise call fail "Use: rexx read_map.rex make ... | at ..."
  end
  exit 0

fail:
  raise syntax 98.900 array (arg(1))

seeError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM read map stopped." co["ADDITIONAL"][1]
  else say "SLAM read map broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  exit 2

::requires "stitch.cls"

/* ================================================================== */
/* make: layers from a stitch                                         */
/* ================================================================== */
::routine makeMap
  use arg stitchFile, outFile, bottom
  dbg = pos("map", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0
  home = filespec("location", stitchFile)
  /* the stitch: each picture's place and size in the frame            */
  layers = .array~new
  frame = ""
  s = .stream~new(stitchFile)
  s~open("read")
  do while s~lines > 0
    l = strip(s~linein)
    if word(l, 1) = "frame" & frame == "" then frame = word(l, 2)
    if word(l, 1) = "stitch" & word(l, 3) \= "1" then if layers~items > 0 then leave
    if word(l, 1) \= "picture" | word(l, 3) \= "at" then iterate
    parse var l "picture" name "at" fx fy "size" fw "by" fh .
    ly = .directory~new
    name = strip(name)
    ly~name = name
    ly~file = home || name
    ly~fx = fx
    ly~fy = fy
    ly~fw = fw
    ly~fh = fh
    layers~append(ly)
  end
  s~close
  if layers~items = 0 then raise syntax 98.900 array ("No pictures in" stitchFile".")

  /* each layer: water and land, specks cleaned, islands               */
  lesson = .directory~new
  lesson~bottom = bottom
  isl = .array~new
  do ly over layers
    pc = readPicture(ly~file, 450, lesson)
    call cleanKinds pc, 8
    ly~pc = pc
    /* one cell of the layer, in places of the frame                   */
    ly~cell = pc~f * ly~fw / pc~fullW
    do b over blobsOf(pc, 4)
      parse var b kind area cx cy .
      if kind \== "l" then iterate
      isl~append((ly~fx + cx * ly~cell) (ly~fy + cy * ly~cell) (area * ly~cell ** 2) ly~name)
    end
    if dbg then say "   layer" ly~name": cell" format(ly~cell, , 3) "frame places"
  end

  /* on the earth: Goat Island and Fort Denison (as top_rope_map.rex) */
  geo = fixOnEarth(isl, dbg)

  /* each layer: metres in one cell; outlines on the earth            */
  do ly over layers
    ly~metres = ly~cell * geo~metres
  end
  order = .array~new
  do i = 1 to layers~items
    order~append(format(layers[i]~metres, , 6) i)
  end
  order = order~sortWith(.ByNumberFirst~new)

  call SysFileDelete outFile
  call out "-- Sydney Harbour from the sky, read by SLAM as layers (read_map.rex)."
  call out "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5)."
  call out "-- Pictures: Google satellite (Imagery (c) 2026 Airbus, CNES / Airbus, Maxar Technologies, Vexcel Imaging US)."
  call out "-- Stitch:" filespec("name", stitchFile) "(stitch.rex). On the earth: fixed by Goat Island and Fort Denison."
  call out "--" geo~note
  call out ""
  call out "read map sydney harbour"
  call out "  rule at a place, use the layer with the fewest metres that saw it"
  call out ""
  call out "  -- fixed places, for other services"
  call out "  place goat island at" ll(-33.8521, 151.1966)
  call out "  place fort denison at" ll(-33.8548, 151.2256)
  call out "  place bradleys head light at" ll(-33.8535, 151.2467)
  call out "  place sydney opera house at" ll(-33.8568, 151.2153)
  call out "  place sydney harbour bridge at" ll(-33.8523, 151.2108)
  total = 0
  do o over order
    ly = layers[word(o, 2)]
    pc = ly~pc
    parse value earth(geo, ly~fx, ly~fy) with nLat wLon
    parse value earth(geo, ly~fx + ly~fw, ly~fy + pc~H * ly~cell) with sLat eLon
    ly~box = nLat wLon sLat eLon
    call out ""
    call out "  layer" ly~name "metres" format(ly~metres, , 1)
    call out "    seen from" ll(nLat, wLon) "to" ll(sLat, eLon)
    shapes = outlinesOf(pc)
    n = 0
    do sh over shapes
      parse var sh kind pts
      list = pts~makeArray(",")
      if list~items < 3 then iterate
      n = n + 1
      total = total + list~items
      call out "    shape" kind
      first = 1
      do p over list
        parse var p x y
        parse value earth(geo, ly~fx + (x + 0.5) * ly~cell, ly~fy + (y + 0.5) * ly~cell) with la lo
        if first then call out "      from" ll(la, lo)
        else call out "      to" ll(la, lo)
        first = 0
      end
    end
    ly~shapes = shapes
    call out "  end"
    say "   layer" left(ly~name, 10) format(ly~metres, 3, 1) "m," n "outlines"
  end
  call out "end"
  call out ""

  /* the same in kilometres for SLAM Draw: the widest layer first, the */
  /* most detail last, each painting only the box it saw               */
  parse value earth(geo, 0, 0) with lat0 lon0
  minE = 1e9
  minS = 1e9
  maxE = -1e9
  maxS = -1e9
  do ly over layers
    parse value ly~box with a b c d
    minE = min(minE, km(lon0, b, geo)); maxE = max(maxE, km(lon0, d, geo))
    minS = min(minS, kmS(lat0, a)); maxS = max(maxS, kmS(lat0, c))
  end
  call out "-- The same layers in kilometres east and south of the top left, for SLAM Draw:"
  call out "-- the widest layer is painted first, the most detail last, each in the box it saw."
  call out "colour water is #1f4e79"
  call out "colour land is #e9e4d8"
  call out "make sydney harbour layers"
  call out "  size" format(maxE - minE, , 3) "by" format(maxS - minS, , 3)
  call out "  paint all none"
  do i = order~items to 1 by -1
    ly = layers[word(order[i], 2)]
    parse value ly~box with a b c d
    call out "  box land from" format(km(lon0, b, geo) - minE, , 3) format(kmS(lat0, a) - minS, , 3) ,
             "to" format(km(lon0, d, geo) - minE, , 3) format(kmS(lat0, c) - minS, , 3)
    do sh over ly~shapes
      parse var sh kind pts
      list = pts~makeArray(",")
      if list~items < 3 then iterate
      line = "  shape" kind
      first = 1
      do p over list
        parse var p x y
        parse value earth(geo, ly~fx + (x + 0.5) * ly~cell, ly~fy + (y + 0.5) * ly~cell) with la lo
        e = format(km(lon0, lo, geo) - minE, , 3)
        so = format(kmS(lat0, la) - minS, , 3)
        if first then line = line "from" e so
        else line = line "to" e so
        first = 0
      end
      call out line
    end
  end
  call out "end"
  call out ""
  call out "page 1600 wide"
  call out "draw sydney harbour layers"
  call lineout outFile
  say "   map:" layers~items "layers," total "places ->" outFile
  return

out:
  call lineout outFile, arg(1)
  return

::routine ll
  use arg lat, lon
  return format(lat, , 5) format(lon, , 5)

::routine km
  use arg lon0, lon, geo
  return (lon - lon0) * 111.320 * geo~cosL

::routine kmS
  use arg lat0, lat
  return (lat0 - lat) * 111.320

/* frame place -> latitude longitude                                  */
::routine earth
  use arg geo, x, y
  lon = geo~lon0 + (x - geo~ax) / geo~ppd
  lat = geo~lat0 - (y - geo~ay) * geo~cosL / geo~ppd
  return lat lon

/* two islands with known places fix the frame on the earth           */
::routine fixOnEarth
  use arg isl, dbg
  gLat = -33.8521
  gLon = 151.1966
  fLat = -33.8548
  fLon = 151.2256
  cosL = RxCalcCos(33.853, 9, "D")
  wantX = fLon - gLon
  wantY = -(fLat - gLat) / cosL
  wantA = atan2(wantY, wantX)
  wantL = RxCalcSqrt(wantX ** 2 + wantY ** 2, 9)
  best = 999
  pick = ""
  do a over isl
    parse var a ax ay an aname
    /* Goat Island is 5.4 ha: metres in one frame place, by its size  */
    mArea = RxCalcSqrt(54000 / an, 9)
    do b over isl
      parse var b bx by bn bname
      if b == a | bn >= an then iterate
      d = RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9)
      if d = 0 then iterate
      err = abs(atan2(by - ay, bx - ax) - wantA) * 180 / RxCalcPi(9)
      if err > 6 then iterate
      mWay = wantL * 111320 * cosL / d
      off = abs(RxCalcLog(mWay / mArea, 9))
      if off > 0.4 then iterate
      /* Fort Denison is small: under a tenth of Goat Island           */
      if bn > an / 4 then iterate
      cost = err + 20 * off
      if cost < best then do
        best = cost
        pick = a "|" b
      end
    end
  end
  if pick == "" then raise syntax 98.900 array ("I can not find Goat Island and Fort Denison in the layers.")
  parse var pick ax ay an aname "|" bx by bn bname
  geo = .directory~new
  geo~ax = ax
  geo~ay = ay
  geo~lat0 = gLat
  geo~lon0 = gLon
  geo~cosL = cosL
  geo~ppd = RxCalcSqrt((bx - ax) ** 2 + (by - ay) ** 2, 9) / wantL
  geo~metres = 111320 * cosL / geo~ppd
  turn = abs(atan2(by - ay, bx - ax) - wantA) * 180 / RxCalcPi(9)
  geo~note = "Goat Island seen in" aname", Fort Denison in" bname"; bearing" format(turn, , 1) "degrees off;",
             "one frame place is" format(geo~metres, , 2) "m."
  say "  " geo~note
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

/* the outlines of a layer: water parts and islands, each             */
/* "kind x y,x y,..." in cells                                        */
::routine outlinesOf
  use arg pc
  out = .array~new
  do id = 1 to pc~info~items
    parse value pc~info[id] with kind size edge first
    if size < 6 then iterate
    if kind == "l" & edge = 1 then iterate
    pts = outline(pc~comp, pc~W, pc~H, id, first)
    if pts~items < 3 then iterate
    few = simplify(pts, 1.0)
    if few~items >= 3 then pts = few
    if kind == "w" then out~append("water" pts~makeString("L", ","))
    else out~append("land" pts~makeString("L", ","))
  end
  return out

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
  do steps = 1 to 64 * (WW + HH)
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

::class ByNumberFirst
::method compare
  use arg a, b
  if word(a, 1) < word(b, 1) then return -1
  if word(a, 1) > word(b, 1) then return 1
  return 0

/* ================================================================== */
/* read: what is at a place, from the map words alone                 */
/* ================================================================== */
::routine readAt
  use arg mapFile, lat, lon
  s = .stream~new(mapFile)
  s~open("read")
  inMap = 0
  layer = ""
  answer = ""
  xs = .array~new
  pts = .array~new
  kindNow = ""
  do while s~lines > 0
    l = strip(s~linein)
    if l = "read map" | word(l, 1) = "read" & word(l, 2) = "map" then do
      inMap = 1
      iterate
    end
    if \inMap then iterate
    w1 = word(l, 1)
    if w1 = "layer" then do
      layer = word(l, 2)
      metres = word(l, 4)
      crossings = 0
      pts = .array~new
    end
    else if w1 = "seen" then do
      parse var l "seen from" nLat wLon "to" sLat eLon
      seen = lat <= nLat & lat >= sLat & lon >= wLon & lon <= eLon
    end
    else if w1 = "shape" then do
      if pts~items > 0 then crossings = crossings + cross(pts, lat, lon)
      pts = .array~new
    end
    else if w1 = "from" | w1 = "to" then pts~append(word(l, 2) word(l, 3))
    else if w1 = "end" then do
      if layer == "" then leave
      if pts~items > 0 then crossings = crossings + cross(pts, lat, lon)
      pts = .array~new
      /* layers come with the most detail first: the first that saw   */
      /* the place answers                                            */
      if seen then do
        kind = "land"
        if crossings // 2 = 1 then kind = "water"
        answer = kind "(layer" layer"," metres "m in one place)"
        leave
      end
      layer = ""
    end
  end
  s~close
  if answer == "" then return "not seen: no layer saw" lat lon
  return answer

/* how many times a line from the place to the east crosses the       */
/* outline (odd: the place is inside)                                 */
::routine cross
  use arg pts, lat, lon
  n = pts~items
  c = 0
  do i = 1 to n
    parse value pts[i] with ya xa
    parse value pts[i // n + 1] with yb xb
    if (ya > lat) \= (yb > lat) then do
      x = xa + (lat - ya) * (xb - xa) / (yb - ya)
      if x > lon then c = c + 1
    end
  end
  return c
