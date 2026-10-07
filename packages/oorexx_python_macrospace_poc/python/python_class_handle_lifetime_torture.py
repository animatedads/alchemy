import gc, weakref
import _rexxpython_poc as n
class A: pass
class B: pass
class C(A,B): pass
o=C()
oh=n.retain_python_object(o)
ch1=n.py_type_handle(oh); ch2=n.py_type_handle(oh)
assert ch1==ch2 and n.python_object_retain_count(ch1)==2
bases1=n.py_direct_base_handles(ch1); bases2=n.py_direct_base_handles(ch1)
assert bases1==bases2 and len(bases1)==2
assert all(n.python_object_retain_count(h)==2 for h in bases1)
n.release_python_object(ch1)
assert n.python_object_retain_count(ch2)==1
# class remains authoritative after one owner releases
assert n.py_isinstance_handle(oh,ch2) is True
for h in bases1: n.release_python_object(h)
assert all(n.python_object_retain_count(h)==1 for h in bases2)
assert n.py_issubclass_handle(ch2,bases2[0]) is True
assert n.py_issubclass_handle(ch2,bases2[1]) is True
for h in bases2: n.release_python_object(h)
n.release_python_object(ch2)
n.release_python_object(oh)
# stale releases are harmless
for h in [ch1,*bases1]: n.release_python_object(h)
print("repeated-type-query-same-handle:",ch1==ch2)
print("repeated-base-query-same-handles:",bases1==bases2)
print("class-survives-penultimate-release:",True)
print("base-classes-survive-penultimate-release:",True)
print("relationships-remain-authoritative:",True)
print("PYTHON CLASS HANDLE LIFETIME TORTURE PASS")
