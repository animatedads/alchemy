# Exact Layered Audio v0.22-dev9 candidate

These five base64 chunks reconstruct the exact candidate that was qualified
statically and stored in the ChatGPT Library.

This is deliberately byte-preserving evidence, not a re-created source tree.
It exists because Autobuilder is currently not running and the independent
qualification worker cannot access ChatGPT Library bytes directly.

Reconstruct:

    ./reconstruct.sh /tmp/layered_audio_oorexx_v0.22-dev9.zip

The script requires the reconstructed file to match:

    97c74f998d2daafac3a0c68dcd8d50f883b1ce1379c4a7d09ed46262176ed6b8

and then runs `unzip -t`.

Once reconstructed, use the package's own `tools/run_environment_test.sh`
with ooRexx 5.3.0 r13196 and the required real dependency roots. Do not
substitute dev8 or infer dev9 runtime status from predecessor evidence.
