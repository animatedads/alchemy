#!/usr/bin/env python3
"""Native ooRexx qualification for actual Sydney v0.13 contact evidence."""
import tempfile,subprocess,pathlib,json,os,shutil
p=pathlib.Path(__file__).parent
interpreter='/mnt/data/tombstone_v011/runtime/usr/local/bin/rexx'
runner=str(p/'qualify_contact.rex')
env={**os.environ,'LD_LIBRARY_PATH':'/mnt/data/tombstone_v011/runtime/usr/local/lib'}
ref={
'det.psv':pathlib.Path('/mnt/data/tombstone_v011/unseeded_candidates.psv').read_text(),
'audit.psv':(p/'manly_audit.psv').read_text(),
'pix.psv':(p/'manly_pixels.psv').read_text(),
}

def corrupt_file(d,name,act):
 file=d/name
 rows=file.read_text().splitlines()
 if act=='duplicate':rows.insert(2,rows[1]);file.write_text('\n'.join(rows)+'\n')
 elif act=='truncate':file.write_text('\n'.join(rows[:-1])+'\n')
 else:
  before,after=act
  t=file.read_text();assert before in t,(name,before)
  file.write_text(t.replace(before,after,1))

def check(name,change=None,success=False,repeat=False):
 with tempfile.TemporaryDirectory() as tmp:
  d=pathlib.Path(tmp)
  for fname,text in ref.items():(d/fname).write_text(text)
  if change:corrupt_file(d,*change)
  output=d/'result.psv'
  args=[interpreter,runner,str(d/'det.psv'),str(d/'audit.psv'),str(d/'pix.psv'),str(output)]
  run=lambda:subprocess.run(args,capture_output=True,text=True,env=env)
  a=run();first=output.read_bytes() if output.exists() else b''
  b=run() if repeat else None
  ok=(a.returncode==0 and len(first.splitlines())==7) if success else (a.returncode!=0 and not output.exists())
  if repeat:ok=ok and b.returncode==0 and output.read_bytes()==first
  return {'name':name,'pass':ok,'rc':a.returncode,'trace':a.stdout.strip()[-160:]}

rows=[
 check('valid_real_manly',success=True),
 check('idempotent_write',success=True,repeat=True),
 check('duplicate_detection_frame',('det.psv','duplicate')),
 check('missing_audit_row',('audit.psv','truncate')),
 check('missing_pixel_row',('pix.psv','truncate')),
 check('invalid_method',('audit.psv',('WARM_HULL_LOWER_EDGE_PROXY','MADE_UP_CONTACT'))),
 check('geographic_promotion',('audit.psv',('APPROXIMATE_UNSURVEYED','SURVEYED'))),
 check('altered_frame_identity',('audit.psv',('0|0.000000|194.100000','999|0.000000|194.100000'))),
 check('out_of_range_contact',('audit.psv',('194.100000|765.000000|11.100000','194.100000|999.000000|245.100000'))),
 check('forged_support',('audit.psv',('|0.277397|WARM_HULL','|0.000000|WARM_HULL'))),
 check('inconsistent_offset',('audit.psv',('765.000000|11.100000','765.000000|22.100000'))),
 check('modified_trajectory',('pix.psv',('194.100000|765.000000','195.100000|765.000000'))),
 check('wrong_time',('pix.psv',('0|0.000000|194.100000','0|1.000000|194.100000'))),
]
assert all(x['pass'] for x in rows),rows
report={'source':'Tombstone v0.13 Manly real recording','runtime':'ooRexx 5.3.0 r13196','passed':len(rows),'total':len(rows),'controls':rows}
(p/'native_qualification.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE',len(rows),'/',len(rows),'PASS')
