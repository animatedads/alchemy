/* ------------------------------------------------------------------ */
/* sight_line.cls -- can one place see another over the ground?       */
/*                                                                    */
/* Architecture : Tom Dyer (map reading gives who can see what; other */
/*                services take it as a fact at the map's own tier)   */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/*   sl = .SightLine~new(.HeightGrid~new(file, source))               */
/*   d  = sl~look(a, b)        a, b: .directory with LAT LON and      */
/*                             either EYE (metres above the ground)   */
/*                             or ASL (metres above the datum)        */
/*   d['SEES']   .true, .false, or "UNKNOWN" (part of the line is off */
/*               the grid or has no data: never guessed)              */
/*   d['CLEAR']  least metres between line and ground (< 0: blocked)  */
/*   d['BLOCK_FROM'] metres from a to where the ground is highest     */
/*               above the line; BLOCK_LAT/BLOCK_LON (degree grids)   */
/*   d['DIST'], d['GROUND_A'], d['GROUND_B'], d['SOURCE']             */
/*   s  = sl~spread(a, ra, b, rb)   a known to within ra metres, b to */
/*               rb: looks from 5 x 5 points round a to 3 x 3 round b */
/*   s['SEEN'], s['TRIED'], s['VERDICT'] SEES / CANNOT / SOMETIMES    */
/*                                                                    */
/* The line is walked in steps of half a grid cell (2 to 25 m). The   */
/* earth's curve is allowed for, with normal refraction (k = 0.13).   */
/* What the grid is (bare earth, or a surface model with today's      */
/* trees and buildings) is the grid's source string, given back with  */
/* every answer.                                                      */
/* ------------------------------------------------------------------ */
::requires "height_grid.cls"
::requires "rxmath" LIBRARY

::class SightLine public

::method init
  expose grid k
  use strict arg grid, k = 0.13

::method grid
  expose grid
  return grid

::method look
  expose grid k
  use strict arg a, b
  R = 6371000
  parse value grid~plane(a['LAT'], a['LON']) with xa ya
  parse value grid~plane(b['LAT'], b['LON']) with xb yb
  out = .directory~new
  out['SOURCE'] = grid~source
  ga = grid~heightXY(xa, ya)
  gb = grid~heightXY(xb, yb)
  out['GROUND_A'] = ga
  out['GROUND_B'] = gb
  dx = xb - xa; dy = yb - ya
  d = RxCalcSqrt(dx * dx + dy * dy)
  out['DIST'] = d
  if ga == "" | gb == "" then do
    out['SEES'] = "UNKNOWN"
    out['WHY'] = "an end is off the grid"
    return out
  end
  ha = eyeHeight(a, ga)
  hb = eyeHeight(b, gb)
  step = max(2, min(25, grid~cellMetres / 2))
  n = max(2, trunc(d / step))
  worst = -1e9; wt = 0
  do i = 1 to n - 1
    t = i / n
    gr = grid~heightXY(xa + t * dx, ya + t * dy)
    if gr == "" then do
      out['SEES'] = "UNKNOWN"
      out['WHY'] = "part of the line is off the grid or has no data"
      return out
    end
    d1 = t * d
    bulge = d1 * (d - d1) * (1 - k) / (2 * R)
    over = gr + bulge - (ha + t * (hb - ha))
    if over > worst then do
      worst = over; wt = t
    end
  end
  out['CLEAR'] = -worst
  out['SEES'] = (worst <= 0)
  out['BLOCK_FROM'] = wt * d
  ll = grid~latLon(xa + wt * dx, ya + wt * dy)
  if ll \== "" then do
    out['BLOCK_LAT'] = ll~word(1)
    out['BLOCK_LON'] = ll~word(2)
  end
  return out

/* positions known only roughly: count the pairs that see */
::method spread
  expose grid
  use strict arg a, ra, b, rb
  seen = 0; tried = 0; unknown = 0
  mLat = 111320
  mLon = 111320 * RxCalcCos(a['LAT'], , "D")
  do i = -2 to 2
    do j = -2 to 2
      pa = moved(a, i * ra / 2 / mLat, j * ra / 2 / mLon)
      do u = -1 to 1
        do v = -1 to 1
          pb = moved(b, u * rb / mLat, v * rb / mLon)
          r = self~look(pa, pb)
          if r['SEES'] == "UNKNOWN" then do
            unknown = unknown + 1
            iterate
          end
          tried = tried + 1
          if r['SEES'] then seen = seen + 1
        end
      end
    end
  end
  out = .directory~new
  out['SEEN'] = seen; out['TRIED'] = tried; out['UNKNOWN'] = unknown
  out['SOURCE'] = grid~source
  select
    when tried = 0 then out['VERDICT'] = "UNKNOWN"
    when seen = tried then out['VERDICT'] = "SEES"
    when seen = 0 then out['VERDICT'] = "CANNOT"
    otherwise out['VERDICT'] = "SOMETIMES"
  end
  return out

::routine eyeHeight
  use arg p, ground
  if p~hasIndex('ASL') then return p['ASL']
  return ground + p['EYE']

::routine moved
  use arg p, dLat, dLon
  q = p~copy
  q['LAT'] = p['LAT'] + dLat
  q['LON'] = p['LON'] + dLon
  return q
