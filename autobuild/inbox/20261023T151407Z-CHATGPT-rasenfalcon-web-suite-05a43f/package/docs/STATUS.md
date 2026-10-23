# Rasen Falcon website publication gates

2026-10-23 — source candidate v0.1.0.

* Website Builder: 9 public pages with local, independently testable compiler output. Content remains editorial candidate.
* Website Publisher v0.2: local browser editor and file/CLI handoff to ooRexx NoSQLServer v0.89 native adapter; not a multi-user CMS.
* Rasen Falcon Delivery v0.4: separately maintained infrastructure/governance plan, not included in this public GitHub source package because it contains private-host routing details and separate qualification tasks.
* No server launch, public deployment, secret import, external approval, or CMS/Wire publication is part of this source submission.
* Native store has not been validated against the v0.90 release or a production host here. Native tests are present but require qualified ooRexx runtime and NoSQLServer source/ABI.
* No scheduled tasks use system cron: future automation must use BashQueues/BashQueues cron, as approved.

Known tests: original website test_site.py (9 tests) and publisher test_publisher.py (46 assertions), test_native_handoff.py (29 standalone assertions plus 4 external pinned-dependency checks). Integrated checks via tests/test_suite.py; JS static check optional when Node available.

Next work: bind Website Publisher to authenticated ooRexx CMS service, Connect Selector, institutional approval and Wire resource release on owned HTTPS Server, preserving private NOC/Office service separation.
