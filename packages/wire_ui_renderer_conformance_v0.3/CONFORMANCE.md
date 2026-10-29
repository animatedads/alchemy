# Wire UI cross-renderer semantic conformance v0.3

Application truth remains outside renderers. Web, Swing, GTK/Direct Linux and Android may differ in native toolkit and presentation, but must preserve the same semantic contract.

Required gates:

1. exact definition identity/content address;
2. exact published ResourceRef, with no renderer-authored URL/copy;
3. authoritative revision ordering;
4. event-time `renderedRevision`;
5. stable collection identity, never row ordinal;
6. bounded `RangeRequested(start,count)` demand;
7. exact opaque server `workspaceContext` for workspace-bound actions;
8. semantic activation;
9. positive-list observation subscription;
10. fail-closed committed-definition deauthorisation/resync.

v0.3 records real renderer-head evidence. Partial gate satisfaction is useful engineering progress but is not renderer conformance.
