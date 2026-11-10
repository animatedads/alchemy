#!/usr/bin/env python3
"""SLAM 450 v0.92 HARBOUR matrix summary: quad vs wing, seat vs back seat,
SLAM-only twins, flight-book accuracy and camera/sweep use.

Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
usage: summarise_harbour450.py RUNS_DIR TAG    (TAG e.g. v92B)
"""
import csv, glob, json, os, re, sys, collections

runs, tag = sys.argv[1], sys.argv[2]

def rows(p):
    return list(csv.DictReader(open(p))) if os.path.exists(p) else []

def race(d):
    log = open(d + ".log").read() if os.path.exists(d + ".log") else ""
    claims = [r for r in csv.reader(open(d + "/race_claims.csv")) if r and r[0].isdigit()]
    outs = re.findall(r"SQUAD OUT (\d+) (A\d)", log)
    calls = [r for f in glob.glob(d + "/race_A[45]_llm_calls.csv") for r in rows(f)]
    cam = [r for r in rows(d + "/race_fixed_camera.csv") if r.get("aircraft") in ("A4", "A5")]
    bel = {}
    for cid in ("A1", "A2", "A3", "A4", "A5"):
        b = rows(f"{d}/race_{cid}_belief_ORACLE_ONLY.csv")
        if b:
            e = [float(r["error_m"]) for r in b]
            bel[cid] = dict(mean=sum(e) / len(e), within50=sum(x <= 50 for x in e) / len(e),
                            reports=sum(r["source"] == "REPORT" for r in b), cov=float(b[-1]["coverage"]))
    sweeps = sum(len(rows_) for rows_ in [open(f).read().splitlines() for f in glob.glob(d + "/race_A?_sweep.csv")])
    sight = [r for f in glob.glob(d + "/race_A[45]_sightings_ORACLE_ONLY.csv") for r in rows(f)]
    return dict(
        done="SQUAD RESULT" in log,
        ticks=int((re.findall(r"TICKS (\d+)", log) or ["0"])[-1]),
        claims=len(claims), h_claims=sum(c[3] in ("A4", "A5") for c in claims),
        h_ko=sum(o[1] in ("A4", "A5") for o in outs), all_ko=len(outs),
        cost=sum(float(r["cost_usd"] or 0) for r in calls), calls=len(calls),
        named_views=sum(1 for r in calls if r["lookup"] not in ("0", "1", "")),
        any_views=sum(1 for r in calls if r["lookup"] == "1"),
        cam_grants=sum(r["status"] == "GRANTED" for r in cam),
        sensors=sum(bool(re.search(r'"(scanner|altimeter|gps)":\s*true', r["raw_reply"])) for r in calls),
        h_bel=[bel[c] for c in ("A4", "A5") if c in bel],
        slam_bel=[bel[c] for c in ("A1", "A2", "A3") if c in bel],
        sweeps=sweeps,
        sight_err=[float(r["error_m"]) for r in sight],
    )

groups = collections.OrderedDict()
for d in sorted(glob.glob(os.path.join(runs, tag + "_*"))):
    if d.endswith(".log") or not os.path.isdir(d):
        continue
    name = os.path.basename(d)
    parts = name.split("_")
    key = "_".join(parts[1:-1])  # haiku_quad_seat / ctrl_quad
    groups.setdefault(key, []).append((name, race(d)))

for key, items in groups.items():
    print(f"== {key}")
    agg = collections.Counter(); hb = []; sb = []; se = []
    for name, r in items:
        print(f"  {name}: done={r['done']} ticks={r['ticks']} claims={r['claims']} H={r['h_claims']} "
              f"H_KO={r['h_ko']} all_KO={r['all_ko']} ${r['cost']:.3f} views(named/any)={r['named_views']}/{r['any_views']} "
              f"grants={r['cam_grants']} sensors_on={r['sensors']} sweeps={r['sweeps']}")
        for k in ("claims", "h_claims", "h_ko", "all_ko", "named_views", "any_views", "cam_grants", "sensors", "sweeps"):
            agg[k] += r[k]
        agg["cost"] += r["cost"]; agg["done"] += r["done"]; agg["n"] += 1
        hb += r["h_bel"]; sb += r["slam_bel"]; se += r["sight_err"]
    line = " ".join(f"{k}={round(v, 3) if isinstance(v, float) else v}" for k, v in agg.items())
    print(f"  TOTAL {line}")
    if hb:
        print(f"  H book: mean err {sum(b['mean'] for b in hb)/len(hb):.1f} m, within 50 m {100*sum(b['within50'] for b in hb)/len(hb):.0f}%, "
              f"reports {sum(b['reports'] for b in hb)}, final coverage {100*sum(b['cov'] for b in hb)/len(hb):.0f}%")
    if sb:
        print(f"  SLAM book: mean err {sum(b['mean'] for b in sb)/len(sb):.1f} m, within 50 m {100*sum(b['within50'] for b in sb)/len(sb):.0f}%, "
              f"final coverage {100*sum(b['cov'] for b in sb)/len(sb):.0f}%")
    if se:
        se.sort()
        print(f"  H sightings: {len(se)} rows, median error {se[len(se)//2]:.0f} m")
