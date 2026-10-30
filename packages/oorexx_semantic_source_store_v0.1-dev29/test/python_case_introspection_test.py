import importlib.util, json, pathlib, sys
p=pathlib.Path(__file__).parents[1]/'tools'/'python_runtime_introspector.py'
spec=importlib.util.spec_from_file_location('ssi', p); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
class Base:
    def speak(self): pass
    def Speak(self): pass
class Child(Base):
    def speak(self): pass
    def SPEAK(self): pass
r=m.inspect_class(Child)
rows=r['method_surface']
assert any(x['name']=='speak' and x['origin_class']=='Child' and x['relation_kind']=='OVERRIDES' for x in rows)
assert any(x['name']=='Speak' and x['origin_class']=='Base' and x['is_effective']==1 for x in rows)
assert any(x['name']=='SPEAK' and x['origin_class']=='Child' and x['is_effective']==1 for x in rows)
assert all(x['lookup_key']==x['name'] for x in rows)
print('PYTHON CASE INTROSPECTION TEST: PASS')
