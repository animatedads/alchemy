import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from portable_admission import Requirement, Witness, eligible

class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.work=Requirement("POSE","sha256:source","sha256:model","uk","actor","pose-checkpoint/1",True)
        self.node=Witness(frozenset({"POSE"}),frozenset({"sha256:model"}),frozenset({"uk"}),frozenset({"actor"}),frozenset({"pose-checkpoint/1"}),True,True,True)
    def test_matching(self):
        self.assertTrue(eligible(self.work,self.node))
    def test_gpu_fails_closed(self):
        self.assertFalse(eligible(self.work,Witness(self.node.operations,self.node.model_digests,self.node.regions,self.node.principals,self.node.checkpoint_schemas,True,True,False)))
    def test_wrong_model(self):
        self.assertFalse(eligible(Requirement("POSE","sha256:source","sha256:other","uk","actor","pose-checkpoint/1",True),self.node))
    def test_no_storage_commit(self):
        self.assertFalse(eligible(self.work,Witness(self.node.operations,self.node.model_digests,self.node.regions,self.node.principals,self.node.checkpoint_schemas,True,False,True)))

if __name__=="__main__": unittest.main()
