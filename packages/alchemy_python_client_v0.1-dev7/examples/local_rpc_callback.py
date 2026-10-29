"""Local callback sink ONLY; a native bridge must project the exact method names."""
from alchemy_python import LocalRpcCallbackSink

sink = LocalRpcCallbackSink(max_events=8)
sink.onNext({'progress': 1})
sink.onNext({'progress': 2})
sink.onComplete('done')
print(sink.snapshot())
