#!/usr/bin/env rexx
/* test_sight_line.rex -- the height layer and the sight line             */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
/* Run from the package folder:  rexx tests/test_sight_line.rex           */
  parse source . . me
  root = filespec('L', me)'..'
  tmp = '/tmp/toprope_sight_test_'random(1, 99999)
  call SysMkDir tmp
  fails = 0; tests = 0

  /* 1. flat ground: two people 1 km apart see each other */
  call grid tmp'/flat.asc', 60, 60, 0.0002, 0, 0, 'flat'
  sl = .SightLine~new(.HeightGrid~new(tmp'/flat.asc', 'test flat'))
  d = sl~look(pt(0.002, 0.002, 2), pt(0.002, 0.010, 2))
  call check 'flat ground: sees', d['SEES'] == 1
  call check 'flat ground: about 1 km', abs(d['DIST'] - 890) < 20

  /* 2. a wall between them: cannot see, and the wall is where it is */
  call grid tmp'/wall.asc', 60, 60, 0.0002, 0, 0, 'wall'
  sl = .SightLine~new(.HeightGrid~new(tmp'/wall.asc', 'test wall'))
  d = sl~look(pt(0.006, 0.002, 2), pt(0.006, 0.010, 2))
  call check 'wall: cannot see', d['SEES'] == 0
  call check 'wall: about 20 m above the line', abs(-d['CLEAR'] - 18) < 1
  call check 'wall: blocked near 0.006 east', abs(d['BLOCK_LON'] - 0.006) < 0.0005

  /* 3. the curve of the earth: 2 m eyes over flat sea see about 10.8 km */
  call grid tmp'/sea.asc', 40, 5, 0.01, 0, 0, 'flat'
  sl = .SightLine~new(.HeightGrid~new(tmp'/sea.asc', 'test sea'))
  d = sl~look(pt(0.02, 0.05, 2), pt(0.02, 0.122, 2))      /* 8 km  */
  call check 'curve: 8 km sees', d['SEES'] == 1
  d = sl~look(pt(0.02, 0.05, 2), pt(0.02, 0.23, 2))       /* 20 km */
  call check 'curve: 20 km cannot see', d['SEES'] == 0
  d = sl~look(pt(0.02, 0.05, 2), pt(0.02, 0.1399, 2))     /* 10 km: inside 10.8 */
  call check 'curve: 10 km sees', d['SEES'] == 1
  d = sl~look(pt(0.02, 0.05, 2), pt(0.02, 0.1578, 2))     /* 12 km: beyond 10.8 */
  call check 'curve: 12 km cannot see', d['SEES'] == 0

  /* 4. off the grid: never guessed */
  d = sl~look(pt(0.02, 0.05, 2), pt(0.02, 0.50, 2))
  call check 'off the grid: UNKNOWN', d['SEES'] == 'UNKNOWN'

  /* 5. Top Rope height words (MGA): the grid gives the fixed places' own heights */
  g = .HeightGrid~new(root'/examples/harbour/harbour_heights.words', 'ELVIS')
  s = .stream~new(root'/examples/harbour/harbour_heights.words')~~open('read')
  do while s~lines > 0
    l = s~linein~strip
    if l~word(1) \== 'place' then iterate
    parse var l 'place' nm ' at ' lat lon 'height' h .
    call check 'harbour:' nm~strip 'height', abs(g~heightAt(lat, lon) - h) < 0.1
  end
  s~close

  /* 6. Balaklava, real terrain: from the Light Brigade's start line the
     reverse slope of the Causeway Heights is hidden from every position
     tried; from Raglan's heights some positions see it */
  g = .HeightGrid~new(root'/examples/balaklava/north_valley.asc', 'Copernicus GLO-30')
  sl = .SightLine~new(g)
  lb = pt(44.5400, 33.6070, 2.5)
  rs = pt(44.5295, 33.6250, 1.5)
  rg = pt(44.5370, 33.5760, 2.5)
  r = sl~spread(lb, 300, rs, 150)
  call check 'balaklava: light brigade cannot see the reverse slope', r['VERDICT'] == 'CANNOT' & r['TRIED'] = 225
  r = sl~spread(rg, 300, rs, 150)
  call check 'balaklava: raglan sees it from some positions', r['SEEN'] > 0

  call SysFileTree tmp'/*', 'f.', 'FO'
  do i = 1 to f.0; call SysFileDelete f.i; end
  call SysRmDir tmp
  say tests - fails 'of' tests 'passed'
  exit fails \= 0

check:
  parse arg what, ok
  tests = tests + 1
  if ok == 1 then say 'PASS' what
  else do
    say 'FAIL' what
    fails = fails + 1
  end
  return

/* a lat/lon point with an eye height */
pt: procedure
  use arg lat, lon, eye
  p = .directory~new
  p['LAT'] = lat; p['LON'] = lon; p['EYE'] = eye
  return p

/* a test grid in degrees from (0,0); 'wall' puts a 20 m wall down the middle */
grid: procedure
  use arg file, nc, nr, cs, x0, y0, shape
  s = .stream~new(file)~~open('write replace')
  s~lineout('ncols' nc)
  s~lineout('nrows' nr)
  s~lineout('xllcorner' x0)
  s~lineout('yllcorner' y0)
  s~lineout('cellsize' cs)
  s~lineout('NODATA_value -9999')
  do r = 1 to nr
    row = ''
    do c = 1 to nc
      h = 0
      if shape = 'wall' then if c = nc % 2 then h = 20
      row = row h
    end
    s~lineout(row~strip)
  end
  s~close
  return

::requires 'sight_line.cls'
