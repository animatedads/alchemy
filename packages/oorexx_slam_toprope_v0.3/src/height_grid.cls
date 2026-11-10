/* ------------------------------------------------------------------ */
/* height_grid.cls -- one height layer, read once, asked many times   */
/*                                                                    */
/* Architecture : Tom Dyer (a height layer under the map layers that  */
/*                other services ask: Boston Crab, SLAM 450)          */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Reads either:                                                      */
/*   an ESRI ASCII grid in degrees (ncols/nrows/xllcorner/yllcorner/  */
/*   cellsize; e.g. Copernicus GLO-30 cut with GDAL), or              */
/*   Top Rope height words ("grid mga 56 top left E N step S ...",    */
/*   "row ..."; made by height_map.rex from ELVIS)                    */
/* and answers in its own flat plane, in metres:                      */
/*   ~plane(lat, lon)      -> "x y"   (x east, y north)               */
/*   ~heightXY(x, y)       -> metres, or "" off the grid / no data    */
/*   ~heightAt(lat, lon)   -> metres, or ""                           */
/* The plane is MGA/UTM for height words, and for a degree grid a     */
/* flat east/north plane about the grid's middle (good to well under  */
/* a metre across a few km, which is what a degree cut covers).       */
/* ------------------------------------------------------------------ */
::requires "mga.cls"
::requires "rxmath" LIBRARY

::class HeightGrid public

::attribute source get       /* what the grid is, for every answer   */
::attribute cellMetres get
::attribute kind get         /* DEGREES or MGA                       */

::method init
  expose kind rows ncols nrows x0 y0 cell zone mLat mLon lat0 lon0 source cellMetres
  use strict arg file, source = ""
  s = .stream~new(file)
  if s~open("read") \= "READY:" then raise syntax 98.900 array ("height grid: I can not read" file)
  first = s~linein
  rows = .array~new
  if first~word(1)~lower = "ncols" then do
    kind = "DEGREES"
    hdr = .directory~new
    hdr[first~word(1)~upper] = first~word(2)
    do 5
      l = s~linein
      hdr[l~word(1)~upper] = l~word(2)
    end
    ncols = hdr~ncols; nrows = hdr~nrows
    cell = hdr~cellsize
    nodata = ""
    if hdr~hasIndex("NODATA_VALUE") then nodata = hdr~nodata_value
    x0 = hdr~xllcorner                   /* west edge, degrees     */
    y0 = hdr~yllcorner + nrows * cell     /* north edge, degrees    */
    do r = 1 to nrows
      a = s~linein~space~makeArray(" ")
      if nodata \== "" then do c = 1 to a~items
        if a[c] = nodata then a[c] = ""
      end
      rows[r] = a
    end
    lat0 = y0 - nrows * cell / 2
    lon0 = x0 + ncols * cell / 2
    mLat = 111132.92 - 559.82 * RxCalcCos(2 * lat0, , "D")
    mLon = 111412.84 * RxCalcCos(lat0, , "D")
    cellMetres = cell * min(mLat, mLon)
  end
  else do
    kind = "MGA"
    l = first
    do forever
      w = l~word(1)
      if w = "grid" then parse var l "grid mga" zone "top left" x0 y0 "step" cell "across" ncols "down" nrows .
      if w = "row" then do
        a = l~subword(2)~makeArray(" ")
        do c = 1 to a~items
          if a[c] = "-" then a[c] = ""
        end
        rows~append(a)
      end
      if s~lines = 0 then leave
      l = s~linein~strip
    end
    if zone = "" then raise syntax 98.900 array ("height grid:" file "has no grid line")
    nrows = rows~items
    cellMetres = cell
  end
  s~close
  if source = "" then source = kind "grid" file

/* lat, lon -> "x y" in the grid's plane, metres */
::method plane
  expose kind zone mLat mLon lat0 lon0
  use strict arg lat, lon
  if kind = "MGA" then return mgaOf(lat, lon, zone)
  return (lon - lon0) * mLon (lat - lat0) * mLat

/* the place on the earth of a plane point, for saying where */
::method latLon
  expose kind mLat mLon lat0 lon0
  use strict arg x, y
  if kind = "DEGREES" then return lat0 + y / mLat lon0 + x / mLon
  return ""      /* MGA back to lat/lon is not needed yet */

::method heightAt
  use strict arg lat, lon
  parse value self~plane(lat, lon) with x y
  return self~heightXY(x, y)

/* bilinear between the four nearest grid points; "" off the grid */
::method heightXY
  expose kind rows ncols nrows x0 y0 cell mLat mLon lat0 lon0
  use strict arg x, y
  if kind = "DEGREES" then do
    lon = lon0 + x / mLon
    lat = lat0 + y / mLat
    fx = (lon - x0) / cell - 0.5     /* ESRI values sit at cell centres */
    fy = (y0 - lat) / cell - 0.5
  end
  else do
    fx = (x - x0) / cell             /* height words: values at points  */
    fy = (y0 - y) / cell
  end
  c = trunc(fx); r = trunc(fy)
  if fx < 0 | fy < 0 then return ""
  if c + 2 > ncols | r + 2 > nrows then return ""
  a = rows[r + 1]; b = rows[r + 2]
  if c + 2 > a~items | c + 2 > b~items then return ""
  h00 = a[c + 1]; h10 = a[c + 2]; h01 = b[c + 1]; h11 = b[c + 2]
  if h00 == "" | h10 == "" | h01 == "" | h11 == "" then return ""
  tx = fx - c; ty = fy - r
  return (h00 * (1 - tx) + h10 * tx) * (1 - ty) + (h01 * (1 - tx) + h11 * tx) * ty
