# Research method corpus

Source corpus: user-supplied `pyaudprocessing.zip`, SHA-256 `4c76aa6ff4fb1d09d663a3f50624e81b8cc9711e771684ba36b3602a95de42b4`.

The original corpus is not redistributed in this package.  v0.21 records the method lineage and re-expresses selected algorithms behind regular provider-neutral contracts.

| Normalized processor | Research lineage | v0.20 status |
|---|---|---|
| alignment.gcc_phat | `fc_dual_feed.py`, `calibrate_tdoa_event.py`, v3/v4/v5/v6 helpers | reference implementation |
| alignment.envelope_lag | `calibrate_tdoa_event.py`, v10.2/v11 TDOA selection | reference implementation |
| alignment.cross_ambiguity | `dual_feed_enhance.py`, `dual_feed_enhance_v8.py` | reference implementation |
| transform.adaptive_spectral_denoise | `fc_dual_feed.py` | reference implementation |
| mask.phase_coherence_wiener | `fc_dual_feed.py`, helper-consistent variants | reference implementation |
| transform.mvdr.dual | `dual_feed_enhance.py`, `fc_dual_feed.py` | reference implementation |
| transform.clean_spectral_lines | `fc_dual_feed.py` CLEAN spectral variant | reference implementation |
| mask.echo_persistence | `dual_feed_enhance_v4.py` | reference implementation |
| measurement.room_profile | `dual_feed_enhance_v5.py` | reference implementation |
| mask.coherence.multi_domain | `dual_feed_enhance_v5.py` | reference implementation |
| mask.coherence.five_domain | `dual_feed_enhance_v6.py` | catalogued |
| measurement.harmonic_product | `dual_feed_enhance_v7.py` | reference implementation |
| mask.syllabic_modulation | `dual_feed_enhance_v7.py` | reference score/mask implementation |
| measurement.spectral_tilt | `dual_feed_enhance_v7.py` | reference implementation |
| transform.log_likelihood_fusion | `dual_feed_enhance_v7.py` | reference implementation |
| transform.eigen_noise_projection | `dual_feed_enhance_v8.py` | reference implementation |
| transform.dynamic_filters | `dual_feed_enhance_v8.py`, `custom_trial_mix.py` | stateful reference implementation |
| spatial.tdoa.geo | `dual_feed_enhance_v10_2_geo_scene_dual_tdoa.py`, v11 | catalogued |
| composite.zonal_scene | `dual_feed_enhance_v11_zonal_scene.py` | catalogued |

## Parameters normalized through v0.21

Recurring implicit constants from the research scripts are now explicit configuration keys: FFT/window/hop, maximum lag/delay, coherence smoothing, mask floor, noise percentile/floor scale, CLEAN iterations/gain/beam width, echo delay range/step, persistence normalization interval, sigmoid threshold/slope, diagonal loading, eigen regularization and syllabic modulation band, denoise state smoothing, and sample-domain dynamic-filter intervals/Q/order.

Future ports should continue this rule: no provider is allowed to hide a parameter that materially changes the processing result merely because a research script once used a module-level constant.
