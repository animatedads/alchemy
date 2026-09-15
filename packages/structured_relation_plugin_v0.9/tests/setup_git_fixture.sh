#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?fixture path required}"
rm -rf "$ROOT"
mkdir -p "$ROOT"
cd "$ROOT"
git init -q
git config user.name 'Fixture Committer'
git config user.email fixture-committer@example.test
cat > crypto.cpp <<'SRC'
#include <cstring>
void copy_key(unsigned char *dst, const unsigned char *src, size_t len) {
    if (len <= 64) std::memcpy(dst, src, len);
}
SRC
cat > helper.c <<'SRC'
int add_one(int x) { return x + 1; }
SRC
cat > fast.S <<'SRC'
.text
.globl tiny_fast
tiny_fast:
    ret
SRC
cat > leak.c <<'SRC'
#include <stdlib.h>
void bad_alloc(size_t n) {
    void *p = malloc(n);
    if (n == 0) return NULL;
    return NULL;
}
void *transfer_alloc(size_t n) {
    void *p = malloc(n);
    return p;
}
void good_alloc(size_t n) {
    void *p = malloc(n);
    free(p);
}
SRC
git add crypto.cpp helper.c fast.S leak.c
GIT_AUTHOR_NAME='Alice Author' GIT_AUTHOR_EMAIL='alice@example.test' GIT_AUTHOR_DATE='2026-08-19T10:00:00+01:00' \
GIT_COMMITTER_NAME='Merge Maintainer' GIT_COMMITTER_EMAIL='merge@example.test' GIT_COMMITTER_DATE='2026-08-19T10:05:00+01:00' \
  git commit -q -m 'crypto: initial guarded copy' -m 'Keep the copy bounded by the local buffer capacity.'
cat > crypto.cpp <<'SRC'
#include <algorithm>
void copy_key(unsigned char *dst, const unsigned char *src, size_t len) {
    if (len <= 64) std::copy(src, src + len, dst);
}
SRC
git add crypto.cpp
GIT_AUTHOR_NAME='Bob Perf' GIT_AUTHOR_EMAIL='bob@example.test' GIT_AUTHOR_DATE='2026-08-20T09:00:00+01:00' \
GIT_COMMITTER_NAME='Merge Maintainer' GIT_COMMITTER_EMAIL='merge@example.test' GIT_COMMITTER_DATE='2026-08-20T09:10:00+01:00' \
  git commit -q -m 'crypto: use range copy semantics' -m 'Preserve empty-range semantics while keeping the same bound.'
