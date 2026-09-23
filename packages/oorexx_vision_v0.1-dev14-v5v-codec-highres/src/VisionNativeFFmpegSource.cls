/* Source contract for the Termux test bed.
 * Native library API:
 *   vision_ffmpeg_open
 *   vision_ffmpeg_next_rgb24
 *   vision_ffmpeg_close
 *
 * The supplied helper executable is deliberately only the first mobile adapter.
 * It uses the exact same compiled libvision_ffmpeg implementation and emits
 * fixed RGB24 frames.  Recognition remains in Vision, never in FFmpeg.
 */
::class VisionNativeFFmpegSource public
::method init
  expose url width height fps frameBytes helper
  use strict arg url,width=55,height=73,fps=5,helper="../build/vision_ffmpeg_source"
  frameBytes=width*height*3
::attribute url get
::attribute width get
::attribute height get
::attribute fps get
::attribute frameBytes get
::attribute helper get

::method command
  expose url width height fps helper
  return helper '"'url'"' width height fps
