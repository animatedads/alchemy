# pre8 durable/path-session increment

Implemented:

- durable host-backed MAS Storage Fabric object-store binding;
- immutable object files with restart journal and namespace reconstruction;
- transport-neutral PATH session dispatcher (OPEN/READ/WRITE/APPEND/CLOSE/STAT/LIST);
- independent Hercules AWSTAPE parser;
- non-mutating Hercules tape attach plan generator.

Qualification in the package-build environment:

- Python durable semantic reference: RUN/PASS.
- Existing pre7 AWS image independent parse: RUN/PASS.
- ZIP integrity and manifest: RUN/PASS.
- New ooRexx durable test: NOT_RUN in the package-build container because an
  ooRexx executable is not installed there. It is included for ED209C, where
  ooRexx 5.3.0 r13196 has already been observed in the live setup work.
- Live MVS PATH interception: NOT_RUN / NOT IMPLEMENTED.
- Hercules DEVINIT of generated tape: NOT_RUN.
- MVS tape read-back: NOT_RUN.
