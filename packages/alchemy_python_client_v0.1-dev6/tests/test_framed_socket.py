"""Real loopback TCP boundary qualification against the ooRexx dev3 hex8 profile.

A Python server double deliberately implements the protocol profile, not ooRexx
method registration; this is NOT a native interpreter integration test.
"""
from __future__ import annotations

import json
import socket
import socketserver
import threading
import unittest

from alchemy_python import (ContractError, FramedSocketTransport, JsonRpcClient,
                            ProtocolError, TransportError)


class _Harness(socketserver.StreamRequestHandler):
    def handle(self):
        self.server.requests.append(self)
        head = self.rfile.read(8)
        if len(head) != 8:
            return
        count = int(head, 16)
        body = self.rfile.read(count)
        request = json.loads(body)
        self.server.received.append(request)
        if 'id' not in request:
            self.server.notify_received.set()
            return
        response = json.dumps({'jsonrpc': '2.0', 'id': request['id'],
                               'result': request.get('params')}, separators=(',', ':')).encode()
        if self.server.response_override is not None:
            response = self.server.response_override(response)
        else:
            response = f'{len(response):08X}'.encode() + response
        # Deliberately fragment a complete header and payload over several writes.
        for part in (response[:2], response[2:8], response[8:11], response[11:]):
            if part:
                try: self.request.sendall(part)
                except BrokenPipeError: break


class _TCP(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    def __init__(self, addr):
        super().__init__(addr, _Harness)
        self.requests = []
        self.received = []
        self.response_override = None
        self.notify_received = threading.Event()


class FramedSocketIntegration(unittest.TestCase):
    def setUp(self):
        self.server = _TCP(('127.0.0.1', 0))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.port = self.server.server_address[1]
        self.client = JsonRpcClient(FramedSocketTransport('127.0.0.1', self.port, timeout=2))

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(3)

    def test_real_tcp_exchange_unicode_nested_and_exact_hex_frame(self):
        result = self.client.request('catalog.lookup', {'sku': 'ä-7', 'children':[1, None, False]})
        self.assertEqual(result, {'sku': 'ä-7', 'children':[1, None, False]})
        self.assertEqual(self.server.received[0]['method'], 'catalog.lookup')

    def test_real_tcp_notification_never_promises_completion(self):
        self.assertIsNone(self.client.notify('catalog.changed', ['C-42']))
        self.assertTrue(self.server.notify_received.wait(2))
        self.assertNotIn('id', self.server.received[0])

    def test_invalid_lowercase_header_fail_closed(self):
        self.server.response_override = lambda _: b'0000000a' + b'0123456789'
        with self.assertRaises(ProtocolError): self.client.request('catalog.lookup')

    def test_oversized_header_fails_before_allocating_payload(self):
        self.server.response_override = lambda _: b'FFFFFFFF'
        with self.assertRaises(ProtocolError): self.client.request('catalog.lookup')

    def test_truncated_body_reports_unknown_outcome_and_never_retries(self):
        self.server.response_override = lambda _: b'00000010' + b'partial'
        with self.assertRaises(TransportError) as error:
            self.client.request('catalog.mutate', {'value': 3})
        self.assertIn('unknown', str(error.exception))
        self.assertEqual(len(self.server.received), 1)

    def test_truncated_header_fails_uncertain(self):
        self.server.response_override = lambda _: b'000'
        with self.assertRaises(TransportError): self.client.request('catalog.mutate')
        self.assertEqual(len(self.server.received), 1)

    def test_empty_and_excess_outbound_payload_rejected_preconnect(self):
        t = FramedSocketTransport('127.0.0.1', self.port, max_bytes=128)
        with self.assertRaises(ProtocolError): t.exchange(b'')
        with self.assertRaises(ProtocolError): t.exchange(b'x' * 129)
        self.assertFalse(self.server.received)

    def test_remote_denied_by_default(self):
        for host in ('example.com', '192.0.2.1', '::ffff:192.0.2.1'):
            with self.assertRaises(ValueError): FramedSocketTransport(host, 7777)
        # Explicit unsafe opt-in only permits construction; not evidence of TLS/auth.
        self.assertEqual(FramedSocketTransport('192.0.2.1', 7777,
                          allow_unauthenticated_remote=True).host, '192.0.2.1')

    def test_parameters_and_profile(self):
        for port in (0, 65536, True):
            with self.assertRaises(ValueError): FramedSocketTransport('localhost', port)
        for timeout in (-1, 0, float('inf')):
            with self.assertRaises(ValueError): FramedSocketTransport('localhost', 1, timeout=timeout)
        self.assertIn('hex8', FramedSocketTransport.PROFILE)

    def test_connect_failure_no_retry(self):
        self.server.shutdown()
        self.server.server_close()
        with self.assertRaises(TransportError): self.client.request('catalog.lookup')


if __name__ == '__main__':
    unittest.main()
