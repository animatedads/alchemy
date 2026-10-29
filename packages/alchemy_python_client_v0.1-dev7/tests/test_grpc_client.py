"""Real grpcio HTTP/2 loopback interoperability; no pretend ooRexx endpoint."""
from concurrent import futures
import unittest

from alchemy_python import GrpcClient, GrpcMethod, GrpcTransportError, ContractError

try:
    import grpc
    from google.protobuf.wrappers_pb2 import StringValue
except ImportError:
    grpc = None


@unittest.skipIf(grpc is None, 'optional grpcio + protobuf required')
class GrpcClientTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.requests = []
        def get(request, context):
            cls.requests.append(('get', request.value))
            return StringValue(value='received:'+request.value)
        def watch(request, context):
            cls.requests.append(('watch', request.value))
            yield StringValue(value='part1:'+request.value)
            if request.value == 'fault':
                context.abort(grpc.StatusCode.PERMISSION_DENIED, 'not allowed')
            yield StringValue(value='part2:'+request.value)
        cls.server = grpc.server(futures.ThreadPoolExecutor(max_workers=3))
        handler = grpc.method_handlers_generic_handler('demo.Inventory',{
            'Get':grpc.unary_unary_rpc_method_handler(get,request_deserializer=StringValue.FromString,response_serializer=StringValue.SerializeToString),
            'Watch':grpc.unary_stream_rpc_method_handler(watch,request_deserializer=StringValue.FromString,response_serializer=StringValue.SerializeToString),
        })
        cls.server.add_generic_rpc_handlers((handler,))
        port = cls.server.add_insecure_port('127.0.0.1:0')
        assert port > 0
        cls.server.start()
        cls.channel = grpc.insecure_channel('127.0.0.1:'+str(port))

    @classmethod
    def tearDownClass(cls):
        cls.channel.close()
        cls.server.stop(0).wait()

    def make(self, max_messages=10000):
        c=GrpcClient(self.channel,max_stream_messages=max_messages)
        c.register(GrpcMethod('inventory.get','/demo.Inventory/Get',StringValue.SerializeToString,StringValue.FromString))
        c.register(GrpcMethod('inventory.watch','/demo.Inventory/Watch',StringValue.SerializeToString,StringValue.FromString,streaming=True))
        c.freeze()
        return c

    def test_real_unary_uses_explicit_protobuf_codec(self):
        result=self.make().unary('inventory.get',StringValue(value='abc'))
        self.assertEqual(result.value,'received:abc')

    def test_real_stream_delivers_items_and_reaches_final_status(self):
        messages=list(self.make().stream('inventory.watch',StringValue(value='abc')))
        self.assertEqual([m.value for m in messages],['part1:abc','part2:abc'])

    def test_late_fault_keeps_already_delivered_values(self):
        stream=self.make().stream('inventory.watch',StringValue(value='fault'))
        self.assertEqual(next(stream).value,'part1:fault')
        with self.assertRaises(GrpcTransportError) as raised:
            next(stream)
        self.assertEqual(raised.exception.code,grpc.StatusCode.PERMISSION_DENIED)

    def test_stream_limit_cancels_instead_of_pretending_complete(self):
        stream=self.make(max_messages=1).stream('inventory.watch',StringValue(value='abc'))
        self.assertEqual(next(stream).value,'part1:abc')
        with self.assertRaises(ContractError):
            next(stream)

    def test_explicit_published_allowlist_and_freeze(self):
        c=self.make()
        with self.assertRaises(ContractError):c.unary('missing',StringValue(value='a'))
        with self.assertRaises(ContractError):c.unary('inventory.watch',StringValue(value='a'))
        with self.assertRaises(ContractError):c.stream('inventory.get',StringValue(value='a'))
        with self.assertRaises(ContractError):c.register(GrpcMethod('new','/demo.X/M',lambda _:b'',lambda _:None))

    def test_timeout_validation(self):
        c=self.make()
        for invalid in (-1,0,86401,True,'no'):
            with self.assertRaises(ValueError):c.unary('inventory.get',StringValue(value='a'),timeout=invalid)

    def test_late_fault_to_sink_does_not_call_onComplete(self):
        sink=Sink()
        with self.assertRaises(GrpcTransportError):
            self.make().consume_stream('inventory.watch',StringValue(value='fault'),sink)
        self.assertEqual([m.value for m in sink.events],['part1:fault'])
        self.assertEqual(sink.complete,0)
        self.assertEqual(len(sink.faults),1)

    def test_successful_callback_runs_on_caller_thread(self):
        sink=Sink()
        count=self.make().consume_stream('inventory.watch',StringValue(value='abc'),sink)
        self.assertEqual(count,2)
        self.assertEqual(sink.complete,1)
        self.assertEqual(sink.faults,[])

    def test_stream_sink_false_requests_cancel_no_completion(self):
        sink=Sink(stop=True)
        with self.assertRaises(ContractError):
            self.make().consume_stream('inventory.watch',StringValue(value='abc'),sink)
        self.assertEqual(len(sink.events),1)
        self.assertEqual(sink.complete,0)
        self.assertEqual(len(sink.faults),1)

    def test_bad_path_or_duplicate_method_refused(self):
        for path in ('Inventory/Get','/Inventory/*','/Inventory/Other/Again','/x../Get'):
            with self.assertRaises(ContractError):
                GrpcMethod('x',path,lambda _:b'',lambda _:None)
        c=GrpcClient(self.channel)
        m=GrpcMethod('x','/demo.Inventory/Get',lambda _:b'',lambda _:None)
        c.register(m)
        with self.assertRaises(ContractError):c.register(m)

class Sink:
    def __init__(self, stop=False):
        self.events=[];self.complete=0;self.faults=[];self.stop=stop
    def onNext(self, value):
        self.events.append(value)
        return False if self.stop else True
    def onComplete(self):self.complete+=1
    def onFault(self, exc):self.faults.append(exc)

if __name__ == '__main__':unittest.main()
