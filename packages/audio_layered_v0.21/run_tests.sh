#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX=${REXX:-rexx}

(cd "$HERE/tests" && "$REXX" test_audio_core.rex)
(cd "$HERE/tests" && "$REXX" test_multilayer_transcript.rex)
(cd "$HERE/tests" && "$REXX" test_fragment_lattice.rex)
(cd "$HERE/tests" && "$REXX" test_pitch_layer.rex)
(cd "$HERE/tests" && "$REXX" test_speaker_embedding_layer.rex)
(cd "$HERE/tests" && "$REXX" test_music_fingerprint_layer.rex)
(cd "$HERE/tests" && "$REXX" test_ml_runtime.rex)
(cd "$HERE/tests" && "$REXX" test_audio_scene_alignment.rex)
(cd "$HERE/tests" && "$REXX" test_processing_toolkit.rex)
(cd "$HERE/tests" && "$REXX" test_camera_audio_interop.rex)
python3 -m py_compile "$HERE/adapters/speechbrain_ecapa.py" "$HERE/adapters/acoustid_chromaprint.py" "$HERE/adapters/python_audio_reference_service.py" "$HERE/adapters/audio_ml_foreign.py" "$HERE/adapters/audio_asr_foreign.py" "$HERE/tests/audio_ml_fixture.py" "$HERE/adapters/audio_processing_foreign.py" "$HERE/tests/audio_processing_fixture.py"
PYTHONPATH="$HERE" python3 "$HERE/tests/test_asr_preparation.py"
echo 'PYTHON ADAPTER SYNTAX: OK'

if [ -n "${FOREIGN_RUNTIME_HOME:-}" ] && [ -n "${RUNTIME_REFERENCE_SRC:-}" ]; then
  fr_rexx="$FOREIGN_RUNTIME_HOME/rexx"
  fr_build="$FOREIGN_RUNTIME_HOME/build"
  if [ ! -f "$fr_rexx/foreign.cls" ]; then echo 'FOREIGN_RUNTIME_HOME missing rexx/foreign.cls' >&2; exit 1; fi
  if [ ! -f "$fr_build/libforeign_runtime.so" ]; then echo 'FOREIGN_RUNTIME_HOME missing build/libforeign_runtime.so' >&2; exit 1; fi
  old_rexx_path=${REXX_PATH:-}
  old_ld_library_path=${LD_LIBRARY_PATH:-}
  if [ -n "$old_rexx_path" ]; then REXX_PATH="$HERE:$fr_rexx:$RUNTIME_REFERENCE_SRC:$old_rexx_path"; else REXX_PATH="$HERE:$fr_rexx:$RUNTIME_REFERENCE_SRC"; fi
  if [ -n "$old_ld_library_path" ]; then LD_LIBRARY_PATH="$fr_build:$old_ld_library_path"; else LD_LIBRARY_PATH="$fr_build"; fi
  export REXX_PATH LD_LIBRARY_PATH
  (cd "$HERE/tests" && "$REXX" test_ffmpeg_foreign_runtime.rex)
  if [ -n "${AUDIO_CAMERA_FIXTURE:-}" ]; then (cd "$HERE/tests" && "$REXX" test_camera_audio_decode.rex); else echo 'AUDIO CAMERA NATIVE DECODE: SKIPPED (set AUDIO_CAMERA_FIXTURE)'; fi
  REXX_PATH=$old_rexx_path
  LD_LIBRARY_PATH=$old_ld_library_path
  export REXX_PATH LD_LIBRARY_PATH
else
  echo 'AUDIO FFMPEG FOREIGN RUNTIME: SKIPPED (set FOREIGN_RUNTIME_HOME and RUNTIME_REFERENCE_SRC)'
fi


if [ -n "${FOREIGN_RUNTIME_HOME:-}" ] && [ -n "${RUNTIME_REFERENCE_SRC:-}" ] && [ -f "$FOREIGN_RUNTIME_HOME/rexx/python_foreign.cls" ] && [ -f "$FOREIGN_RUNTIME_HOME/build/libforeign_python.so" ]; then
  old_rexx_path=${REXX_PATH:-}
  old_ld_library_path=${LD_LIBRARY_PATH:-}
  old_pythonpath=${PYTHONPATH:-}
  maths_path=${MATHS_REXX_PATH:-}
  if [ -n "$old_rexx_path" ]; then REXX_PATH="$HERE:$FOREIGN_RUNTIME_HOME/rexx:$RUNTIME_REFERENCE_SRC:$old_rexx_path"; else REXX_PATH="$HERE:$FOREIGN_RUNTIME_HOME/rexx:$RUNTIME_REFERENCE_SRC"; fi
  if [ -n "$maths_path" ]; then REXX_PATH="$REXX_PATH:$maths_path"; fi
  if [ -n "$old_ld_library_path" ]; then LD_LIBRARY_PATH="$FOREIGN_RUNTIME_HOME/build:$old_ld_library_path"; else LD_LIBRARY_PATH="$FOREIGN_RUNTIME_HOME/build"; fi
  if [ -n "$old_pythonpath" ]; then PYTHONPATH="$HERE/adapters:$HERE/tests:$old_pythonpath"; else PYTHONPATH="$HERE/adapters:$HERE/tests"; fi
  export REXX_PATH LD_LIBRARY_PATH PYTHONPATH
  (cd "$HERE/tests" && "$REXX" test_foreign_python_sequence_support.rex)
  if [ -n "${MATHS_REXX_PATH:-}" ] && [ -n "${MCGILL_FIXTURE:-}" ]; then
    (cd "$HERE/tests" && MCGILL_FIXTURE="$MCGILL_FIXTURE" "$REXX" test_processing_foreign_python.rex)
  else
    echo 'AUDIO PROCESSING FOREIGNPYTHON: SKIPPED (set MATHS_REXX_PATH and MCGILL_FIXTURE)'
  fi
  if [ -n "${MATHS_REXX_PATH:-}" ]; then
    (cd "$HERE/tests" && "$REXX" test_processing_v020.rex)
    (cd "$HERE/tests" && "$REXX" test_processing_streaming_v021.rex)
  else
    echo 'AUDIO PROCESSING v0.20/v0.21: SKIPPED (set MATHS_REXX_PATH)'
  fi
  (cd "$HERE/tests" && "$REXX" test_foreign_python_ml_provider.rex)
  (cd "$HERE/tests" && "$REXX" test_foreign_python_speechbrain_runtime.rex)
  (cd "$HERE/tests" && "$REXX" test_ml_material_zero_copy.rex)
  (cd "$HERE/tests" && "$REXX" test_ml_tensor_binding.rex)
  if [ -n "${AUDIO_CAMERA_FIXTURE:-}" ]; then
    (cd "$HERE/tests" && "$REXX" test_camera_audio_tensor_material.rex)
    (cd "$HERE/tests" && "$REXX" test_camera_asr_preparation.rex)
  else
    echo 'AUDIO CAMERA TENSOR MATERIAL: SKIPPED (set AUDIO_CAMERA_FIXTURE)'
    echo 'AUDIO CAMERA ASR PREPARATION: SKIPPED (set AUDIO_CAMERA_FIXTURE)'
  fi
  REXX_PATH=$old_rexx_path
  LD_LIBRARY_PATH=$old_ld_library_path
  PYTHONPATH=$old_pythonpath
  export REXX_PATH LD_LIBRARY_PATH PYTHONPATH
else
  echo 'AUDIO FOREIGNPYTHON ML: SKIPPED (Foreign Runtime Python provider unavailable)'
fi


if [ -n "${RUNTIME_REFERENCE_SRC:-}" ]; then
  # json.cls and socket.cls are shipped with ooRexx.  Resolve them from the
  # active Rexx installation rather than treating JSON as an external package.
  runtime_rexx_dir="${OOREXX_REXX_DIR:-}"
  if [ -z "$runtime_rexx_dir" ]; then
    rexx_cmd=$(command -v "$REXX" 2>/dev/null || true)
    if [ -n "$rexx_cmd" ]; then runtime_rexx_dir=$(CDPATH= cd -- "$(dirname -- "$rexx_cmd")" && pwd); fi
  fi
  if [ -z "$runtime_rexx_dir" ] || [ ! -f "$runtime_rexx_dir/json.cls" ] || [ ! -f "$runtime_rexx_dir/socket.cls" ]; then
    echo 'AUDIO RUNTIME REFERENCE WORKERS: FAILED (active ooRexx runtime json.cls/socket.cls not found)' >&2
    exit 1
  fi
  portfile=$(mktemp)
  cleanup() {
    if [ -n "${worker_pid:-}" ]; then kill "$worker_pid" 2>/dev/null || true; fi
    rm -f "$portfile"
  }
  trap cleanup EXIT INT TERM
  AUDIO_REFERENCE_TEST_STUB=1 python3 "$HERE/adapters/python_audio_reference_service.py" --port 0 --port-file "$portfile" &
  worker_pid=$!
  i=0
  while [ ! -s "$portfile" ]; do
    i=$((i+1))
    if [ "$i" -gt 100 ]; then echo 'audio reference worker failed to start' >&2; exit 1; fi
    sleep 0.05
  done
  AUDIO_REFERENCE_TEST_PORT=$(cat "$portfile")
  export AUDIO_REFERENCE_TEST_PORT
  old_rexx_path=${REXX_PATH:-}
  if [ -n "$old_rexx_path" ]; then REXX_PATH="$RUNTIME_REFERENCE_SRC:$runtime_rexx_dir:$old_rexx_path"; else REXX_PATH="$RUNTIME_REFERENCE_SRC:$runtime_rexx_dir"; fi
  export REXX_PATH
  (cd "$HERE/tests" && "$REXX" test_runtime_reference_workers.rex)
  kill "$worker_pid" 2>/dev/null || true
  worker_pid=
  trap - EXIT INT TERM
  rm -f "$portfile"
else
  echo 'AUDIO RUNTIME REFERENCE WORKERS: SKIPPED (set RUNTIME_REFERENCE_SRC)'
fi
