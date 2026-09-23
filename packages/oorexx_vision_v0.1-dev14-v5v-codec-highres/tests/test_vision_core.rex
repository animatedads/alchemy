call testPacked5
call testPackedArbitrary
call testSurface
call testRegion
call testCurveLibrary
call testPalette
call testDelta
call testChangeRegions
call testAOI
say "PASS vision/0.1 dev3 core + palette + temporal + AOI"
exit 0

testPacked5:
  p = .VisionPackedValues~new(5, 26)
  do i = 0 to 25; p~put(i, i); end
  bytes = p~packedBytes
  call assert bytes~length = 17, "26 x 5 bits should occupy 17 bytes"
  q = .VisionPackedValues~fromPackedBytes(bytes, 5, 26)
  do i = 0 to 25; call assert q~at(i) = i, "5-bit round trip"; end
  return

testPackedArbitrary:
  do bits over .array~of(1, 3, 5, 7, 9, 12, 17)
    n = 19
    p = .VisionPackedValues~new(bits, n)
    cap = 2 ** bits
    do i = 0 to n - 1; p~put(i, (i * 7 + 3) // cap); end
    q = .VisionPackedValues~fromPackedBytes(p~packedBytes, bits, n)
    do i = 0 to n - 1; call assert p~at(i) = q~at(i), "arbitrary width round trip"; end
  end
  return

testSurface:
  s = .VisionSurface~new(4, 3, 5, 26)
  s~put(2, 1, 25)
  call assert s~at(2, 1) = 25, "surface coordinate access"
  call assert s~packedBytes~length = 8, "12 x 5 bits should occupy 8 bytes"
  return

testRegion:
  a = .VisionRegion~new(10, 10, 20, 20, 4, 17)
  b = .VisionRegion~new(25, 25, 10, 10)
  c = .VisionRegion~new(31, 31, 2, 2)
  call assert a~contains(10, 10), "region contains origin"
  call assert a~intersects(b), "region intersection"
  call assert \a~intersects(c), "region non-intersection"
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "FAIL:" message
    exit 1
  end
  return

testCurveLibrary:
  lib = .VisionCurveLibrary~new
  do id over .array~of(0, 1, 17, 162, 254)
    c = lib~curve(id)
    call assert c~at(0) = 0, "curve black endpoint"
    call assert c~at(25) = 255, "curve white endpoint"
    previous = -1
    do i = 0 to 25
      call assert c~at(i) >= previous, "curve monotonic"
      previous = c~at(i)
    end
  end
  return

testPalette:
  lib = .VisionCurveLibrary~new
  selector = .VisionPaletteSelector~new(lib, 162, 19, 202)
  model = selector~colourModel
  call assert model~valueCount = 26, "palette has 26 values"
  c0 = model~colour(0); c25 = model~colour(25)
  call assert c0[1] = 0 & c0[2] = 0 & c0[3] = 0, "palette index zero is black"
  call assert c25[1] = 255 & c25[2] = 255 & c25[3] = 255, "palette index 25 is white"
  dm = .VisionPaletteDistanceMatrix~new(model)
  call assert dm~distance(4, 4) = 0, "distance diagonal"
  call assert dm~distance(3, 17) = dm~distance(17, 3), "distance symmetric"
  return

testDelta:
  a = .VisionSurface~new(5, 4, 5, 26)
  b = .VisionSurface~new(5, 4, 5, 26)
  do y = 0 to 3
    do x = 0 to 4
      a~put(x, y, (x + y) // 26)
      b~put(x, y, (x + y) // 26)
    end
  end
  b~put(1, 1, 20); b~put(4, 3, 25)
  d = .VisionSurfaceDelta~new(a, b)
  call assert d~changedCount = 2, "delta changed count"
  r = d~applyTo(a)
  do y = 0 to 3
    do x = 0 to 4
      call assert r~at(x, y) = b~at(x, y), "delta exact reconstruction"
    end
  end
  return

testChangeRegions:
  a=.VisionSurface~new(8,6,5,26); b=.VisionSurface~new(8,6,5,26)
  do y=1 to 2
    do x=2 to 3
      b~put(x,y,9)
    end
  end
  b~put(7,5,4)
  d=.VisionSurfaceDelta~new(a,b)
  rs=.VisionChangeRegionExtractor~new(8,2)~extract(d)
  call assert rs~items=1, "isolated noise removed"
  r=rs[1]
  call assert r~x=2 & r~y=1 & r~width=2 & r~height=2, "change bounds"
  call assert r~cellCount=4 & r~density=1, "change evidence"
  return

testAOI:
  a=.VisionSurface~new(8,6,5,26); b=.VisionSurface~new(8,6,5,26)
  do y=2 to 4
    do x=1 to 3
      b~put(x,y,12)
    end
  end
  d=.VisionSurfaceDelta~new(a,b)
  areas=.VisionAreaOfInterestDetector~new~fromDelta(d,4,17)
  call assert areas~items=1, "AOI coherent change"
  area=areas[1]
  req=area~request("storage:raw-video",8,256)
  call assert req~sourceRef="storage:raw-video", "AOI source"
  call assert req~bits=8 & req~valueCount=256, "AOI fidelity"
  return

::requires "../src/Vision.cls"
