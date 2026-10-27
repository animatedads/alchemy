"""Exact public Connect Selector dev5 contract exercised with projected native doubles."""
import unittest
from dataclasses import dataclass
from alchemy_python import (NativeConnectSelectorPort, ConnectSelectionError,
                            ContractError, ProtocolError, LocalRpcCallbackSink)


@dataclass
class Result:
    ok: bool = True
    provider: str = 'DIRECT'
    accepted: bool = True
    completed: bool = True
    durable: bool = False
    value: object = 'result'
    code: str = 'OK'
    detail: str = ''

class Backend:
    def __init__(self, result=None):
        self.calls = []
        self.result = result or Result()
        self.observer = None
    def execute(self, intent, payload):
        self.calls.append((intent, payload))
        return self.result
    def setObserver(self, observer):
        self.observer = observer
    def explain(self, intent):
        return intent

class Observer:
    def selection(self, intent, selection):
        return None
    def outcome(self, intent, outcome):
        return None

class SelectorDev5Tests(unittest.TestCase):
    def make(self, result=None, **kwargs):
        backend = Backend(result)
        return backend, NativeConnectSelectorPort(backend, lambda *args: args, **kwargs)

    def test_callback_constructor_keeps_sink_local_and_method_explicit(self):
        backend, port = self.make()
        sink = LocalRpcCallbackSink()
        result = port.callback('catalog.watch', {'id':3}, sink, destination='LOCAL', context={'scope':'test'})
        self.assertTrue(result.completed)
        args, payload = backend.calls[0]
        self.assertEqual(args[:5], ('catalog.watch','CALLBACK','IMMEDIATE','AUTO','LOCAL'))
        self.assertIs(args[5]['callbackSink'], sink)
        self.assertEqual(args[5]['context'], {'scope':'test'})
        self.assertEqual(payload, {'id':3})

    def test_callback_cannot_route_over_rpc_or_rto2(self):
        backend, port = self.make()
        for preferred in ('RPC','QUEUE','RTO2'):
            with self.assertRaises(ContractError):
                port.callback('catalog.watch', None, LocalRpcCallbackSink(), preferred=preferred)
        self.assertEqual(backend.calls, [])

    def test_callback_invalid_sink_fails_before_dispatch(self):
        backend, port = self.make()
        with self.assertRaises(ContractError):
            port.callback('catalog.watch', None, object())
        self.assertEqual(backend.calls, [])

    def test_callback_does_not_claim_remote_completion(self):
        backend, port = self.make(Result(provider='RPC'))
        with self.assertRaises(ProtocolError):
            port.callback('catalog.watch', None, LocalRpcCallbackSink())
        self.assertEqual(len(backend.calls), 1)

    def test_continuity_explicit_requirements_and_rto2_reply(self):
        backend, port = self.make(Result(provider='RTO2',accepted=True,completed=False))
        result = port.continuity_request('runtime.continue', {'ref':'r1'}, destination='RUNTIME')
        self.assertFalse(result.completed)
        self.assertTrue(result.accepted)
        self.assertEqual(backend.calls[0][0], ('runtime.continue','REQUEST','CONTINUITY','AUTO','RUNTIME',{}))

    def test_continuity_refuses_downgrade_before_execution(self):
        backend, port = self.make()
        for provider in ('DIRECT','RPC','QUEUE'):
            with self.assertRaises(ContractError):
                port.continuity_request('runtime.continue', None, preferred=provider)
        self.assertFalse(backend.calls)

    def test_continuity_rejects_spoofed_provider(self):
        backend, port = self.make(Result(provider='RPC'))
        with self.assertRaises(ProtocolError):
            port.continuity_request('runtime.continue')
        self.assertEqual(len(backend.calls), 1)

    def test_estate_changed_uncertain_outcome_preserved(self):
        reply = Result(ok=False,provider='RTO2',accepted=True,completed=False,
                       code='ESTATE_CHANGED', detail='incarnation changed')
        backend, port = self.make(reply)
        with self.assertRaises(ConnectSelectionError) as caught:
            port.continuity_request('runtime.continue')
        self.assertEqual(caught.exception.outcome.code, 'ESTATE_CHANGED')
        self.assertTrue(caught.exception.outcome.accepted)
        self.assertEqual(len(backend.calls), 1)

    def test_observer_passthrough_and_validation(self):
        backend, port = self.make()
        o = Observer()
        port.set_observer(o)
        self.assertIs(backend.observer, o)
        with self.assertRaises(ContractError):
            port.set_observer(object())
        self.assertIs(backend.observer, o)
        port.set_observer(None)
        self.assertIsNone(backend.observer)

    def test_explain_continuity_mode_uses_actual_native_constructor(self):
        _, port = self.make()
        self.assertEqual(port.explain('runtime.continue',requirement='CONTINUITY',destination='RUNTIME'),
                         ('runtime.continue','REQUEST','CONTINUITY','AUTO','RUNTIME',{}))
        with self.assertRaises(ContractError):
            port.explain('runtime.continue',mode='ENQUEUE',requirement='CONTINUITY')

if __name__ == '__main__':
    unittest.main()
