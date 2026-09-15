#!/bin/sh
set -eu
GOPHER=${GOPHER:?set GOPHER to a v0.17+ gopher launcher}
"$GOPHER" --profile java context java --full > /tmp/java-sphere-context.$$
grep -q '"class": "OPENED"' /tmp/java-sphere-context.$$
grep -q '"java.lessons"' /tmp/java-sphere-context.$$
grep -q '"source.java.examine"' /tmp/java-sphere-context.$$
"$GOPHER" --profile java search JMS --sphere java --corpus java.lessons > /tmp/java-sphere-search.$$
grep -q '"class": "FOUND"' /tmp/java-sphere-search.$$
rm -f /tmp/java-sphere-context.$$ /tmp/java-sphere-search.$$
echo "PASS JAVA SPHERE v0.1"
