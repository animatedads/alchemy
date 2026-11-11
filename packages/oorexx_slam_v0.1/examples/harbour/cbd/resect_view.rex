/* ------------------------------------------------------------------ */
/* resect_view.rex -- where a photo was taken from, from known points */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx resect_view.rex points.words width height [fov]               */
/*                                                                    */
/* points.words lines:  point name scene x y z pixel u v               */
/* A grid search, coarse then finer, for the camera x y z, heading    */
/* and tilt (and fov if not given) that put each point nearest its    */
/* pixel; prints the best camera and each point's miss in pixels.     */
/* A level camera (no roll) and a plain pinhole are assumed.           */
/* ------------------------------------------------------------------ */
parse arg pf W H fovIn .
numeric digits 14
pts = .array~new
do while lines(pf) > 0
  l = linein(pf)~strip
  if word(l, 1) \== "point" then iterate
  parse var l "point" nm "scene" x y z "pixel" u v .
  pts~append(.array~of(nm, x, y, z, u, v))
end
call stream pf, "c", "close"
d2r = RxCalcPi(14) / 180
best = 1e30
/* start: a box north of the Quay                                     */
lo.1 = -600; hi.1 = 600       /* x            */
lo.2 = -900; hi.2 = -150      /* y: over the harbour, south of Kirribilli */
lo.3 = 150;  hi.3 = 800       /* z: the photo looks down on the Quay */
lo.4 = 150;  hi.4 = 220       /* heading      */
lo.5 = -20;  hi.5 = 0         /* tilt         */
lo.6 = 40;   hi.6 = 90        /* fov          */
if fovIn \= "" then do; lo.6 = fovIn; hi.6 = fovIn; end
STEPS = 6
do pass = 1 to 7
  do i1 = 0 to STEPS
    p1 = lo.1 + (hi.1 - lo.1) * i1 / STEPS
    do i2 = 0 to STEPS
      p2 = lo.2 + (hi.2 - lo.2) * i2 / STEPS
      do i3 = 0 to STEPS
        p3 = lo.3 + (hi.3 - lo.3) * i3 / STEPS
        do i4 = 0 to STEPS
          p4 = lo.4 + (hi.4 - lo.4) * i4 / STEPS
          do i5 = 0 to STEPS
            p5 = lo.5 + (hi.5 - lo.5) * i5 / STEPS
            do i6 = 0 to STEPS
              p6 = lo.6 + (hi.6 - lo.6) * i6 / STEPS
              e = cost(p1, p2, p3, p4, p5, p6)
              if e < best then do
                best = e; b.1 = p1; b.2 = p2; b.3 = p3; b.4 = p4; b.5 = p5; b.6 = p6
              end
              if lo.6 = hi.6 then leave
            end
          end
        end
      end
    end
  end
  /* shrink round the best                                            */
  do k = 1 to 6
    span = (hi.k - lo.k) / 3
    lo.k = b.k - span / 2; hi.k = b.k + span / 2
  end
  say "pass" pass": rms" format(RxCalcSqrt(best / pts~items, 8), , 1) "px  camera" format(b.1, , 0) format(b.2, , 0) format(b.3, , 0) ,
      "heading" format(b.4, , 1) "tilt" format(b.5, , 1) "fov" format(b.6, , 1)
end
say "misses (pixels):"
call cost b.1, b.2, b.3, b.4, b.5, b.6, 1
exit 0

cost: procedure expose pts W H d2r
  use arg cx, cy, cz, hd, tl, fov, show = 0
  sh = RxCalcSin(hd * d2r, 12, "R"); ch = RxCalcCos(hd * d2r, 12, "R")
  st = RxCalcSin(tl * d2r, 12, "R"); ct = RxCalcCos(tl * d2r, 12, "R")
  fx = sh * ct; fy = ch * ct; fz = st
  rx = ch; ry = -sh
  ux = ry * fz; uy = -rx * fz; uz = rx * fy - ry * fx
  f = (W / 2) / RxCalcTan(fov / 2 * d2r, 12, "R")
  sum = 0
  do p over pts
    dx = p[2] - cx; dy = p[3] - cy; dz = p[4] - cz
    depth = dx * fx + dy * fy + dz * fz
    if depth <= 1 then return 1e20
    u = W / 2 + f * (dx * rx + dy * ry) / depth
    v = H / 2 - f * (dx * ux + dy * uy + dz * uz) / depth
    sum += (u - p[5]) ** 2 + (v - p[6]) ** 2
    if show then say "  " left(p[1], 16) "du" format(u - p[5], , 0) "dv" format(v - p[6], , 0)
  end
  return sum

::requires "rxmath" LIBRARY
