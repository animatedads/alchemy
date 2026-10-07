import _rexxpython_poc as native
from pathlib import Path
import threading
import time

FACTORY = str(Path(__file__).resolve().parents[1] / "rexx" / "factory.rex")
h = native.create_guarded(FACTORY, "Monty")
result = {}
errors = {}

def guarded():
    try:
        started = time.monotonic()
        result["guarded"] = native.send0_attached(h, "GUARDEDVALUE")
        result["guarded_elapsed"] = time.monotonic() - started
    except BaseException as e:
        errors["guarded"] = repr(e)

def unguarded():
    try:
        started = time.monotonic()
        result["ping"] = native.send0_attached(h, "CONCURRENTPING")
        result["ping_elapsed"] = time.monotonic() - started
    except BaseException as e:
        errors["ping"] = repr(e)

try:
    a = threading.Thread(target=guarded, name="guarded-call")
    a.start()
    time.sleep(0.12)
    assert a.is_alive(), "guarded call did not remain blocked"

    b = threading.Thread(target=unguarded, name="unguarded-call")
    b.start()
    b.join(0.35)
    assert not b.is_alive(), "unguarded call serialized behind guarded call"
    assert not errors, errors
    assert result["ping"].startswith("PING:0:"), result["ping"]
    assert a.is_alive(), "guarded call released before gate"

    a.join(2.0)
    assert not a.is_alive(), "guarded call did not release"
    assert not errors, errors
    assert result["guarded"].startswith("Monty released after 8 ticks")
    print("unguarded-while-guarded-waits:", result["ping"])
    print("unguarded-elapsed-ms:", round(result["ping_elapsed"] * 1000))
    print("guarded-result:", result["guarded"])
    print("GUARDED + UNGUARDED CONCURRENT PYTHON->REXX POC PASS")
finally:
    native.release_handle(h)
