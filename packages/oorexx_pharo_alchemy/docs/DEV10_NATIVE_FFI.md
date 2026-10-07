# dev10 native FFI crossing

This cut executes a genuine in-process native crossing from the supplied Pharo
12 image through Pharo FFI into a shared library built from the Alchemy native
lifecycle core. The exported qualification entry point publishes a generation-
tagged receiver, calls `pa_dispatch_pinned`, preserves call correlation, and
returns the dispatch result to Pharo. Input 41 returns 42.

This is stronger than dev9's Pharo-only semantic probe and stronger than dev8's
C-only adapter test. It proves the supplied Pharo runtime and our compiled
Alchemy native core can participate in the same process.

Scope remains honest: the exported function is a qualification entry point,
not yet the final generic oop/selector marshaller. ooRexx -> Pharo -> ooRexx
same-activation re-entry is still NOT RUN.
