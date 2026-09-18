#!/bin/sh
set -eu
say(){ printf '%s\n' "$*"; }
die(){ say "ERROR: $*" >&2; exit 1; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); cd "$ROOT"
rexx_bin=$(command -v rexx 2>/dev/null || true); dotnet_bin=$(command -v dotnet 2>/dev/null || true)
[ -n "$rexx_bin" ] || die "rexx not found on PATH"; [ -n "$dotnet_bin" ] || die "dotnet not found on PATH"
FOREIGN="$ROOT/dependencies/alchemy_foreign_object_v0.2/src"; OBJECTS="$ROOT/dependencies/alchemy_objects_v0.8/src"; SUPPORT="$ROOT/dependencies/oorexx_runtime_support"
need_file(){ [ -f "$1" ] || die "bundled dependency missing: $1"; }
need_file "$FOREIGN/AlchemyForeignObject.cls"; need_file "$OBJECTS/AlchemyObject.cls"; need_file "$OBJECTS/AlchemySecurity.cls"; need_file "$OBJECTS/AlchemyLockedMethod.cls"; need_file "$OBJECTS/AlchemyEvidence.cls"; need_file "$SUPPORT/crypto.cls"; need_file "$SUPPORT/json.cls"
say "Alchemy root       : $ROOT"; say "rexx               : $rexx_bin"; say "dotnet             : $dotnet_bin"; say "foreign-object base: $FOREIGN/AlchemyForeignObject.cls"; say "AlchemyObject      : $OBJECTS/AlchemyObject.cls"; say "runtime support    : $SUPPORT"
./build-native.sh
say "native bridge      : $ROOT/build/libalchemy_rexx_bridge.so"; say "CLR package        : $ROOT/build/libalchemy_clr_package.so"
dotnet build dotnet/Alchemy.OoRexx.Probe/Alchemy.OoRexx.Probe.csproj -c Release
export LD_LIBRARY_PATH="$ROOT/build${OOREXX_LIB:+:$OOREXX_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; export PATH="$ROOT/build${PATH:+:$PATH}"
export REXX_PATH="$ROOT/rexx:$FOREIGN:$OBJECTS:$SUPPORT${REXX_PATH:+:$REXX_PATH}"
say "REXX_PATH          : $REXX_PATH"; say "LD_LIBRARY_PATH    : $LD_LIBRARY_PATH"
dotnet run --project dotnet/Alchemy.OoRexx.Probe/Alchemy.OoRexx.Probe.csproj -c Release --no-build
