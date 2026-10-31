"""Reproducible native ooRexx gate: 21 cases, no CV, no geographic data."""
from pathlib import Path
import os, shutil, subprocess, tempfile, csv, math, sys
ROOT=Path(__file__).resolve().parent
REXX=os.environ.get('REXX_BIN') or shutil.which('rexx') or '/mnt/data/oorexx_runtime/usr/local/bin/rexx'
FILES=['metadata_synthetic.psv','controls_synthetic.psv','holdouts_synthetic.psv','points_synthetic.psv']
CASES=[
 ('ok_calibration','c','',None,None),
 ('holdout_outlier','c','holdouts_synthetic.psv','V2|1250|720|','V2|1250|720|6000'),
 ('wrong_units','c','metadata_synthetic.psv','unit|metre','unit|degree'),
 ('geographic_degrees','c','metadata_synthetic.psv','crs|EPSG:3857','crs|EPSG:4326'),
 ('fake_survey','c','metadata_synthetic.psv','mode|SYNTHETIC','mode|SURVEYED_CANDIDATE'),
 ('bad_source_ref','c','metadata_synthetic.psv','SYNTHETIC_TEST','SOME_CAMERA'),
 ('duplicate_metadata','c','metadata_synthetic.psv','@append','unit|metre\n'),
 ('three_controls','c','controls_synthetic.psv','@last',''),
 ('duplicate_point','c','controls_synthetic.psv','C2|1450','C1|1450'),
 ('cross_set_id','c','holdouts_synthetic.psv','V1|750','C1|750'),
 ('out_of_frame','c','controls_synthetic.psv','C1|230','C1|2300'),
 ('poor_coverage','c','controls_synthetic.psv','@narrow',''),
 ('collinear','c','controls_synthetic.psv','@collinear',''),
 ('non_numeric','c','holdouts_synthetic.psv','V1|750','V1|not_a_number'),
 ('missing_holdouts','c','holdouts_synthetic.psv','@empty',''),
 ('absurd_error_limit','c','metadata_synthetic.psv','max_error_m|0.00001','max_error_m|100'),
 ('ok_jacobian','m','',None,None),
 ('unqualified_state','m','calibrated.psv','SYNTHETIC_MATH_ONLY','SURVEYED_VALIDATED'),
 ('duplicate_sample','m','points_synthetic.psv','@append','N1|400|600\n'),
 ('out_of_frame_sample','m','points_synthetic.psv','N1|400|600','N1|2400|600'),
 ('bad_coefficient','m','calibrated.psv','h9|1','h9|nope'),
]
def modify(d, fn, old, new):
    if not fn:return
    p=d/fn;t=p.read_text()
    if old=='@append':t+=new
    elif old=='@last':t='\n'.join(t.splitlines()[:-1])+'\n'
    elif old=='@empty':t=t.splitlines()[0]+'\n'
    elif old=='@narrow':t=t.replace('C2|1450|500','C2|241|500').replace('C3|360|980','C3|240|980').replace('C4|1510|930','C4|250|930')
    elif old=='@collinear':t='point_id|u_px|v_px|east_m|north_m|uncertainty_m|source_id\n'+''.join(f'C{i}|{200*i}|{200+100*i}|{10*i}|{10*i+10}|0.01|SYNTHETIC\n' for i in range(1,5))
    else:
        assert old in t,(fn,old)
        t=t.replace(old,new,1)
    p.write_text(t)
def run(d, kind, output):
    args=[str(REXX),str(ROOT/'qualify_water_plane.rex'),'metadata_synthetic.psv','controls_synthetic.psv','holdouts_synthetic.psv',output] if kind=='c' else [str(REXX),str(ROOT/'water_pixel_metric.rex'),'calibrated.psv','points_synthetic.psv',output]
    return subprocess.run(args,cwd=d,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
passed=0
for name,kind,fn,old,new in CASES:
    with tempfile.TemporaryDirectory(prefix='tombstone09-') as temp:
        d=Path(temp)
        for file in FILES:shutil.copy2(ROOT/file,d/file)
        if kind=='m':
            pre=run(d,'c','calibrated.psv')
            assert pre.returncode==0,pre.stdout
        modify(d,fn,old,new)
        proc=run(d,kind,'result.psv')
        result=d/'result.psv'
        should_pass=name.startswith('ok_')
        good=(proc.returncode==0 and result.exists()) if should_pass else (proc.returncode!=0 and not result.exists())
        if good and name=='ok_calibration':
            rows=dict(line.split('|',1) for line in result.read_text().splitlines()[1:]);good=rows['status']=='SYNTHETIC_MATH_ONLY' and float(rows['max_holdout_error_m'])<1e-8
        if good and name=='ok_jacobian':
            rows=list(csv.DictReader(result.open(),delimiter='|'))
            good=len(rows)==4
            for row in rows:
                u,v=next((float(a),float(b)) for pid,a,b in [line.split('|') for line in (d/'points_synthetic.psv').read_text().splitlines()[1:]] if pid==row['point_id'])
                def xy(u,v):
                    un=u/1920;vn=v/1080;den=1+0.2*un+0.1*vn
                    return (100+600*un+110*vn)/den,(-40+40*un+850*vn)/den
                h=0.001
                Dx=(xy(u+h,v)[0]-xy(u-h,v)[0])/(2*h)
                Dy=(xy(u,v+h)[1]-xy(u,v-h)[1])/(2*h)
                good=good and row['status']=='SYNTHETIC_MATH_ONLY' and abs(float(row['dX_du_mpx'])-Dx)<1e-7 and abs(float(row['dY_dv_mpx'])-Dy)<1e-7
        passed+=int(good)
        print(('PASS' if good else 'FAIL'),name,'native_rc='+str(proc.returncode))
print('NATIVE',passed,'/',len(CASES))
sys.exit(0 if passed==len(CASES) else 1)
