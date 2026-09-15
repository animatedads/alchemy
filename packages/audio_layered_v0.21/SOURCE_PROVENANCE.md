# v0.21 stateful-streaming provenance

- Continuation baseline: Layered Audio v0.20 ZIP SHA-256 `b0704047ee5c94da27ed21ac6c12fb4c582a0a4184de78a062e619de0ae20c66`.
- Research/method source remains user-supplied `pyaudprocessing.zip`, SHA-256 `4c76aa6ff4fb1d09d663a3f50624e81b8cc9711e771684ba36b3602a95de42b4`. The original project plumbing is not redistributed.
- API roll-up: `oorexxapis(20260901-115634).zip`, SHA-256 `2879714a6747bfe26dd487910914f252c9763dca6543028816f7166f07137ac0`, supplying Foreign Runtime v0.22.5, Runtime Reference v0.4 and Maths v0.5.
- External McGill A-law fixture remains `M1F1-Alaw-AFsp.wav`, SHA-256 `cfbc1821b7dd3d288d4223859c454d28065f4fbf23eabcdc77a13166a61fd37f`; not redistributed.
- External camera fixture used in qualification: `1000053600.mp4` upload SHA-256 `66fb8fa4ac2ea93e0b2338fbc1bb5f34e224237722deb3d59e23eef471d39a44`; not redistributed.
- v0.21 re-expresses persistent denoise/echo/filter state from the research corpus behind regular stream-session contracts; it is not a byte translation of the original scripts.

# v0.20 typed-graph / expanded processing provenance

- Continuation baseline: Layered Audio v0.19.
- Research-method source: user-supplied `pyaudprocessing.zip`; original project plumbing is not redistributed.
- Runtime qualification baseline: `oorexxapis(20260901-115634).zip` supplying Foreign Runtime v0.22.5, Runtime Reference v0.4 and Maths v0.5.
- v0.20 re-expresses additional method ideas from `dual_feed_enhance_v5.py` and `dual_feed_enhance_v7.py` behind regular provider-neutral contracts; implementations are intentionally tightened and are not byte translations of research scripts.
- McGill `M1F1-Alaw-AFsp.wav` remains an external channel-independence regression and is not redistributed.

# v0.19 processing-toolkit provenance

- Research/method corpus: user-supplied `pyaudprocessing.zip`, SHA-256 `4c76aa6ff4fb1d09d663a3f50624e81b8cc9711e771684ba36b3602a95de42b4`. The original project is not redistributed. Selected mathematical methods were re-expressed behind regular ooRexx/provider contracts.
- API roll-up: `oorexxapis(20260901-115634).zip`, SHA-256 `2879714a6747bfe26dd487910914f252c9763dca6543028816f7166f07137ac0`.
- ooRexx Maths v0.5 standalone within roll-up, SHA-256 `cc72fcc7a068df2cb636ec116b75f5865d6b025219c65a42e344cbc0b4596423`.
- ooRexx Foreign Runtime v0.22.5 standalone within roll-up, SHA-256 `c098aaabcbed14fdb80ca2a9aafece263fa092df5567014a485ce79e784711c2`.
- Runtime Reference v0.4 standalone within roll-up, SHA-256 `c42a0c51cc5f5e26056d22db97d53eae2633141a7cebe3304b5f19b1847f957a`.
- External channel-independence fixture: McGill `M1F1-Alaw-AFsp.wav`, SHA-256 `cfbc1821b7dd3d288d4223859c454d28065f4fbf23eabcdc77a13166a61fd37f`. It is not redistributed in this package.
- Qualification runtime: user-supplied ooRexx 5.3.0 r13196 Internal Test Version.

# Source provenance - Layered Audio ooRexx v0.18

Continuation base:

- Layered Audio ooRexx v0.17 ZIP SHA-256: `7a5599a6dc4c26fa73c27464df479ef382b0133bae8c30ccd5b9fa04ab055a6b`

Qualified dependencies/context:

- Runtime Reference v0.2
- ooRexx 5.3.0 r13196 Internal Test Version
- Camera Behaviour ooRexx v0.52 as adjacent integration context

External validation media:

- `1000053605.mp4` SHA-256: `4a69f88ca0b4ed90d3cb19caab98129d76496f880399ccb7e2e93befb3a25c32`
- used for native AAC decode and camera tensor-material qualification
- not redistributed in this package

Foreign Runtime tensor qualification uses its packaged independent native tensor consumer (`libtensor_probe.so` + tensor descriptor ABI) as an external runtime dependency, not copied into Layered Audio.


## v0.18 additions
- user-supplied ooRexx Foreign Runtime v0.22.2 ZIP SHA-256: `b4ed0572247cb68755f259b5403b9e06ace0d8a06bde39991c24416641e9def2`
- user-supplied early transcript sample app SHA-256: `477593a8306138fb13169ef0f11c0ceffa9e72cef1028f55fc01ed9d29938096`; used as diagnostic source for the ASR-preparation repair, not redistributed as authoritative transcript evidence.
