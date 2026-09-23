# Wire3D architecture

## Authority
A `Wire3DScene` is an OO spatial model and projection state, not business authority. `semanticRef` points at the authoritative object/service/data source. `Wire3DObjectProjection~inspect` returns its target; future Component Projection adapters populate detached state without moving authority.

## Three equal domains
1. Systems visualisation: runtime, placement, storage, calls, boundaries and evidence.
2. Data visualisation: relations, clusters, histories, models and topology.
3. Marketplace/interaction: people, institutions, agents, services, products and transactions.

No special marketplace renderer is required: these are semantic objects and relationships in the same world.

## Corporate cyberpunk
A visual boundary represents a real boundary; traffic represents an observed relationship/event; institutional AI is presented as infrastructure or an actor with identity/authority/activity. No anthropomorphic assistant avatar is defined by the protocol.

## Mobile
Pointer/touch are renderer inputs translated into semantic interactions. Mobile is an acceptance target, not a reduced alternate protocol.
