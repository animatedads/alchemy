# API v0.1-dev2

Retains dev1: `AxisServo`, `MachineMotionSample`, `MachineAxisExperiment`, `CartesianMachineRig`.

## Common Parts projection

`MachinePartProjection~new(definition,instanceId,mass,sizeX,sizeY,sizeZ,role='PAYLOAD')`

Read-only: `definition`, `instanceId`, `mass`, `sizeX`, `sizeY`, `sizeZ`, `role`, `partId`, `family`.

`MachinePartFactory~project(...)` creates the manufacturing projection while retaining the exact catalogue definition object.

`MachinePartFactory~movingAxisExperiment(carriagePart,payloadParts,kp=800,kd=45,maxForce=80)` sums physical projected masses and builds the finite-force X-axis experiment. Catalogue identity is not copied or redefined.
