"""Alchemy facade for upstream oorexx.Interpreter."""
from contextlib import contextmanager

@contextmanager
def interpreter():
    import oorexx
    with oorexx.Interpreter() as runtime:
        yield runtime

def evaluate(expression):
    with interpreter() as runtime:
        return runtime.eval(expression)

def execute_routine(source, *args):
    with interpreter() as runtime:
        return runtime.routine(source)(*args)
