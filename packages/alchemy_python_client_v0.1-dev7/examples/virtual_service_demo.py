"""An in-process demonstrator of the Python virtual service-class projection."""
import json
from alchemy_python import (AlchemySession, CallableTransport, JsonRpcClient,
                            Operation, ServiceContract, VirtualServiceClassFactory)


def exchange(frame):
    req = json.loads(frame)
    assert req["method"] == "math.sum"
    return json.dumps({"jsonrpc": "2.0", "id": req["id"], "result": sum(req["params"])}).encode()


contract = ServiceContract("demo.math", "1.0", (Operation("sum", "math.sum"),))
Math = VirtualServiceClassFactory.make("Math", contract)
client = JsonRpcClient(CallableTransport(exchange, lambda frame: None))
service = Math(client, contract)
print(service.sum([1, 2, 3]))
