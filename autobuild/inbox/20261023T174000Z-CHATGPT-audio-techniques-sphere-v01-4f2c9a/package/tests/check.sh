#!/bin/sh
set -eu
test -s SPHERE.md
test -s integration.json
grep -q 'Maths v0.17' SPHERE.md
grep -q 'Media Methodology Index' SPHERE.md
echo 'PASS: sphere manifest and provenance present'
