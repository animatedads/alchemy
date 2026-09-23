param([string]$Build="build")
$ErrorActionPreference="Stop"
cmake -S . -B $Build -A x64
cmake --build $Build --config Release
