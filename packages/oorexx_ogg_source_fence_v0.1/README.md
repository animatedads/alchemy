# Local Ogg source identity fence v0.1

Architecture: Tom Dyer. Coding: ChatGPT GPT-6.

A small POSIX C source-identity guard used *inside* an ooRexx-owned Foreign Runtime Ogg decoder. It samples device, inode, mode, extent, nanosecond mtime and nanosecond ctime from a read-only, nonempty regular file descriptor before a bounded seek. It refuses acceptance if the descriptor's source metadata differs at the end of a catalogue or decode request. The source remains local and no subprocess media DSP is used.

This is **not cryptographic source identity**: content changes that are not reflected in metadata, or changes that revert before the final check, can evade this guard. Durable Storage Fabric digest/immutable source version must be checked separately when accepting original-source evidence.

Run `sh tests/run_source_fence.sh`. It checks unchanged FD, changed source extent, independent inode with same contents, missing FD and zero-length file. This supports the SPASH Challenger Ogg provider in draft PR135. It neither qualifies Vorbis seek sample accuracy nor 1 GiB read locality, chained tracks or audio enhancement.

The integration contract is for a **new immutable publication path** `packages/oorexx_ogg_source_fence_v0.1`, not an overwrite of the existing SPASH Challenger v0.1-dev1 package. Tests are run by Autobuilder on accepted main; only a PASS receipt qualifies publication.
