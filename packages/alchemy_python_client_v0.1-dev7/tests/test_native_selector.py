"""Contract tests against the published ConnectIntent/ConnectResult API shape.

No ooRexx runtime is claimed: these are Python doubles with the exact callable
shapes; native bridge qualification remains a separate integration requirement.
"""
import unittest
from dataclasses import dataclass

from alchemy_python import (AlchemySession, ContractError, NativeConnectSelectorPort,
                            ConnectSelectionError, Operation, ServiceContract, SelectorClient,
                            ProtocolError)


@dataclass
class FakeResult:
    ok: bool = True
    provider: str = 'DIRECT'
    accepted: bool = True
    completed: bool = True
    durable: bool = False
    value: object = 'reply'
    code: str = 'OK'
    detail: str = ''


class FakeSelector:
    def __init__(self, result=None):
        self.calls = []
        self.result = result or FakeResult()
    def execute(self, intent, payload):
        self.calls.append((intent, payload))
        return self.result
    def explain(self, intent):
        return {'mode': intent[1], 'requirement': intent[2]}


class NativeContractTests(unittest.TestCase):
    def make(self, result=None, **kwargs):
        backend = FakeSelector(result)
        port = NativeConnectSelectorPort(backend, lambda *values: values, **kwargs)
        return backend, port

    def test_request_exact_native_constructor_and_result(self):
        backend, port = self.make()
        contract = ServiceContract('catalog', '1', (Operation('lookup', 'catalog.lookup'),))
        answer = AlchemySession(SelectorClient(port)).service(contract).lookup({'id': 'a'})
        self.assertEqual(answer, 'reply')
        self.assertEqual(backend.calls[0], (('catalog.lookup','REQUEST','IMMEDIATE','AUTO','',{}),{'id':'a'}))

    def test_request_with_job_semantics_is_still_a_service_request(self):
        backend, port = self.make(FakeResult(provider='RPC', value={
            'accepted': True, 'job_id': 'J-2', 'state': 'queued'}))
        contract = ServiceContract('jobs', '1', (Operation('submit', 'jobs.submit', semantics='job'),))
        reply = AlchemySession(SelectorClient(port)).service(contract).submit({'payload':'work'})
        self.assertEqual(reply['job_id'], 'J-2')
        self.assertEqual(backend.calls[0][0][1:3], ('REQUEST','IMMEDIATE'))

    def test_notification_is_not_confirmation_of_work(self):
        backend, port = self.make(FakeResult(provider='RPC', completed=False, value=None))
        contract = ServiceContract('catalog','1',(Operation('changed','catalog.changed',kind='notification'),))
        self.assertIsNone(AlchemySession(SelectorClient(port)).service(contract).changed({'id': 'a'}))
        self.assertEqual(backend.calls[0][0][1], 'NOTIFY')

    def test_durable_enqueue_native_semantics_and_receipt(self):
        backend, port = self.make(FakeResult(provider='QUEUE', completed=False, durable=True, value='put-7'))
        receipt = port.enqueue('tasks.submit', {'task':'a'},destination='WORK',options={'correlationId':'c-5'})
        self.assertTrue(receipt.accepted)
        self.assertTrue(receipt.durable)
        self.assertFalse(receipt.completed)
        self.assertEqual(receipt.value, 'put-7')
        self.assertEqual(backend.calls[0][0], ('tasks.submit','ENQUEUE','DURABLE','AUTO','WORK',{'correlationId':'c-5'}))

    def test_best_effort_does_not_imply_durable(self):
        _, port = self.make(FakeResult(provider='QUEUE', completed=False, durable=False))
        result = port.enqueue('tasks.submit', {}, requirement='BEST_EFFORT')
        self.assertFalse(result.durable)

    def test_denial_keeps_accepted_uncertainty_and_never_retries(self):
        backend, port = self.make(FakeResult(ok=False, provider='QUEUE', accepted=True, completed=False,
                                             durable=True, code='ACK_UNCERTAIN', detail='ack uncertain'))
        with self.assertRaises(ConnectSelectionError) as caught:
            port.enqueue('work', {})
        self.assertTrue(caught.exception.outcome.accepted)
        self.assertTrue(caught.exception.outcome.durable)
        self.assertEqual(len(backend.calls), 1)

    def test_unsupported_explicit_choice_is_not_retried(self):
        backend, port = self.make(FakeResult(ok=False, provider='QUEUE', accepted=False, completed=False,
                                             code='UNSUPPORTED', detail='no synchronous result'), preferred='QUEUE')
        contract = ServiceContract('x','1',(Operation('lookup','x.lookup'),))
        with self.assertRaises(ConnectSelectionError):
            AlchemySession(SelectorClient(port)).service(contract).lookup()
        self.assertEqual(backend.calls[0][0][3], 'QUEUE')
        self.assertEqual(len(backend.calls), 1)

    def test_native_codec_injection_required_for_real_values(self):
        backend, port = self.make(FakeResult(value={'native': 10}),
                                  encode_payload=lambda obj: ('encoded', obj),
                                  decode_value=lambda obj: ('decoded', obj),
                                  encode_options=lambda obj: ('options', obj))
        contract=ServiceContract('x','1',(Operation('m','x.m'),))
        self.assertEqual(AlchemySession(SelectorClient(port)).service(contract).m([1]),
                         ('decoded', {'native': 10}))
        self.assertEqual(backend.calls[0][1], ('encoded', [1]))
        self.assertEqual(backend.calls[0][0][-1], ('options', {}))

    def test_native_projection_getter_can_use_exact_method_dispatch(self):
        backend, port = self.make(read_field=lambda obj, field: obj.__dict__[field])
        contract=ServiceContract('x','1',(Operation('m','x.m'),))
        self.assertEqual(AlchemySession(SelectorClient(port)).service(contract).m(), 'reply')

    def test_bad_native_result_is_rejected(self):
        backend, port = self.make(FakeResult(accepted=1))
        contract=ServiceContract('x','1',(Operation('m','x.m'),))
        with self.assertRaises(ProtocolError):
            AlchemySession(SelectorClient(port)).service(contract).m()
        _, queue_port = self.make(FakeResult(provider='QUEUE',completed=False,durable=False))
        with self.assertRaises(ProtocolError):
            queue_port.enqueue('work',{})
        _, notify_port = self.make(FakeResult(provider='DIRECT',completed=True))
        notification=ServiceContract('x','1',(Operation('n','x.n',kind='notification'),))
        with self.assertRaises(ProtocolError):
            AlchemySession(SelectorClient(notify_port)).service(notification).n()

    def test_invalid_intents_rejected_before_native_call(self):
        backend, port = self.make()
        with self.assertRaises(ContractError): port.enqueue('work', {}, requirement='UNKNOWN')
        with self.assertRaises(ContractError): port.enqueue('work', {}, preferred='TYPO')
        with self.assertRaises(ContractError): port.enqueue('work', {}, requirement='DURABLE', options={5: 'bad'})
        self.assertFalse(backend.calls)

    def test_explain_calls_native_explain(self):
        _,port=self.make()
        self.assertEqual(port.explain('catalog.lookup'), {'mode':'REQUEST','requirement':'IMMEDIATE'})

if __name__ == '__main__': unittest.main()
