# Second-order input/output systems — ooRexx Maths v0.15

v0.15 extends the generic constant-coefficient second-order dynamics model from

`M*x'' + C*x' + K*x = f(t)`

to a selected-channel form

`M*x'' + C*x' + K*x = B*u(t)`

`y(t) = Hx*x(t) + Hv*x'(t)`

without assigning any physical meaning to the input or output channels.

The caller owns `B`, `Hx`, and `Hv`.  A Physics consumer may use them for
pressure-to-generalized-force distribution and pickup/modal observation; a
controls, structural, acoustic or vibration consumer can use the same object
for entirely different meanings.

```rexx
base=.Maths~secondOrderSystem(M,C,K,ctx)
io=.Maths~secondOrderInputOutputSystem(base,B,Hx,Hv,ctx)
result=io~integrateProjected(x0,v0,dt,steps,inputHistory,0,'SYMPLECTIC_EULER')

selected=result~outputs
final=result~finalState
```

The `SCIPY` provider performs `B*u`, the second-order integration, and the
selected `Hx/Hv` projection in NumPy/SciPy.  It returns the selected channels
plus the full final state rather than requiring the caller to materialise the
entire DOF trajectory merely to observe a small number of linear channels.

For the current Foreign Runtime list-marshalling boundary, independently
reprojecting an already-materialised binary64 trajectory in ooRexx can differ
from the native selected output by roughly 1e-10 in the focused qualification.
The v0.15 native test therefore uses an explicit 2e-10 selected-output migration
tolerance; final mechanical state comparisons retain the existing tighter
state tolerances.
