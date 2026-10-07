import os
from pathlib import Path
import _rexxpython_poc as n
ROOT=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(ROOT/'rexx'),os.environ['ALCHEMY_OBJECTS_SRC'],os.environ['ALCHEMY_CRYPTO_SRC'],os.environ['OOREXX_PLATFORM_BIN']])
n.bootstrap_rexx_package_space(rp,str(ROOT/'rexx'/'animals.cls'))
FACTORY=str(ROOT/'rexx'/'foreign_factory.rex')
class Robot:
    def foo(self): return 'P1'
a=Robot(); b=Robot()
pa,ha=n.wrap_python_object(a,FACTORY); pb,hb=n.wrap_python_object(b,FACTORY)
try:
    assert n.send0_text(pa,'FOO')=='P1'
    assert n.send0_text(pb,'FOO')=='P1'
    tmp=n.send0_handle(pa,'INSTALLREXXFOOR1'); n.release_handle(tmp)
    assert n.send0_text(pa,'FOO')=='R1'
    assert n.send0_text(pa,'EXPLICITPYTHONFOO')=='P1'
    assert n.send0_text(pb,'FOO')=='P1'
    def p2(self): return 'P2'
    Robot.foo=p2
    assert n.send0_text(pa,'FOO')=='R1'
    assert n.send0_text(pa,'EXPLICITPYTHONFOO')=='P2'
    assert n.send0_text(pb,'FOO')=='P2'
    c=Robot(); pc,hc=n.wrap_python_object(c,FACTORY)
    try:
        assert n.send0_text(pc,'FOO')=='P2'
        tmp=n.send0_handle(pa,'INSTALLREXXFOOR2'); n.release_handle(tmp)
        assert n.send0_text(pa,'FOO')=='R2'
        assert n.send0_text(pa,'EXPLICITPYTHONFOO')=='P2'
        tmp=n.send0_handle(pa,'REMOVEREXXFOO'); n.release_handle(tmp)
        assert n.send0_text(pa,'FOO')=='P2'
        assert n.send0_text(pb,'FOO')=='P2' and n.send0_text(pc,'FOO')=='P2'
        del Robot.foo
        for h in (pa,pb,pc):
            assert n.send0_text(h,'FOO') == 'PYTHON_OBJECT_ERROR'
        print('python-class-P1-visible-through-existing-proxies: True')
        print('rexx-object-layer-R1-shadows-python-P1: True')
        print('python-P2-mutates-under-live-rexx-layer: True')
        print('future-instance-sees-P2: True')
        print('rexx-R2-replaces-only-rexx-layer: True')
        print('remove-rexx-layer-reveals-current-python-P2: True')
        print('python-delete-immediately-visible: True')
        print('DUAL RUNTIME LIVE METHOD SURGERY PASS')
    finally:
        n.release_handle(pc); n.release_python_object(hc)
finally:
    n.release_handle(pa); n.release_handle(pb); n.release_python_object(ha); n.release_python_object(hb)
