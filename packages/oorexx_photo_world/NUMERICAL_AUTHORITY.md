# Numerical authority — Photo Survey World dev17

Photo Survey World does not create a second tensor, array or matrix model for foreign providers.

The authority split is:

1. **Photo Survey World** owns cameras, observations, evidence semantics, constraints, provenance and promotion into `SurveyWorld`.
2. **ooRexx Maths v0.14** owns reusable numerical values and mathematics. Dense depth is represented by `MathMatrix`; embeddings by `MathVector`; mesh vertex/face/normal material is carried in Maths matrices. A Maths value may itself retain an accelerated backend according to the Maths provider contract.
3. **Python Macrospace** owns projected Python/Rexx live-object invocation. v0.31.6 retains arbitrary-arity framed calls and adds live retained ooRexx object arguments, natural Python dispatch back into those objects, positional arguments, and live non-string Rexx return projection.
4. **Specialist Python libraries** such as Depth Anything V2, GeoCLIP and PyMeshLab are optional derived-compute providers. They do not mutate `SurveyWorld` and do not become the numerical authority merely because they execute in Python.

`SurveyDepthField` therefore contains a Maths `MathMatrix`; `SurveyMeshCandidate` contains Maths matrices. The Python adapters deliberately mark their immediate results `*_RAW`. Promotion from raw foreign output into `SurveyDepthEvidence` / `SurveyMeshEvidence` is explicit and requires Maths-owned numerical material.

Maths v0.14 already records optional resident NumPy acceleration through Foreign Runtime, including retained backend values, and its dependency qualification records NumPy reverse import, zero-copy and DLPack tensor prerequisites. Photo Survey World consumes that Maths contract rather than defining `PythonTensor`, `PythonArray` or `PythonBuffer` classes of its own.

## dev17 live Maths objects in Python

Macrospace v0.31.6 can project an arbitrary retained ooRexx object into Python and naturally dispatch methods on it. Photo World uses that capability to pass a real `MathMatrix` rather than inventing a Python tensor authority. The regression calls matrix shape/index operations and chains through the returned `MathContext` to its provider. Crossing the language boundary does not transfer mathematical ownership away from Maths.
