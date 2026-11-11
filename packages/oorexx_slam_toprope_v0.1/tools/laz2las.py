# laz2las.py -- unpack LAZ (compressed LAS) to plain LAS. Decode only: no point is
# changed, dropped or decided here; las_grid.rex reads the LAS and decides everything.
# Why Python: LAZ's arithmetic coding is a format decoder, the same role ImageMagick
# plays for PNG; lazrs (the reference Rust decoder) through laspy does it exactly.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
import sys, laspy
src, dst = sys.argv[1], sys.argv[2]
with laspy.open(src) as f:
    las = f.read()
las.write(dst, do_compress=False)
print(src, "->", dst, len(las.points), "points, LAS", las.header.version, "format", las.header.point_format.id)
