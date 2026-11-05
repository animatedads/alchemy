# make_test_las.py -- a small synthetic tile with known answers, to test las_grid.rex.
# Ground at 5 m (class 2) over 40 x 40 m; a 30 m building (class 6) on 10-20 x 10-20 m;
# a tree (class 5) at 30,30 reaching 12 m; water (class 9, 0.4 m) along x 0-4; a noise
# point (class 7) at 99 m that must be ignored. Architecture: Tom Dyer. Code: Claude (Opus 5.5).
# python3 make_test_las.py out.las format [unsorted]
# unsorted: as the 2018 tiles sorted only into 1, 2 and 7: the building is class 1 with no
# ground return under it, and a class 1 tree 6 by 6 m (24-30) reaches 15 m with ground
# returns under it. Expected then: one block (the building), the tree in none.
import sys, numpy as np, laspy
fmt = int(sys.argv[2]); ver = "1.4" if fmt >= 6 else "1.2"
unsorted = len(sys.argv) > 3 and sys.argv[3] == "unsorted"
x0, y0 = 334000.0, 6252000.0
pts = []
for x in np.arange(0.5, 40, 1.0):
    for y in np.arange(0.5, 40, 1.0):
        if 10 <= x < 20 and 10 <= y < 20: pts.append((x, y, 35.0, 1 if unsorted else 6))
        elif x < 4: pts.append((x, y, 0.4, 9))
        else: pts.append((x, y, 5.0, 2))
        if 10 <= x < 20 and 10 <= y < 20 and not unsorted: pts.append((x, y, 5.0, 2))
        if unsorted and 24 <= x < 30 and 24 <= y < 30: pts.append((x, y, 15.0, 1))
pts.append((30.5, 30.5, 12.0, 5)); pts.append((25.5, 25.5, 99.0, 7))
a = np.array(pts)
h = laspy.LasHeader(point_format=fmt, version=ver); h.scales = [0.001]*3; h.offsets = [x0, y0, 0]
las = laspy.LasData(h)
las.x = a[:,0] + x0; las.y = a[:,1] + y0; las.z = a[:,2]; las.classification = a[:,3].astype(np.uint8)
las.write(sys.argv[1]); print(sys.argv[1], len(a), "points, format", fmt)
