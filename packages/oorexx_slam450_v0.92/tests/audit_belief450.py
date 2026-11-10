#!/usr/bin/env python3
"""SLAM 450 v0.92 flight-book auditor (independent of the Rexx code).

Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.

Checks, per aircraft, from the race evidence only:
  1. NO TRUTH LEAK: between REPORT rows the believed position is reproduced
     exactly by dead reckoning on the craft's OWN logged commands
     (<id>_battery.csv yaw/forward/side), starting from the previous belief.
     A belief that tracked truth instead would fail this.
  2. error_m equals the distance between the logged belief and truth.
  3. coverage never decreases and stays within 0..1.
  4. sighting error_m equals the logged belief-to-truth distance.
Prints a JSON verdict with mean error, within-50 m share and Brier score
(sure vs error<=50 m) - the "encourage correct" score.
Why Python: the auditor must not share code with what it audits; Python's
csv/math is an independent second implementation of the same arithmetic.
"""
import argparse, csv, json, math, os, sys

def rows(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))

def llm_reports(prefix, cid, crop):
    """tick -> (x, y) world position from the LLM's own "where" (decision tick)."""
    import json as _j
    rep = {}
    if crop is None:
        return rep
    x0, x1, y0, y1, sc = crop
    for r in rows(f"{prefix}_{cid}_llm_calls.csv"):
        raw = r.get("raw_reply", "")
        # raw_reply is cut at 300 chars in the log, so read "where" by pattern
        import re as _re
        m = _re.search(r'"where"\s*:\s*\[\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)', raw)
        if m and r.get("status") == "OK":
            rep[int(r["tick"])] = (x0 + float(m.group(1)) / sc, y1 - float(m.group(2)) / sc)
    return rep

def audit(prefix, crop=None):
    out = {"prefix": prefix, "craft": {}, "problems": []}
    for cid in ("A1", "A2", "A3", "A4", "A5"):
        bel = rows(f"{prefix}_{cid}_belief_ORACLE_ONLY.csv")
        if not bel:
            continue
        bat = {int(r["tick"]): r for r in rows(f"{prefix}_{cid}_battery.csv")}
        reps = llm_reports(prefix, cid, crop)
        fixes = {}
        for fr in rows(f"{prefix}_{cid}_visfix.csv"):
            if fr["accepted"] == "1":
                fixes[int(fr["tick"])] = (float(fr["fix_x"]), float(fr["fix_y"]), float(fr["fix_heading"]))
        dr_checked = dr_bad = 0
        prev = None
        cov_prev = 0.0
        errs = []; within = 0; brier = 0.0
        for r in bel:
            t = int(r["tick"])
            bx, by, bh = float(r["bel_x"]), float(r["bel_y"]), float(r["bel_heading"])
            tx, ty = float(r["true_x"]), float(r["true_y"])
            e = math.hypot(bx - tx, by - ty)
            if abs(e - float(r["error_m"])) > 0.02:
                out["problems"].append(f"{cid} t{t}: error_m {r['error_m']} != {e:.2f}")
            cov = float(r["coverage"])
            if cov < cov_prev - 1e-9 or cov < 0 or cov > 1:
                out["problems"].append(f"{cid} t{t}: coverage {cov} after {cov_prev}")
            # coverage is per belief position; a REPORT can move it, never shrink it
            cov_prev = cov
            sure = float(r["sure"]); hit = 1.0 if e <= 50 else 0.0
            errs.append(e); within += hit; brier += (sure - hit) ** 2
            if prev is not None and r["source"] in ("DR", "REPORT_DR", "VISFIX_DR", "VISFIX_LM_DR") and t in bat:
                b = bat[t]
                try:
                    yaw = float(b["yaw_cmd"]); fwd = float(b["forward_cmd"]); side = float(b["side_cmd"] or 0)
                except ValueError:
                    prev = r; continue
                h = (float(prev["bel_heading"]) + yaw) % 360
                sx, sy = float(prev["bel_x"]), float(prev["bel_y"])
                if (t - 1) in fixes:         # an accepted visual fix, then one DR step
                    sx, sy, fh = fixes[t - 1]
                    h = (fh + yaw) % 360
                elif r["source"].startswith("VISFIX"):
                    out["problems"].append(f"{cid} t{t}: VISFIX row without an accepted fix logged at t{t-1}")
                    prev = r; continue
                elif (t - 1) in reps:          # the pilot's own report, then one DR step
                    sx, sy = reps[t - 1]
                elif r["source"] == "REPORT_DR":
                    prev = r; continue      # report present but not reconstructable without --crop
                ex = sx + fwd * math.sin(math.radians(h)) + side * math.cos(math.radians(h))
                ey = sy + fwd * math.cos(math.radians(h)) - side * math.sin(math.radians(h))
                dr_checked += 1
                if math.hypot(ex - bx, ey - by) > 0.05 or abs(((h - bh + 180) % 360) - 180) > 0.2:
                    dr_bad += 1
                    if dr_bad <= 3:
                        out["problems"].append(f"{cid} t{t}: belief ({bx:.2f},{by:.2f},{bh:.1f}) != own-command DR ({ex:.2f},{ey:.2f},{h:.1f})")
            prev = r
        for s in rows(f"{prefix}_{cid}_sightings_ORACLE_ONLY.csv"):
            e = math.hypot(float(s["bel_x"]) - float(s["true_x"]), float(s["bel_y"]) - float(s["true_y"]))
            if abs(e - float(s["error_m"])) > 0.2:
                out["problems"].append(f"{cid} sighting t{s['tick']} T{s['target']}: error mismatch")
        n = len(errs)
        out["craft"][cid] = {
            "ticks": n, "mean_error_m": round(sum(errs) / n, 2), "max_error_m": round(max(errs), 2),
            "within_50m_pct": round(100 * within / n, 1), "brier": round(brier / n, 4),
            "dr_rows_checked": dr_checked, "dr_mismatch": dr_bad,
            "reports": sum(1 for r in bel if r["source"].startswith("REPORT")),
            "visual_fixes": sum(1 for r in bel if r["source"].startswith("VISFIX")),
            "final_coverage": float(bel[-1]["coverage"]),
        }
    if not out["craft"]:
        out["problems"].append("no belief logs found")
    out["status"] = "PASS" if not out["problems"] else "FAIL"
    return out

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("prefix")
    ap.add_argument("--out")
    ap.add_argument("--crop", help="x0,x1,y0,y1,scale of the plan map (needed to rebuild LLM reports)")
    a = ap.parse_args()
    crop = tuple(float(v) for v in a.crop.split(",")) if a.crop else None
    res = audit(a.prefix, crop)
    txt = json.dumps(res, indent=2)
    if a.out:
        open(a.out, "w").write(txt + "\n")
    print(txt)
    sys.exit(0 if res["status"] == "PASS" else 1)
