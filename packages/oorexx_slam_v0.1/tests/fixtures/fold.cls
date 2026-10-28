/* SLAM fold fixture: areaB is areaA under other names; totalB is totalA but calls areaB.
   Folding areaB into areaA (pass 1) makes totalB the same as totalA (pass 2): BOLT's fixpoint.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28. */
::routine areaA
  use arg w, h
  if w < 0 then return 0
  return w * h
::routine areaB
  use arg width, height
  if width < 0 then return 0
  return width * height
::routine totalA
  use arg a, b
  x = areaA(a, b)
  return x + 1
::routine totalB
  use arg p, q
  y = areaB(p, q)
  return y + 1
::routine notTheSame
  use arg p, q
  y = areaB(p, q)
  return y + 2
