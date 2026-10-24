# 2026-10-24: NotNotes source publication and ooRexx qualification

**Published:** `packages/alchemy_notnotes_v0.1-dev15` (31 files) and `packages/notnotes_mini_approval_app_v0.1-dev16` (110 files). Both are direct, byte-preserving source imports from the Library archives; each includes an exact source-member SHA-256 manifest. The package roots and their vendor copies are distinct ownership/version boundaries.

**Library archive SHA-256:** `alchemy_notnotes_v0.1-dev15.zip` `57a7d1b09234621f20c9de5dda312b4e38140b57cb87c45f7318e59730db4488`; `initech_notnotes_helpdesk_v0.1-dev5.zip` `0448068f18fee165381441e2afb33dbee170f44957f6d3c704ef2948ed42f9c6`.

**Key source SHA-256:** `AlchemyNotNotesIntentions.cls` `11056f3b853e32b9efe5de11adea4902fb85b88775a75224ad864dea6ba97442`; `MiniNotesApp.cls` `575c5ee7745c5fddb169a3b720488c08ec63a7b47878c1c31d37c12779083d14`. `NoSQLServer.cls` is the exact 573370-byte v0.87 file, Git blob SHA `92b531320894ec7334665a9864617af4adc42918`.

**Runtime test:** the user's Library `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb`, extracted in isolation, reports ooRexx 5.3.0 r13196. Retained Help Desk dev5 `tools/run_environment_test.sh`: exit **0**, covering help-desk compile, Mini tests, NoSQL persistence, Instrumentation Mesh/Intentions, and end-to-end TPS reporting. Independently staged published Mini source `tools/run_github_source_qualification.sh`: exit **0**, seven core tests for documents, query safety, TPS design, semantic projection, many document references, instrumentation, and persistence.

**Not yet qualified:** clean GitHub Help Desk standalone launcher/fixtures; omitted mutable TPS and management-review records; optional native CLI UI compiled libraries; general registry-based dependency resolution; LLM Gopher runtime registration/lint. The source publisher did **not** modify any intentionally excluded customer data, replace vendor patches or assert that the entire Alchemy/NotNotes release is production-ready.
