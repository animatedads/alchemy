/* Mobile Vision acquisition test bed.
 * Produces frame-local Vision observations.  Temporal interpretation is owned
 * by the separately packaged oorexx_motion_control component.
 */
parse arg url seconds
if url="" then url="https://127.0.0.1:4444/video/mjpeg"
if seconds="" then seconds=10
src=.VisionNativeFFmpegSource~new(url)
say "VISION LIVE SOURCE"
say "url="src~url
say "surface="src~width"x"src~height "fps="src~fps "rgb_frame_bytes="src~frameBytes
say "native_command="src~command
say "Temporal events: use oorexx_motion_control test bed."
::requires "../src/VisionNativeFFmpegSource.cls"
::requires "../src/VisionLive.cls"
