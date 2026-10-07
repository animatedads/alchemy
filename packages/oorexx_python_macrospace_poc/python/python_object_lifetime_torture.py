import gc, weakref
import _rexxpython_poc as n
class Target: pass
o=Target(); w=weakref.ref(o)
h1=n.retain_python_object(o); h2=n.retain_python_object(o)
assert h1==h2
assert n.python_object_retain_count(h1)==2
del o; gc.collect()
assert w() is not None
n.release_python_object(h1)
assert n.python_object_retain_count(h1)==1
gc.collect(); assert w() is not None
n.release_python_object(h2)
assert n.python_object_retain_count(h1)==0
gc.collect(); assert w() is None
n.release_python_object(h1) # idempotent stale release
assert n.python_object_retain_count(h1)==0
print("same-object-same-handle:",h1==h2)
print("survives-first-release:",True)
print("collected-after-final-release:",True)
print("stale-release-tolerated:",True)
print("PYTHON OBJECT IDENTITY + LIFETIME TORTURE PASS")
