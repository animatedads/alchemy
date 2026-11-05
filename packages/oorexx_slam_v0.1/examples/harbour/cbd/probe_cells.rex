/* ------------------------------------------------------------------ */
/* probe_cells.rex -- what the LiDAR mosaic holds round one place      */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx probe_cells.rex mosaic.words streets.words lat lon [radius]   */
/*   (or easting northing, MGA 56, in place of lat lon)               */
/*                                                                    */
/* Prints, north row first, each cell's top (AHD, tens of metres:     */
/* 0-9 then a = 100 m ... z = 350 m) with its kind letter: b building,*/
/* o other structure, g ground, v plant, w water, - a structure under */
/* 3 m above its own ground, upper case B O: no ground return in the  */
/* cell, s a street cell. A diagnostic only.                          */
/* ------------------------------------------------------------------ */
parse arg mos streets la lo radius .
if lo = "" then do
  say "usage: rexx probe_cells.rex mosaic.words streets.words lat lon [radius]"
  exit 2
end
if radius = "" then radius = 40
numeric digits 16
CODES = "0123456789abcdefghijklmnopqrstuvwxyz"
if abs(la) > 1000 then do; e = la; n = lo; end
else parse value mgaOf(la, lo) with e n
top = .array~new; grd = .array~new; knd = .array~new
do while lines(mos) > 0
  l = linein(mos)~strip
  w1 = word(l, 1)
  if w1 == "grid" then parse var l "south west" x0 y0 "cell" cell "across" nc "up" nr .
  else if w1 == "top" then top~append(subword(l, 2))
  else if w1 == "ground" then grd~append(subword(l, 2))
  else if w1 == "kind" then knd~append(word(l, 2))
end
call stream mos, "c", "close"
srow = .array~new
do while lines(streets) > 0
  l = linein(streets)~strip
  if word(l, 1) == "row" then srow~append(word(l, 2))
end
call stream streets, "c", "close"
c0 = trunc((e - x0) / cell) + 1
r0 = nr - trunc((n - y0) / cell)
k = trunc(radius / cell)
say "place" la lo "is MGA" format(e, , 1) format(n, , 1) "cell col" c0 "row" r0
do r = r0 - k to r0 + k
  t = word(top[r], 1)
  out = ""
  tr = top[r]; gr = grd[r]; kr = knd[r]; sr = srow[r]
  do c = c0 - k to c0 + k
    tv = word(tr, c); gv = word(gr, c); kv = substr(kr, c, 1)
    ch = "."
    if datatype(tv, "N") then do
      d = trunc(tv / 10)
      if d >= 0 & d < 36 then ch = substr(CODES, d + 1, 1)
      else ch = "+"
      if datatype(gv, "N") then do; if tv - gv < 3 then kv = translate(kv, "--", "bo"); end
      else kv = translate(kv)
    end
    if substr(sr, c, 1) == "s" then kv = "s"
    if r = r0 & c = c0 then out = out || "[" || ch || kv
    else out = out || " " || ch || kv
  end
  say out
end
exit 0

::requires "mga.cls"
