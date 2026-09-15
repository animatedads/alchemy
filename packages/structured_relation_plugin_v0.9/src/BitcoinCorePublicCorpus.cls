/*
 * BitcoinCorePublicCorpus v0.8
 *
 * A checked, public evidence snapshot used to exercise the source-history model.
 * Snapshot date: 2026-08-20.  It intentionally stores distinct claims and
 * observations rather than flattening PR prose into a single rationale.
 */

::class BitcoinCorePublicCorpus public

::method build class
  retrieved = "2026-08-20T12:51:00+01:00"
  repo = .GitHubRepositoryEvidence~new("bitcoin/bitcoin", "https://github.com/bitcoin/bitcoin", retrieved)
  repo~addPullRequest(self~pr35688(retrieved))
  repo~addPullRequest(self~pr31868(retrieved))
  repo~addPullRequest(self~pr34083(retrieved))
  return repo

::method pr35688 class private
  use arg retrieved
  url = "https://github.com/bitcoin/bitcoin/pull/35688"
  pr = .GitHubPullRequestEvidence~new("bitcoin/bitcoin", 35688, "crypto: accept empty HMAC keys", -
       "OPEN", .false, "l0rinc", -
       "81405fc7abbd1889f3978b8924e7acbe12b3403b", -
       "dc67c4cc39062875c6571f9188abc83cfc6e6b90", url, retrieved)
  pr~addLabel("Utils/log/libs")

  bodySource = .GitHubEvidenceSource~new("PULL_REQUEST_BODY", url, "PR#35688", "l0rinc", "2026-07-08T22:46:49Z", "", pr~headSha)
  pr~addClaim(.GitHubClaimEvidence~new("PROBLEM", -
      "Empty HMAC key vectors can expose a null data pointer to a zero-length memcpy and trigger UBSan.", -
      "AUTHOR_CLAIM", bodySource, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("FIX_INTENT", -
      "Use std::copy for defined empty-range semantics and remove empty-input fuzz workarounds.", -
      "AUTHOR_CLAIM", bodySource, "DIRECT_SOURCE"))

  reviewSource = .GitHubEvidenceSource~new("PR_REVIEW_COMMENT", -
      url || "#discussion_r3550259003", "discussion_r3550259003", "maflcko", -
      "2026-07-09T08:56:38Z", "src/crypto/hmac_sha256.cpp", pr~headSha)
  reviewClaim = .GitHubClaimEvidence~new("REVIEW_RATIONALE", -
      "Reviewer prefers std::copy for type checking and defined empty-source-range semantics, while expecting equivalent generated code.", -
      "REVIEW_OBSERVATION", reviewSource, "DIRECT_SOURCE")
  pr~addReview(reviewClaim)

  review2Source = .GitHubEvidenceSource~new("PR_REVIEW", -
      url || "#pullrequestreview-4661456996", "review-4661456996", "maflcko", -
      "2026-07-09T09:59:15Z", "", pr~headSha)
  review2 = .GitHubClaimEvidence~new("EVIDENCE_QUALITY", -
      "Reviewer considers the change reasonable but says the earlier explanation mixed distinct topics and should be made more precise.", -
      "REVIEW_OBSERVATION", review2Source, "DIRECT_SOURCE")
  pr~addReview(review2)

  diffSource = .GitHubEvidenceSource~new("PR_DIFF", url, "PR#35688-diff", "l0rinc", retrieved, "src/crypto/hmac_sha256.cpp", pr~headSha)
  beforeLoc = .RemoteCodeLocation~new("bitcoin/bitcoin", pr~baseSha, "src/crypto/hmac_sha256.cpp", 15, 15, -
      "https://github.com/bitcoin/bitcoin/blob/" || pr~baseSha || "/src/crypto/hmac_sha256.cpp", "CHMAC_SHA256::CHMAC_SHA256")
  afterLoc = .RemoteCodeLocation~new("l0rinc/bitcoin", pr~headSha, "src/crypto/hmac_sha256.cpp", 16, 16, -
      "https://github.com/l0rinc/bitcoin/blob/" || pr~headSha || "/src/crypto/hmac_sha256.cpp", "CHMAC_SHA256::CHMAC_SHA256")

  argsBefore = .array~of("rkey", "key", "keylen")
  beforeProps = .table~new
  beforeProps["sensitiveDomain"] = "CRYPTOGRAPHIC_KEY_MATERIAL"
  beforeProps["guard"] = "keylen <= 64"
  beforeProps["destinationExtent"] = 64
  beforeProps["lengthExpression"] = "keylen"
  before = .CodeOperationEvidence~new("BYTE_COPY", "memcpy", beforeLoc, argsBefore, beforeProps, diffSource)

  argsAfter = .array~of("key", "key + keylen", "rkey")
  afterProps = .table~new
  afterProps["sensitiveDomain"] = "CRYPTOGRAPHIC_KEY_MATERIAL"
  afterProps["guard"] = "keylen <= 64"
  afterProps["destinationExtent"] = 64
  afterProps["rangeSemantics"] = "EMPTY_RANGE_DEFINED"
  after = .CodeOperationEvidence~new("RANGE_COPY", "std::copy", afterLoc, argsAfter, afterProps, diffSource)

  change = .CodeChangeEvidence~new(before, after, pr)
  do claim over pr~claims
    change~addClaim(claim)
  end
  do review over pr~reviews
    change~addReviewEvidence(review)
  end
  testClaim = .GitHubClaimEvidence~new("TEST_COVERAGE", -
      "The PR adds empty-key HMAC test vectors and allows fuzz targets to exercise empty byte vectors.", -
      "DIFF_OBSERVATION", diffSource, "DIRECT_SOURCE")
  change~addTestEvidence(testClaim)
  change~annotate("component", "crypto/hmac")
  pr~addCodeChange(change)
  return pr

::method pr31868 class private
  use arg retrieved
  url = "https://github.com/bitcoin/bitcoin/pull/31868"
  pr = .GitHubPullRequestEvidence~new("bitcoin/bitcoin", 31868, "[IBD] specialize block serialization", -
       "OPEN", .true, "l0rinc", -
       "baa554f7089d8ce8ecb11e78ae097c10bfa85d8d", -
       "41ef25fcbaf2c3d14f901ef3f56311a2d396a3d8", url, retrieved)
  pr~addLabel("Needs rebase")
  body = .GitHubEvidenceSource~new("PULL_REQUEST_BODY", url, "PR#31868", "l0rinc", "2025-02-14T16:48:23Z", "", pr~headSha)
  pr~addClaim(.GitHubClaimEvidence~new("PERFORMANCE_INTENT", -
      "Specialize common single-byte serialization paths discovered through IBD profiling and block serialization benchmarks.", -
      "AUTHOR_CLAIM", body, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("MEMORY_OPERATION_EFFECT", -
      "The proposed specialization lets CSHA256 single-byte writes avoid the general memcpy path.", -
      "AUTHOR_CLAIM", body, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("MEASUREMENT", -
      "Reported benchmarks show substantial serialization microbenchmark gains and about a two percent IBD gain in the described setup.", -
      "AUTHOR_MEASUREMENT", body, "SOURCE_REPORTED"))
  pr~addClaim(.GitHubClaimEvidence~new("UNCERTAINTY", -
      "The PR remains draft pending remeasurement and simplification after other merges.", -
      "AUTHOR_CAVEAT", body, "DIRECT_SOURCE"))
  return pr

::method pr34083 class private
  use arg retrieved
  url = "https://github.com/bitcoin/bitcoin/pull/34083"
  pr = .GitHubPullRequestEvidence~new("bitcoin/bitcoin", 34083, "Add initial vectorized chacha20 implementation for 2-3x speedup", -
       "OPEN", .true, "theuni", -
       "13891a8a685d255cb13dd5018e3d5ccc18b07c34", -
       "5155730de55bdbada706ffaa39a827de7370efb8", url, retrieved)
  pr~addLabel("CI failed")
  body = .GitHubEvidenceSource~new("PULL_REQUEST_BODY", url, "PR#34083", "theuni", "2025-12-16T20:42:37Z", "", pr~headSha)
  pr~addClaim(.GitHubClaimEvidence~new("PERFORMANCE_INTENT", -
      "Vectorize ChaCha20 over multiple states to improve throughput on modern processors.", -
      "AUTHOR_CLAIM", body, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("IMPLEMENTATION_CHOICE", -
      "Use compiler vector built-ins rather than hand-written assembly or architecture-specific intrinsics.", -
      "AUTHOR_CLAIM", body, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("MEASUREMENT", -
      "Author reports roughly two-times speedup on x86-64 and three-times on ARM+NEON in local benchmarks.", -
      "AUTHOR_MEASUREMENT", body, "SOURCE_REPORTED"))
  pr~addClaim(.GitHubClaimEvidence~new("GENERATED_CODE_EVIDENCE", -
      "Implementation choices were iterated by comparing generated assembly and IR across compiler variants.", -
      "AUTHOR_CLAIM", body, "DIRECT_SOURCE"))
  pr~addClaim(.GitHubClaimEvidence~new("UNCERTAINTY", -
      "Author explicitly says improved network performance or latency is not established, though CPU efficiency should improve.", -
      "AUTHOR_CAVEAT", body, "DIRECT_SOURCE"))
  ciSource = .GitHubEvidenceSource~new("PULL_REQUEST_LABEL", url, "CI failed", "github", "2026-08-19T07:26:33Z", "", pr~headSha)
  pr~addCheck(.GitHubClaimEvidence~new("CI_STATE", "The public PR currently carries a CI failed label.", "OBSERVED_STATE", ciSource, "DIRECT_SOURCE"))
  return pr


::method semantic35688 class
  repo = self~build
  pr = repo~pullRequest(35688)
  retrieved = "2026-08-20T12:51:00+01:00"
  baseContent = "// Copyright (c) 2014-present The Bitcoin Core developers" || '0a'x || -
"// Distributed under the MIT software license, see the accompanying" || '0a'x || -
"// file COPYING or http://www.opensource.org/licenses/mit-license.php." || '0a'x || '0a'x || -
"#include <crypto/hmac_sha256.h>" || '0a'x || '0a'x || -
"#include <crypto/sha256.h>" || '0a'x || -
"#include <support/cleanse.h>" || '0a'x || '0a'x || -
"#include <cstring>" || '0a'x || '0a'x || -
"CHMAC_SHA256::CHMAC_SHA256(const unsigned char* key, size_t keylen)" || '0a'x || -
"{" || '0a'x || -
"    unsigned char rkey[64];" || '0a'x || -
"    if (keylen <= 64) {" || '0a'x || -
"        memcpy(rkey, key, keylen);" || '0a'x || -
"        memset(rkey + keylen, 0, 64 - keylen);" || '0a'x || -
"    } else {" || '0a'x || -
"        CSHA256().Write(key, keylen).Finalize(rkey);" || '0a'x || -
"        memset(rkey + 32, 0, 32);" || '0a'x || -
"    }" || '0a'x || '0a'x || -
"    for (int n = 0; n < 64; n++)" || '0a'x || -
"        rkey[n] ^= 0x5c;" || '0a'x || -
"    outer.Write(rkey, 64);" || '0a'x || '0a'x || -
"    for (int n = 0; n < 64; n++)" || '0a'x || -
"        rkey[n] ^= 0x5c ^ 0x36;" || '0a'x || -
"    inner.Write(rkey, 64);" || '0a'x || '0a'x || -
"    memory_cleanse(rkey, sizeof(rkey));" || '0a'x || -
"}" || '0a'x || '0a'x || -
"void CHMAC_SHA256::Finalize(unsigned char hash[OUTPUT_SIZE])" || '0a'x || -
"{" || '0a'x || -
"    unsigned char temp[32];" || '0a'x || -
"    inner.Finalize(temp);" || '0a'x || -
"    outer.Write(temp, 32).Finalize(hash);" || '0a'x || -
"    memory_cleanse(temp, sizeof(temp));" || '0a'x || -
"}" || '0a'x

  headContent = baseContent~changestr("#include <cstring>", "#include <algorithm>" || '0a'x || "#include <cstring>")
  headContent = headContent~changestr("memcpy(rkey, key, keylen);", "std::copy(key, key + keylen, rkey);")
  base = .RemoteSourceFileRevision~new("bitcoin/bitcoin", pr~baseSha, "src/crypto/hmac_sha256.cpp", -
      "0796bbeb3271a210ed7ed5d85a82fc76939db61a", baseContent, -
      "https://github.com/bitcoin/bitcoin/blob/" || pr~baseSha || "/src/crypto/hmac_sha256.cpp", retrieved)
  head = .RemoteSourceFileRevision~new("l0rinc/bitcoin", pr~headSha, "src/crypto/hmac_sha256.cpp", -
      "d9e16f361107c6d66f32ad8050c658d3b01f9241", headContent, -
      "https://github.com/l0rinc/bitcoin/blob/" || pr~headSha || "/src/crypto/hmac_sha256.cpp", retrieved)
  if \base~verifyBlobIdentity then raise syntax 93.900 array("Bitcoin public base snapshot does not match claimed Git blob identity")
  if \head~verifyBlobIdentity then raise syntax 93.900 array("Bitcoin public head snapshot does not match claimed Git blob identity")
  beforeDoc = .CxxSemanticAnalyzer~analyze(base)
  afterDoc = .CxxSemanticAnalyzer~analyze(head)
  beforeSymbol = beforeDoc~symbol("CHMAC_SHA256::CHMAC_SHA256")
  afterSymbol = afterDoc~symbol("CHMAC_SHA256::CHMAC_SHA256")
  return .CxxSemanticAnalyzer~compareMemoryOperation(beforeSymbol, afterSymbol, pr~codeChanges[1])

::requires "GitHubEvidence.cls"
::requires "CodeSemanticSource.cls"
