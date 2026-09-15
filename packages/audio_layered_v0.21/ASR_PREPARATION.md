# ASR preparation in Layered Audio v0.18

The early Foreign Runtime v0.22.2 transcript sample proved the native FFmpeg -> ForeignBuffer -> NumPy -> ForeignTensor/DLPack -> Torch -> SpeechBrain execution path.  Its lexical output was not accepted as reliable evidence because the sample fed fixed two-second windows to a LibriSpeech CRDNN+RNNLM after whole-recording peak normalisation.  Low-SNR camera ambience can then become language-model-dominated output.

v0.17 changes the preparation strategy without changing transcript authority:

1. Decode camera audio natively and fail closed unless the material presented to the sample app is mono 16 kHz float32 (`flt`/`fltp`).
2. Preserve the decoded PCM as the source material; no transcript replaces the source.
3. Estimate an adaptive RMS noise floor in 20 ms frames / 10 ms hops.
4. Produce padded, merged, utterance-sized speech-region hypotheses (maximum 12 s with overlap where a region must split).
5. Skip very low active-frame-occupancy regions by default (`0.08`, configurable by `LAYERED_AUDIO_ASR_MIN_SPEECH_SCORE`).  This is a heuristic occupancy measure, not a calibrated probability.
6. Prepare each selected region independently: DC removal, 80 Hz high-pass, target RMS -20 dBFS with maximum +12 dB boost, then peak limiting at 0.95.  This avoids blindly amplifying a whole minute of camera ambience to full scale.
7. Reuse one resident SpeechBrain model across every supplied file and transcribe complete candidate utterance regions rather than blind two-second fragments.
8. Emit each lexical result as a separate Layered Audio transcript boundary with its original source-time interval and preparation/segmentation metadata.

The default `speechbrain/asr-crdnn-rnnlm-librispeech` remains a LibriSpeech read-speech model.  v0.17 therefore does not claim that it is the best model for distant conversational camera audio, and it does not manufacture lexical confidence that the model does not supply.  Alternative ASR models and alternative preparation chains should be retained as separate transcript views/hypothesis sets when compared.

Foreign Runtime v0.22.2 is important here because resident Python proxy arguments, including `ForeignTensor`, are marshalled as the underlying Python object.  This repairs the earlier `AttributeError: 'str' object has no attribute 'dtype'` failure and makes direct ooRexx -> Python tensor calls viable.
