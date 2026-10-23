# Font Manager architecture

Font management is a shared service, not a PDF feature.

`FontManager` owns semantic selection and central registration. A request can say BODY, CODE, UI, PRINT_BODY or WEB_BODY and remain independent of where fonts are installed. Discovery is delegated to providers; v0.1-dev1 supplies deterministic manifest discovery and a live Fontconfig provider.

Packaging is likewise provider based. A renderer can ask for a subset suitable for an application or web deployment without knowing how it is made. The included `PyftsubsetTransformer` is optional and can emit ordinary subset font files or WOFF/WOFF2. The core manager does not shell out directly and does not make fontTools compulsory.

Intentions are a separate adapter over the same service. Font operations register into the existing Intention Service rather than creating another natural-language dispatcher.

Future renderers should depend on FontManager, not on each other's font logic: PDF for embedding/metrics, Wire renderers for native/UI selection, HTML generation for CSS and web subsets, and application packagers for deployment closure.


## dev3 coverage and fallback boundary

A semantic font choice and a glyph-coverage choice are distinct operations. `findForPurpose` still selects the preferred face for a purpose. `planRunsForPurpose` then evaluates the actual text corpus and introduces fallback faces only where the preferred face lacks a glyph.

Coverage providers are optional accelerators. They answer a narrow question — which face can cover a Unicode scalar under an optional language hint — but they do not decide PDF, CSS, UI or packaging syntax. Glyph providers remain authoritative for the final coverage proof; a provider suggestion is accepted only when the resulting `FontGlyphPlan` contains a non-zero glyph.

The returned `FontRunPlan` is renderer-neutral. PDF may map each run to a CID font, Wire may map it to native text runs, and HTML may derive a CSS fallback stack. Missing characters remain explicit evidence.

Run planning currently operates at UTF-8 Unicode-scalar boundaries. It deliberately does not claim shaping authority: grapheme clustering, bidirectional reordering and OpenType GSUB/GPOS shaping require a dedicated shaping provider/service in a later slice.
