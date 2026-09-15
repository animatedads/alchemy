# Camera Behaviour v0.56 / Foreign Runtime v0.20.0

Camera v0.56 is requalified on the user-supplied Foreign Runtime v0.20.0, SHA-256 `6637c45e2fdddb0f60cacc2417e0fa2477c421509258b97e01dc3654ee5699fa`.

The direct native FFmpeg path continues to use the inherited borrowed-memory APIs `structView`, `pointerAt`, and `peekBytes`, including decoded AVFrame/AVStream timestamp metadata used by source-boundary analysis.

Foreign Runtime v0.20.0 additionally preserves v0.17.2 concurrency repairs, v0.18 bidirectional zero-copy ForeignBuffer/Python semantics, v0.19 ForeignTensor/DLPack behavior, and adds the v0.20 provider-neutral native tensor descriptor ABI. Camera v0.56 does not require Python, NumPy, Torch, DLPack, or the tensor descriptor ABI; those capabilities remain optional provider mechanisms for future numerical implementations.

Scene-aware primitive context in v0.56 is implemented entirely in ooRexx and introduces no new native-library dependency.
