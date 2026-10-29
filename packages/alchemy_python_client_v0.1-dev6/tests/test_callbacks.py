"""RpcServiceCore/0.1 callback sink interface; native bridge remains external."""
import threading
import unittest
from alchemy_python import CallbackSnapshot, ContractError, LocalRpcCallbackSink


class CallbackTests(unittest.TestCase):
    def test_ooRexx_expected_method_surface_and_terminal_completion(self):
        sink = LocalRpcCallbackSink(max_events=3)
        for name in ('onNext','onComplete','onFault','isCancelled'):
            self.assertTrue(callable(getattr(sink, name)))
        sink.onNext('one')
        sink.onNext({'object':'two'})
        sink.onComplete('finished')
        self.assertEqual(sink.snapshot(), CallbackSnapshot(('one', {'object':'two'}), True, False, 'finished', None))
        with self.assertRaises(ContractError): sink.onNext('three')
        with self.assertRaises(ContractError): sink.onFault('after complete')

    def test_fault_terminal_carries_native_value_without_json_projection(self):
        value = object()
        sink = LocalRpcCallbackSink()
        sink.onFault(value)
        self.assertIs(sink.snapshot().fault, value)
        with self.assertRaises(ContractError): sink.onComplete()

    def test_cancel_and_bounded_buffer_fail_closed(self):
        sink = LocalRpcCallbackSink(max_events=1)
        sink.onNext('first')
        with self.assertRaises(ContractError): sink.onNext('second')
        self.assertTrue(sink.isCancelled())
        self.assertEqual(sink.snapshot().events, ('first',))
        with self.assertRaises(ContractError): sink.onComplete()

    def test_cancelled_sink_rejects_events(self):
        sink = LocalRpcCallbackSink()
        sink.cancel()
        self.assertTrue(sink.isCancelled())
        with self.assertRaises(ContractError): sink.onNext('too late')

    def test_concurrent_writers_remain_bounded(self):
        sink = LocalRpcCallbackSink(max_events=15)
        def producer():
            for n in range(100):
                try: sink.onNext(n)
                except ContractError: return
        jobs=[threading.Thread(target=producer) for _ in range(4)]
        for j in jobs: j.start()
        for j in jobs: j.join()
        self.assertEqual(len(sink.snapshot().events),15)
        self.assertTrue(sink.isCancelled())

    def test_invalid_capacity(self):
        for value in (0, -1, 3.4, True):
            with self.assertRaises(ValueError): LocalRpcCallbackSink(max_events=value)

if __name__ == '__main__': unittest.main()
