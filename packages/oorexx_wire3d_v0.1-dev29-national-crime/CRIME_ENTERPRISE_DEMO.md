# CrimeEnterprise spatial application demo

This is a consumer of Wire3D, not part of Wire3D's domain model.

`examples/crime_enterprise_space.rex` instantiates the supplied `CrimeEnterprise.cls` model and projects seven fictional SUBJECT records into the same Wire3D scene. The supplied photographs are demonstration resources only and are deliberately associated with unassigned SUBJECT identifiers; the demo makes no identity or criminal allegation from an image.

Interaction grammar:

- select a person -> expand the person card;
- card shows headshot, domain details, authority and map context;
- relationship buttons navigate to the actual related projected Person;
- media opens in-place without discarding spatial context;
- relationship lines are derived from real `Relationship` objects in the fixture;
- MAP CONTEXT opens the declared OpenStreetMap context at 55.82331,-4.43032;
- the deterministic projector tracking field remains enabled underneath the application.

The package-local copy of `CrimeEnterprise.cls` changes its superclass-qualified constructor calls from named scope notation to `:super` so it executes under the supplied ooRexx 5.3.0 r13196 runtime. No domain semantics are changed by that compatibility repair.
