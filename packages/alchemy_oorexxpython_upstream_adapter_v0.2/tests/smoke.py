from alchemy_oorexx_adapter import evaluate, execute_routine
assert evaluate('6 * 7') == 42
assert execute_routine('use arg a, b; return a * b', 6, 7) == 42
print('ALCHEMY-UPSTREAM-PYTHON-PASS')
