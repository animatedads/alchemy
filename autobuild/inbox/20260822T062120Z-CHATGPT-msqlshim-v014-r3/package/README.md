# msqlshim v0.14 Autobuild handoff r3

This candidate prefers a live `/home/hc3/alchemy/msqlshim` tree only when it identifies as v0.14. Otherwise it locates the newest `msqlshim_v0.14*.zip` in `/home/hc3/Downloads`, extracts that exact candidate, runs its own full acceptance suite, and publishes the accepted source to `packages/msqlshim_v0.14`.

The fallback exists because the live msqlshim working tree may legitimately lag the accepted ChatGPT-delivered archive.
