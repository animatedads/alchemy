/* Untested-report fixture: area is used by the test, perimeter only by area, unused by nobody.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29. */
::routine area public
  use arg w, h
  return w * h + perimeter(0, 0)
::routine perimeter public
  use arg w, h
  return 2 * (w + h)
::routine unused public
  return 'nobody calls me'
