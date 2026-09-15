# Alchemy Inbox v0.2

Git submission discovery for the resident ooRexx Autobuild service.

The inbox acquires the shared repository lease while fetching and inventorying
remote refs so branch/main discovery is based on one stable local ref view.  It
releases the lease before any candidate is executed.

Inherited ready markers, existing receipts, identical duplicate submissions and
same-ID/different-tree conflicts retain the v0.1 semantics.
