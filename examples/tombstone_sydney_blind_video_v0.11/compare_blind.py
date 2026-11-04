import csv,numpy as np,json
from pathlib import Path
p=Path('/mnt/data/tombstone_v011')
a=list(csv.DictReader((p/'unseeded_candidates.psv').open(),delimiter='|'))
b=list(csv.DictReader((p/'tombstone_sydney_manly_v0.6/observations.psv').open(),delimiter='|'))
ref={int(r['frame']):r for r in b}
errors=[]; matches=[]; misses=[]
for row in a:
 frame=int(row['frame']);r=ref.get(frame)
 if r is None:continue
 if row['status']!='candidate': misses.append(frame);continue
 dx=float(row['x_center'])-float(r['x_center_native']);dy=float(row['y_center'])-float(r['y_center_native']); err=float(np.hypot(dx,dy))
 errors.append(err);matches.append([frame,float(row['x_center']),float(row['y_center']),float(r['x_center_native']),float(r['y_center_native']),round(err,2)])
metrics={'reference_count':len(ref),'sampled':len(a),'matched':len(errors),'misses':len(misses),'median_error_px':float(np.median(errors)),'p95_error_px':float(np.percentile(errors,95)),'max_error_px':float(np.max(errors)),'within_20px':int(np.sum(np.array(errors)<20)),'within_40px':int(np.sum(np.array(errors)<40)),'miss_frames':misses}
print(json.dumps(metrics,indent=2));(p/'blind_comparison.json').write_text(json.dumps(metrics,indent=2)+'\n')
with (p/'blind_comparison.psv').open('w') as f:
 f.write('frame|blind_x|blind_y|reference_x|reference_y|error_px\n');f.write('\n'.join('|'.join(map(str,r)) for r in matches)+'\n')
