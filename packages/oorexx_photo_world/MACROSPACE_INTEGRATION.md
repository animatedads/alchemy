# Macrospace integration — dev17

## Exact bridge

Photo Survey World dev17 qualifies against `oorexx_python_macrospace_poc_v0.31.6.zip` with SHA-256 `38175f11db8e7e7de28a37e4012c92a94109b4fbcfec7fb96ee166b4d4644c6b`. The archive is a sealed-delivery snapshot only; the Python Macrospace project remains source authority.

## Ownership boundary

- Photo Survey World owns survey semantics, evidence promotion and world-hypothesis decisions.
- ooRexx Maths v0.14 owns matrices, vectors, precision/provider semantics and higher mathematics.
- Python Macrospace owns live Python/Rexx object projection, class loading, dispatch, argument framing and cross-runtime identity/lifetime.
- Depth Anything / GeoCLIP / PyMeshLab remain specialised providers. Their output is derived evidence, not world authority.

## dev17 executable crossing

The Photo World provider regression constructs one resident Python `PhotoWorldProviderProbe`, proves arbitrary-arity constructor / instance / classmethod framing, and preserves state across two depth calls. It then passes an actual Maths `MathMatrix` to Python as a retained ooRexx object. Python evaluates:

```python
matrix.rows()
matrix.cols()
matrix.at(1, 2)
matrix.context().provider()
```

The last expression exercises the v0.31.6 live non-string Rexx-return projection and chained natural dispatch. The expected contract string is `2x3:2:PURE`. No depth matrix is copied into a Python-owned tensor merely to cross the boundary.

This is the intended shape for future specialised providers: Python may operate an explicitly supplied Maths object, while reusable numerical meaning and higher mathematics remain Maths-owned.
