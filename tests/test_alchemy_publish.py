import sys,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from alchemy_publication import bashqueues
from alchemy_publication.common import extract_component_zip,manifest_for

def mk(path,files):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for n,d in files.items(): z.writestr(n,d)
class Tests(unittest.TestCase):
    def test_dependency_and_duplicate_omitted(self):
        with tempfile.TemporaryDirectory() as td:
            td=Path(td); z=td/'c.zip'; mk(z,{'c/src/A.cls':'A','c/vendor/D.cls':'D','c/src/D.cls':'D'}); out=td/'out'; r=extract_component_zip(z,out,'packages/c')
            self.assertTrue((out/'src/A.cls').exists()); self.assertFalse((out/'src/D.cls').exists()); self.assertTrue((out/'vendor/README.md').exists()); self.assertEqual({x.reason for x in r.omitted},{'dependency_payload','byte_identical_to_dependency_payload'})
    def test_bashqueues_state_omitted(self):
        with tempfile.TemporaryDirectory() as td:
            td=Path(td); z=td/'b.zip'; mk(z,{'README.md':'delivery','queuebash.sh':'code','.queuebash/pending/j':'x','running/j':'y','testr/q':'z'}); stage,m=bashqueues.build(z,'0.18.test')
            try:
                self.assertTrue((stage/'bashqueues/queuebash.sh').exists()); self.assertFalse((stage/'bashqueues/.queuebash').exists()); self.assertEqual(m['summary']['files_omitted'],3); self.assertTrue((stage/'bashqueues/docs/history/README_0.18.test_delivery.md').exists())
            finally:
                import shutil; shutil.rmtree(stage,ignore_errors=True)
    def test_manifest_hides_local_path(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'a.zip'; mk(p,{'x':'x'}); self.assertNotIn('path',manifest_for('x',[],[p])['sources'][0])
if __name__=='__main__': unittest.main()
