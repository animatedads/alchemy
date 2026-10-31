"""Repeatable native ooRexx checks for the 200m unlocated quay baseline."""
from pathlib import Path
import subprocess,tempfile,os,hashlib,json,shutil
BASE=Path(__file__).parent
RUN=os.environ.get('REXX_BIN') or shutil.which('rexx') or '/mnt/data/oorexx_runtime/usr/local/bin/rexx'
SRC=str(BASE/'quay_baseline.rex')
ENV={**os.environ,'LD_LIBRARY_PATH':os.environ.get('LD_LIBRARY_PATH','/mnt/data/oorexx_runtime/usr/local/lib')}
initial=(BASE/'user_map_approx.psv').read_text()
synth=initial.replace('mode|LENGTH_ONLY','mode|PIXEL_TIED_CANDIDATE')+'image_sha256|'+'0'*64+'\nnative_width|1536\nnative_height|709\neast_u|500\neast_v|425\nwest_u|700\nwest_v|425\npixel_source|SYNTHETIC_TEST_ONLY\n'
cases=[
 ('length_recorded',initial,True,'LENGTH_RECORDED_IMAGE_UNLOCATED'),
 ('synthetic_interval',synth,True,'SYNTHETIC_PIXEL_INTERVAL_ONLY'),
 ('dup_key',initial+'length_m|200\n',False,''),
 ('bad_length',initial.replace('length_m|200','length_m|220'),False,''),
 ('mode_conflict',initial+'east_u|500\n',False,''),
 ('source_forged',initial.replace('USER_MAP_2026-10-31','SURVEYED_OFFICIAL'),False,''),
 ('bad_sha',synth.replace('image_sha256|','image_sha256|wrong'),False,''),
 ('bad_bounds',synth.replace('west_u|700','west_u|1600'),False,''),
 ('identical_point',synth.replace('west_u|700','west_u|500'),False,''),
 ('missing_pixel_source',synth.replace('pixel_source|SYNTHETIC_TEST_ONLY\n',''),False,''),
 ('invented_pixel_source',synth.replace('pixel_source|SYNTHETIC_TEST_ONLY','pixel_source|SURVEYED'),False,''),
 ('nonnumeric',synth.replace('east_u|500','east_u|abc'),False,''),
 ('insufficient_span',synth.replace('west_u|700','west_u|505'),False,''),
 ('forged_survey_status',initial.replace('APPROXIMATE_USER_MAP_READING','MEASURED_SURVEYED'),False,''),
 ('duplicate_header',initial+'key|value\n',False,''),
 ('wrong_label',initial.replace('CIRCULAR_QUAY_FIVE_WHARF_FRONTAGE','OTHER'),False,'')
]
results=[]
for name,txt,want,status in cases:
 with tempfile.TemporaryDirectory() as t:
  src=Path(t)/'in.psv';dst=Path(t)/'result.psv';src.write_text(txt)
  proc=subprocess.run([RUN,SRC,str(src),str(dst)],env=ENV,capture_output=True,text=True)
  passed=(proc.returncode==0 and dst.exists() and f'status|{status}' in dst.read_text()) if want else (proc.returncode!=0 and not dst.exists())
  if want and name=='length_recorded':passed=passed and 'secant_metres_per_pixel|NA' in dst.read_text()
  if want and name=='synthetic_interval':passed=passed and 'secant_metres_per_pixel|1' in dst.read_text()
  results.append({'case':name,'pass':passed,'returncode':proc.returncode,'stdout':proc.stdout.strip()})
  print(('PASS' if passed else 'FAIL'),name,proc.returncode)
out={'native':'Open Object Rexx 5.3.0 r13196','passed':sum(x['pass'] for x in results),'total':len(results),'cases':results,'ground_plane_homography':'NOT_AVAILABLE','real_pixel_correspondence':'NOT_AVAILABLE'}
(BASE/'qualification_v010.json').write_text(json.dumps(out,indent=2)+'\n')
print(f"QUALIFICATION {out['passed']}/{out['total']}")
if out['passed']!=out['total']:raise SystemExit(1)
