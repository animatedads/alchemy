# Semantic Source Control Gopher Sphere v0.1-dev2

This sphere teaches an LLM how to use LLM Gopher around ooRexx Semantic Source Control.

Core rule: **Gopher is the bounded operational interface; SSC is the historical/semantic authority.**

The sphere deliberately does not fake executable SSC capabilities. `ssc.interface` records the planned bounded adapter surface until Gopher installs a dedicated implementation.

## dev2: the store write authority exists

The Semantic Source Store (`packages/oorexx_semantic_source_store`) now has the component its design always required and never had: a write authority. Read `ssc.store-authority` before importing or accepting, `ssc.backend-constraints` before touching the database, and `ssc.mcp-operations` before wiring a transport.

Evidence is LOCAL_PASS (ooRexx 5.3.0 r13196, NoSQLServer v0.79, Crypto v0.8.3 with Foreign Runtime v0.22.6). No MCP host is wired yet, so live MCP SSC state is UNKNOWN.
