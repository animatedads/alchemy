# Android / Termux

Matches the Rust Alchemy phone layout:

    OOREXX_SRC=$HOME/src/ooRexx
    OOREXX_BUILD=$HOME/build/oorexx-xcover-safe

Termux dependencies:

    pkg install clang tcl unzip

Then:

    ./tests/run_roundtrip.sh
