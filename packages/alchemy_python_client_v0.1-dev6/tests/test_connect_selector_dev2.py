"""Dev2 source contract / strict policy result qualification via native API double."""
import unittest
from dataclasses import dataclass

from alchemy_python import (AlchemySession, ConnectSelectionError, ContractError,
                            NativeConnectSelectorPort, Operation, SelectorClient,
                            ServiceContract)

@dataclass
class NativeResult:
    ok: bool = False
    provider: str = 'RPC'
    accepted: bool = False
    completed: bool = False
    durable: bool = False
    value: object = None
    code: str = 'POLICY_DENIED'
    detail: str = 'Provider is not authorised for this route'

class SelectorDouble:
    def __init__(self):
        self.invocations = []
    def execute(self, intent, payload):
        self.invocations.append((intent,payload))
        return NativeResult()
    def explain(self, intent):
        return {'ok':False,'provider':intent[3],'code':'POLICY_DENIED',
                'reason':'Provider is not authorised for this route',
                'operation':intent[0],'mode':intent[1], 'requirement':intent[2],
                'preferred':intent[3],'destination':intent[4]}

class PolicyContractTests(unittest.TestCase):
    def test_explicit_rpc_cannot_bypass_server_denial(self):
        backend=SelectorDouble()
        port=NativeConnectSelectorPort(backend,lambda *args:args,preferred='RPC')
        contract=ServiceContract('catalog','1',(Operation('lookup','catalog.lookup'),))
        with self.assertRaises(ConnectSelectionError) as caught:
            AlchemySession(SelectorClient(port)).service(contract).lookup({'key':'x'})
        self.assertEqual(caught.exception.outcome.code,'POLICY_DENIED')
        self.assertFalse(caught.exception.outcome.accepted)
        self.assertEqual(len(backend.invocations),1)
        self.assertEqual(backend.invocations[0][0][3],'RPC')

    def test_explain_preserves_selector_result_not_python_route_choice(self):
        backend=SelectorDouble()
        port=NativeConnectSelectorPort(backend,lambda *args:args)
        view=port.explain('catalog.lookup', preferred='RPC', destination='tenant-A')
        self.assertFalse(view['ok'])
        self.assertEqual(view['code'],'POLICY_DENIED')
        self.assertEqual(view['destination'],'tenant-A')
        self.assertFalse(backend.invocations)

    def test_queue_destination_is_explicit_in_native_constructor(self):
        backend=SelectorDouble()
        port=NativeConnectSelectorPort(backend,lambda *args:args)
        with self.assertRaises(ConnectSelectionError):
            port.enqueue('tasks.submit', {'value':'task'}, destination='WORK',preferred='QUEUE')
        self.assertEqual(backend.invocations[0][0],
            ('tasks.submit','ENQUEUE','DURABLE','QUEUE','WORK',{}))

if __name__ == '__main__': unittest.main()
