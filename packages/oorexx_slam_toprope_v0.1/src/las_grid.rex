/* ------------------------------------------------------------------ */
/* las_grid.rex -- a classified LiDAR point cloud (LAS) to roof and   */
/*   ground grids                                                     */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* Data         : NSW Government LiDAR (CC BY 4.0), read as LAS. A    */
/*                LAZ tile is first unpacked to LAS by a standard     */
/*                decoder (laz2las); every decision is here.          */
/*                                                                    */
/* rexx las_grid.rex tile.las out.words [cell m]                      */
/*                                                                    */
/* For each cell (default 2 m) of the tile:                           */
/*   top     the highest return that is not noise (classes 7, 18)     */
/*   ground  the mean of the ground returns (class 2), "-" if none    */
/*   water   "w" if a water return (class 9) fell in it               */
/*   kind    "b" if the top return is a building (class 6), "v" if    */
/*           vegetation (3, 4, 5), "g" ground, "w" water, "o" other   */
/* and, for the tile, how many points each class has. The roof of a   */
/* building is its top less the ground round it (later step).          */
/* LAS 1.2 to 1.4, point formats 0 to 10. Coordinates as the file      */
/* gives them (here GDA2020 MGA zone 56, AHD heights).                */
/* ------------------------------------------------------------------ */
parse arg lasFile out cell .
if out = "" then do
  say "usage: rexx las_grid.rex tile.las out.words [cell m]"
  exit 2
end
if cell = "" then cell = 2
numeric digits 16
h = charin(lasFile, 1, 375)
if left(h, 4) \== "LASF" then raise syntax 88.900 array(lasFile "is not LAS (LAZ must be unpacked first)")
vMaj = c2d(substr(h, 25, 1)); vMin = c2d(substr(h, 26, 1))
hSize = le(substr(h, 95, 2)); offPts = le(substr(h, 97, 4))
fmt = c2d(substr(h, 105, 1)) // 128          /* bit 7: LAZ flag        */
recLen = le(substr(h, 106, 2))
nPts = le(substr(h, 108, 4))
if vMin >= 4 & nPts = 0 then nPts = le(substr(h, 248, 8))
sx = dbl(substr(h, 132, 8)); sy = dbl(substr(h, 140, 8)); sz = dbl(substr(h, 148, 8))
ox = dbl(substr(h, 156, 8)); oy = dbl(substr(h, 164, 8)); oz = dbl(substr(h, 172, 8))
maxX = dbl(substr(h, 180, 8)); minX = dbl(substr(h, 188, 8))
maxY = dbl(substr(h, 196, 8)); minY = dbl(substr(h, 204, 8))
maxZ = dbl(substr(h, 212, 8)); minZ = dbl(substr(h, 220, 8))
say "LAS" vMaj"."vMin", point format" fmt", record" recLen "bytes," nPts "points"
say "  E" format(minX, , 2) "to" format(maxX, , 2)", N" format(minY, , 2) "to" format(maxY, , 2)", height" format(minZ, , 2) "to" format(maxZ, , 2)
if fmt <= 5 then clsAt = 16; else clsAt = 17     /* 1-based byte of classification */

/* the grid: west and south edges on whole cells */
x0 = trunc(minX / cell) * cell; y0 = trunc(minY / cell) * cell
nc = trunc((maxX - x0) / cell) + 1; nr = trunc((maxY - y0) / cell) + 1
top = .array~new(nr * nc); gsum = .array~new(nr * nc); gn = .array~new(nr * nc); wet = .array~new(nr * nc)
topCl = .array~new(nr * nc)
classes = .directory~new

/* read in chunks of 200000 points                                    */
chunk = 200000
done = 0
pos0 = offPts + 1
do while done < nPts
  k = min(chunk, nPts - done)
  buf = charin(lasFile, pos0, k * recLen)
  pos0 += k * recLen
  do i = 0 to k - 1
    b = i * recLen
    cl = c2d(substr(buf, b + clsAt, 1))
    if fmt <= 5 then cl = cl // 32
    if classes~hasIndex(cl) then classes[cl] = classes[cl] + 1
    else classes[cl] = 1
    /* inline little-endian: a routine call per value costs more than */
    /* the sums; x and y are never negative here (offsets at the tile) */
    xi = c2d(reverse(substr(buf, b + 1, 4))); yi = c2d(reverse(substr(buf, b + 5, 4)))
    zi = c2d(reverse(substr(buf, b + 9, 4))); if zi >= 2147483648 then zi = zi - 4294967296
    if xi >= 2147483648 then xi = xi - 4294967296
    if yi >= 2147483648 then yi = yi - 4294967296
    x = xi * sx + ox; y = yi * sy + oy; z = zi * sz + oz
    c = trunc((x - x0) / cell); r = trunc((y - y0) / cell)
    j = r * nc + c + 1
    if cl = 7 | cl = 18 then iterate
    t = top[j]
    if t == .nil then do; top[j] = z; topCl[j] = cl; end
    else if z > t then do; top[j] = z; topCl[j] = cl; end
    if cl = 2 then do
      if gsum[j] == .nil then do; gsum[j] = z; gn[j] = 1; end
      else do; gsum[j] += z; gn[j] += 1; end
    end
    if cl = 9 then wet[j] = 1
  end
  done += k
end
call stream lasFile, "c", "close"

call SysFileDelete out
call lineout out, "-- Roof and ground grids from" filespec("name", lasFile) "(LiDAR, NSW Government, CC BY 4.0)."
call lineout out, "-- Read by las_grid.rex, Claude (Opus 5.5). Architecture: Tom Dyer."
call lineout out, "-- Rows go north to south. top: highest return, not noise; ground: mean of ground returns."
cl = ""
do key over classes~allIndexes~sort
  cl = cl key"="classes[key]
end
call lineout out, "-- classes (count):" strip(cl)
call lineout out, ""
call lineout out, "lidar grid" filespec("name", lasFile)
call lineout out, "  grid mga 56 gda2020 south west" x0 y0 "cell" cell "across" nc "up" nr
do r = nr - 1 to 0 by -1
  mt = .mutableBuffer~new; mg = .mutableBuffer~new; mw = .mutableBuffer~new; mk = .mutableBuffer~new
  do c = 0 to nc - 1
    j = r * nc + c + 1
    if top[j] == .nil then mt~append(" -"); else mt~append(" " || format(top[j], , 2))
    if gn[j] == .nil then mg~append(" -"); else mg~append(" " || format(gsum[j] / gn[j], , 2))
    if wet[j] == .nil then mw~append("."); else mw~append("w")
    tc = topCl[j]
    select
      when tc == .nil then mk~append(".")
      when tc = 6 then mk~append("b")
      when tc >= 3 & tc <= 5 then mk~append("v")
      when tc = 2 then mk~append("g")
      when tc = 9 then mk~append("w")
      otherwise mk~append("o")
    end
  end
  call lineout out, "  top" strip(mt~string)
  call lineout out, "  ground" strip(mg~string)
  call lineout out, "  water" mw~string
  call lineout out, "  kind" mk~string
end
call lineout out, "end"
call stream out, "c", "close"
say "  classes:" strip(cl)
say "wrote" out "(" nc "by" nr "cells of" cell "m )"
exit 0

/* little-endian unsigned and signed whole numbers                     */
le: return c2d(reverse(arg(1)))
sle: procedure
  s = arg(1)
  v = c2d(reverse(s))
  if v >= 2 ** 31 then v = v - 2 ** 32
  return v
/* little-endian IEEE double                                           */
dbl: procedure
  numeric digits 20
  bits = x2b(c2x(reverse(arg(1))))
  sgn = left(bits, 1); ex = x2d(b2x(substr(bits, 2, 11))); fr = substr(bits, 13)
  if ex = 0 then return 0
  m = 1; f = 0.5
  do i = 1 to 52; if substr(fr, i, 1) then m = m + f; f = f / 2; end
  v = m * 2 ** (ex - 1023)
  if sgn then v = -v
  return v
