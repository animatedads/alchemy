"""Protocol and virtual-class qualification, stdlib unittest (no extra dependencies)."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import textwrap
import unittest

from alchemy_python import (
    AlchemySession, CallableTransport, ContractError, HttpTransport, JsonRpcClient,
    LiveRexxObject, Macrospace, Operation, ProtocolError, RemoteError,
    ServiceContract, SubprocessTransport, TransportError, VirtualRexxClassFactory,
    VirtualServiceClassFactory,
)


class FakeServer:
    def __init__(self):
        self.requests = []
        self.notifications = []
        self.override = None

    def exchange(self, frame: bytes) -> bytes:
        req = json.loads(frame)
        self.requests.append(req)
        if self.override:
            return self.override(req)
        return json.dumps({"jsonrpc": "2.0", "id": req["id"], "result": req.get("params", None)}).encode()

    def send(self, frame: bytes) -> None:
        self.notifications.append(json.loads(frame))


class RpcTests(unittest.TestCase):
    def setUp(self):
        self.server = FakeServer()
        self.client = JsonRpcClient(CallableTransport(self.server.exchange, self.server.send))

    def test_method_request_preserves_json_values_and_unique_string_id(self):
        params = {"text": "é\nΩ", "none": None, "false": False, "empty": "", "number": 1}
        self.assertEqual(self.client.request("object.echo", params), params)
        a = self.server.requests[-1]["id"]
        self.client.request("object.echo", [])
        b = self.server.requests[-1]["id"]
        self.assertNotEqual(a, b)
        self.assertIs(type(a), str)

    def test_notification_has_no_id_or_reply(self):
        self.assertIsNone(self.client.notify("events.changed", {"x": True}))
        self.assertNotIn("id", self.server.notifications[0])
        self.assertEqual(self.server.requests, [])

    def test_remote_error_preserves_code_and_data(self):
        self.server.override = lambda req: json.dumps({"jsonrpc": "2.0", "id": req["id"],
                            "error": {"code": -32602, "message": "Invalid params", "data": {"name": "x"}}}).encode()
        with self.assertRaises(RemoteError) as ctx:
            self.client.request("object.echo")
        self.assertEqual(ctx.exception.code, -32602)
        self.assertEqual(ctx.exception.data, {"name": "x"})

    def test_mismatched_id_rejected(self):
        self.server.override = lambda req: b'{"jsonrpc":"2.0","id":"wrong","result":5}'
        with self.assertRaises(ProtocolError):
            self.client.request("object.echo")

    def test_duplicate_json_member_rejected(self):
        self.server.override = lambda req: ('{"jsonrpc":"2.0","id":"%s","result":1,"result":2}' % req["id"]).encode()
        with self.assertRaises(ProtocolError):
            self.client.request("object.echo")

    def test_response_requires_exactly_one_result_or_error(self):
        self.server.override = lambda req: json.dumps({"jsonrpc": "2.0", "id": req["id"],
                                                          "result": 4, "error": None}).encode()
        with self.assertRaises(ProtocolError):
            self.client.request("object.echo")

    def test_nan_float_and_unsafe_integer_and_bool_key_rejected(self):
        for invalid in ([float("nan")], [float("inf")], [2**60], [{True: 2}], [b"bytes"]):
            with self.subTest(invalid=invalid), self.assertRaises((ValueError, TypeError)):
                self.client.request("object.echo", invalid)
        self.assertEqual(self.server.requests, [])

    def test_bytes_and_params_bounds(self):
        small = JsonRpcClient(CallableTransport(self.server.exchange, self.server.send), max_bytes=128)
        with self.assertRaises(ProtocolError):
            small.request("method", ["z"*200])
        with self.assertRaises(TypeError):
            self.client.request("method", "scalar")

    def test_reserved_method_rejected(self):
        with self.assertRaises(ValueError):
            self.client.request("rpc.system.describe")

    def test_no_automatic_retry(self):
        times = []
        def fail(_):
            times.append(1)
            raise TransportError("connection lost")
        with self.assertRaises(TransportError):
            JsonRpcClient(CallableTransport(fail, lambda _: None)).request("job.submit", {"value": 1})
        self.assertEqual(len(times), 1)


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.server = FakeServer()
        self.client = JsonRpcClient(CallableTransport(self.server.exchange, self.server.send))
        self.contract = ServiceContract("example.vault", "1.0", (
            Operation("lookup", "vault.lookup"), Operation("event", "vault.changed", "notification"),
        ))

    def test_contract_allowlist_and_generation(self):
        Vault = VirtualServiceClassFactory.make("Vault", self.contract)
        proxy = Vault(self.client, self.contract)
        self.assertEqual(proxy.lookup({"ref": "x"}), {"ref": "x"})
        proxy.event({"ref": "y"})
        self.assertEqual(self.server.notifications[-1]["method"], "vault.changed")
        with self.assertRaises(ContractError):
            proxy.call("vault.erase", {})
        with self.assertRaises(AttributeError):
            proxy.erase
        self.assertIs(Vault.__alchemy_contract__, self.contract)
        self.assertNotIsInstance(proxy, LiveRexxObject)

    def test_session_dynamic_proxy(self):
        service = AlchemySession(self.client).service(self.contract)
        self.assertEqual(service.lookup([1]), [1])
        service.event({"a": 1})

    def test_manifest_version_and_restricted_operation(self):
        doc = {"schema": "alchemy.python.service-contract.v1", "name": "jobs", "api_version": "1",
               "operations": [{"python_name": "submit", "rpc_method": "jobs.submit", "semantics": "job"}]}
        contract = ServiceContract.from_manifest(doc)
        self.assertEqual(contract.operations[0].semantics, "job")
        with self.assertRaises(ContractError):
            ServiceContract("jobs", "1", (Operation("submit", "jobs.submit", "notification", "job"),))
        with self.assertRaises(ContractError):
            ServiceContract.from_manifest({**doc, "schema": "unknown"})

    def test_collision_rejected(self):
        with self.assertRaises(ContractError):
            ServiceContract("x", "1", (Operation("lookup", "x.y"), Operation("lookup", "x.z")))
        bad = ServiceContract("x", "1", (Operation("request", "x.y"),))
        # request would shadow neither ServiceProxy's call nor notify, so it is allowed
        self.assertIsNotNone(VirtualServiceClassFactory.make("X", bad))
        with self.assertRaises(ContractError):
            VirtualServiceClassFactory.make("Bad", ServiceContract("x", "1", (Operation("call", "x.call"),)))


class LiveObjectTests(unittest.TestCase):
    def test_virtual_class_reuses_live_target_no_method_cache(self):
        class Target:
            def __init__(self):
                self.calls = []
            def describe(self):
                return "v1"
            def send(self, name, *args):
                self.calls.append((name, args))
                return 77
        target = Target()
        Animal = VirtualRexxClassFactory.make("Animal", {"describe": "describe"})
        proxy = Animal(target)
        self.assertEqual(proxy.describe(), "v1")
        target.describe = lambda: "v2"
        self.assertEqual(proxy.describe(), "v2")
        self.assertIs(proxy.projection, target)
        self.assertEqual(proxy.send_exact("DESCRIBE"), 77)
        self.assertEqual(target.calls, [("DESCRIBE", ())])

    def test_macrospace_injection_and_collision(self):
        class Native:
            pass
        bridge = Macrospace(Native())
        Counter = bridge.virtual_class("Counter", {"read": "read_value"})
        class Target:
            def read_value(self): return 3
        self.assertEqual(bridge.adopt(Counter, Target()).read(), 3)
        with self.assertRaises(ContractError):
            bridge.virtual_class("Bad", {"projection": "m"})
        with self.assertRaises(TypeError):
            bridge.adopt(object, Target())


class TransportTests(unittest.TestCase):
    def test_stdio_roundtrip_and_no_reply_for_notification(self):
        # Fake standalone process exercises the wire framing independent of installed ooRexx.
        script = textwrap.dedent('''
            import sys, json
            for line in sys.stdin:
                request=json.loads(line)
                if "id" in request:
                    print(json.dumps({"jsonrpc":"2.0","id":request["id"],"result":"pong"}))
        ''')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "server.py"
            path.write_text(script)
            client = JsonRpcClient(SubprocessTransport([sys.executable, str(path)], timeout=8.0))
            self.assertEqual(client.request("system.ping"), "pong")
            client.notify("system.ping")

    def test_stdio_timeout_is_ambiguous(self):
        with self.assertRaises(TransportError):
            SubprocessTransport([sys.executable, "-c", "import time; time.sleep(2)"], timeout=0.1).exchange(b"{}")

    def test_http_requires_https_and_no_plaintext_bearer(self):
        with self.assertRaises(ValueError): HttpTransport("http://example.com/rpc")
        with self.assertRaises(ValueError): HttpTransport("http://localhost/rpc", token="private", allow_insecure_loopback=True)
        with self.assertRaises(ValueError): HttpTransport("https://user:pass@example.com/rpc")
        HttpTransport("http://127.0.0.1/rpc", allow_insecure_loopback=True)

    def test_http_success_with_injected_opener(self):
        class Response:
            status = 200
            headers = {"Content-Type": "application/json"}
            def __init__(self, data): self.data = data
            def __enter__(self): return self
            def __exit__(self, *_): pass
            def read(self, n): return self.data[:n]
        def opener(req, timeout):
            self.assertEqual(req.get_method(), "POST")
            doc = json.loads(req.data)
            if "id" in doc:
                return Response(json.dumps({"jsonrpc":"2.0", "id":doc["id"], "result":True}).encode())
            return Response(b"")
        client = JsonRpcClient(HttpTransport("https://alchemy.example/rpc", opener=opener))
        self.assertIs(client.request("ping"), True)
        self.assertIsNone(client.notify("event"))


# Separate test class deliberately also works with unittest discover's module scan.
from alchemy_python import JobReceipt, JobServiceClient

class DurableJobTests(unittest.TestCase):
    def setUp(self):
        self.server = FakeServer()
        self.client = JsonRpcClient(CallableTransport(self.server.exchange, self.server.send))
        self.contract = ServiceContract("jobs", "1", tuple(Operation(k, "jobs." + k, semantics="job" if k == "submit" else "immediate")
                                                       for k in ("submit", "status", "result", "cancel")))
        self.jobs = JobServiceClient(AlchemySession(self.client).service(self.contract))

    def test_accepted_receipt_and_explicit_status(self):
        def responder(req):
            if req["method"] == "jobs.submit":
                response = {"accepted": True, "job_id": "J-19", "state": "queued", "correlation_id": "C-1"}
            elif req["method"] == "jobs.status":
                response = {"job_id": "J-19", "state": "running", "revision": 2}
            else:
                response = {"acknowledged": True}
            return json.dumps({"jsonrpc": "2.0", "id": req["id"], "result": response}).encode()
        self.server.override = responder
        r = self.jobs.submit({"task": "measure"}, idempotency_key="trace-19")
        self.assertEqual(r, JobReceipt("J-19", "queued", "C-1"))
        self.assertEqual(self.server.requests[0]["params"]["idempotency_key"], "trace-19")
        self.assertEqual(self.jobs.status(r.job_id)["state"], "running")
        self.assertEqual(self.jobs.cancel(r.job_id, idempotency_key="cancel-19"), {"acknowledged": True})

    def test_no_claim_on_bad_receipt_or_missing_key(self):
        with self.assertRaises(ContractError):
            self.jobs.submit({"task": "work"}, idempotency_key="")
        self.server.override = lambda req: json.dumps({"jsonrpc": "2.0", "id": req["id"],
                                                        "result": {"accepted": False}}).encode()
        with self.assertRaises(ContractError):
            self.jobs.submit({"task": "work"}, idempotency_key="key-1")
        with self.assertRaises(ContractError):
            JobReceipt.parse({"accepted": True, "job_id": "", "state": "queued"})

    def test_job_contract_requires_all_methods(self):
        with self.assertRaises(ContractError):
            JobServiceClient(AlchemySession(self.client).service(
                ServiceContract("jobs", "1", (Operation("submit", "jobs.submit", "request", "job"),))))


if __name__ == "__main__":
    unittest.main()
