# Provider Implementation Execution Profile

A methodology describes **what the method means**.  An implementation profile describes **what one executable provider needs**.

`MediaImplementationExecutionProfile` may declare hard requirements that are safe to project into Job-to-Node:

- implementation/package identity;
- methodology ID implemented;
- runtime;
- required abilities;
- required tags;
- architecture;
- installed/free memory and disk minima;
- installed/available CPU minima;
- minimum WLU rate and expected total WLU;
- deterministic/probabilistic declaration;
- recovery class.

These values must come from the implementation/provider's qualification envelope.  The methodology catalogue must not invent them.

For example, one implementation of leading-edge blur backprojection might require only ooRexx + a CPU FFmpeg provider.  Another might require a CUDA optical-flow provider.  They share the same methodology ID but have distinct implementation IDs and distinct execution profiles.

Provider profiles should be versioned with their implementation and retained in execution provenance.
