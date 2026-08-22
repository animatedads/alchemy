# Shannon Reputation Dependency Probe

Artifact-only Alchemy Autobuild probe for the observed Shannon acceptance failure where the reputation gate reports `reputation.effect/0.1` immediately before `test_shannon_reputation_communication.rex` attempts to construct the v0.2-only `ReputationCommunicationFailure` class.

The probe does not modify the Shannon working tree. It records the real harness references, relevant test source, locally visible reputation package candidates, and API strings from visible `ReputationEffect.cls` files. It passes only when it confirms the specific mixed-version contract that motivated the probe.
