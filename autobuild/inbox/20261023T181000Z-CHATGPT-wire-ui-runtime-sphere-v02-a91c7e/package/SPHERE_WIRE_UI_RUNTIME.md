# Wire UI Runtime Sphere

This sphere exists so a new implementation session can recover the architectural decisions that are easy to lose when looking only at individual packages.

## Authority map

```text
ooRexx application / Wire UI Server
        authoritative state, journey, revisions, actions
                |
                | Queue Fabric
                v
Queue Fabric Web Gateway
        fixed access-point queues, transport trust boundary
                |
                | WebSocket
                v
Logical Comms
        subscriptions + ordered direct queue
                |
                v
Browser Wire UI runtime
        exact definitions, caches, precompiled renderer
                |
                +---- Resource Resolver ----> external Resource Authority
                |
                v
DOM / presentation state
```

`wire-ui-swing` is a sibling renderer of the same semantic protocol.

## Remember the two separations

1. `subscription` is authorised wiring; `direct queue` is actual communication.
2. `render profile` is renderer capability/display selection; `interaction profile` is semantic projection such as HUMAN_VISUAL or AI_AGENT_OPTIMISED.

## Customer-facing resource rule

No interface description/copy authoring in Builder/runtime. A backend assessment/presentation decision selects an exact approved ResourceRef. The Resource Authority owns the approved content and representations; the resolver verifies and supplies one approved representation.

## Network rule

On GPRS, remove round trips before inventing semantic compromises. One immutable prelinked/gzip runtime + cached exact definitions/resources + fresh snapshot/deltas is the target.