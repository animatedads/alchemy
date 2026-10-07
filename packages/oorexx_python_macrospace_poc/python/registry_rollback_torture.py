"""Regression checks for Python-object registry transactional ownership."""
import gc
import weakref
import _rexxpython_poc as native


class Payload:
    pass


def check(label, condition):
    print(f"{label}: {bool(condition)}")
    if not condition:
        raise AssertionError(label)


obj = Payload()
handle = native.retain_python_object(obj)
check("pre-retain-count-is-one", native.python_object_retain_count(handle) == 1)

# Validation must happen before wrap_python_object acquires another ownership.
try:
    native.wrap_python_object(obj, "/definitely/not/a/rexx/factory.rex", {"FOO": 7})
except TypeError:
    pass
else:
    raise AssertionError("invalid case map accepted")
check("invalid-case-map-does-not-retain", native.python_object_retain_count(handle) == 1)

# Factory failure occurs after retain; rollback must release only that new owner.
try:
    native.wrap_python_object(obj, "/definitely/not/a/rexx/factory.rex")
except RuntimeError:
    pass
else:
    raise AssertionError("missing factory unexpectedly succeeded")
check("factory-failure-restores-existing-owner", native.python_object_retain_count(handle) == 1)

ref = weakref.ref(obj)
native.release_python_object(handle)
check("final-release-clears-registry", native.python_object_retain_count(handle) == 0)
del obj
gc.collect()
check("payload-collects-after-final-release", ref() is None)

print("PYTHON REGISTRY ROLLBACK TORTURE PASS")
