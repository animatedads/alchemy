# Submission evidence boundary

Architecture: Tom Dyer. Implementation and update: ChatGPT GPT-6.

This package is submitted through an immutable `autobuild-submit/<id>` Git branch
with a ready-last marker. LOCAL_PASS is not FIELD_PASS or an autobuild receipt.
The `integration.json` test runs `sh run_tests.sh` with `rexx` on PATH.
Do not publish the receiver's true coordinates, source recordings, private
inventory, or extracted ADS-B histories in this repository.

Source is intentionally independent of an ADS-B JSON decoder. The input is
receiver-relative trajectory vectors with one fixed reference frame; callers
must provide parsed and source-bound vectors. Outputs are prediction-only.
