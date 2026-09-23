# Vision + Motion live test bed v0.1-dev2

The phone has qualified the direct native stream at exactly 5 fps:
0.0, 0.2, 0.4 ... with complete 12045-byte RGB24 transactions.

dev2 replaces the checksum-only projection with an actual packed Vision surface:

* 55 x 73 = 4015 samples
* 26 value positions
* 5 bits/sample
* ceil(4015*5/8) = 2510 packed bytes
* no `.rgb` intermediate file

For this first live codec qualification the native encoder deliberately uses a
fixed deterministic 26-level neutral palette. It is not presented as the final
adaptive three-curve selector. This isolates and tests the live 5-bit packing
contract before adaptive palette policy is introduced.

Build/run:

    export VISION_HOME=$HOME/downloads/oorexx_vision_v0.1-dev13-live-termux
    ./build-termux.sh
    ./run-live.sh 'https://192.168.188.25:4444/video/mjpeg'

Expected records:

    VISION  1  0.000000  55  73  12045  2510  <rgb-hash>  <vision-hash>
    VISION  2  0.200000  55  73  12045  2510  <rgb-hash>  <vision-hash>

The next stage derives frame-local change/region observations from these Vision
surfaces and hands only those observations to the independent Motion Control
package.
