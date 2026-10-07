# XTP dev11: multipath data plane

`libxtp` now consumes the ordered route set rather than exposing it only for inspection.

A logical transfer is divided into XMP1 chunks.  Chunks are assigned round-robin across the selected XTP paths.  Each chunk carries transfer identity, path-generation value, chunk index/count and logical length before the route's normal wire-filter chain and XTP packet framing are applied.

If an assigned path fails, that path is marked dead for the remainder of the transfer and the same XMP1 chunk is sent over the next surviving path.  The receiver reassembles by transfer/generation/chunk identity, so path failure is invisible above the XTP socket layer.

This increment deliberately implements transfer-local failure fencing.  Requalification of a failed physical path for later transfers and persistent path-generation management remain a separate control-plane operation; a path is not automatically reintroduced during the transfer that declared it failed.

The ooRexx native binding exposes explicit multipath sender/listener hooks while retaining full Rexx `SocketAddress` objects.  Carrier selection and failover remain inside `libxtp`.
