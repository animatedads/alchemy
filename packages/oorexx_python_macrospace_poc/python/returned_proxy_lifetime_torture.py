import os,gc,weakref
from pathlib import Path
import _rexxpython_poc as n
ROOT=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(ROOT/"rexx"),os.environ["ALCHEMY_OBJECTS_SRC"],os.environ["ALCHEMY_CRYPTO_SRC"],os.environ["OOREXX_PLATFORM_BIN"]])
n.bootstrap_rexx_package_space(rp,str(ROOT/"rexx"/"animals.cls"))
FACTORY=str(ROOT/"rexx"/"foreign_factory.rex")
class Child:
    def ping(self): return "CHILD-ALIVE"
class Parent:
    def __init__(self,child): self.child=child
    def childobj(self): return self.child
child=Child(); parent=Parent(child); wc=weakref.ref(child)
parent_proxy,parent_h=n.wrap_python_object(parent,FACTORY)
try:
    # Rexx UNKNOWN calls Python, non-scalar result becomes a new AlchemyPythonObject.
    child_proxy=n.send0_handle(parent_proxy,"CHILDOBJ")
    child_h=int(n.send0_text(child_proxy,"FOREIGNHANDLE"))
    assert n.python_object_retain_count(child_h)==1
    # Drop all ordinary Python ownership.
    del child; del parent
    n.release_python_object(parent_h); gc.collect()
    assert wc() is not None
    assert n.send0_text(child_proxy,"PING")=="CHILD-ALIVE"
    # Rexx proxy can be released independently; Python foreign handle is still explicit ownership.
    n.release_handle(child_proxy); gc.collect()
    assert wc() is not None
    n.release_python_object(child_h); gc.collect()
    assert wc() is None
    print("returned-object-became-rexx-proxy:",True)
    print("survives-parent-release:",True)
    print("callable-through-rexx-proxy:",True)
    print("rexx-and-python-handles-independent:",True)
    print("collected-after-foreign-handle-release:",True)
    print("RETURNED FOREIGN PROXY LIFETIME TORTURE PASS")
finally:
    n.release_handle(parent_proxy)
