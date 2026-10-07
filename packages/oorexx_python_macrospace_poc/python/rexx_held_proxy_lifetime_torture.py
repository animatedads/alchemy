import os,gc,weakref
from pathlib import Path
import _rexxpython_poc as n
ROOT=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(ROOT/"rexx"),os.environ["ALCHEMY_OBJECTS_SRC"],os.environ["ALCHEMY_CRYPTO_SRC"],os.environ["OOREXX_PLATFORM_BIN"]])
n.bootstrap_rexx_package_space(rp,str(ROOT/"rexx"/"animals.cls"))
FACTORY=str(ROOT/"rexx"/"foreign_factory.rex")
class Target:
    def ping(self): return "REXX-HELD-PYTHON-ALIVE"
obj=Target(); w=weakref.ref(obj)
proxy,ph=n.wrap_python_object(obj,FACTORY)
collection=n.create_object_collection(FACTORY)
try:
    assert int(n.send1_handle(collection,"ADD",proxy))==1
    # Collection now owns a Rexx reference to the proxy; native global reference is unnecessary.
    n.release_handle(proxy)
    del obj; gc.collect()
    assert w() is not None
    held=n.send1_index_handle(collection,"AT",1)
    try:
        assert n.send0_text(held,"PING")=="REXX-HELD-PYTHON-ALIVE"
        assert int(n.send0_text(held,"FOREIGNHANDLE"))==ph
    finally:
        n.release_handle(held)
    # Removing the collection's native root does not release explicit Python foreign ownership.
    n.release_handle(collection); collection=None; gc.collect()
    assert w() is not None
    n.release_python_object(ph); gc.collect()
    assert w() is None
    print("rexx-collection-retains-proxy:",True)
    print("native-proxy-root-can-be-released:",True)
    print("python-call-through-rexx-held-proxy:",True)
    print("foreign-identity-preserved:",True)
    print("python-foreign-ownership-independent:",True)
    print("REXX-HELD FOREIGN PROXY LIFETIME TORTURE PASS")
finally:
    if collection is not None: n.release_handle(collection)
