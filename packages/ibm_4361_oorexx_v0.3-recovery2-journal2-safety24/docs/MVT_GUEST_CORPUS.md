# OS/360 MVT guest corpus policy

First target corpus: Jay Maynard's February 2003 OS/360 MVT turnkey distribution from CBT Tape.

The CBT Tape page describes it as a turnkey OS/360 MVT system configured for Hercules and notes that it includes a non-functional HASP III copy. Rick Fochtman's companion OS/360 collection is described as a complete gathered source collection with a genned minimal system and distribution libraries; the page records IBM-agent assurance to Rick concerning free distribution and asks for appropriate attribution on reuse.

For this project the media is an **external historical corpus**:

- never bundled in the emulator ZIP;
- identified by source/provenance plus SHA-256/SHA-512 digest when imported;
- mounted by reference;
- checkpoint resume must fail if referenced mutable media no longer matches its frozen identity;
- Hercules configuration files may be parsed as configuration evidence for device numbers/types but do not become runtime authority.

Likely useful corpus material includes DASD/tape images, Hercules configuration, JCL, source, utilities and card-deck files. Small card decks are particularly valuable as deterministic differential/replay workloads.
