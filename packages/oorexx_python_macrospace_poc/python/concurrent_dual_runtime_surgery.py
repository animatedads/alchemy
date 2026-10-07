import os
from pathlib import Path
import threading
import time
import _rexxpython_poc as n

ROOT=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(ROOT/'rexx'),os.environ['ALCHEMY_OBJECTS_SRC'],os.environ['ALCHEMY_CRYPTO_SRC'],os.environ['OOREXX_PLATFORM_BIN']])
n.bootstrap_rexx_package_space(rp,str(ROOT/'rexx'/'animals.cls'))
FACTORY=str(ROOT/'rexx'/'factory.rex')
h=n.create_live_rexx_target(FACTORY)

class Robot:
    def pyfoo(self): return 'P1'

x=n.make_rexx_live_callable(h,'VALUE')
Robot.rexxfoo=x
r=Robot()
stop=threading.Event()
errors=[]
py_seen=[]
rexx_seen=[]
lock=threading.Lock()

py_impls=[]
for label in ('P1','P2','P3','P4'):
    def f(self, value=label): return value
    py_impls.append(f)


def python_writer():
    try:
        for i in range(1200):
            Robot.pyfoo=py_impls[i % len(py_impls)]
            if i % 23 == 0: time.sleep(0)
    except BaseException as e:
        errors.append(('python-writer',repr(e)))


def rexx_writer():
    try:
        for i in range(600):
            n.send0_attached(h, 'SETR2' if i & 1 else 'SETR3')
            if i % 17 == 0: time.sleep(0)
    except BaseException as e:
        errors.append(('rexx-writer',repr(e)))


def caller():
    try:
        while not stop.is_set():
            p=r.pyfoo()
            q=r.rexxfoo()
            with lock:
                py_seen.append(p); rexx_seen.append(q)
    except BaseException as e:
        errors.append(('caller',repr(e)))

callers=[threading.Thread(target=caller,name=f'caller-{i}') for i in range(3)]
for t in callers:t.start()
pw=threading.Thread(target=python_writer,name='python-writer')
rw=threading.Thread(target=rexx_writer,name='rexx-writer')
pw.start(); rw.start(); pw.join(); rw.join()
time.sleep(.05); stop.set()
for t in callers:t.join(5)
assert all(not t.is_alive() for t in callers), 'caller did not terminate'
assert not errors, errors
assert py_seen and rexx_seen
assert set(py_seen) <= {'P1','P2','P3','P4'}, set(py_seen)
assert set(rexx_seen) <= {'R1','R2','R3'}, set(rexx_seen)
assert Robot.rexxfoo is x

# Lifetime/revocation race: calls already pinned at revocation may complete with
# a real published Rexx value; calls starting after registry revocation fail.
race_stop=threading.Event(); race_values=[]; race_errors=[]
def revoke_caller():
    while not race_stop.is_set():
        try: race_values.append(r.rexxfoo())
        except RuntimeError as e:
            if 'revoked Rexx callable' not in str(e): race_errors.append(str(e))
            else: race_errors.append('REVOKED')

ts=[threading.Thread(target=revoke_caller,name=f'revoke-caller-{i}') for i in range(4)]
for t in ts:t.start()
time.sleep(.02)
n.revoke_rexx_handle(h)
time.sleep(.02); race_stop.set()
for t in ts:t.join(5)
assert all(not t.is_alive() for t in ts)
assert set(race_values) <= {'R1','R2','R3'}, set(race_values)
assert set(race_errors) <= {'REVOKED'}, set(race_errors)
try:
    r.rexxfoo()
    raise AssertionError('post-revocation call unexpectedly succeeded')
except RuntimeError as e:
    assert 'revoked Rexx callable' in str(e)

print('python-concurrent-results-authoritative-only: True')
print('rexx-concurrent-results-authoritative-only: True')
print('same-python-rexx-callable-identity-through-race: True')
print('revocation-race-no-use-after-free: True')
print('post-revocation-deterministic-failure: True')
print('CONCURRENT DUAL RUNTIME LIVE SURGERY PASS')
