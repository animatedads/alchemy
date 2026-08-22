import json, os, subprocess, tempfile, time, unittest, zipfile
from pathlib import Path
import alchemy_autobuild as a

def man(argv=None): return {"schema":a.SCHEMA,"package":{"name":"demo","version":"0.1"},"environment":{"set":{},"prepend_path":[]},"tests":[{"name":"acceptance","argv":argv or ["sh","run_tests.sh"],"timeout_seconds":10}]}
def zmake(p,m=None,nested=False,extra=None):
    with zipfile.ZipFile(p,"w") as z:
        if m is not None:z.writestr("nested/integration.json" if nested else "integration.json",json.dumps(m))
        for k,v in (extra or {}).items():z.writestr(k,v)
class T(unittest.TestCase):
    def test_defaults(self): self.assertEqual(a.defaults()["repo_url"],"git@github-alchemy:animatedads/alchemy.git")
    def test_start_watermark_latest_shallow(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); dl=d/"Downloads"; dl.mkdir(); zmake(dl/"old.zip",man()); (dl/"sub").mkdir(); zmake(dl/"sub"/"nested.zip",man()); time.sleep(.003); start=time.time_ns(); zmake(dl/"a.zip",man()); time.sleep(.003); zmake(dl/"b.zip",man()); self.assertEqual(a.candidate(dl,start)[0].name,"b.zip")
    def test_root_manifest_only(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"x.zip"; zmake(p,man(),True); self.assertIsNone(a.manifest(p))
    def test_argv_only(self):
        m=man(); m["tests"][0]["command"]="echo no"
        with self.assertRaises(ValueError):a.validate(m)
    def test_safe_extract(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); p=d/"x.zip"
            with zipfile.ZipFile(p,"w") as z:z.writestr("../x","x")
            with self.assertRaises(ValueError):a.extract(p,d/"out")
    def test_env(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); (d/"bin").mkdir(); c=a.defaults(); c["root"]=d/"auto"; c["repo"]=d/"repo"; e=a.environment({"set":{"X":"${PACKAGE_ROOT}/x"},"prepend_path":["bin"]},d,c); self.assertEqual(e["X"],str(d/"x")); self.assertEqual(e["PATH"].split(os.pathsep)[0],str(d/"bin"))
    def test_full_fake_git(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); remote=d/"r.git"; seed=d/"seed"; dl=d/"Downloads"; dl.mkdir(); subprocess.run(["git","init","--bare",str(remote)],check=True,stdout=subprocess.DEVNULL); subprocess.run(["git","clone",str(remote),str(seed)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); subprocess.run(["git","-C",str(seed),"config","user.name","seed"],check=True); subprocess.run(["git","-C",str(seed),"config","user.email","seed@x"],check=True); (seed/"README").write_text("x"); subprocess.run(["git","-C",str(seed),"add","README"],check=True); subprocess.run(["git","-C",str(seed),"commit","-m","seed"],check=True,stdout=subprocess.DEVNULL); subprocess.run(["git","-C",str(seed),"branch","-M","main"],check=True); subprocess.run(["git","-C",str(seed),"push","-u","origin","main"],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); subprocess.run(["git","--git-dir",str(remote),"symbolic-ref","HEAD","refs/heads/main"],check=True)
            start=time.time_ns(); p=dl/"demo.zip"; m=man(); m["publish"]={"files":[{"source":"reply.msg","path":"mesh/ctl/DEMO-CHATGPT/reply.msg"}]}; zmake(p,m,extra={"run_tests.sh":"#!/bin/sh\necho PASS\n","reply.msg":"EVENT|{}\n"}); c=a.defaults(); c.update(root=d/"auto",repo=d/"auto"/"repo",downloads=dl,repo_url=str(remote)); r=a.integrate(p,p.stat(),a.manifest(p),c,start); self.assertEqual(r["status"],"PASS"); self.assertEqual(r["runner"]["started_ns"],start); self.assertTrue((c["repo"]/r["artifact_path"]).exists()); self.assertTrue((c["repo"]/"mesh/ctl/DEMO-CHATGPT/reply.msg").exists())
if __name__=="__main__":unittest.main()
