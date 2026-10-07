import _rexxpython_poc as native

class Animal: pass
class Pet: pass
class WorkingAnimal: pass
class Dog(Animal, Pet): pass
class GuideDog(Dog, WorkingAnimal): pass
class OtherAnimal: pass

g = GuideDog()
handles = {}
def retain(name, obj):
    h = native.retain_python_object(obj)
    handles[name] = h
    return h

try:
    gh=retain("g",g)
    animal=retain("Animal",Animal); dog=retain("Dog",Dog); guide=retain("GuideDog",GuideDog)
    pet=retain("Pet",Pet); working=retain("WorkingAnimal",WorkingAnimal); other=retain("OtherAnimal",OtherAnimal)

    actual=native.py_type_handle(gh); handles["actual"]=actual
    assert actual == guide, (actual, guide)  # registry preserves class identity
    assert native.py_isinstance_handle(gh, guide)
    assert native.py_isinstance_handle(gh, dog)
    assert native.py_isinstance_handle(gh, animal)
    assert native.py_isinstance_handle(gh, pet)
    assert native.py_isinstance_handle(gh, working)
    assert not native.py_isinstance_handle(gh, other)
    assert native.py_issubclass_handle(guide, dog)
    assert native.py_issubclass_handle(guide, animal)
    assert native.py_issubclass_handle(guide, pet)
    assert native.py_issubclass_handle(guide, working)
    assert not native.py_issubclass_handle(guide, other)

    info=native.py_class_info(guide)
    expected=[f"{c.__module__}.{c.__qualname__}" for c in GuideDog.__mro__]
    assert info["module"] == GuideDog.__module__
    assert info["qualname"] == GuideDog.__qualname__
    assert info["mro"] == expected
    print("actual-class-identity-preserved:", actual == guide)
    print("isinstance-Animal/Dog/Pet/Working:", True)
    print("unrelated-class-rejected:", True)
    print("mro:", " -> ".join(info["mro"]))
    print("PYTHON-AUTHORITATIVE INHERITANCE POC PASS")
finally:
    for h in set(handles.values()):
        native.release_python_object(h)
