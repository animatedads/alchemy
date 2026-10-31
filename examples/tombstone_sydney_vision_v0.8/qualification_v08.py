"""Subprocess-only native r13196 qualification. Does not implement any classifier."""
import pathlib, tempfile, shutil, subprocess, os, json, hashlib
root = pathlib.Path(__file__).resolve().parent
rexx = '/mnt/data/oorexx_runtime/usr/local/bin/rexx'
env = dict(os.environ, LD_LIBRARY_PATH='/mnt/data/oorexx_runtime/usr/local/lib')
source = {s: (root/s).read_text() for s in ['features.psv','video_features.psv','predictions_v08.psv','sources.sha256.psv']}

def run_case(name, modify=None, should_pass=False):
    with tempfile.TemporaryDirectory(prefix='tombstone08-') as td:
        d=pathlib.Path(td)
        for file,content in source.items(): (d/file).write_text(content)
        if modify: modify(d)
        out=d/'evidence.psv'
        cp=subprocess.run([rexx,str(root/'vision_evidence_adapter.rex'),'features.psv','video_features.psv','predictions_v08.psv','sources.sha256.psv',str(out)],cwd=d,env=env,capture_output=True,text=True)
        ok=(cp.returncode==0 and out.is_file() and len(out.read_text().splitlines())==55) if should_pass else (cp.returncode!=0 and not out.exists())
        return dict(name=name,passed=ok,actual_rc=cp.returncode,output=cp.stdout.strip()[-400:],expected='PASS' if should_pass else 'REJECT')

def m(fname,old,new):
    def change(d):
        p=d/fname
        t=p.read_text();assert old in t
        p.write_text(t.replace(old,new,1))
    return change
def run_repeat():
    with tempfile.TemporaryDirectory(prefix='tombstone08-repeat-') as td:
        d=pathlib.Path(td)
        for file, content in source.items(): (d/file).write_text(content)
        output=d/'evidence.psv'
        cmd=[rexx,str(root/'vision_evidence_adapter.rex'),'features.psv','video_features.psv','predictions_v08.psv','sources.sha256.psv',str(output)]
        a=subprocess.run(cmd,cwd=d,env=env,capture_output=True,text=True)
        before=output.read_bytes() if output.exists() else b''
        b=subprocess.run(cmd,cwd=d,env=env,capture_output=True,text=True)
        after=output.read_bytes() if output.exists() else b''
        ok=a.returncode==0 and b.returncode==0 and before==after and len(after.splitlines())==55
        return dict(name='idempotent_adapter_replay',passed=ok,actual_rc=b.returncode,output=b.stdout.strip()[-400:],expected='PASS')

cases=[
 run_case('valid_all',should_pass=True),
 run_repeat(),
 run_case('duplicate_prediction',lambda d: (d/'predictions_v08.psv').write_text((d/'predictions_v08.psv').read_text()+(d/'predictions_v08.psv').read_text().splitlines()[1]+'\n')),
 run_case('duplicate_historical_file',lambda d: (d/'predictions_v08.psv').write_text((root/'predictions_v07_duplicated.psv').read_text())),
 run_case('review_promoted_to_scored',lambda d: (d/'predictions_v08.psv').write_text((d/'predictions_v08.psv').read_text()+'R01|review|ferry|0.9|9|1000066214.jpg|0.08|0.11\n')),
 run_case('non_hex_source_sha',m('sources.sha256.psv','bc68efe9aa7b7615d6ca6d34a154926c43cdbd535b670c86fb9b64467610bfd2','z'*64)),
 run_case('missing_source',lambda d: (d/'sources.sha256.psv').write_text((d/'sources.sha256.psv').read_text().replace('1000066232.mp4|'+[r.split('|')[1] for r in source['sources.sha256.psv'].splitlines() if r.startswith('1000066232.mp4')][0]+'\n',''))),
 run_case('corrupt_crop_hash',m('features.psv','4d273f5ee38adf9b28c0fd43e3a88a03f61c953804eea8a5ffe1acc58a8dfd76','b'*63+'x')),
 run_case('wrong_raw_ratio',m('predictions_v08.psv','4.217582','2.1')),
 run_case('forged_support',m('predictions_v08.psv','0.808340','0.999999')),
 run_case('wrong_fold',m('predictions_v08.psv','P01|positive|ferry|0.808340|4.217582|1000066215.jpg','P01|positive|ferry|0.808340|4.217582|OTHER.jpg')),
 run_case('wrong_decision',m('predictions_v08.psv','P01|positive|ferry|','P01|positive|not_ferry|')),
 run_case('modified_evidence_feature',m('features.psv','0.309726|0.056849','0.999999|0.056849')),
 run_case('invented_id',m('predictions_v08.psv','P01|positive|ferry|','X01|positive|ferry|')),
 run_case('invalid_dimension',m('features.psv','broadside|326|137','broadside|0|137')),
 run_case('bad_video_identity',m('video_features.psv','1000066232.mp4|video_manly','1000066230.mp4|video_manly')),
 run_case('unexpected_field',m('predictions_v08.psv','P01|positive|ferry|','P01|positive|ferry||')),
]
# Hash original uploads independently, not relying on manifest assertions.
for row in source['sources.sha256.psv'].splitlines()[1:]:
    filename,sha=row.split('|')
    p=pathlib.Path('/mnt/data')/filename
    assert p.exists() and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==sha,(filename,'source SHA mismatch')
results={'native_version':'ooRexx 5.3.0 r13196', 'checks':cases, 'source_files_verified':17,'passed':sum(x['passed'] for x in cases),'total':len(cases)}
(root/'qualification_v08.json').write_text(json.dumps(results,indent=2)+'\n')
for c in cases: print(('PASS' if c['passed'] else 'FAIL')+': '+c['name']+' native_rc='+str(c['actual_rc']))
print('QUALIFICATION',results['passed'],'/',results['total'],'SOURCE_HASHES',results['source_files_verified'])
if results['passed']!=results['total']: raise SystemExit(1)
