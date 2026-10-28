/* SLAM fold fixture: areaB is areaA under other names; totalB is totalA but calls areaB.
   Folding areaB into areaA (pass 1) makes totalB the same as totalA (pass 2): BOLT's fixpoint.
   areaC is areaA's text under another name, so it is skipped at ingest and kept as an alias (pass 0);
   totalC calls areaC, so it is the same as totalA from pass 1.
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
::routine areaC
  use arg w, h
  if w < 0 then return 0
  return w * h
::routine totalC
  use arg a, b
  x = areaC(a, b)
  return x + 1
