#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
lintdir="$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
# Verify the exact checker used to qualify this candidate.
[ "$(git hash-object "$lintdir/PitfallChecker.cls")" = e6ee19c34dd441170d8dcc023277b4042819463d ]
[ "$(git hash-object "$lintdir/SourceLint.cls")" = 7295efb10e6ff0b53315900eb26c9d747182c11c ]
logdir="$ALCHEMY_REPO_ROOT/packages/oorexx_logging_v0.7/src"
[ "$(sha256sum "$logdir/LoggingCore.cls" | cut -d' ' -f1)" = 62b3f6b5bd2ad21db01aa83736d440d96035729b8dcccf589982f8196b9537d6 ]
[ "$(sha256sum "$logdir/MethodInterposition.cls" | cut -d' ' -f1)" = 4f8edcf4f8ab8c838ddf0b26b26e5ca40bd110e2ced434e1c928d4247e1ea985 ]
cryptodir="$ALCHEMY_REPO_ROOT/packages/oorexx_crypto_v0.8.3/src"
[ "$(sha256sum "$cryptodir/crypto.cls" | cut -d' ' -f1)" = edd6fdfd2a08ac90fe9776c3d8c345526e814ec1c260d343a6a0215b6c905466 ]
export REXX_PATH="$PWD/src:$PWD/tools:$PWD/review:$lintdir:$logdir:$cryptodir${REXX_PATH:+:$REXX_PATH}"
sha256sum --check --quiet MANIFEST.sha256
sha256sum --check --quiet evidence/production-identity.sha256
sha256sum --check --quiet evidence/reviewer-recovered.sha256
for file in src/*.cls tests/*.rex tools/*.cls tools/*.rex review/game_audit.rex review/DiplomacyRichStubSource.cls; do
  rexx tests/lint.rex "$file"
done
rexx tests/board.rex
rexx tests/reference.rex
rexx tests/orders.rex
rexx tests/movement.rex data/movement-fixtures.txt 39
rexx tests/movement.rex data/datc-v3-movement.txt 130
rexx tests/season.rex data/datc-v3-season.txt 36
rexx tests/season.rex data/season-fixtures.txt 14
rexx tests/movement.rex review/datc-v3.4-additions-movement.txt 6
rexx tests/season.rex review/datc-v3.4-additions-season.txt 3
rexx tests/movement.rex review/datc-v3.4-strict-support-coast.txt 2
rexx tests/movement.rex review/datc-v3.4-sixth-order.txt 2

# Step 5 native full-game gate. Tests own this temporary directory.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
rexx tests/game.rex "$work"
sha256sum "$work"/HOLD.log "$work"/HOLD-replay.log "$work"/RANDOM.log "$work"/RANDOM-replay.log

# Step 6: press ON with exact replay and directed delivery assertions.
rexx tests/press.rex "$work"
sha256sum "$work"/PRESS-DIRECTED.log "$work"/PRESS-DIRECTED-replay.log "$work"/PRESS-FULL.log "$work"/PRESS-FULL-replay.log

# Step 5 review follow-up: rich source exercises retreats/builds/disbands.
rexx review/game_audit.rex 5 1000 RICH "$work/audit"
# Step 7 offline: provider protocol, isolation, one game year and replay.
rexx tests/player.rex "$work"
sha256sum "$work"/PLAYER.log "$work"/PLAYER-replay.log
# Trusted transport has no real network; fake curl verifies stdin and argv.
mkdir "$work/fake-bin"
cp tests/fake-curl.sh "$work/fake-bin/curl"
chmod +x "$work/fake-bin/curl"
PATH="$work/fake-bin:$PATH" rexx tests/transport.rex "$work"
