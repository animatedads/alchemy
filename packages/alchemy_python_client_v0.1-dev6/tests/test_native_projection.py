"""Contract double tests; not a native ooRexx interpreter qualification."""
import unittest
from alchemy_python import (RexxSelectorProjection, rexx_result_field,
    rexx_logical, NativeConnectSelectorPort, ConnectSelectionError, ProtocolError,
    AlchemySession, SelectorClient, Operation, ServiceContract)


class Retained:
    def __init__(self, behavior):
        self.behavior = behavior
        self.calls = []
    def send(self, name, *args):
        self.calls.append((name, args))
        return self.behavior(name, *args)


class ProjectionTests(unittest.TestCase):
    def create(self, *, reply=None, destination='server-A', accepted='1', ok='1',
               completed='1', durable='0'):
        identity = object()
        if reply is None:
            reply = identity
        raw = dict(ok=ok, provider='DIRECT', accepted=accepted, completed=completed,
                   durable=durable, value=reply, code='OK', detail='')
        result = Retained(lambda name, *_: raw[name.lower()])
        selector = Retained(lambda name, *_: result if name == 'EXECUTE' else {'native': True})
        port = NativeConnectSelectorPort(RexxSelectorProjection(selector),
              lambda *args: args, read_field=rexx_result_field, decode_bool=rexx_logical,
              default_destination=destination)
        return selector, result, port, reply

    def test_request_retains_native_value_identity(self):
        selector, result, port, reply = self.create()
        contract = ServiceContract('catalog', '1', (Operation('read', 'catalog.read'),))
        answer = AlchemySession(SelectorClient(port)).service(contract).read({'key':'K'})
        self.assertIs(answer, reply)
        self.assertEqual(selector.calls[0][0], 'EXECUTE')
        self.assertEqual(selector.calls[0][1][0],
                         ('catalog.read', 'REQUEST','IMMEDIATE','AUTO','server-A',{}))
        self.assertEqual(result.calls[0][0], 'OK')
        self.assertEqual(len(selector.calls), 1)

    def test_no_implicit_bool_truthiness(self):
        self.assertFalse(rexx_logical('0'))
        self.assertFalse(rexx_logical(0))
        self.assertTrue(rexx_logical('1'))
        self.assertTrue(rexx_logical(1))
        for invalid in ('FALSE', 'true', '', 2, object(), None):
            with self.subTest(invalid=invalid), self.assertRaises(ProtocolError):
                rexx_logical(invalid)

    def test_denial_does_not_retry_or_erase_accepted(self):
        selector, _, port, _ = self.create(ok='0', accepted='1', completed='0')
        with self.assertRaises(ConnectSelectionError) as raised:
            port.request(type('InvocationDouble',(),dict(kind='request',operation='x.read',params=None))())
        self.assertTrue(raised.exception.outcome.accepted)
        self.assertFalse(raised.exception.outcome.completed)
        self.assertEqual(len(selector.calls), 1)

    def test_notify_uses_named_destination(self):
        selector, _, port, _ = self.create(completed='0')
        contract=ServiceContract('x','1',(Operation('changed','x.notify',kind='notification'),))
        self.assertIsNone(AlchemySession(SelectorClient(port)).service(contract).changed())
        self.assertEqual(selector.calls[0][1][0][4], 'server-A')

    def test_enqueued_job_not_conflated_with_request(self):
        selector, _, port, _ = self.create(completed='0',durable='1')
        rec=port.enqueue('tasks.add', object(),destination='jobs-Q')
        self.assertTrue(rec.durable)
        self.assertFalse(rec.completed)
        self.assertEqual(selector.calls[0][1][0][1:5],('ENQUEUE','DURABLE','AUTO','jobs-Q'))

    def test_callback_sink_passes_as_identity(self):
        selector, _, port, _ = self.create()
        sink=type('Sink',(),{k:lambda self,*a:None for k in
                          ('onNext','onComplete','onFault','isCancelled')})()
        port.callback('math.sum', [], sink)
        self.assertIs(selector.calls[0][1][0][5]['callbackSink'],sink)

    def test_exact_getters_only(self):
        _, result, _, _=self.create()
        self.assertEqual(rexx_result_field(result,'provider'),'DIRECT')
        with self.assertRaises(ProtocolError):rexx_result_field(result,'password')
        with self.assertRaises(ProtocolError):rexx_result_field(object(),'ok')

    def test_no_constructor_instantiation_or_runtime_claim(self):
        with self.assertRaises(TypeError):RexxSelectorProjection(object())
        with self.assertRaises(TypeError):NativeConnectSelectorPort(RexxSelectorProjection(Retained(lambda *_:None)),None)

if __name__ == '__main__': unittest.main()
