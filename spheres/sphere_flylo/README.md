# FlyLo airline platform

Use `gopher --profile flylo context flylo` after installing/loading this sphere.

## Current continuity

The sphere covers three connected FlyLo lines:

- the durable ooRexx/Wire UI airline application baseline (`flylo_v0.4.11.zip`);
- the MVS 3.8J/TK5 airline-backend validation stream, including ED209ZZ clean-room bring-up;
- the own-platform access boundary: project-owned LDAP Identity for authenticated identity and project-owned ooRexx HTTPS Server for TLS termination.

The MVS stream validates airline semantics independently of the browser. Presentation, language, LDAP and HTTPS layers do not own airline business truth.

Current LDAP/HTTPS/Terminal candidates are pinned by exact artifact digest and remain fail-closed until their recorded live/runtime gates pass.
