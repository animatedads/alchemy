#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gtk="$root/src/wire_gtk4_renderer.c"
host="$root/examples/wire_mailreader_demo.c"
grep -q '"RangeRequested","start",requested' "$gtk"
# The native scroll callback must dispatch demand, not call show_range_r itself.
body=$(awk '/static void virtual_scroll_changed/{f=1} f{print} /static gboolean virtual_wheel/{exit}' "$gtk")
printf '%s\n' "$body" | grep -q 's->dispatch'
if printf '%s\n' "$body" | grep -q 'show_range_r'; then
  echo 'FAIL: GTK scroll callback still pulls source directly' >&2; exit 1
fi
grep -q '"RangeRequested"' "$host"
grep -q 'show_list_range(a->renderer,a->messages,start,a->message_window)' "$host"
grep -q 'count="100"' "$root/examples/mailreader/mailreader.xml"
grep -q 'count=100' "$root/examples/mailreader/mailreader.wire"
echo 'wire-virtual-demand-authority=PASS semantic=RangeRequested resident=100 backing=200000'
