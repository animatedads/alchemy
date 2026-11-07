/* FpRoute.cls - SLAM 450 Flight Planner v0.1: a route file, point|name|lat|lon
 * lines in flying order, loaded once into an Array of Directories (NAME, LAT,
 * LON) that every tool loops over.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
::class FpRoute public
::method load class
  use strict arg file
  pts = .array~new
  do while lines(file) > 0
    parse value linein(file) with kind '|' name '|' lat '|' lon .
    if kind \== 'point' then iterate
    d = .directory~new; d['NAME'] = name; d['LAT'] = lat; d['LON'] = lon
    pts~append(d)
  end
  call stream file, 'c', 'close'
  return pts
