#!/bin/sh
set -eu
source_words=${1:?Usage: qualify_harbour_words.sh harbour_heights.words [expected_sha]}
expected_sha=${2:-3243f644556f084bf8f524b6b080f8b539fdf5986622b4b207a3a690c32a102e}
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
command -v rexx >/dev/null || { echo 'ooRexx runtime unavailable' >&2; exit 4; }
actual=$(sha256sum "$source_words" | awk '{print $1}')
[ "$actual" = "$expected_sha" ] || { echo 'SOURCE_HASH_MISMATCH' >&2; exit 5; }
REXX_PATH="$script_dir${REXX_PATH:+:$REXX_PATH}"; export REXX_PATH
rexx "$script_dir/test_harbour_words.rex" "$source_words"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
num=0
check_reject() {
  label=$1
  if rexx "$script_dir/test_loader.rex" "$work/fake.words" > "$work/log" 2>&1; then
    echo "SOURCE_TAMPER_NOT_REJECTED: $label" >&2
    exit 6
  fi
  if ! grep -Eq 'Error [0-9]+|Invalid|FAIL' "$work/log"; then
    echo "FAIL_WITHOUT_REASON $label" >&2
    cat "$work/log" >&2
    exit 7
  fi
  num=$((num+1)); printf 'REJECTED %s\n' "$label"
}
sed 's/grid mga 56/grid mga 55/' "$source_words" > "$work/fake.words"; check_reject forged_crs
sed 's/across 226/across 225/' "$source_words" > "$work/fake.words"; check_reject forged_columns
sed 's/step 50/step 500/' "$source_words" > "$work/fake.words"; check_reject forged_resolution
sed '0,/  row 68.8/s//  row BAD/' "$source_words" > "$work/fake.words"; check_reject nonnumeric_sample
awk '$1=="row" && ++n==204 {next}{print}' "$source_words" > "$work/fake.words"; check_reject missing_last_row
sed '/^end$/d' "$source_words" > "$work/fake.words"; check_reject missing_end
sed 's/^end$/end\ninjected_landmass/' "$source_words" > "$work/fake.words"; check_reject post_end_injection
awk '$1=="grid"{print} {print}' "$source_words" > "$work/fake.words"; check_reject duplicate_grid
awk '$1=="height"{print} {print}' "$source_words" > "$work/fake.words"; check_reject duplicate_title
awk '$1=="row"&&!done {print; print "  place forged at 0 0 height 300";done=1;next} {print}' "$source_words" > "$work/fake.words"; check_reject late_place_injection
awk '$1=="row"&&!done {$NF="";done=1} {print}' "$source_words" > "$work/fake.words"; check_reject truncated_row
sed 's/^end$/  water yes\nend/' "$source_words" > "$work/fake.words"; check_reject unknown_semantic_declaration
[ "$num" -eq 12 ] || exit 9
printf 'HARBOUR_HEIGHT_WORDS_NEGATIVE_PASS %s/12\n' "$num"
