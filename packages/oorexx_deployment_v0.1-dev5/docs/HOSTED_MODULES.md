# Hosted-module deployment contract

MCP, Wire browser/access-point modules and future HTTPS-hosted components use one deployment lifecycle. The core does not know MCP or Wire semantics; an application package supplies an adapter declaration and host-specific probe.

A hosted module is only successful after **staged -> package-loadable -> composed -> activated -> live-probed**. Copying files, `rexxc` success, or a unit test against a fake host is not live deployment evidence.

For ooRexx HTTPS Server v0.4.4, `HttpsServer~route` refuses mutation after the listener has started. Consequently the current activation strategy is `compose-before-start`: stage the module, prove it loads against the real HTTPS package, bind it into the next host composition, start/replace that host generation, and only then probe the real endpoint. Deployment must never report a module as live when it is merely staged beside an already-running server.

The package boundary is also part of deployment correctness. A module that uses `.HttpResponse` must directly `::requires 'https_server.cls'` from the package where the class is referenced; a sibling package importing HTTPS Server does not make that public class automatically visible.

The same lifecycle works for MCP, Wire and later modules. Differences such as route constructor arguments, authentication interceptors, browser assets, or protocol-specific probes belong to their adapter/configuration declarations.
