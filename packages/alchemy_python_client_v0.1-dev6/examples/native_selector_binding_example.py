"""Integration sketch with the EXACT public native selector constructor shape.

This file intentionally has no automatic discovery of ooRexx class paths:
provide live ooRexx objects through the macrospace bridge in your host.
"""
from alchemy_python import (AlchemySession, NativeConnectSelectorPort,
                            Operation, SelectorClient, ServiceContract)


def bind_native_selector(native_selector, native_new_intent, *,
                         encode_payload, decode_value, encode_options, read_field):
    port = NativeConnectSelectorPort(
        native_selector,
        native_new_intent,             # ConnectIntent~new(op,mode,requirement,preferred,destination,options)
        encode_payload=encode_payload,
        decode_value=decode_value,
        encode_options=encode_options,
        read_field=read_field,
    )
    contract = ServiceContract('catalog', '1', (Operation('lookup', 'catalog.lookup'),))
    service = AlchemySession(SelectorClient(port)).service(contract)
    return port, service
