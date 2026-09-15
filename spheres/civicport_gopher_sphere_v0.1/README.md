# CivicPort authoritative sphere v0.1

Authoritative LLM Gopher continuity for the CivicPort project and its JMS-to-AlchemyQueue ingress seam.

Current project head recorded here: `civicport_v0.14.zip`.

Start with:

    gopher --profile civicport context civicport --full

This sphere deliberately includes the side-by-side JMS bridge boundary because CivicPort's SWIM evidence contract depends on that handoff, while preserving the rule that CivicPort does not own JMS, Java/BSF/JNDI, provider credentials or Secret Broker leases.
