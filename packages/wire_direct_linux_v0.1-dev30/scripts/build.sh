#!/bin/sh
set -eu
CC=${CC:-cc}
mkdir -p build
$CC -std=c11 -Wall -Wextra -Werror -Iinclude src/wire_test_renderer.c tests/test_core.c -o build/test_core
./build/test_core
$CC -std=c11 -Wall -Wextra -Werror -Iinclude src/wire_filter_window.c tests/test_filter_window.c -o build/test_filter_window
./build/test_filter_window
$CC -std=c11 -Wall -Wextra -Werror -Iinclude src/wire_test_renderer.c src/wire_ui_loader.c tests/test_ui_loader.c -o build/test_ui_loader
./build/test_ui_loader

# Real JavaScript qualification is optional only when QuickJS-NG development
# artifacts are unavailable. Set QUICKJS_INCLUDE and QUICKJS_LIB explicitly.
if [ -n "${QUICKJS_INCLUDE:-}" ] && [ -n "${QUICKJS_LIB:-}" ] && [ -f "$QUICKJS_INCLUDE/quickjs.h" ] && [ -f "$QUICKJS_LIB/libqjs.a" ]; then
  $CC -std=c11 -Wall -Wextra -Werror -Iinclude -I"$QUICKJS_INCLUDE" src/wire_filter_window.c src/wire_quickjs_predicate.c tests/test_quickjs_filter.c "$QUICKJS_LIB/libqjs.a" -lm -ldl -lpthread -o build/test_quickjs_filter
  ./build/test_quickjs_filter
else
  echo 'SKIP real QuickJS filtered-window qualification: set QUICKJS_INCLUDE and QUICKJS_LIB'
fi
if pkg-config --exists gtk4 2>/dev/null; then
  $CC -std=c11 -Wall -Wextra -Werror -DWIRE_WITH_GTK4 -Iinclude $(pkg-config --cflags gtk4) -c src/wire_gtk4_renderer.c -o build/wire_gtk4_renderer.o
  $CC -std=c11 -Wall -Wextra -Werror -DWIRE_WITH_GTK4 -Iinclude $(pkg-config --cflags gtk4) examples/wire_demo.c src/wire_gtk4_renderer.c $(pkg-config --libs gtk4) -o build/wire_demo
  $CC -std=c11 -Wall -Wextra -Werror -DWIRE_WITH_GTK4 -Iinclude $(pkg-config --cflags gtk4) examples/wire_mailreader_demo.c src/wire_ui_loader.c src/wire_gtk4_renderer.c $(pkg-config --libs gtk4) -o build/wire_mailreader_demo
  echo 'PASS GTK4 boundary compile + demo hosts link (wire_demo + wire_mailreader_demo)'
else
  echo 'SKIP GTK4 boundary compile: gtk4 development package not installed'
fi

python3 tests/test_imap_adapter_static.py
python3 tests/test_uid_window.py
python3 tests/test_mailreader_controller_static.py
python3 tests/test_projection_static.py
python3 tests/test_architecture_boundaries.py
python3 tests/test_semantic_projection_static.py
python3 tests/test_dev7_boundaries.py
python3 tests/test_interaction_port_static.py
python3 tests/test_observation_port_static.py
python3 tests/test_assessment_view_static.py
python3 tests/test_visible_assessment_static.py

python3 tests/test_mailreader_behaviour_static.py

python3 tests/test_application_model_static.py
python3 tests/test_builder_binding_shape.py
python3 tests/test_builder_session_static.py

python3 tests/test_language_block_static.py
python3 tests/test_javascript_alchemy_contract.py

python3 tests/test_completion_contract.py
python3 tests/test_completion_static.py
python3 tests/test_ui_proxy_static.py

python3 scripts/qualify-gtk-demo-static.py

python3 tests/test_renderer_event_port_static.py
