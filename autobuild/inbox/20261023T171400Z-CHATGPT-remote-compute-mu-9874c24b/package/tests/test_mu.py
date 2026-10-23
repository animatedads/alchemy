import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
from remote_mu import Conflict, DisabledBackend, Rejected, RemoteComputeMU, SimulatorBackend

class Placement:
    allowed = True
    def check(self, lease, req):
        return self.allowed and lease == {'token': 'verified-by-external-authority'}

class WLU:
    def check(self, receipt, req):
        return receipt == {'token': 'verified-by-external-wlu'}

class Storage:
    def __init__(self):
        self.commits = []
    def input_ready(self, ref):
        return ref == 'storage:input'
    def output_commit(self, ref, manifest):
        self.commits.append((ref, manifest))

class MUCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.placement = Placement()
        self.storage = Storage()
        self.backend = SimulatorBackend()
        self.backends = dict.fromkeys(['colab','zerogpu','windows_vm','windows_container'], self.backend)
        self.mu = RemoteComputeMU(self.tmp.name, self.placement, WLU(), self.storage, self.backends)
        self.req = dict(jobId='job_1', backend='colab', workload={'type':'python-package','resource':'CPU'},
                        inputRef='storage:input', outputRef='storage:output',
                        lease={'token':'verified-by-external-authority'},
                        entitlement={'token':'verified-by-external-wlu'})
    def tearDown(self):
        self.tmp.cleanup()
    def test_execution_commit_and_restart_replay(self):
        self.assertEqual(self.mu.dispatch(self.req).state, 'SUBMITTED')
        reopened = RemoteComputeMU(self.tmp.name, self.placement, WLU(), self.storage, self.backends)
        self.assertEqual(reopened.dispatch(self.req).state, 'SUBMITTED')
        self.assertEqual(self.backend.submissions, 1)
        self.backend.jobs['sim:job_1'] = {'state':'SUCCEEDED', 'outputManifest':{'sha256':'a'*64,'size':0}}
        self.assertEqual(reopened.refresh('job_1').state,'SUCCEEDED')
        self.assertEqual(len(self.storage.commits),1)
        reopened.refresh('job_1')
        self.assertEqual(len(self.storage.commits),1)
    def test_ambiguous_submission_never_resubmits(self):
        self.backend.error_after_effect = True
        with self.assertRaises(OSError):
            self.mu.dispatch(self.req)
        self.assertEqual(self.mu.get('job_1').state,'UNCERTAIN')
        self.backend.error_after_effect = False
        self.assertEqual(self.mu.dispatch(self.req).state,'UNCERTAIN')
        self.assertEqual(self.backend.submissions,1)
        self.assertEqual(self.mu.recover('job_1').state,'SUBMITTED')
        self.assertEqual(self.backend.submissions,1)
    def test_staging_crash_does_not_issue_new_dispatch(self):
        rec = self.mu.accept(self.req)
        self.mu._set(rec,'STAGING')
        self.assertEqual(self.mu.dispatch(self.req).state,'STAGING')
        self.assertEqual(self.backend.submissions,0)
    def test_missing_reconciliation_evidence_remains_uncertain(self):
        self.backend.error_after_effect = True
        with self.assertRaises(OSError): self.mu.dispatch(self.req)
        self.backend.by_key.clear()
        self.assertEqual(self.mu.recover('job_1').state,'UNCERTAIN')
    def test_untrusted_reconciliation_evidence_rejected(self):
        self.backend.error_after_effect = True
        with self.assertRaises(OSError): self.mu.dispatch(self.req)
        self.backend.reconcile = lambda key: {'dispatchKey':'wrong','remoteId':'rogue'}
        with self.assertRaises(Rejected): self.mu.recover('job_1')
    def test_lease_revalidated(self):
        self.mu.accept(self.req)
        self.placement.allowed = False
        self.assertEqual(self.mu.dispatch(self.req).state,'HELD')
        self.assertEqual(self.backend.submissions,0)
    def test_entitlement_denied(self):
        self.req['entitlement']={}
        with self.assertRaisesRegex(Rejected,'ENTITLEMENT_DENIED'):self.mu.accept(self.req)
    def test_conflicting_job_identity(self):
        self.mu.accept(self.req)
        self.req['workload']['type']='different'
        with self.assertRaises(Conflict): self.mu.accept(self.req)
    def test_storage_commit_fault_never_replays_blindly(self):
        self.mu.dispatch(self.req)
        self.backend.jobs['sim:job_1']={'state':'SUCCEEDED','outputManifest':{'sha256':'a'*64,'size':4}}
        def broken(ref, manifest):
            raise OSError('storage operation outcome unknown')
        self.storage.output_commit = broken
        with self.assertRaises(OSError): self.mu.refresh('job_1')
        self.assertEqual(self.mu.get('job_1').state, 'COMMITTING')
        self.assertEqual(self.mu.refresh('job_1').state, 'COMMITTING')
    def test_missing_output_manifest_holds(self):
        self.mu.dispatch(self.req)
        self.backend.jobs['sim:job_1']={'state':'SUCCEEDED'}
        self.assertEqual(self.mu.refresh('job_1').state,'HELD')
        self.assertEqual(self.storage.commits,[])
    def test_short_hash_rejected(self):
        self.mu.dispatch(self.req)
        self.backend.jobs['sim:job_1']={'state':'SUCCEEDED','outputManifest':{'sha256':'abc','size':1}}
        self.assertEqual(self.mu.refresh('job_1').state,'HELD')
    def test_cancel_requires_provider_confirmation(self):
        self.mu.dispatch(self.req)
        self.assertEqual(self.mu.cancel('job_1').state,'CANCEL_REQUESTED')
        self.assertEqual(self.mu.refresh('job_1').state,'CANCELLED')
    def test_uncertain_cancel_does_not_fabricate_confirmation(self):
        self.backend.error_after_effect=True
        with self.assertRaises(OSError):self.mu.dispatch(self.req)
        self.assertEqual(self.mu.cancel('job_1').state,'UNCERTAIN')
    def test_windows_container_requires_digest_and_kernel(self):
        self.req['backend']='windows_container'
        with self.assertRaises(Rejected):self.mu.accept(self.req)
        self.req['workload'].update(requiresWindowsKernel=True,isolation='windows',imageDigest='sha256:'+'0'*64)
        self.assertEqual(self.mu.accept(self.req).state,'ACCEPTED')
    def test_windows_vm_requires_image_ref(self):
        self.req['backend']='windows_vm'
        with self.assertRaises(Rejected):self.mu.accept(self.req)
        self.req['workload']['imageRef']='windows-test-image@sha256:123'
        self.assertEqual(self.mu.accept(self.req).state,'ACCEPTED')
    def test_zerogpu_requires_space_operation(self):
        self.req['backend']='zerogpu'
        with self.assertRaises(Rejected):self.mu.accept(self.req)
        self.req['workload'].update(space='owner/space',operation='/run')
        self.assertEqual(self.mu.accept(self.req).state,'ACCEPTED')
    def test_zerogpu_exclusive_gpu_fails_closed(self):
        self.req['backend']='zerogpu'
        self.req['workload'].update(space='owner/space',operation='/run',exclusiveGpu=True)
        with self.assertRaises(Rejected):self.mu.accept(self.req)
    def test_disabled_live_provider_remains_unknown(self):
        mu=RemoteComputeMU(self.tmp.name,self.placement,WLU(),self.storage,
                           {'colab':DisabledBackend('colab')})
        with self.assertRaises(Rejected):mu.dispatch(self.req)
        self.assertEqual(mu.get('job_1').state,'UNCERTAIN')
    def test_bad_job_id(self):
        self.req['jobId']='../../bad'
        with self.assertRaises(Rejected):self.mu.accept(self.req)
    def test_insecure_root(self):
        self.tmp2=tempfile.TemporaryDirectory()
        pathlib.Path(self.tmp2.name).chmod(0o755)
        try:
            with self.assertRaises(Rejected):RemoteComputeMU(self.tmp2.name,self.placement,WLU(),self.storage,self.backends)
        finally:
            self.tmp2.cleanup()

if __name__=='__main__':unittest.main()
