# ooRexx Physical Manufacturing v0.1-dev2

Physical machine/process modelling above ooRexx Physics World. Commands are demands on finite physical actuators; commanded coordinates never teleport machine components.

Dev2 adds the first Common Parts integration boundary. `MachinePartProjection` retains the authoritative `PartDefinition` while adding experiment-specific mass, dimensions and machine role. `MachinePartFactory~movingAxisExperiment` constructs a finite-force moving assembly from projected parts, so changing the manufactured payload changes actual motion under an identical command.

Common Parts remains catalogue authority. Physics World remains physics authority. Physical Manufacturing owns the process/machine interpretation connecting them.
