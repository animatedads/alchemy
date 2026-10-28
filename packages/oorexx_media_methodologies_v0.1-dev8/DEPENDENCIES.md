# Dependencies

Core catalogue / experiment / intention classes use ordinary ooRexx collection classes and this package's own source files.

Optional execution integrations use current external contracts rather than vendoring them:

| Component | Reviewed baseline | Role |
| --- | --- | --- |
| Memory Fabric | v0.1-dev10 | sparse/reference backing, adaptive horizons, movement-demand authority |
| RexxOS RTO2 Grid | v0.1-dev15 | estate/node identity and live membership evidence |
| Job-to-Node Allocator | v0.6-network4 | placement/admission/lease authority |
| Vision | v0.1-dev21 branch | current dynamic visual intention/evidence direction |
| Layered Audio | v0.22-dev9 | current object-bound dynamic audio intention direction |
| Audio V9 | dev20 candidate18r1, SHA-256 `83ecf6584707dc9535d86e41b1a243fee5e1fe4376b78c27bc2f89e6a9736018` | optional multipath measurement/reconstruction implementation provider |
| Instrumentation Mesh | v0.1-dev7, SHA-256 `ef5500d09580f58bd815edc9e82f5dbb4b06380266acc1bc703f44f7d205d6ad` | optional operational event observation/replay |
| Wire3D | dev29.22, SHA-256 `aa49fc6418c268ae1a5554032574d41a73c96ee94d49c0f37e28d58150d78c5a` | optional NOC consumer of Instrumentation Mesh events |

The dev4 **reference video provider** is optional and requires:

- Python 3;
- OpenCV (`cv2`);
- NumPy;
- a video decoder available through the OpenCV build.

The provider is an implementation plugin, not a core dependency. If those capabilities are absent, the methodologies remain present in the catalogue and another implementation provider may satisfy them.

Vision and Layered Audio remain architectural compatibility references for dynamic methodology discovery; Media Methodologies does not require either package to load its core catalogue.


The dev5 **Audio V9 provider** is optional and requires the exact Audio V9 Candidate18 native binaries/classes for the selected methodology. The package does not vendor Audio V9. `AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY` uses the ooRexx Audio V9 policy bridge; the other current executable provider paths call the qualified Candidate18 native tools.

Instrumentation is also optional. `MediaMethodologyInstrumentation.cls` requires Instrumentation Mesh dev7 only when operational timeline events are requested. Wire3D is not required by Media Methodologies; it is merely a qualified consumer of the Mesh event timeline.

Reference audio providers additionally require Python 3 with numpy, scipy, scikit-learn and soundfile. These are implementation dependencies, not methodology semantics.


## Optional sequence-locality qualification

Audio V9 dev20 Candidate20 supplies `AudioV9SequenceExecutionExperiment.cls`. Media Methodologies consumes that contract only for execution-planning/qualification evidence; Audio V9, GCI, Job-to-Node, Storage Fabric, Memory Fabric and RexxOS/RTO2 keep their existing authorities.

## Dev8 optional integrations

- **Audio Spectral Integrity v0.2** (SHA-256 `9a9bd452a2f71bb1791b00774b30cb2f5720f262e5e40eb16999095aa66589b4`) is the optional provider for the five `SPECTRAL_INTEGRITY` methodologies.  The adapter dynamically imports its Python backend and never treats alternating bucket views as independent sources.
- **Evidence Revision ooRexx v0.1-dev2** (SHA-256 `9aae5b671e71d67ff764266b544f0c060a813c10ead841098fbbde13cbe545af`) is optional.  Media Methodologies consumes only its detached audit classification and does not take over belief/truth/provenance authority.
- **Generalized Compute Intentions v0.1-dev5** (SHA-256 `4b6d61e651dc7ea729ccc21e66bd471fa51629b77fc86fe8ca8ff1dd5ed25afd`) is optional.  Media tasks may be projected for non-mutating route planning; resulting handoffs always require compute/allocation/WLU/router revalidation.
- **Memory Fabric/XTP candidate4** and **RexxOS/RTO2 dev15** remain execution/identity authorities outside this package.

