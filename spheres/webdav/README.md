# ooRexx WebDAV engineering sphere v0.1

Grounded baseline:
- ooRexx WebDAV Gateway v0.1-dev5
- canonical source `packages/oorexx_webdav`
- delivery `oorexx_webdav_v0.1-dev5.zip`
- SHA-256 `5ec140808cb95d1fbe2c6f99c2abf0f14d7f59f06fd387a490538da8aef83f2d`
- qualification: 14/14 local tests PASS under ooRexx 5.3.0 r13196

This sphere records WebDAV protocol authority and continuation knowledge. It
does not replace HTTPS Server, Storage Fabric, Queue Fabric or Hercules media
authority.

Start:

    gopher --profile webdav context webdav --full
    gopher --profile webdav search '<term>' --sphere webdav
