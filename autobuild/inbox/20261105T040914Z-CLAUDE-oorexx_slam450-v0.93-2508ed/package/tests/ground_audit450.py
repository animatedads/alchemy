#!/usr/bin/env python3
"""SLAM450 v0.91 independent ground check (audit-only; never imported by a pilot).

Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.

Shares NOTHING with the race's Rexx code path:
  * reads harbour_heights.words and harbour_water.words itself;
  * maps scene metres to lat/lon with the scene's published definition
    (lat = -33.852 + y/111200, lon = 151.210 + x/92300);
  * projects lat/lon to GDA94 / MGA zone 56 with its own Transverse Mercator
    (Krueger n-series, Karney 2011 form) — NOT the race's verified affine;
  * nearest cell, as the estate adapter: L = height, W = sea 0, X/outside = no-fly.
Each flown segment is sampled every <= 1 m on the centre line and the four
2 m horizontal offsets; every sample must clear its cell surface by `margin`.
Where a sample lies within 1 m of a cell edge the lower neighbouring surface
is used (the race's affine differs from exact TM by < 1 m), so a fault here
is never an artefact of the two projections disagreeing at a cell boundary.
"""
import math
from pathlib import Path

OFFS = [(0, 0), (2, 0), (-2, 0), (0, 2), (0, -2)]


class Ground:
    def __init__(self, words_dir):
        d = Path(words_dir)
        self.hdr, hrows = self._read(d / 'harbour_heights.words', water=False)
        whdr, wrows = self._read(d / 'harbour_water.words', water=True)
        if whdr != self.hdr:
            raise ValueError(f'grid mismatch {self.hdr} {whdr}')
        self.e0, self.n0, self.res, self.cols, self.rows = self.hdr
        self.h = hrows
        self.w = wrows
        # GRS80 / GDA94, zone 56
        a = 6378137.0; f = 1 / 298.257222101
        self.n = n = f / (2 - f)
        self.A = a / (1 + n) * (1 + n ** 2 / 4 + n ** 4 / 64)
        self.alpha = [n / 2 - 2 * n ** 2 / 3 + 5 * n ** 3 / 16,
                      13 * n ** 2 / 48 - 3 * n ** 3 / 5,
                      61 * n ** 3 / 240]
        self.k0 = 0.9996; self.lon0 = math.radians(153.0)

    @staticmethod
    def _read(path, water):
        hdr = None; rows = []
        for line in open(path):
            s = line.strip()
            if s.startswith('grid mga '):
                p = s.split()
                h = (float(p[5]), float(p[6]), float(p[8]), int(p[10]), int(p[12]))
                hdr = hdr or h
            elif s.startswith('row ') and hdr and len(rows) < hdr[4]:
                body = s[4:].strip()
                rows.append(body if water else body.split())
        return hdr, rows

    def mga(self, x, y):
        lat = math.radians(-33.852 + y / 111200.0)
        lon = math.radians(151.210 + x / 92300.0) - self.lon0
        n = self.n; c = 2 * math.sqrt(n) / (1 + n)
        t = math.sinh(math.atanh(math.sin(lat)) - c * math.atanh(c * math.sin(lat)))
        xi_ = math.atan2(t, math.cos(lon))
        eta_ = math.atanh(math.sin(lon) / math.sqrt(1 + t * t))
        xi = xi_ + sum(al * math.sin(2 * (j + 1) * xi_) * math.cosh(2 * (j + 1) * eta_) for j, al in enumerate(self.alpha))
        eta = eta_ + sum(al * math.cos(2 * (j + 1) * xi_) * math.sinh(2 * (j + 1) * eta_) for j, al in enumerate(self.alpha))
        return 500000 + self.k0 * self.A * eta, 10000000 + self.k0 * self.A * xi

    def top_cell(self, col, row):
        if col < 1 or col > self.cols or row < 1 or row > self.rows:
            return math.inf, 'X'
        role = self.w[row - 1][col - 1]
        if role == 'W':
            return 0.0, 'W'
        v = self.h[row - 1][col - 1]
        if role == 'L' and v != '-':
            return float(v), 'L'
        return math.inf, 'X'

    def surface(self, x, y, edge_tolerance=1.0):
        e, n = self.mga(x, y)
        u = (e - self.e0) / self.res + 0.5; v = (self.n0 - n) / self.res + 0.5
        cands = {(math.floor(u) + 1, math.floor(v) + 1)}
        tu = edge_tolerance / self.res
        for du in (-tu, tu):
            for dv in (-tu, tu):
                cands.add((math.floor(u + du) + 1, math.floor(v + dv) + 1))
        tops = [self.top_cell(c, r) for c, r in cands]
        return min(t for t, _ in tops), [r for _, r in tops]

    def cell(self, x, y):
        e, n = self.mga(x, y)
        return self.top_cell(math.floor((e - self.e0) / self.res + 0.5) + 1, math.floor((self.n0 - n) / self.res + 0.5) + 1)

    def check_segment(self, a, b, margin):
        """Return worst (clearance - margin) over the segment, and a fault text or ''."""
        L = math.dist(a[:2], b[:2])
        steps = max(1, int(math.ceil(L / 1.0)))
        worst = math.inf; fault = ''
        for ox, oy in OFFS:
            for i in range(steps + 1):
                t = i / steps
                x = a[0] + ox + (b[0] - a[0]) * t; y = a[1] + oy + (b[1] - a[1]) * t; z = a[2] + (b[2] - a[2]) * t
                top, roles = self.surface(x, y)
                gap = z - top - margin
                if gap < worst:
                    worst = gap
                    if gap <= 0:
                        fault = f'{z:.2f} m over surface {top} m (+{margin} m) at ({x:.1f},{y:.1f})'
        return worst, fault
