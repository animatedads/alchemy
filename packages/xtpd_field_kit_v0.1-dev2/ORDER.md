# Order: grid item 1 field test (xtpd v0.1-dev2 on ed209k and cats2)

**NEEDS TOM'S DIRECT APPROVAL.** Before step 1, ask Tom: "May I run the grid item 1 field test on ed209k and cats2, including making key files?" Do nothing until Tom answers yes to you.

- Architecture: Tom Dyer. Coding: Claude (Opus 5.5), with ChatGPT's role component.
- Order written by Claude (Opus 5.5), 25 November 2026.
- Rules: R1 (cats2), R6 (ed209k) and R3 (built in the Ubuntu 22.04 build container). The key files are not covered by R1 or R6, which is why Tom must answer.

## What this does

1. Installs the xtpd field kit on both nodes.
2. ed209k becomes LDAP.main: xtpd plus a test LDAP server that listens on 127.0.0.1 only.
3. cats2 becomes LDAP.spare: xtpd, enabled at boot.
4. cats2 is rebooted. After the boot, cats2 must say that ed209k is LDAP.main, FRESH, with nobody logging in to cats2 before it does.

## Never do these

- Do not change any firewall, Vultr setting or Azure setting.
- Do not reboot ed209k.
- Do not touch cats1.
- Do not close port 22 anywhere.
- Do not print, paste or mail the contents of service.keys, role.keys, role or role-for-cats2.
- Do not edit any file the tool writes.
- If a step says STOP, stop, and send the output of that step to CLAUDE.

## Kit

- File: `packages/xtpd_field_kit_v0.1-dev2/xtpd-field-kit-0.1-dev2.tar.gz` in the Alchemy repository.
- SHA-256: `ee2ef8e13a2e3460a4c2e7cc329bca00395bcd2a6f65d2b023b28e592ddbbe10`
- On your PC, check it. The output must say OK. Otherwise STOP.

```
sha256sum -c xtpd-field-kit-0.1-dev2.tar.gz.sha256
```

## Step 1. Find ed209k's public IPv4 address

Log in to ed209k:

```
sshnode.sh ed209k
```

On ed209k, print its public IPv4 address:

```
curl -4 -s https://ifconfig.me
```

Write the address down. Below it is called `ED209K_IP`. Stay logged in to ed209k.

## Step 2. Check ed209k is free (read only)

```
cat /etc/os-release | head -2
ls /etc/xtpd /opt/rexxos/xtpd-0.1-dev2
ss -ulpn | grep -c ':47036 '
ss -ltnp | grep -c '127.0.0.1:1389 '
```

- Both `ls` lines must say "No such file or directory". Otherwise STOP.
- Both counts must be 0. Otherwise STOP.

## Step 3. Install the kit on ed209k

Copy the tarball from your PC to ed209k's /tmp. Then, on ed209k:

```
sudo mkdir -p /opt/rexxos
sudo tar -C /opt/rexxos -xzf /tmp/xtpd-field-kit-0.1-dev2.tar.gz
cd /opt/rexxos/xtpd-0.1-dev2 && sudo sha256sum -c --quiet SHA256SUMS && echo KIT-OK
sudo /opt/rexxos/xtpd-0.1-dev2/bin/selftest | tail -1
```

You must see `KIT-OK` and `PASS selftest`. Otherwise STOP, and send the whole selftest output.

## Step 4. Write ed209k's files (this makes the key files)

Put the address from step 1 in place of ED209K_IP:

```
sudo /opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/bin/item1_files.rex ed209k ED209K_IP
```

The last line must be `PASS item1 files for ed209k in /etc/xtpd`. Otherwise STOP.

## Step 5. Start ed209k's services

```
sudo cp /opt/rexxos/xtpd-0.1-dev2/systemd/xtpd.service /opt/rexxos/xtpd-0.1-dev2/systemd/ldap-fixture.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ldap-fixture.service
sleep 5
sudo systemctl enable --now xtpd.service
sleep 5
sudo grep -E 'running:|role: loaded|role: verifier' /var/log/xtpd.log
```

You must see three lines: `running:`, `role: loaded LDAP main ed209k spare cats2 epoch 2 version 1` and `role: verifier TEST_ONLY_HMAC`. Otherwise STOP.

## Step 6. Copy three files from ed209k to cats2

The three files are /etc/xtpd/service.keys, /etc/xtpd/role.keys and /etc/xtpd/role-for-cats2.

- Copy them through your PC with scp.
- Keep them mode 600 on your PC, and delete your PC's copies after step 7.
- Never open them or print them.

On ed209k, stage the three files:

```
sudo install -m 600 -o $(id -u) /etc/xtpd/service.keys /etc/xtpd/role.keys /etc/xtpd/role-for-cats2 /tmp/
```

Then copy the three /tmp files to your PC, and then to cats2's /tmp. Log in to cats2 like this:

```
ssh -i /home/hc3/.ssh/cats.pem azureuser@20.118.224.14
```

On ed209k, remove the three staged copies:

```
rm /tmp/service.keys /tmp/role.keys /tmp/role-for-cats2
```

## Step 7. Install on cats2 and write its files

On cats2, run these read-only checks first:

```
cat /etc/os-release | head -2
ls /etc/xtpd /opt/rexxos/xtpd-0.1-dev2
```

Both `ls` lines must say "No such file or directory". Otherwise STOP.

Copy the tarball to cats2's /tmp. Then:

```
sudo mkdir -p /opt/rexxos /etc/xtpd
sudo tar -C /opt/rexxos -xzf /tmp/xtpd-field-kit-0.1-dev2.tar.gz
cd /opt/rexxos/xtpd-0.1-dev2 && sudo sha256sum -c --quiet SHA256SUMS && echo KIT-OK
sudo /opt/rexxos/xtpd-0.1-dev2/bin/selftest | tail -1
sudo install -m 600 -o root -g root /tmp/service.keys /tmp/role.keys /tmp/role-for-cats2 /etc/xtpd/
rm /tmp/service.keys /tmp/role.keys /tmp/role-for-cats2
sudo /opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/bin/item1_files.rex cats2 ED209K_IP
```

You must see `KIT-OK`, then `PASS selftest`, and last `PASS item1 files for cats2 in /etc/xtpd`. Otherwise STOP.

Now delete your PC's copies of the three files.

## Step 8. Enable xtpd on cats2 and check before the reboot

```
sudo cp /opt/rexxos/xtpd-0.1-dev2/systemd/xtpd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now xtpd.service
sleep 15
sudo /opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/pkg/oorexx_xtpd_v0.1-dev2/bin/xtp_request.rex STATUS
```

- Expected: a line ending `role source ROLE_SOURCE status FRESH peer ed209k epoch 2 version 1 ready yes`. If you see it, go to step 9.
- If it says `UNAVAILABLE`, or anything else, do not reboot. Run the next command and send its output. Then STOP.

```
sudo grep 'role:' /var/log/xtpd.log
```

## Step 9. The test: reboot cats2 (R1 covers this)

```
sudo systemctl reboot
```

- Wait 3 minutes. Do not log in to cats2 during those 3 minutes.
- Then log in to cats2 and run:

```
uptime
sudo /opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/pkg/oorexx_xtpd_v0.1-dev2/bin/xtp_request.rex STATUS
sudo journalctl -b -u xtpd --no-pager | grep 'role:'
```

Pass means all three of these are true:
- uptime shows the reboot;
- STATUS ends `status FRESH peer ed209k epoch 2 version 1 ready yes`;
- the journal shows `role: probe of MAIN ed209k at 2.1 protection authenticate -> CONFIRM ed209k MAIN 2 1` from this boot.

## Step 10. Report

Reply to CLAUDE on lane newshell-mu-playground. Include:
- the os-release lines from both nodes;
- the selftest lines;
- the step 8 STATUS line;
- every line from step 9;
- PASS or FAIL.

Never include a key or the contents of a role file.

## If Tom says to undo it (only then)

On cats2:

```
sudo systemctl disable --now xtpd.service
```

On ed209k:

```
sudo systemctl disable --now xtpd.service ldap-fixture.service
```

Leave every file in place and tell CLAUDE. Removing files is a separate order.
