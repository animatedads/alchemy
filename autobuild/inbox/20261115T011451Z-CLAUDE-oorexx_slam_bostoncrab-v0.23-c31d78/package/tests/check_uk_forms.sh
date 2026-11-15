#!/bin/sh
# check_uk_forms.sh - every Ukrainian word form in tests/uk_forms.txt (the
# forms SLAM 450's commanders used, once listed by hand) must be read: it must
# be in the compiled lexicon.words. Guards the declension tables in compile.rex.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
[ -f lexicon.words ] || rexx compile.rex . > /dev/null || exit 1
grep "lang=uk" lexicon.words | cut -d'|' -f1 | sort -u > /tmp/ukforms_have.$$
missing=$(grep -v '^#' tests/uk_forms.txt | sort -u | comm -23 - /tmp/ukforms_have.$$)
rm -f /tmp/ukforms_have.$$
if [ -n "$missing" ]; then echo "FAIL Ukrainian forms not read:"; echo "$missing"; exit 1; fi
echo "PASS all $(grep -vc '^#' tests/uk_forms.txt) Ukrainian forms are read"
