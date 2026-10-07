import abc, _rexxpython_poc as n

class AbstractAnimal(metaclass=abc.ABCMeta): pass
class Concrete: pass
AbstractAnimal.register(Concrete)

class Meta(type): pass
class MetaAnimal(metaclass=Meta): pass

def make_local():
    class SameName: pass
    return SameName
A=make_local(); B=make_local()
Dynamic=type("DynamicAnimal",(MetaAnimal,),{})

objs=[Concrete(),Dynamic(),A(),B()]
handles=[n.retain_python_object(x) for x in objs]
classes=[AbstractAnimal,Concrete,MetaAnimal,Dynamic,A,B]
ch={c:n.retain_python_object(c) for c in classes}
extra=[]
try:
    # ABC virtual relationship is authoritative despite absence from concrete MRO.
    assert n.py_isinstance_handle(handles[0],ch[AbstractAnimal])
    assert n.py_issubclass_handle(ch[Concrete],ch[AbstractAnimal])
    info=n.py_class_info(ch[Concrete])
    assert not any(x.endswith(".AbstractAnimal") for x in info["mro"])
    print("abc-virtual-subclass-authoritative: True")

    # Metaclass + dynamic class.
    assert n.py_isinstance_handle(handles[1],ch[MetaAnimal])
    assert n.py_issubclass_handle(ch[Dynamic],ch[MetaAnimal])
    bases=n.py_direct_base_handles(ch[Dynamic]); extra += bases
    assert len(bases)==1 and n.py_class_info(bases[0])["qualname"]=="MetaAnimal"
    print("metaclass-dynamic-class: True")
    print("direct-bases-authoritative: True")

    # Same module + qualname is still not class identity.
    ia=n.py_class_info(ch[A]); ib=n.py_class_info(ch[B])
    assert ia["module"]==ib["module"] and ia["qualname"]==ib["qualname"]
    assert ch[A] != ch[B]
    assert not n.py_isinstance_handle(handles[2],ch[B])
    assert not n.py_isinstance_handle(handles[3],ch[A])
    print("same-name-distinct-class-identity: True")

    print("PYTHON TYPE AUTHORITY TORTURE PASS")
finally:
    for h in set(handles+list(ch.values())+extra):
        n.release_python_object(h)
