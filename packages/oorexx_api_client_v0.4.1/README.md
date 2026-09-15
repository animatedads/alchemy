# ooRexx API Client v0.4.1

v0.4 extends the v0.3 native HTTPS transport with governed redirects and negotiated HTTP/2 while preserving the provider-neutral routing/session/WLU/callback core.

Redirect following is disabled by default for v0.3 compatibility. When enabled, 301/302/303/307/308 are handled in the transport rather than provider adapters. Relative `Location` values are resolved against the current URL. Redirect loops and redirect-count overflow fail closed. HTTPS-to-HTTP downgrade and cross-origin redirects are denied by default. 303 changes non-HEAD requests to GET; 307/308 preserve method and body. 301/302 preserve POST by default; `legacyPostRedirectToGet` must be explicitly enabled for historical behaviour. Credential-bearing Authorization, Proxy-Authorization and Cookie headers are stripped if cross-origin redirects are explicitly enabled.

HTTP version policy is `HTTP1_ONLY`, `NEGOTIATE`, or `HTTP2_REQUIRED`. TLS ALPN offers h2 and http/1.1 when HTTP/2 is enabled. HTTP/2 framing and HPACK are delegated to libnghttp2 through Foreign Runtime v0.22.6; API Client does not contain a hand-written HPACK implementation. TLS identity/hostname verification remains OpenSSL through the existing Foreign Runtime memory-BIO path, and socket ownership remains RxSock.

`ApiResponse` exposes `httpVersion`, `finalUrl`, and `redirectCount` so callers can qualify protocol and redirect behaviour explicitly.

`native/build.sh` builds `bridge/liboorexx_api_h2.so` and requires libnghttp2, OpenSSL and a C compiler. The packaged shared object is a Linux x86-64 build artifact for the current construction environment; rebuild it on the target ABI rather than treating it as portable.

The native bridge has been strict-compiled and directly checked to emit the HTTP/2 client connection preface/SETTINGS. The packaged ooRexx tests include real TLS ALPN + python-h2 server coverage for HTTP/2, response handling, redirect following, redirect-loop rejection and cross-origin rejection. They require the ooRexx r13196 qualification environment plus Foreign Runtime v0.22.6; this container has no `rexx` executable, so those ooRexx tests are included but are not claimed as executed here.
