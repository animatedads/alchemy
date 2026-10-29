"""Shape example: native_selector, intent_factory must come from actual bridge."""
from alchemy_python import NativeConnectSelectorPort, LocalRpcCallbackSink

# Inject a qualified ooRexx ConnectSelector projection and native ConnectIntent
# constructor; Python tuples and dictionaries are NOT substitutes for real Rexx
# objects and cannot be used without a live macrospace conversion layer.
# port = NativeConnectSelectorPort(native_selector, native_intent_factory,
#                                  encode_payload=to_rexx, encode_options=to_rexx_directory,
#                                  decode_value=from_rexx)
# observer = native-visible observer object with selection()/outcome()
# port.set_observer(observer)
# sink = native-visible LocalRpcCallbackSink projection (check native lifetime)
# event = port.callback('catalog.watch', {'id': 7}, sink, destination='LOCAL')
# result = port.continuity_request('runtime.continue', {'checkpoint':'...'}, destination='RUNTIME')
