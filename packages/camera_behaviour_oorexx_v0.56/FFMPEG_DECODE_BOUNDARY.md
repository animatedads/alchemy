# FFmpeg decode boundary — resolved in Camera v0.47

Camera v0.46 stopped at `AVStream.codecpar` because Foreign Runtime v0.11.0 could not create a typed view over borrowed native pointers.

Foreign Runtime v0.11.1 adds non-owning `structView`, pointer-vector traversal, and bounded byte peeks. Camera v0.47 uses those generic facilities to traverse:

`AVFormatContext -> streams[] -> AVStream.codecpar -> avcodec_parameters_to_context`

and then performs the normal FFmpeg decode loop directly from ooRexx.

The three supplied CCTV fixtures each decode to 900 video frames at 640x360 YUV420P on the qualified FFmpeg ABI. Camera reads bytes from the first decoded luminance plane directly; no FFmpeg CLI process and no FFmpeg-specific C shim is used.
