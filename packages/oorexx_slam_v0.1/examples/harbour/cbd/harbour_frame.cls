/* ------------------------------------------------------------------ */
/* harbour_frame.cls -- shared sums for the Power SLAM harbour checks  */
/*   MGA56 to Power SLAM scene metres (fitted to the exact scene to    */
/*   MGA sums), box footprints, bearings                              */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* ------------------------------------------------------------------ */
::requires "SlamHarbourWordsScene.cls"
::requires "SlamHarbourPose.cls"
::requires "rxmath" LIBRARY

::routine bearingOf public
  use arg dx, dy
  if dx = 0 & dy = 0 then return 0
  if dy = 0 then do
    if dx > 0 then return 90
    return 270
  end
  a = RxCalcArcTan(abs(dx) / abs(dy), 12, "D")
  if dx >= 0 & dy > 0 then return a
  if dx >= 0 & dy < 0 then return 180 - a
  if dx < 0 & dy < 0 then return 180 + a
  return 360 - a

/* one box's ground footprint, from Power SLAM's eight corners:       */
/* 1 (-along,-across) 2 (-along,+across) 3 (+along,-across) 4 (+,+)  */
::class Footprint public
::attribute cx get
::attribute cy get
::attribute long get
::attribute wide get
::attribute bearing get
::attribute corners get
::method init
  expose cx cy long wide bearing corners
  use arg v
  corners = .array~of(v[1], v[2], v[4], v[3])
  cx = (v[1][1] + v[2][1] + v[3][1] + v[4][1]) / 4
  cy = (v[1][2] + v[2][2] + v[3][2] + v[4][2]) / 4
  ax = v[3][1] - v[1][1]; ay = v[3][2] - v[1][2]
  bx = v[2][1] - v[1][1]; by = v[2][2] - v[1][2]
  la = HSqrt(ax * ax + ay * ay); lb = HSqrt(bx * bx + by * by)
  /* the long side gives the bearing */
  if lb > la then do
    parse value ax ay la with tx ty tl
    ax = bx; ay = by; la = lb
    bx = tx; by = ty; lb = tl
  end
  long = la; wide = lb
  bearing = bearingOf(ax, ay) // 180
  if bearing > 90 then bearing = bearing + 180   /* name the northern end */
  bearing = bearing // 360
/* is (x, y) inside, with padL metres added along and padW across     */
::method holds
  expose cx cy long wide bearing
  use arg x, y, padL = 0, padW = 0
  ux = RxCalcSin(bearing, 12, "D"); uy = RxCalcCos(bearing, 12, "D")
  dx = x - cx; dy = y - cy
  a = dx * ux + dy * uy
  b = dx * uy - dy * ux
  return abs(a) <= long / 2 + padL & abs(b) <= wide / 2 + padW
/* metres along the long axis from the middle, toward the north end  */
::method alongOf
  expose cx cy bearing
  use arg x, y
  ux = RxCalcSin(bearing, 12, "D"); uy = RxCalcCos(bearing, 12, "D")
  return (x - cx) * ux + (y - cy) * uy
::method northEnd
  expose cx cy long bearing
  /* the end of the long axis nearer north */
  ux = RxCalcSin(bearing, 12, "D"); uy = RxCalcCos(bearing, 12, "D")
  if uy < 0 then do; ux = -ux; uy = -uy; end
  return .array~of(cx + ux * long / 2, cy + uy * long / 2)

/* MGA (E, N) to scene (x, y): least squares plane fitted to the exact */
/* scene -> MGA sums (sceneMGA = inverse of ~local, then mgaOf). The   */
/* scene frame is true north and MGA is grid north, so the plane       */
/* carries the turn between them; its error is measured, not assumed. */
::class FrameFit public
::attribute points get
::attribute worst get
::attribute turn get
::method init
  expose cx cy pts points worst turn em nm
  use arg tile
  pts = 0
  sE = .array~new; sN = .array~new; sX = .array~new; sY = .array~new
  do x = -2500 to 3000 by 500
    do y = -2500 to 1500 by 500
      p = tile~sceneMGA(x, y)
      sE~append(p[1]); sN~append(p[2]); sX~append(x); sY~append(y)
    end
  end
  pts = sE~items; points = pts
  em = 0; nm = 0
  do k = 1 to pts; em += sE[k]; nm += sN[k]; end
  em = em / pts; nm = nm / pts
  cx = solve3(sE, sN, sX, em, nm)
  cy = solve3(sE, sN, sY, em, nm)
  /* turn of grid north against scene north, from the fitted plane */
  turn = bearingOf(cx[3], cy[3])
  if turn > 180 then turn = turn - 360
  /* worst error at points between the fitting points */
  worst = 0
  do x = -2250 to 2750 by 500
    do y = -2250 to 1250 by 500
      p = tile~sceneMGA(x, y)
      q = self~scene(p[1], p[2])
      worst = max(worst, HSqrt((q[1] - x) ** 2 + (q[2] - y) ** 2))
    end
  end
::method scene
  expose cx cy em nm
  use arg e, n
  de = e - em; dn = n - nm
  return .array~of(cx[1] + cx[2] * de + cx[3] * dn, cy[1] + cy[2] * de + cy[3] * dn)

/* least squares: out = a + b*(E-em) + c*(N-nm); returns array a b c   */
::routine solve3
  use arg sE, sN, out, em, nm
  numeric digits 30
  s11 = 0; s12 = 0; s13 = 0; s22 = 0; s23 = 0; s33 = 0; t1 = 0; t2 = 0; t3 = 0
  do k = 1 to sE~items
    u = sE[k] - em; w = sN[k] - nm; z = out[k]
    s11 += 1; s12 += u; s13 += w; s22 += u * u; s23 += u * w; s33 += w * w
    t1 += z; t2 += u * z; t3 += w * z
  end
  d = det3(s11, s12, s13, s12, s22, s23, s13, s23, s33)
  a = det3(t1, s12, s13, t2, s22, s23, t3, s23, s33) / d
  b = det3(s11, t1, s13, s12, t2, s23, s13, t3, s33) / d
  c = det3(s11, s12, t1, s12, s22, t2, s13, s23, t3) / d
  return .array~of(a, b, c)

::routine det3
  use arg a, b, c, d, e, f, g, h, i
  return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)

