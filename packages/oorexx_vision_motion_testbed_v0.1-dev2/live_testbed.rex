#!/data/data/com.termux/files/usr/bin/rexx
parse arg url
if url="" then url="https://192.168.188.25:4444/video/mjpeg"

say "OO REXX VISION + MOTION LIVE TEST BED"
say "camera:" url
say "This dev1 executable proves the direct native live transaction stream."
say "No intermediate RGB file is used."
say
say "Start the native producer with:"
say "  ./build/vision_live_probe '"url"' 55 73 5"
say
say "The next test-bed increment feeds VisionRegionObservation records from"
say "the codec into MotionController; camera transport remains unchanged."

::requires "src/LiveTestBed.cls"
