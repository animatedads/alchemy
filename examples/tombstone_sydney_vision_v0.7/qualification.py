#!/usr/bin/env python3
"""Untrusted-input rejection tests for ooRexx vision evidence and homography contracts."""
import os,subprocess, tempfile, pathlib, json
ROOT=pathlib.Path(__file__).resolve().parent
REXX='/mnt/data/oorexx_runtime/usr/local/bin/rexx'
env=os.environ.copy();env['LD_LIBRARY_PATH']='/mnt/data/oorexx_runtime/usr/local/lib:'+env.get('LD_LIBRARY_PATH','')
def run(script,*args):
    return subprocess.run([REXX,str(ROOT/script),*map(str,args)],cwd=ROOT,env=env,capture_output=True,text=True)
checks=[]
def chk(name,result,expected):
    pass_case=(result.returncode==0) if expected=='pass' else (result.returncode!=0)
    checks.append({'test':name,'expected':expected,'actual_rc':result.returncode,'passed':pass_case,'output':(result.stdout+result.stderr)[-400:]})
chk('vision normal',run('score_vision.rex','features.psv','video_features.psv'),'pass')
chk('homography synthetic',run('calibrate_water_plane.rex','control_synthetic.psv','holdout_synthetic.psv'),'pass')
with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
    tmp=pathlib.Path(tmp)
    original=(ROOT/'features.psv').read_text().splitlines(keepends=True)
    held=(ROOT/'video_features.psv').read_text().splitlines(keepends=True)
    controls=(ROOT/'control_synthetic.psv').read_text().splitlines(keepends=True)
    ho=(ROOT/'holdout_synthetic.psv').read_text().splitlines(keepends=True)
    for name,edited in [('duplicate_id',original+[original[1]]),
                        ('nonnumeric_feature',[original[0],original[1].replace('0.309957','nan')]+original[2:]),
                        ('unknown_truth',[original[0],original[1].replace('positive','banana')]+original[2:]),
                        ('bad_hash',[original[0],original[1].rsplit('|',1)[0]+'|INVALID\n']+original[2:])]:
        if name=='nonnumeric_feature':
            cols=original[1].rstrip('\n').split('|');cols[7]='NaN_not_numeric';edited=[original[0],'|'.join(cols)+'\n']+original[2:]
        f=tmp/f'{name}.psv';f.write_text(''.join(edited))
        chk(name,run('score_vision.rex',f,ROOT/'video_features.psv'),'reject')
    f=tmp/'heldout_label.psv';f.write_text(''.join([held[0],held[1].replace('heldout_positive','negative')]+held[2:]))
    chk('heldout_provenance',run('score_vision.rex',ROOT/'features.psv',f),'reject')
    f=tmp/'singular.psv';f.write_text(''.join(controls[:-1]+[controls[1]]))
    chk('singular_controls',run('calibrate_water_plane.rex',f,ROOT/'holdout_synthetic.psv'),'reject')
    f=tmp/'bad_holdout.psv';cols=ho[1].rstrip('\n').split('|');cols[2]=str(float(cols[2])+10)
    f.write_text(ho[0]+'|'.join(cols)+'\n'+''.join(ho[2:]))
    chk('holdout_disagreement',run('calibrate_water_plane.rex',ROOT/'control_synthetic.psv',f),'reject')
(ROOT/'qualification.json').write_text(json.dumps(checks,indent=2))
print(json.dumps({'total':len(checks),'passed':sum(c['passed'] for c in checks),'details':[{k:c[k] for k in ('test','expected','actual_rc','passed')} for c in checks]},indent=2))
if not all(c['passed'] for c in checks):raise SystemExit(1)
