# Media Methodology Index

Canonical catalogue contains **180 methodologies**. The catalogue is open-world: this is the baseline set, not a closed claim that no other valid method exists.

## AUDIO / ACQUISITION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.DECODE.PRESERVE_TIME` | Decode with sample-time preservation | ESTABLISHED | PRESERVE | no | no |
| `AUDIO.RESAMPLE.DECLARED` | Declared resampling | ESTABLISHED | PRESERVE | no | no |

## AUDIO / ANALYSIS

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.CORRELATE` | Waveform/spectral cross-correlation | ESTABLISHED | MEASURE | no | no |
| `AUDIO.DIARIZATION` | Speaker-turn diarization | MODEL_ASSISTED | HYPOTHESIZE | no | no |
| `AUDIO.FEATURE.MFCC_SPECTRAL` | Spectral/cepstral feature extraction | ESTABLISHED | PRESERVE | no | no |
| `AUDIO.FORMANT.TRACK` | Formant/resonance tracking | ESTABLISHED | MEASURE | no | no |
| `AUDIO.PERIODICITY` | Audio periodicity/modulation analysis | ESTABLISHED | MEASURE | no | no |
| `AUDIO.PITCH.F0` | Fundamental-frequency tracking | ESTABLISHED | MEASURE | no | no |
| `AUDIO.SPECTRAL_FLUX` | Spectral-flux event measurement | ESTABLISHED | MEASURE | no | no |
| `AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS` | Complementary alternating spectral-bucket views | EXPERIMENTAL | MEASURE | yes | no |
| `AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION` | Externally-seeded harmonic observation | EXPERIMENTAL | MEASURE | yes | no |
| `AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP` | Alternating-bucket phase sensitivity sweep | EXPERIMENTAL | MEASURE | yes | no |
| `AUDIO.TRANSIENT.DETECT` | Transient/onset detection | ESTABLISHED | MEASURE | no | no |
| `AUDIO.VAD` | Voice activity detection | ESTABLISHED | MEASURE | no | no |

## AUDIO / CALIBRATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.CHANNEL.ALIGN` | Inter-channel delay alignment | ESTABLISHED | MEASURE | no | no |
| `AUDIO.CLOCK.DRIFT` | Audio clock drift estimation | ESTABLISHED | MEASURE | no | no |
| `AUDIO.GAIN.MEASURE_NORMALIZE` | Gain measurement / optional normalization | ESTABLISHED | PRESERVE | no | no |
| `AUDIO.IMPULSE.CALIBRATION` | Impulse/response calibration | ESTABLISHED | MEASURE | no | no |
| `AUDIO.POLARITY.CHECK` | Channel polarity/coherence check | ESTABLISHED | MEASURE | no | no |

## AUDIO / ENHANCEMENT

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW` | Bounded alternating-bucket preference listening view | EXPERIMENTAL | RECONSTRUCT | yes | yes |

## AUDIO / FORENSIC

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.FORENSIC.CODEC` | Audio codec artefact analysis | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `AUDIO.FORENSIC.DOUBLE_ENCODE` | Audio double-encoding indicators | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `AUDIO.FORENSIC.ENF` | Electrical-network-frequency analysis | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `AUDIO.FORENSIC.NOISE_FLOOR` | Noise-floor continuity | FORENSIC_CAUTIOUS | MEASURE | no | no |
| `AUDIO.FORENSIC.PHASE_COHERENCE` | Inter-channel phase/coherence audit | FORENSIC_CAUTIOUS | MEASURE | no | no |
| `AUDIO.FORENSIC.REVERB_CONSISTENCY` | Reverberation consistency | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `AUDIO.FORENSIC.SPLICE` | Audio splice/discontinuity analysis | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `AUDIO.FORENSIC.TIMELINE_AUDIT` | Audio packet/sample timeline audit | ESTABLISHED | PRESERVE | no | no |

## AUDIO / MEASUREMENT

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.CLIP.DETECT` | Clipping/saturation detection | ESTABLISHED | MEASURE | no | no |

## AUDIO / MULTIPATH

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.MULTIPATH.MOTION_COHERENCE` | Motion-induced acoustic path coherence | QUALIFIED_PATTERN | MEASURE | no | no |
| `AUDIO.MULTIPATH.PATH_ESTIMATE` | Sparse coherent multipath path estimation | QUALIFIED_PATTERN | MEASURE | no | no |
| `AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY` | Acoustic multipath physics-compatibility evidence | QUALIFIED_PATTERN | MEASURE | no | no |
| `AUDIO.MULTIPATH.SPECTRAL_TRACK` | Time-varying spectral multipath trajectory tracking | QUALIFIED_PATTERN | MEASURE | no | no |

## AUDIO / RECONSTRUCTION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.BANDWIDTH.EXTEND` | Audio bandwidth extension | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `AUDIO.CLICK.REPAIR` | Click/pop impulse repair | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DECLIP` | Waveform declipping | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `AUDIO.DECONV.RIR` | Room-response inverse filtering | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DROPOUT.CONCEAL` | Dropout/packet-loss concealment | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.RECON.MULTIPATH_VIRTUAL_MIC` | Trajectory-conditioned multipath virtual-microphone reconstruction | QUALIFIED_PATTERN | RECONSTRUCT | yes | yes |
| `AUDIO.SPECTRAL.REPAIR` | Time-frequency spectral repair | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `AUDIO.SUPERRES.MODEL` | Learned audio super-resolution | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `AUDIO.SYSTEM.BLIND_DECONV` | Blind acoustic deconvolution | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `AUDIO.WOW_FLUTTER.CORRECT` | Wow/flutter timebase correction | ESTABLISHED | RECONSTRUCT | no | yes |

## AUDIO / RESTORATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.DC.REMOVE` | DC offset removal | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DENOISE.MMSE` | MMSE spectral enhancement | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DENOISE.NEURAL` | Learned speech/audio denoising | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `AUDIO.DENOISE.NMF` | NMF noise/source model | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DENOISE.SPECTRAL_SUBTRACTION` | Spectral subtraction | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DENOISE.WAVELET` | Wavelet audio denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DENOISE.WIENER` | Wiener filtering | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.DEREVERB.WPE` | Weighted prediction error dereverberation | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.ECHO.CANCEL` | Echo cancellation | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.FILTER.BANDPASS_NOTCH` | Band-pass/notch filtering | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.HUM.REMOVE` | Mains hum/harmonic suppression | ESTABLISHED | RECONSTRUCT | no | yes |

## AUDIO / SEMANTIC_ANALYSIS

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.ASR` | Automatic speech recognition | MODEL_ASSISTED | HYPOTHESIZE | no | no |
| `AUDIO.EVENT.CLASSIFY` | Acoustic event classification | MODEL_ASSISTED | HYPOTHESIZE | no | no |
| `AUDIO.FORCED_ALIGN` | Transcript/audio forced alignment | ESTABLISHED | HYPOTHESIZE | no | no |

## AUDIO / SEPARATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.HARMONIC_PERCUSSIVE` | Harmonic/percussive separation | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.SEPARATE.DEEP` | Learned source separation | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `AUDIO.SEPARATE.ICA` | Independent component analysis | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.SEPARATE.NMF` | NMF source separation | ESTABLISHED | RECONSTRUCT | no | yes |

## AUDIO / SPATIAL

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.BEAMFORM.DAS` | Delay-and-sum beamforming | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.BEAMFORM.GEV` | GEV beamforming | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.BEAMFORM.MVDR` | MVDR beamforming | ESTABLISHED | RECONSTRUCT | no | yes |
| `AUDIO.SPATIAL.ACOUSTIC_IMAGE` | Acoustic imaging / steered response map | ESTABLISHED | VISUALIZE | no | no |
| `AUDIO.SPATIAL.GCC_PHAT` | GCC-PHAT time-difference estimation | ESTABLISHED | MEASURE | no | no |
| `AUDIO.SPATIAL.MUSIC` | MUSIC direction estimation | ESTABLISHED | HYPOTHESIZE | no | no |
| `AUDIO.SPATIAL.SOURCE_LOCALIZE` | Acoustic source localization | ESTABLISHED | HYPOTHESIZE | no | no |
| `AUDIO.SPATIAL.SRP_PHAT` | SRP-PHAT localization | ESTABLISHED | HYPOTHESIZE | no | no |

## AUDIO / SYSTEM_IDENTIFICATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AUDIO.RIR.ESTIMATE` | Room impulse-response estimation | ESTABLISHED | HYPOTHESIZE | no | no |

## CROSS_MODAL / FUSION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AV.CONTRADICTION.ANALYSIS` | Cross-modal contradiction analysis | ESTABLISHED | HYPOTHESIZE | no | no |
| `AV.EVENT.COOCCURRENCE` | Cross-modal event co-occurrence | ESTABLISHED | HYPOTHESIZE | no | no |
| `AV.LOCALIZE.FUSE` | Audio/visual source localization fusion | ESTABLISHED | HYPOTHESIZE | no | no |

## CROSS_MODAL / PHYSICS

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AV.COUPLING.ACOUSTIC_MECHANICAL` | Acoustic-to-mechanical coupling analysis | EXPERIMENTAL | HYPOTHESIZE | yes | no |
| `AV.PHYSICS.TRANSFER_FUNCTION` | Cross-modal transfer-function estimation | EXPERIMENTAL | HYPOTHESIZE | yes | no |

## CROSS_MODAL / RECONSTRUCTION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AV.RECON.CONSENSUS` | Multi-method reconstruction consensus | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `AV.VISUAL_MICROPHONE` | Visual microphone reconstruction | EXPERIMENTAL | RECONSTRUCT | yes | yes |

## CROSS_MODAL / SYNC

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `AV.SPEECH.LIP_SYNC` | Speech/lip synchrony hypothesis | MODEL_ASSISTED | HYPOTHESIZE | no | no |
| `AV.SYNC.CLOCK` | Audio/video clock alignment | QUALIFIED_PATTERN | MEASURE | no | no |
| `AV.SYNC.TRANSIENT_MOTION` | Acoustic-transient / visual-motion lag | ESTABLISHED | HYPOTHESIZE | no | no |

## VALIDATION / PROVENANCE

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `QUAL.PROVENANCE.HASH_CHAIN` | Evidence/provenance hash chain | ESTABLISHED | PRESERVE | no | no |

## VALIDATION / QUALIFICATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL` | Known-input alternating spectral interleave positive control | ESTABLISHED | PRESERVE | no | no |
| `QUAL.AUTHORITY.GATING` | Evidence-authority gating test | ESTABLISHED | PRESERVE | no | no |
| `QUAL.BEFORE_AFTER` | Before/after method A-B qualification | ESTABLISHED | PRESERVE | no | no |
| `QUAL.BOOTSTRAP.UNCERTAINTY` | Bootstrap uncertainty | ESTABLISHED | PRESERVE | no | no |
| `QUAL.CLOCK.PERTURB` | Clock perturbation test | ESTABLISHED | PRESERVE | no | no |
| `QUAL.CODEC.INVARIANCE` | Codec/container invariance test | ESTABLISHED | PRESERVE | no | no |
| `QUAL.CROSS_METHOD.DISAGREEMENT` | Cross-method disagreement preservation | ESTABLISHED | PRESERVE | no | no |
| `QUAL.FORWARD_MODEL.REPROJECTION` | Forward-model reconstruction check | ESTABLISHED | PRESERVE | no | no |
| `QUAL.HOLDOUT.WINDOWS` | Held-out event-window qualification | ESTABLISHED | PRESERVE | no | no |
| `QUAL.MATCHED_QUIET_STATIC` | Matched quiet/static controls | ESTABLISHED | PRESERVE | no | no |
| `QUAL.PARAMETER.SENSITIVITY` | Parameter sensitivity sweep | ESTABLISHED | PRESERVE | no | no |
| `QUAL.RESOLUTION.INVARIANCE` | Resolution invariance test | ESTABLISHED | PRESERVE | no | no |
| `QUAL.SYNTHETIC.GROUND_TRUTH` | Synthetic ground-truth qualification | ESTABLISHED | PRESERVE | no | no |
| `QUAL.TIME_REVERSE` | Time-reversal asymmetry control | ESTABLISHED | PRESERVE | no | no |
| `QUAL.TIME_SHUFFLE` | Time-shuffled null control | ESTABLISHED | PRESERVE | no | no |

## VIDEO / ACQUISITION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.CADENCE.RECOVER` | Frame cadence recovery | ESTABLISHED | MEASURE | no | no |
| `VIDEO.COLOUR.LINEARIZE` | Colour transfer linearisation | ESTABLISHED | PRESERVE | no | no |
| `VIDEO.DECODE.PRESERVE_PTS` | Decode with preserved decoded PTS | ESTABLISHED | PRESERVE | no | no |
| `VIDEO.DEINTERLACE.MOTION_ADAPTIVE` | Motion-adaptive deinterlacing | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.EXPOSURE.FLICKER_NORMALIZE` | Exposure/flicker normalisation | ESTABLISHED | MEASURE | no | no |
| `VIDEO.ROI.SELECTIVE_HIGHRES` | Selective source-resolution request | QUALIFIED_PATTERN | PRESERVE | no | no |

## VIDEO / CAMERA_MODEL

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.CHROMATIC_ABERRATION.CORRECT` | Chromatic aberration correction | ESTABLISHED | MEASURE | no | no |
| `VIDEO.LENS.DISTORTION_CORRECT` | Lens distortion correction | ESTABLISHED | MEASURE | no | no |
| `VIDEO.ROLLING_SHUTTER.CORRECT` | Rolling-shutter geometry correction | ESTABLISHED | RECONSTRUCT | no | yes |

## VIDEO / CAMERA_STATE

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.CAMERA_STATE.GATE` | Camera-motion authority gating | QUALIFIED_PATTERN | MEASURE | no | no |
| `VIDEO.SCENE.REACQUIRE` | Scene geometry reacquisition | QUALIFIED_PATTERN | MEASURE | no | no |
| `VIDEO.STABILIZE.GLOBAL` | Global camera stabilisation | ESTABLISHED | RECONSTRUCT | no | yes |

## VIDEO / ENHANCEMENT

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.CONTRAST.LOCAL` | Local contrast enhancement | ESTABLISHED | VISUALIZE | no | no |
| `VIDEO.EXPOSURE.FUSE` | Exposure fusion | ESTABLISHED | VISUALIZE | no | no |
| `VIDEO.ILLUMINATION.RETINEX` | Illumination/reflectance separation | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.MOTION.EULERIAN_MAGNIFY` | Eulerian motion magnification | ESTABLISHED | VISUALIZE | no | no |

## VIDEO / FORENSIC

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.FORENSIC.CLOCK_ALIGN` | Burned-clock / decoded-PTS alignment | QUALIFIED_PATTERN | MEASURE | no | no |
| `VIDEO.FORENSIC.COMPRESSION_MAP` | Compression artefact mapping | FORENSIC_CAUTIOUS | MEASURE | no | no |
| `VIDEO.FORENSIC.DOUBLE_ENCODE` | Double-encoding indicators | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `VIDEO.FORENSIC.EDIT_DISCONTINUITY` | Visual edit discontinuity analysis | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `VIDEO.FORENSIC.FRAME_DUP_DROP` | Frame duplicate/drop analysis | FORENSIC_CAUTIOUS | MEASURE | no | no |
| `VIDEO.FORENSIC.GOP_AUDIT` | GOP/keyframe structure audit | FORENSIC_CAUTIOUS | PRESERVE | no | no |
| `VIDEO.FORENSIC.ILLUMINATION_CONSISTENCY` | Illumination/shadow consistency | FORENSIC_CAUTIOUS | HYPOTHESIZE | no | no |
| `VIDEO.FORENSIC.PTS_METADATA_AUDIT` | PTS/container/metadata audit | ESTABLISHED | PRESERVE | no | no |
| `VIDEO.FORENSIC.SENSOR_NOISE` | Sensor-pattern consistency | FORENSIC_CAUTIOUS | HYPOTHESIZE | yes | no |

## VIDEO / GEOMETRY

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.GEOM.BUNDLE_ADJUST` | Bundle adjustment | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.CAMERA_PATH_FEASIBILITY` | Camera-path/view feasibility | QUALIFIED_PATTERN | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.DEPTH_FROM_MOTION` | Depth from motion/parallax | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.HOMOGRAPHY` | Planar/projective homography | ESTABLISHED | MEASURE | no | no |
| `VIDEO.GEOM.INTRINSIC_CALIBRATION` | Camera intrinsic calibration | ESTABLISHED | MEASURE | no | no |
| `VIDEO.GEOM.MONOCULAR_DEPTH_MODEL` | Learned monocular depth | MODEL_ASSISTED | HYPOTHESIZE | yes | no |
| `VIDEO.GEOM.OCCLUSION_REASONING` | Occlusion/disocclusion reasoning | ESTABLISHED | MEASURE | no | no |
| `VIDEO.GEOM.PHOTOMETRIC_STEREO` | Photometric stereo | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.PLANE_FIT` | Plane reconstruction | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.POSE_ESTIMATION` | Camera pose estimation | ESTABLISHED | MEASURE | no | no |
| `VIDEO.GEOM.SHAPE_FROM_SHADING` | Shape from shading | EXPERIMENTAL | HYPOTHESIZE | yes | no |
| `VIDEO.GEOM.SHAPE_FROM_SILHOUETTE` | Shape from silhouettes | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.STEREO_DISPARITY` | Stereo disparity | ESTABLISHED | MEASURE | no | no |
| `VIDEO.GEOM.STRUCTURE_FROM_MOTION` | Structure from motion | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.TEMPORAL_REGISTRATION` | Temporal photo/video registration | ESTABLISHED | HYPOTHESIZE | no | no |
| `VIDEO.GEOM.VANISHING_POINTS` | Vanishing-point estimation | ESTABLISHED | MEASURE | no | no |

## VIDEO / MOTION_MEASUREMENT

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.MOTION.BACKGROUND_SUBTRACTION` | Background subtraction | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.BLOCK_VECTOR` | Block motion estimation | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.DENSE_FLOW` | Dense optical flow | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.FEATURE_MATCH` | Feature descriptor matching | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.FRAME_DIFFERENCE` | Frame differencing | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.KLT` | Sparse feature tracking (KLT family) | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.PERIODICITY` | Periodic motion analysis | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.PHASE_CORRELATION` | Phase-correlation displacement | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.PHASE_SUBPIXEL` | Phase-based subpixel motion | ESTABLISHED | MEASURE | no | no |
| `VIDEO.MOTION.ROLLING_VIBRATION` | Rolling-shutter vibration estimation | EXPERIMENTAL | MEASURE | yes | no |
| `VIDEO.MOTION.SEGMENT` | Motion segmentation | ESTABLISHED | MEASURE | no | no |
| `VIDEO.SILHOUETTE.TRACK` | Silhouette tracking | ESTABLISHED | MEASURE | no | no |

## VIDEO / RECONSTRUCTION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.DEBLUR.BLIND` | Blind deconvolution | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.DEBLUR.DEFOCUS` | Defocus deblurring | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DEBLUR.NONBLIND` | Known-PSF deconvolution | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.FOCUS.STACK` | Focus stacking | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.HDR.FUSE` | Multi-exposure HDR fusion | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.BACKGROUND_TEMPORAL` | Temporal background reconstruction | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL` | Bidirectional blur-envelope reconstruction | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.FLOW_WARP_ACCUMULATE` | Optical-flow warp-and-accumulate | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.FRAME_INTERPOLATION` | Temporal frame interpolation | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.INPAINT_TEMPORAL` | Temporal video inpainting | MODEL_ASSISTED | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.LATENT_MULTI_FRAME` | Multi-frame latent sharp reconstruction | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION` | Leading-edge motion-blur backprojection | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.MOTION_BLUR_TOMOGRAPHY` | Motion-blur trajectory tomography | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.MOVING_STRIP_MOSAIC` | Moving-object strip mosaic | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.MULTIVIEW_TEXTURE` | Multi-view texture fusion | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.OCCLUSION_REVEAL` | Temporal occlusion reveal | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.ROLLING_SLICE` | Rolling-shutter slice reconstruction | EXPERIMENTAL | RECONSTRUCT | yes | yes |
| `VIDEO.RECON.SILHOUETTE_HULL` | Visual hull / silhouette reconstruction | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.RECON.TRAJECTORY_STACK` | Trajectory-aligned stacking | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.SUPERRES.MULTIFRAME` | Multi-frame super-resolution | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.SUPERRES.SINGLE_MODEL` | Single-frame learned super-resolution | MODEL_ASSISTED | RECONSTRUCT | yes | yes |

## VIDEO / RESTORATION

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.DEBLOCK` | Block artefact suppression | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DENOISE.BM3D` | BM3D/CBM3D-style denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DENOISE.MOTION_COMPENSATED` | Motion-compensated temporal denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DENOISE.NONLOCAL` | Non-local patch denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DENOISE.TEMPORAL_MEDIAN` | Temporal median denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DENOISE.WAVELET` | Wavelet denoising | ESTABLISHED | RECONSTRUCT | no | yes |
| `VIDEO.DERING` | Ringing suppression | ESTABLISHED | RECONSTRUCT | no | yes |

## VIDEO / STRUCTURE_MEASUREMENT

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.BOUNDARY.VALUE_DISTANCE` | Value-distance boundary extraction | ESTABLISHED | MEASURE | no | no |
| `VIDEO.LINE.CONTINUITY` | Line/edge continuity | ESTABLISHED | MEASURE | no | no |

## VIDEO / TRACKING

| ID | Method | Maturity | Authority | Experimental | Reconstructive |
|---|---|---|---|---:|---:|
| `VIDEO.TRACK.TRAJECTORY` | Trajectory association | ESTABLISHED | MEASURE | no | no |

