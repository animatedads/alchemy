# ooRexx PCB Planner v0.1-dev4

PCB Planner is a separate package from Rexx-tronics. Rexx-tronics remains electrical authority; PCB Planner owns board planning objects and consumes external part, material, physics and manufacturing authorities.

## dev4: native Intention Service dev11 discovery

Dev4 removes the dev3 application-owned capability catalogue/rebuilt-service pattern. A `PCBIntentionDiscovery` is registered with Intention Service dev11 and returns an `IntentionDiscoverySnapshot` on each fresh proposal cycle.

The snapshot carries current board evidence and discovery-scoped `IntentionSurfaceAdvertisement` objects. The board surface is always present for a retained board. The routing surface exists only while manufacturing rules and routable endpoints are observed. The routing-verification surface exists only when copper is present.

This means capability lifetime follows the actual PCB object graph. Stale discovery evidence is replaced atomically by Intention Service; PCB Planner does not cache a second truth.

The surface providers propose meaning only. Internal registrations retain the executable PCB event objects, and Intention Service still owns selection and READY dispatch. The board, circuit, manufacturing-rules and electrical-net objects remain ooRexx objects throughout the path.

## Authority boundaries

- Rexx-tronics: circuit, component, pin, electrical-net truth.
- PCB Planner: footprints/pads, pin-pad bindings, placement, board/layer geometry, copper graph, candidate routing and PCB verification.
- Intention Service dev11: discovery freshness, transient intention surfaces, evidence generations, meaning/decision state and dispatch gate.
- Physical Manufacturing: fabrication/process capability; PCB Planner only consumes a source-attributed projection today.
- Common Parts, Materials and Physics World: peer authorities to be bound by subsequent adapters, not duplicated here.

## Qualification

Direct package test (already-extracted dependencies):

```sh
REXX_BIN=/path/to/rexx \
REXXTRONICS_ROOT=/path/to/rexxtronics \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev11 \
  ./run_tests.sh
```

Complete environment qualification from distributable archives:

```sh
OOREXX_DEB=/path/to/oorexx-5.3.0-13196.deb \
REXXTRONICS_ZIP=/path/to/rexxtronics.zip \
INTENTION_SERVICE_ZIP=/path/to/oorexx_intention_service_v0.1-dev11.zip \
  ./tools/run_environment_test.sh
```
