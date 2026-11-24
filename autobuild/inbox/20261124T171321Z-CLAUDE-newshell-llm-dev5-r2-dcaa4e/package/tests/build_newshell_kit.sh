#!/bin/bash
# build_newshell_kit.sh -- the newshell_llm v0.1-dev5 agent kit for Ubuntu 22.04 (cats1, cats2),
# built inside the jammy chroot. Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 24 November 2026.
# No LLM client on the node: ShellLlm.cls and the Anthropic packages are not in the kit.
set -euo pipefail
S=/build/nssrc; N=$S/newshell; K=/build/nskit/opt/newshell; R=/usr/local
rm -rf /build/nskit; mkdir -p $K/bin $K/src $K/lib $K/etc $K/tests
make -s -C $S/process/native OOREXX_ROOT=$R
cp $S/process/native/librxprocessnative.so $K/lib/
for f in ShellObject ShellLog ShellSecurity ShellProposal ShellJobs FileSystem Computer ShellNet ShellHost ShellAgent; do cp $N/src/$f.cls $K/src/; done
cp $S/process/src/*.cls $S/process/src/providers/*.cls $K/src/
cp $S/LoggingCore.cls $S/MethodInterposition.cls $S/crypto.cls $K/src/
cp $N/bin/nsh-agent.rex $K/bin/; cp $N/etc/cats1.policy $N/etc/agent.conf $K/etc/; cp $N/tests/kit_selftest.sh $K/tests/
cat > $K/bin/nsh-agent <<'E2'
#!/bin/sh
# nsh-agent ... -- newshell for an agent (Codex) on this MU. See /opt/newshell/KIT.txt.
K=/opt/newshell
REXX_PATH="$K/src:/usr/local/bin"; LD_LIBRARY_PATH="$K/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH LD_LIBRARY_PATH
exec /usr/local/bin/rexx "$K/bin/nsh-agent.rex" "$@"
E2
chmod 755 $K/bin/nsh-agent $K/tests/kit_selftest.sh
printf '%s\n' 'newshell_llm v0.1-dev5 agent kit for Ubuntu 22.04 (built 2026-11-24 in a jammy chroot against ooRexx 5.3.0 at /usr/local).' \
 'Codex runs: /opt/newshell/bin/nsh-agent describe | check FILE | run FILE [--follows JOB] | jobs | report JOB' \
 'Config /opt/newshell/etc/agent.conf (state /var/lib/newshell), policy /opt/newshell/etc/cats1.policy.' \
 'Sources: newshell_llm v0.1-dev5, oorexx_process v0.1-dev2, oorexx_logging v0.7 (LoggingCore, MethodInterposition), oorexx_crypto v0.1.' \
 'Uses /opt/mu-tools (the MU audit) when present. No LLM client and no build tools on the node.' \
 'Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).' > $K/KIT.txt
cd /build/nskit && find opt -type f ! -name SHA256SUMS | sort | xargs sha256sum > /build/nskit.sums && mv /build/nskit.sums opt/newshell/SHA256SUMS
echo "== ldd"; ldd $K/lib/librxprocessnative.so | grep -v "linux-vdso\|ld-linux" | awk '{print "   "$1" "$3}'
tar -czf /build/newshell-kit-v0.1-dev5-jammy.tar.gz -C /build/nskit opt
sha256sum /build/newshell-kit-v0.1-dev5-jammy.tar.gz
