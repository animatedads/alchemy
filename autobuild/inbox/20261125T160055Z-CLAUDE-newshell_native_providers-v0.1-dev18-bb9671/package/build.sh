#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${REXX_INCLUDE:=/usr/local/include}"
mkdir -p lib
${CXX:-g++} -std=c++11 -Wall -Wextra -Werror -O2 -fPIC -shared -I"$REXX_INCLUDE" native/posix.cpp -o lib/librxshellposix.so
