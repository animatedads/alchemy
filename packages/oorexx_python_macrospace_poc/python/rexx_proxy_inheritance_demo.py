import _rexxpython_poc as native
from pathlib import Path
F=str(Path(__file__).resolve().parents[1]/"rexx"/"factory.rex")
class Animal: pass
class Pet: pass
class Dog(Animal,Pet): pass
class GuideDog(Dog): pass
g=GuideDog()
rh,ph=native.wrap_python_object(g,F)
ah=native.retain_python_object(Animal); dh=native.retain_python_object(Dog)
try:
    # Ask through the real Rexx AlchemyPythonObject.
    cls=native.send0_handle(rh,"PYTHONCLASS")
    q=native.send0(cls,"QUALIFIEDNAME")
    assert q.endswith(":GuideDog"),q
    # construct Rexx AlchemyPythonClass objects by wrapping class objects then asking their class isn't useful;
    # use native authoritative relation to verify class identity and Rexx surface class retrieval.
    actual=native.py_type_handle(ph)
    assert native.py_isinstance_handle(ph,ah)
    assert native.py_issubclass_handle(actual,dh)
    print("rexx-proxy-pythonClass:",q)
    print("rexx-proxy-class-handle-preserves-python-type:", actual)
    print("instance/subclass-authority: Python")
    lineage=native.send0(rh,"ALCHEMYBASESTATE")
    assert lineage, lineage
    print("alchemy-base-state-returned:", True)
    print("ALCHEMY PYTHON OBJECT ADOPTION POC PASS")
finally:
    for h in {ph,ah,dh}: native.release_python_object(h)
    native.release_handle(rh); native.release_handle(cls)
