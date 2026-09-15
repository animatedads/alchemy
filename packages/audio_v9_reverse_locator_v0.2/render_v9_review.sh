#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EVENT=${1:?usage: render_v9_review.sh evt_NNNNNN [locations.tsv]}
TSV=${2:-"$ROOT/run/v9_locator/locations.tsv"}
ORIGINALS=${V9_ORIGINALS:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${V9_REVIEW_OUT:-"$ROOT/run/v9_locator/review/$EVENT"}
PRE=${V9_REVIEW_PRE_SEC:-4}
DUR=${V9_REVIEW_DURATION_SEC:-18}
AMP_DB=${V9_REVIEW_AMP_DB:-32}

command -v ffmpeg >/dev/null || { echo 'ffmpeg not found' >&2; exit 3; }
test -f "$TSV" || { echo "locations TSV not found: $TSV" >&2; exit 3; }
mkdir -p "$OUT"

python3 - "$EVENT" "$TSV" "$ORIGINALS" "$OUT" "$PRE" "$DUR" "$AMP_DB" <<'PY'
import csv, os, subprocess, sys
from pathlib import Path

event, tsv, originals, out, pre, dur, amp = sys.argv[1:]
pre=float(pre); dur=float(dur); amp=float(amp)
with open(tsv, newline='', encoding='utf-8') as f:
    rows=[r for r in csv.DictReader(f, delimiter='\t') if r.get('event_id')==event]
if len(rows)!=1:
    raise SystemExit(f'expected exactly one {event} row in {tsv}, found {len(rows)}')
r=rows[0]
print(f"event={event} absolute_time={r.get('absolute_time')} chosen_rank={r.get('chosen_rank')} chosen_score={r.get('chosen_score')}")
for ch in (0,1):
    feed=r.get(f'feed_ch{ch}','').strip()
    name=r.get(f'source_ch{ch}','').strip()
    off=r.get(f'offset_ch{ch}','').strip()
    if not name or not off:
        continue
    if feed not in {'fc','fd'}:
        raise SystemExit(f'unknown feed for channel {ch}: {feed!r}')
    src=Path(originals)/f'camera_{feed}'/name
    if not src.is_file():
        raise SystemExit(f'missing source: {src}')
    start=max(0.0,float(off)-pre)
    dst=Path(out)/f'{event}_{feed}_amp{int(amp)}.wav'
    subprocess.check_call([
        'ffmpeg','-y','-v','error','-ss',f'{start:.6f}','-i',str(src),'-t',f'{dur:.6f}',
        '-vn','-ac','1','-ar','16000','-af',f'volume={amp}dB,alimiter=limit=0.98',str(dst)
    ])
    print(f'{feed}: {src.name} offset={off}s review={dst}')
PY
