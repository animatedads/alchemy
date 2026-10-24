# Computer v0.1-dev4 — named search locations, GitHub, and governed learning

## 1. Named scopes resolve locally, not globally

A **search scope** is a durable user-local NAME -> [absolute directory, ...] mapping.
The name is the portable intention; the paths belong to the current machine.
Each invocation rechecks registered directories. Unknown/unavailable scopes **never**
fall back to the entire home directory, mounted disks or unrelated locations.

```bash
# On the Architect's workstation:
Computer 'add /home/hc3/Downloads to my find file locations as inboundfiles'
Computer 'add /home/hc3/Downloads/current to my find file locations as inboundfiles'
# On a different agent's machine, the same name points to its own path:
Computer 'add /mnt to my find file locations as inboundfiles'
# Another agent might instead register /home/bacon:
Computer 'add /home/bacon to my find file locations as inboundfiles'
Computer 'add ~/sources to my find file locations as dependencies'
Computer 'search scopes'
Computer '--json find new files in last 30 minutes in inboundfiles'
Computer '--json find dependency rexx crypto in dependencies'
```

The paths above are examples on distinct machines: **do not register nonexistent
paths**. Multiple paths can be registered under one name. Each must already exist.

Candidate results are bounded, sorted by `modified_epoch_ns` descending,
and include UTC modification timestamp, file size, exact path, match reason,
SHA-256 (if calculated) and `hash_status`. ZIP member names are metadata
observations, **not extracted files**. Hashes of ZIP-member matches are
hashes of the archive when available; never claim that an archive hash is a
member hash. `mtime` is **not proven download/receipt time**. The scanner does
not follow symlinks and has 50,000-file / 16-level bounds and a result cap.
An unknown scope returns a nonzero exit status and will not provoke an
unbounded exploratory scan.

## 2. GitHub read versus write: let SSH decide the key

GitHub remotes may use SSH host aliases with a different deploy key for each
project. A typical `~/.ssh/config` fragment (example names only):

```sshconfig
Host gh-project-a
    HostName github.com
    User git
    IdentityFile ~/.ssh/project-a-deploy-key
    IdentitiesOnly yes
Host gh-project-b
    HostName github.com
    User git
    IdentityFile ~/.ssh/project-b-deploy-key
    IdentitiesOnly yes
```

Their Git remotes should use the corresponding alias, e.g.
`git@gh-project-a:owner/repository.git`. **Computer does not create keys,
rewrite remotes, change `.ssh/config` or supply `ssh -i`.** It uses `ssh -G`
for a nonconnecting effective-profile inspection, and hands the remote URL
to Git unchanged. Environment overrides `GIT_SSH_COMMAND` / `GIT_SSH` are
reported; write previews refuse unexpected overrides. A repository's
`core.sshCommand` is also printed for inspection. Git itself remains the
transport and SSH identity authority; no live GitHub access is implied by
successful local qualifications.

```bash
Computer 'github inspect /home/hc3/projects/myrepo'
Computer 'github status /home/hc3/projects/myrepo'
Computer 'github fetch /home/hc3/projects/myrepo'
Computer 'github pull /home/hc3/projects/myrepo'
Computer 'github clone https://github.com/owner/repo.git to /home/hc3/projects/newrepo'
Computer 'github clone git@gh-project-a:owner/repo.git to /home/hc3/projects/newrepo'

Computer 'github stage /home/hc3/projects/myrepo file src/Crypto.cls'
Computer 'github commit /home/hc3/projects/myrepo message "Qualify Crypto update"'
Computer 'github push /home/hc3/projects/myrepo'
```

**Read path:** `clone`, `fetch`, `pull` need no Computer confirmation roundtrip;
clone creates the specified new directory beneath HOME. Pull is intentionally
`git pull --ff-only origin <current-branch>` and rejects a dirty working tree.
GitHub Enterprise remotes require explicit `COMPUTER_GITHUB_HOSTS` approval.
**Write path:** `stage`, `commit`, `push` each print the exact `COMMAND=` and
`ARGV=` before returning exit 3. They are not executed until a new, unexpired,
single-use `Computer confirm TOKEN` is supplied. Confirm revalidates relevant
HEAD, index, remote, SSH profile and staged-file hash evidence. Stage never
runs `git add -A`, and push never uses `--force`. Commit can invoke
repository-controlled hooks or filters; preview does not validate those hooks.

**Codex rule:** copy the previewed argv/command into the review and explicitly
check repo root, remote URL, SSH alias and IdentityFile, branch, subcommand,
argument order, staged file set and authorisation **before** confirming.
A `DRY_RUN` result is not evidence that a real network operation succeeded.

## 3. Computer learn — two distinct approvals

`learn` is **not** shell code capture. It registers a named alias for one of
an allowlisted set of already implemented and read-only Computer intentions.
New executable providers must be implemented, reviewed and qualified as
specialists; they cannot be smuggled in through `learn`.

```bash
Computer 'learn locatecrypto as "find dependency rexx crypto in dependencies"'
# The tool prints the exact COMMAND and a REVIEW instruction.
# Codex MUST ask: “Is this the intended operation, with these positional
# arguments and options in precisely this order?” and present COMMAND as run.
Computer 'learn review REVIEW_TOKEN Computer '\''find dependency rexx crypto in dependencies'\'''
# That review consumes REVIEW_TOKEN. If the exact rendered command is attested,
# a DIFFERENT token is returned for activation.
Computer 'confirm ACTIVATION_TOKEN'
Computer 'do locatecrypto'
```

**No silent correction**: changing the shell-rendered command, option placement,
argument grouping, or phrase requires abandoning that review and restarting.
Token 1 and token 2 expire in 10 minutes and are single-use. Learned names
cannot overwrite existing entries. The complete approved command is persisted
with a SHA-256 of its rendered form. Execution reclassifies it against the
allowlist and uses the normal intention adapter again; there is no direct
shell evaluation or freeform interpreter.

## 4. Evidence and status

- `0`: successful operation (not automatically proof of provenance)
- `1`: mismatch or no result
- `2`: unrecognised or malformed instruction
- `3`: needs details or confirmation; **nothing pending was executed**
- `4`: denied, changed authority or spent/expired token
- `5`: execution or I/O error

`Computer run tests` qualifies using offline fixtures and a controlled SSH
argument recorder. It does **not** test remote GitHub credentials or live
cloud/firewall access. For any operational claim preserve the exact command,
its exit status, and separately confirmed evidence (full path, SHA, size,
source/remote identity, test logs). Never invent successful actions from a
preview, a dry-run, a candidate filename or an untrusted checksum.
