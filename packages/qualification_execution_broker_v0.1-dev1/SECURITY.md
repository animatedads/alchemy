# Security invariants

1. Private authorization keys are local-workstation material only.
2. Server, MCP, ChatGPT/Claude/Grok and ed209XX may possess only public verification keys.
3. No authorization challenge is produced until preflight has passed.
4. The human signs a domain-separated SHA-256 of the complete frozen intent.
5. Artifact, authorised-data manifest, runtime, sandbox, test plan, commands, target and resource limits are all hash-bound.
6. Material drift after signing fails closed as `INTENT_STALE`.
7. Authorization is one-run and one-use; worker start consumes the authorized state.
8. LLMs cannot provide arbitrary commands or server paths; test commands come from an operator-controlled test-plan identity.
9. There is no MCP execute tool. Execution transition is worker authority only.
10. Journal replay preserves grants/results without creating signing authority.
