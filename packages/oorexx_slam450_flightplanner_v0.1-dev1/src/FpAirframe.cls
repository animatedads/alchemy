/* FpAirframe.cls - SLAM 450 Flight Planner v0.1: the fixed wing the plan is
 * made for, its glide and its wind triangle; and FpGeo, distances and
 * bearings on the sphere. All trigonometry through the estate's Maths package.
 *
 * Planning defaults (Tom: "plan for fixed wing ... a beefy energy budget"),
 * each overridable from the environment until the airframe is chosen:
 *   FP_CRUISE_MS    27     cruise true airspeed, m/s (about 52 kt)
 *   FP_GLIDE_MS     22     best-glide airspeed, m/s
 *   FP_GLIDE_RATIO  16     best lift/drag: metres forward per metre of height
 *   FP_XWIND_MS     12     largest crosswind component it may fly in, m/s
 *   FP_ENDURANCE_H  24     energy budget at cruise, hours ("beefy")
 *   FP_RESERVE      0.30   fraction of the budget kept back
 *
 * Glide, engine off, at best-glide speed V from height h with wind W:
 * in the moving air it reaches a circle of radius R = h*LD; it is airborne
 * T = R/V seconds, and the air carries it W*T downwind. So on the ground the
 * reachable area is that circle, its centre W*T downwind:
 *   reach into the wind  = R - W*T
 *   reach downwind       = R + W*T
 *   reach across the wind = sqrt(R*R - (W*T)**2)
 * (Holding best-glide speed into a headwind is conservative: speeding up
 * gains a little; this plans on the smaller figure.)
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
::requires 'MathsBootstrap.cls'

::class FpAirframe public
::attribute cruise get
::attribute glideSpeed get
::attribute glideRatio get
::attribute maxCrosswind get
::attribute enduranceHours get
::attribute reserve get

::method init
  expose cruise glideSpeed glideRatio maxCrosswind enduranceHours reserve
  cruise = env('FP_CRUISE_MS', 27)
  glideSpeed = env('FP_GLIDE_MS', 22)
  glideRatio = env('FP_GLIDE_RATIO', 16)
  maxCrosswind = env('FP_XWIND_MS', 12)
  enduranceHours = env('FP_ENDURANCE_H', 24)
  reserve = env('FP_RESERVE', 0.30)

::method describe
  expose cruise glideSpeed glideRatio maxCrosswind enduranceHours reserve
  return 'fixed wing: cruise' cruise 'm/s, best glide' glideSpeed 'm/s at L/D' glideRatio', crosswind limit' maxCrosswind 'm/s, budget' enduranceHours 'h with' format(reserve*100,,0)'% reserve'

/* reach on the ground from height h (m) with wind W (m/s): Directory of
   INTO, DOWN, ACROSS (m) and SECONDS airborne */
::method glide
  expose glideSpeed glideRatio
  use strict arg h, w
  r = h * glideRatio
  t = r / glideSpeed
  d = w * t
  g = .directory~new
  g['SECONDS'] = t
  g['DOWN'] = r + d
  if d >= r then do; g['INTO'] = 0; g['ACROSS'] = 0; end
  else do
    g['INTO'] = r - d
    g['ACROSS'] = .Maths~sqrt(r*r - d*d)
  end
  return g

/* the wind triangle on a track (deg true) with the wind FROM windFrom (deg)
   at w (m/s): Directory of TAIL (m/s, + behind), CROSS (m/s, + from the
   left), GROUND (m/s, 0 if it cannot be flown), OK (1/0), WHY */
::method triangle
  expose cruise maxCrosswind
  use strict arg track, w, windFrom
  rel = windFrom - track
  tail = -w * cosd(rel)
  cross = w * sind(rel)
  t = .directory~new
  t['TAIL'] = tail; t['CROSS'] = cross; t['OK'] = 1; t['WHY'] = ''
  if abs(cross) > maxCrosswind then do; t['OK'] = 0; t['WHY'] = 'crosswind' format(abs(cross),,1) 'm/s over the limit'; end
  if abs(cross) >= cruise then do; t['GROUND'] = 0; t['OK'] = 0; t['WHY'] = 'crosswind at or above airspeed'; return t; end
  along = .Maths~sqrt(cruise*cruise - cross*cross)
  t['GROUND'] = along + tail
  if t['GROUND'] <= 0 then do; t['GROUND'] = 0; t['OK'] = 0; t['WHY'] = 'headwind at or above airspeed'; end
  return t

::routine env
  use strict arg name, default
  v = value(name,, 'ENVIRONMENT')
  if datatype(v, 'N') then return v
  return default

::routine sind public
  use strict arg x
  return .Maths~angleDegrees(x)~sin
::routine cosd public
  use strict arg x
  return .Maths~angleDegrees(x)~cos


/* Great-circle distance (m) and initial bearing (deg true), mean Earth radius 6371 km */
::class FpGeo public
::method distance class
  use strict arg lat1, lon1, lat2, lon2
  dlat = (lat2 - lat1) / 2; dlon = (lon2 - lon1) / 2
  a = sind(dlat)**2 + cosd(lat1) * cosd(lat2) * sind(dlon)**2
  c = 2 * .Maths~atan2(.Maths~sqrt(a), .Maths~sqrt(1 - a))~degreesValue
  return 6371000 * c * 3.14159265358979323846 / 180

::method bearing class
  use strict arg lat1, lon1, lat2, lon2
  dlon = lon2 - lon1
  y = sind(dlon) * cosd(lat2)
  x = cosd(lat1) * sind(lat2) - sind(lat1) * cosd(lat2) * cosd(dlon)
  b = .Maths~atan2(y, x)~degreesValue
  if b < 0 then b = b + 360
  return b
