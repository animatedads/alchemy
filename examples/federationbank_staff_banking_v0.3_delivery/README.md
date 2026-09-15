# FederationBank Staff Banking v0.3 delivery

This is the full replacement continuation delivery after the recovered/sealed v0.2 staff-banking baseline.

v0.3 keeps the accepted Staff Authority, Staff Authority Service, Intermediary Staff Authority and Staff Channel packages unchanged, requalifies them against `oorexxapis(20260828-191958).zip`, and adds **FederationBank Staff Method Permissions v0.1**.

The new component pairs Staff Banking with the generic ooRexx Access Permissions/Security Manager layer while preserving authority separation:

- Authentication provides attribution/integrity evidence; it grants no authority.
- Access Control is coarse domain-entry authority ("enter the building").
- Method Permission controls an exact technical principal × exact Alchemy object × exact method under Security Effect.
- Staff Authority controls the represented banking action.
- Core Banking remains final execution authority for applicable core monetary commands.

`packages/` contains the complete Staff Banking component set. `qualified_dependencies/` carries the exact Access Permissions v0.1 package used for this new boundary; it remains independently versioned and is included only to make the qualification closure reproducible.
