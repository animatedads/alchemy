"""Explicit opt-in private-profile client; needs a running ooRexx TCP service.

Use only against the unauthenticated loopback demonstration, not a public port.
"""
from __future__ import annotations
import argparse
from alchemy_python import AlchemySession, FramedSocketTransport, JsonRpcClient, Operation, ServiceContract


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--item', default='item-7')
    args = parser.parse_args()
    transport = FramedSocketTransport(args.host, args.port)
    contract = ServiceContract('catalog', '1', (Operation('lookup', 'catalog.lookup'),))
    print(AlchemySession(JsonRpcClient(transport)).service(contract).lookup([args.item]))


if __name__ == '__main__':
    main()
