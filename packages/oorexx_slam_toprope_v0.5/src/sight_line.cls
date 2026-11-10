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
/* Buildings and other solids the grid does not hold (a bare-earth    */
/* grid has no CBD): give SightLine an occluder, any object with      */
/*   ~blocks(a, b)  a, b: .directory with LAT LON ASL (eye, metres)   */
/*                  -> "" or the name of what is in the way           */
/* e.g. .BoxOccluders below, or an adapter over a SLAM 450 scene.     */
/* d['BLOCKED_BY'] then names it, and d['SEES'] is false.             */
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
  expose grid k occluder
  use strict arg grid, k = 0.13, occluder = .nil

::method occluder
  expose occluder
  return occluder

::method setOccluder
  expose occluder
  use strict arg occluder

::method grid
  expose grid
  return grid

::method look
  expose grid k occluder
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
  out['BLOCKED_BY'] = ''
  if worst > 0 then out['BLOCKED_BY'] = 'ground'
  /* solids the grid does not hold */
  if out['SEES'] then if occluder \== .nil then do
    ea = a~copy; ea['ASL'] = ha
    eb = b~copy; eb['ASL'] = hb
    hit = occluder~blocks(ea, eb)
    if hit \== '' then do
      out['SEES'] = .false
      out['BLOCKED_BY'] = hit
    end
  end
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

/* ------------------------------------------------------------------ */
/* BoxOccluders -- upright boxes (buildings, pylons) in the grid's     */
/* plane: each is a name, a centre (lat lon), half width east and half */
/* depth north in metres, a turn in degrees (clockwise from north),    */
/* and its base and top in metres above the datum.                     */
/*   occ = .BoxOccluders~new(grid)                                     */
/*   occ~add('salesforce', -33.8616, 151.2078, 30, 30, 0, 5, 263)      */
/* or read them from words, one a line:                                */
/*   box <name> <lat> <lon> <half east> <half north> <turn> <base> <top>*/
/* ------------------------------------------------------------------ */
::class BoxOccluders public

::method init
  expose grid boxes
  use strict arg grid
  boxes = .array~new

::method add
  expose grid boxes
  use strict arg nm, lat, lon, hx, hy, turn, base, top
  parse value grid~plane(lat, lon) with cx cy
  b = .directory~new
  b['NAME'] = nm; b['CX'] = cx; b['CY'] = cy; b['HX'] = hx; b['HY'] = hy
  b['C'] = RxCalcCos(turn, , 'D'); b['S'] = RxCalcSin(turn, , 'D')
  b['BASE'] = base; b['TOP'] = top
  boxes~append(b)

::method load
  use strict arg file
  s = .stream~new(file)~~open('read')
  do while s~lines > 0
    l = s~linein~strip
    if l~word(1) \== 'box' then iterate
    parse var l 'box' nm lat lon hx hy turn base top .
    self~add(nm, lat, lon, hx, hy, turn, base, top)
  end
  s~close

::method items
  expose boxes
  return boxes~items

/* the first box the eye-to-eye segment passes through, or "" (slab test
   in each box's own frame: across, along, up) */
::method blocks
  expose grid boxes
  use strict arg a, b
  parse value grid~plane(a['LAT'], a['LON']) with ax ay
  parse value grid~plane(b['LAT'], b['LON']) with bx by
  best = 2; found = ''
  do bx_ over boxes
    /* into the box frame: u across (east when turn is 0), v along */
    ux0 = ax - bx_['CX']; uy0 = ay - bx_['CY']
    ux1 = bx - bx_['CX']; uy1 = by - bx_['CY']
    c = bx_['C']; s = bx_['S']
    p0 = .array~of(ux0 * c - uy0 * s, ux0 * s + uy0 * c, a['ASL'])
    p1 = .array~of(ux1 * c - uy1 * s, ux1 * s + uy1 * c, b['ASL'])
    lo = .array~of(-bx_['HX'], -bx_['HY'], bx_['BASE'])
    hi = .array~of(bx_['HX'], bx_['HY'], bx_['TOP'])
    t0 = 0; t1 = 1; miss = .false
    do k = 1 to 3
      d = p1[k] - p0[k]
      if abs(d) < 1e-9 then do
        if p0[k] < lo[k] | p0[k] > hi[k] then miss = .true
        iterate
      end
      ta = (lo[k] - p0[k]) / d
      tb = (hi[k] - p0[k]) / d
      if ta > tb then do; tt = ta; ta = tb; tb = tt; end
      t0 = max(t0, ta); t1 = min(t1, tb)
      if t0 > t1 then miss = .true
    end
    if miss then iterate
    /* a watcher or target in or on a box (a camera in a tower, a man on
       a roof) is not hidden by that box */
    if inside(p0, lo, hi) | inside(p1, lo, hi) then iterate
    if t1 <= 1e-6 | t0 >= 1 - 1e-6 then iterate
    if t0 < best then do
      best = t0; found = bx_['NAME']
    end
  end
  return found

::routine inside
  use arg p, lo, hi
  do k = 1 to 3
    if p[k] < lo[k] - 0.01 | p[k] > hi[k] + 0.01 then return .false
  end
  return .true
