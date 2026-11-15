#!/bin/sh
# run_matrix.sh -- start the local test fixtures, run the browser UI tests (signed out and signed on), stop.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
KIT=$(cd "$(dirname "$0")/.." && pwd)
cd "$KIT" || exit 2
mkdir -p var/tls
if [ ! -f var/tls/cert.pem ]; then
  echo "run_matrix: making the fixtures' self-signed 127.0.0.1 certificate (var/tls)"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=127.0.0.1 \
    -addext subjectAltName=IP:127.0.0.1 -keyout var/tls/key.pem -out var/tls/cert.pem 2>/dev/null || exit 2
  chmod 600 var/tls/key.pem
fi
sh bin/kit.sh rexx fixtures/fixture_host.rex "$KIT" > var/fixture_host.out 2>&1 &
HOST=$!
trap 'kill $HOST 2>/dev/null' EXIT INT TERM
i=0
until grep -q FIXTURES_READY var/fixture_host.out 2>/dev/null; do
  i=$((i+1))
  if [ $i -gt 60 ] || ! kill -0 $HOST 2>/dev/null; then
    echo "run_matrix: the fixture host did not start; see var/fixture_host.out" >&2
    tail -20 var/fixture_host.out >&2
    exit 2
  fi
  sleep 0.5
done
sleep 1
echo "run_matrix: fixtures up ($(grep FIXTURES_READY var/fixture_host.out))"
# results also kept in var/matrix.out, so they can be read back later (e.g. over the computer link)
{ sh bin/kit.sh rexx tests/test_uikit.rex; echo $? > var/matrix.rc; sh bin/kit.sh rexx tests/test_cli.rex; echo $? >> var/matrix.rc; } 2>&1 | tee var/matrix.out
# fail if either suite failed
! grep -qv '^0$' var/matrix.rc
