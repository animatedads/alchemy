#!/usr/bin/env sh
# Shared test-harness Python capability resolver.
if [ -n "${LLM_GOPHER_PYTHON:-}" ]; then
  PYTHON="$LLM_GOPHER_PYTHON"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  PYTHON="$(command -v python)"
else
  echo 'SKIP: no Python interpreter available (tried LLM_GOPHER_PYTHON, python3, python)' >&2
  exit 77
fi
export PYTHON
