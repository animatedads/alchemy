# Font Manager architecture

Font management is a shared service, not a PDF feature.

`FontManager` owns semantic selection and central registration. A request can say BODY, CODE, UI, PRINT_BODY or WEB_BODY and remain independent of where fonts are installed. Discovery is delegated to providers; v0.1-dev1 supplies deterministic manifest discovery and a live Fontconfig provider.

Packaging is likewise provider based. A renderer can ask for a subset suitable for an application or web deployment without knowing how it is made. The included `PyftsubsetTransformer` is optional and can emit ordinary subset font files or WOFF/WOFF2. The core manager does not shell out directly and does not make fontTools compulsory.

Intentions are a separate adapter over the same service. Font operations register into the existing Intention Service rather than creating another natural-language dispatcher.

Future renderers should depend on FontManager, not on each other's font logic: PDF for embedding/metrics, Wire renderers for native/UI selection, HTML generation for CSS and web subsets, and application packagers for deployment closure.
