#!/bin/sh
set -eu
cd "$(dirname "$0")"
cc=${CC:-gcc}
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -o make_spatial_fixture make_spatial_fixture.c -lm
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -o make_tf_mask_fixture make_tf_mask_fixture.c -lm
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -o measure_tone measure_tone.c -lm
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -o make_edge_calibration_fixture make_edge_calibration_fixture.c -lm
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -o make_loud_echo_fixture make_loud_echo_fixture.c -lm
sha256sum make_spatial_fixture make_tf_mask_fixture measure_tone make_edge_calibration_fixture make_loud_echo_fixture
