mu-tools 0.1-dev4 - MU audit and file survey for the RexxOS MU playground.
Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  Logging: oorexx_logging v0.7 (LoggingCore.cls, MethodInterposition.cls).
Runs on ooRexx 5.2 and 5.3 (dev3: the audit and the survey no longer use CATCH or THROW; the
identity providers in NewShellIdentity.cls still do, and the audit does not call them).
Start it from the package directory (cd /opt/mu-tools): ooRexx 5.2 resolves ::requires '../src'
from the current directory, 5.3 from the script's own.

  rexx bin/mu_audit.rex etc/mu_contract.txt record FILE     audit this host, save a recording
  rexx bin/mu_audit.rex etc/mu_contract.txt replay FILE     audit a recording
  rexx bin/mu_tree_survey.rex etc/mu_tree_rules.txt PATHLIST [DEPTH]
  bash tests/run_tests.sh                                   the tests (a fake root with its own /var/lib/dpkg)

0.1-dev4 (24 Nov 2026): etc/mu_contract_cats.txt v0.4, accepted by Tom Dyer: witnesses for cats1's
105 findings, each placed in CONTRACT_REVIEW_v0.4.md (witness, remove, or the image), with apt-get -s
simulations deciding what can be removed. Replaying cats1's recording: 105 findings under v0.3, 32 under
v0.4, 16 expected after the removals. No code change from dev3.

0.1-dev3 (24 Nov 2026), after Tom looked round cats1 as root and found script, gpg, perl,
hexdump and dbus "sat around" while the audit said THIN:
- The audit read processes, sockets, accounts, packages and boot units, never programs or
  files, and packages only against a forbid list.  dev3 adds two checks, each switched on by
  the contract:
    check exec DIR...                 every program in DIR needs a witness:
    allow exec NAME... | witness      by name, or
    allow exec-package PKG... | w     by the package that owns it.
    forbid exec CATEGORY NAME...      reported even when its package is allowed.
    watch DIR... | witness            every file under DIR must belong to a package, or
    allow file PREFIX... | witness    carry a witness.
  Programs with no witness are reported one line per package, with Essential packages
  marked: those cannot be removed with apt, only by building the stripped image.
- Ownership is read from /var/lib/dpkg itself (info/PACKAGE.list, status, alternatives),
  with Ubuntu 22.04's merged /usr handled (packages list /bin/bash for /usr/bin/bash).
- etc/mu_contract_cats.txt v0.3: dbus-daemon and systemd-logind are witnessed only for ssh
  login sessions until M8 (on cats1 only dbus-user-session and libdbus-1-3 depend on dbus);
  the program witnesses; the forbidden programs (recorders, setarch, perl, gpg, network
  clients, dumpers, D-Bus tools, debuggers, editors); /usr/bin /usr/sbin /usr/local /root
  /home /opt watched.
- What the audit will now say about cats1 that it did not: script's "typescript" left in
  /usr/bin, gpg's /root/.gnupg, and every program with no witness.
- HostCommand: a missing command now gives rc 127 instead of failing ("does not understand
  RC"); mu_audit.rex and mu_tree_survey.rex trap SYNTAX and exit 2 naming the error.
- Why the CATCH change: the autobuild host runs ooRexx 5.3.0 r13196 Internal Test Version,
  which has no CATCH, so dev3's first submission could not run its tests there.
- Known contradiction, reported, not hidden: apt and dpkg are witnessed until the image, and
  debconf (which they need) is Perl, while perl is forbidden.  perl-base is Essential: only
  the stripped image removes both.
