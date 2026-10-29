"""Selector seam tests; no simulated results are misrepresented as native calls."""
import unittest
from alchemy_python import (AlchemySession, ContractError, Invocation,
                            JobServiceClient, Operation, SelectorClient,
                            ServiceContract, VirtualServiceClassFactory)

class RecordingSelector:
    def __init__(self):
        self.requests, self.notifications = [], []
    def request(self, intent):
        self.requests.append(intent)
        if intent.operation == 'jobs.submit':
            return {'accepted': True, 'job_id': 'J-7', 'state': 'queued'}
        if intent.operation == 'jobs.status':
            return {'job_id': 'J-7', 'state': 'running'}
        return {'selected': True}
    def notify(self, intent):
        self.notifications.append(intent)
        return {'not_a_confirmation': True}

class SelectorTests(unittest.TestCase):
    def setUp(self):
        self.backend = RecordingSelector()
        self.client = SelectorClient(self.backend)

    def test_pinned_service_metadata_preserved(self):
        contract = ServiceContract('measurement', '2.1', (
            Operation('read', 'measurement.read'),
            Operation('signal', 'measurement.signal', kind='notification')))
        svc = AlchemySession(self.client).service(contract)
        self.assertEqual(svc.read({'device': 'x'}), {'selected': True})
        self.assertEqual(self.backend.requests[0], Invocation(
            'measurement', '2.1', 'measurement.read', 'request', 'immediate', {'device': 'x'}))
        self.assertIsNone(svc.signal({'device': 'x'}))
        self.assertEqual(self.backend.notifications[0].kind, 'notification')
        with self.assertRaises(ContractError):
            svc.call('measurement.destroy', {})
        self.assertEqual(len(self.backend.requests), 1)

    def test_virtual_service_class_uses_selector(self):
        contract = ServiceContract('catalog', '1', (Operation('lookup', 'catalog.lookup'),))
        Catalog = VirtualServiceClassFactory.make('Catalog', contract)
        self.assertEqual(Catalog(self.client, contract).lookup({'key': 'sku'}), {'selected': True})

    def test_job_intent_and_actual_receipt_still_required(self):
        contract = ServiceContract('jobs', '3', tuple(Operation(
            name, 'jobs.' + name, semantics='job' if name == 'submit' else 'immediate')
            for name in ('submit', 'status', 'result', 'cancel')))
        jobs = JobServiceClient(AlchemySession(self.client).service(contract))
        receipt = jobs.submit({'work': 'reindex'}, idempotency_key='client-18')
        self.assertEqual(receipt.job_id, 'J-7')
        self.assertEqual(self.backend.requests[0].semantics, 'job')
        self.assertEqual(self.backend.requests[0].params['idempotency_key'], 'client-18')
        self.assertEqual(jobs.status(receipt.job_id)['state'], 'running')

    def test_missing_adapter_or_invalid_intent_rejected(self):
        with self.assertRaises(TypeError): SelectorClient(object())
        with self.assertRaises(ContractError):
            Invocation('jobs', '1', 'jobs.submit', 'notification', 'job', {})
        with self.assertRaises(TypeError):
            Invocation('s', '1', 'read', 'request', 'immediate', 'text')

    def test_selector_is_not_retried_after_ambiguous_exception(self):
        class Failing(RecordingSelector):
            def request(self, intent):
                self.requests.append(intent)
                raise TimeoutError('may have been executed')
        backend = Failing()
        contract = ServiceContract('x', '1', (Operation('mutate', 'x.mutate'),))
        with self.assertRaises(TimeoutError):
            AlchemySession(SelectorClient(backend)).service(contract).mutate({})
        self.assertEqual(len(backend.requests), 1)

if __name__ == '__main__':
    unittest.main()
