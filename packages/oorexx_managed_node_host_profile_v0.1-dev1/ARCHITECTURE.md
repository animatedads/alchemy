# Architecture

The previous Remote Host v0.2-dev1 combined useful node-profile concepts with a second queued worker contract. The uploaded Oracle Managed Node increment now owns the stronger execution contract (Work Bundle, exact task authorisation, durable dispatch, attempt fencing and result semantics), so this package retains only the non-overlapping profile/bootstrap portion.

Durable vs transient state is explicit:

- identity: nodeId/providerResourceId/provider/topology/cost class;
- capability generation: installed hardware, declared runtimes, task kinds, queue-ready state, runtime generation;
- capacity observation generation: free memory/disk/CPU, WLU/s, queue depth and active jobs, with observation expiry.

Terminal owns concrete SSH/PTY/automation and credentials. This package exposes an abstract bootstrap port only.
