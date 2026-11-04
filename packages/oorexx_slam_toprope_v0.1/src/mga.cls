/* ------------------------------------------------------------------ */
/* mga.cls -- latitude and longitude to MGA (GDA94, Transverse        */
/*            Mercator on GRS80), so SLAM can read the NSW / ELVIS    */
/*            height grids at a place on the earth                    */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* The sums: Snyder, Map Projections - A Working Manual (USGS 1395),  */
/* Transverse Mercator on the ellipsoid; good to well under a metre   */
/* inside one zone.                                                   */
/* ------------------------------------------------------------------ */
::requires "rxmath" LIBRARY

/* lat, lon in degrees (south is less than 0) -> "E N" in metres      */
::routine mgaOf public
  use arg lat, lon, zone = 56
  numeric digits 20
  a = 6378137
  f = 1 / 298.257222101
  e2 = f * (2 - f)
  e4 = e2 * e2
  e6 = e4 * e2
  ep2 = e2 / (1 - e2)
  k0 = 0.9996
  lon0 = zone * 6 - 183
  pi = RxCalcPi(18)
  phi = lat * pi / 180
  s = RxCalcSin(phi, 18, "R")
  c = RxCalcCos(phi, 18, "R")
  t = s / c
  NN = a / RxCalcSqrt(1 - e2 * s * s, 18)
  TT = t * t
  CC = ep2 * c * c
  AA = (lon - lon0) * pi / 180 * c
  M = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi ,
         - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * RxCalcSin(2 * phi, 18, "R") ,
         + (15 * e4 / 256 + 45 * e6 / 1024) * RxCalcSin(4 * phi, 18, "R") ,
         - (35 * e6 / 3072) * RxCalcSin(6 * phi, 18, "R"))
  x = k0 * NN * (AA + (1 - TT + CC) * AA ** 3 / 6 ,
                + (5 - 18 * TT + TT * TT + 72 * CC - 58 * ep2) * AA ** 5 / 120)
  y = k0 * (M + NN * t * (AA * AA / 2 + (5 - TT + 9 * CC + 4 * CC * CC) * AA ** 4 / 24 ,
                + (61 - 58 * TT + TT * TT + 600 * CC - 330 * ep2) * AA ** 6 / 720))
  E = 500000 + x
  N = y
  if lat < 0 then N = 10000000 + y
  return format(E, , 2) format(N, , 2)
