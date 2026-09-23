#!/bin/sh
# Sourced helper for exact ooRexx and host metadata discovery.
av9_find_rexx(){
  if [ -n "${OOREXX_REXX:-}" ]; then printf '%s\n' "$OOREXX_REXX"; return; fi
  if command -v rexx >/dev/null 2>&1; then command -v rexx; return; fi
  if [ -x /usr/local/bin/rexx ]; then printf '%s\n' /usr/local/bin/rexx; return; fi
  return 1
}
av9_oorexx_prefix(){
  rexx=$1
  if [ -n "${OOREXX_PREFIX:-}" ] && [ -f "$OOREXX_PREFIX/include/oorexxapi.h" ]; then printf '%s\n' "$OOREXX_PREFIX"; return; fi
  p=$(CDPATH= cd -- "$(dirname "$rexx")/.." 2>/dev/null && pwd || true)
  if [ -n "$p" ] && [ -f "$p/include/oorexxapi.h" ]; then printf '%s\n' "$p"; return; fi
  [ -f /usr/local/include/oorexxapi.h ] && { printf '%s\n' /usr/local; return; }
  [ -f /usr/include/oorexxapi.h ] && { printf '%s\n' /usr; return; }
  return 1
}
av9_oorexx_libdir(){
  p=$1
  [ -d "$p/lib64" ] && { printf '%s\n' "$p/lib64"; return; }
  printf '%s\n' "$p/lib"
}
av9_check_rexx(){
  rexx=$1
  [ -x "$rexx" ] || { echo "FAIL exact ooRexx not executable: $rexx" >&2; return 2; }
  ver=$($rexx -v 2>&1 | sed -n '1p')
  case "$ver" in
    *"Open Object Rexx Version 5.3.0 r13196 - Internal Test Version"*) ;;
    *) echo "FAIL ooRexx runtime mismatch: $ver" >&2; return 2;;
  esac
}
av9_glibc(){ getconf GNU_LIBC_VERSION 2>/dev/null || ldd --version 2>/dev/null | sed -n '1p' || printf 'unknown\n'; }
