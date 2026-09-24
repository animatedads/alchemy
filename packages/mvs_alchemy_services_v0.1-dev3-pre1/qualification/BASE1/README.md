# BASE-1 live qualification gate

This directory is intentionally evidence-free in dev3-pre1.

BASE-1 passes only when the supplied MVS 3.8j TK5 executes S/370 MASIVP1 through the real Hercules DYN75 facility, negotiates `mvs.alchemy/1` with the real ooRexx MAS endpoint, completes PING, proves exact 00-FF binary integrity, disconnects normally, and ends CC 0000.

Required evidence for a qualified build: `tk5_environment.txt`, `dyn75_interface.txt`, `masivp1.jes.txt`, `host_reference.log`, `host_oorexx.log`, `frame_capture.txt`, and `qualification.txt`.
