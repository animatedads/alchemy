#!/bin/sh
# Synthetic multi-voice fixture for the multiF0 test: three harmonic voices with vibrato and known timing
# (130 Hz 0-4 s, 285 Hz 1-3 s, 210 Hz 2-4 s) plus noise, 8 kHz float32. ffmpeg is used as a signal generator only.
# usage: make_synthetic_mix.sh out.f32
set -eu
E=""
for h in 1 2 3 4 5 6 7 8 9 10; do E="$E+0.05/$h*sin(2*PI*$h*130*t+0.3*$h*sin(2*PI*5*t))"; done
for h in 1 2 3 4 5 6 7 8; do E="$E+between(t,1,3)*0.05/$h*sin(2*PI*$h*285*t+0.3*$h*sin(2*PI*4*t))"; done
for h in 1 2 3 4 5 6 7 8 9 10; do E="$E+between(t,2,4)*0.04/$h*sin(2*PI*$h*210*t+0.3*$h*sin(2*PI*6*t))"; done
E="${E#+}+0.01*(2*random(0)-1)"
ffmpeg -v error -nostdin -y -f lavfi -i "aevalsrc='$E':s=8000:d=4" -f f32le "$1"
