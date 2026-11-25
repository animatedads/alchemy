# Order: grid item 1 field test for a NEW pair of nodes (xtpd v0.1-dev3), kit v0.1-dev5

Item 1 passed on ed209k and cats2 on 25 Nov 2026 with kit v0.1-dev4. Use this order only for nodes that have no /etc/xtpd yet. kit dev5 moves the UDP carrier to the estate's commissioned XTP port, 62801.

This replaces the kit v0.1-dev2 and v0.1-dev3 orders (REQ-00005927, REQ-00005933 and REQ-00005935). Use only this one.

**NEEDS TOM'S DIRECT APPROVAL.** Before step 1, ask Tom: "May I run the grid item 1 field test on ed209k and cats2, including making key files?" Do nothing until Tom answers yes to you.

- Architecture: Tom Dyer. Coding: Claude (Opus 5.5), with ChatGPT's role component.
- Order written by Claude (Opus 5.5), 25 November 2026.
- Rules: R1 (cats2), R6 (ed209k) and R3 (built in the Ubuntu 22.04 build container). The key files are not covered by R1 or R6, which is why Tom must answer.

## What this does

1. Installs the xtpd field kit on both nodes.
2. ed209k becomes LDAP.main: xtpd plus a test LDAP server that listens on 127.0.0.1 only.
3. cats2 becomes LDAP.spare: xtpd, enabled at boot.
4. Pass 1, over UDP (layer 4): cats2 is rebooted. After the boot, cats2 must say that ed209k is LDAP.main, FRESH, with nobody logging in to cats2 before it does.
5. Pass 2, over raw IP protocol 36 (layer 3, XTP's own carrier): both nodes switch their peer line to raw36, and cats2 is rebooted again. It must say the same.

## Never do these

- Do not change any firewall, Vultr setting or Azure setting.
- Do not reboot ed209k.
- Do not touch cats1.
- Do not close port 22 anywhere.
- Do not print, paste or mail the contents of service.keys, role.keys, role or role-for-cats2.
- Do not edit any file the tool writes.
- If a step says STOP, stop, and send the output of that step to CLAUDE.

## Kit

- File: `packages/xtpd_field_kit_v0.1-dev5/xtpd-field-kit-0.1-dev5.tar.gz` in the Alchemy repository.
- SHA-256: `2b763f9f967ae6511e8c6cba62df671a7f47f693ecf75d092d14783b327043d7`
- On your PC, check it. The output must say OK. Otherwise STOP.

```
sha256sum -c xtpd-field-kit-0.1-dev5.tar.gz.sha256
```

## Step 1. Find ed209k's public IPv4 address

Log in to ed209k:

```
sshnode.sh ed209k
```

On ed209k, print its name and the IPv4 addresses on its network interfaces:

```
hostname
ip -4 -o addr show scope global
```

- ed209k is 80.240.21.156 (Vultr Frankfurt, Debian 13), from Tom's host table. 155.138.214.182 is ed209h: do not touch ed209h.
- The address 80.240.21.156 must be shown. If it is not, STOP: xtpd binds to that address, so it must be on the interface.
- Write the address down. Below it is called `ED209K_IP`. Stay logged in to ed209k.

## Step 2. Check ed209k is free (read only)

On ed209k you may be logged in as root, and sudo may not be installed. Check:

```
id -u; command -v sudo
```

If `id -u` prints 0 and sudo is missing, run every ed209k command below without the word `sudo`. Change nothing else.

```
cat /etc/os-release | head -2
ls /etc/xtpd /opt/rexxos/xtpd-0.1-dev3
ss -ulpn | grep -c ':62801 '
ss -ltnp | grep -c '127.0.0.1:1389 '
```

- Both `ls` lines must say "No such file or directory". Otherwise STOP.
- Both counts must be 0. Otherwise STOP.

## Step 3. Install the kit on ed209k

Copy the tarball from your PC to ed209k's /tmp. Then, on ed209k:

```
sudo mkdir -p /opt/rexxos
sudo tar -C /opt/rexxos -xzf /tmp/xtpd-field-kit-0.1-dev5.tar.gz
cd /opt/rexxos/xtpd-0.1-dev3 && sudo sha256sum -c --quiet SHA256SUMS && echo KIT-OK
sudo /opt/rexxos/xtpd-0.1-dev3/bin/selftest | tail -1
```

You must see `KIT-OK` and `PASS selftest`. Otherwise STOP, and send the whole selftest output. The selftest also checks that this node can make xtpd's foreign calls (the kit carries its own libffi).

## Step 4. Write ed209k's files (this makes the key files)

Put the address from step 1 in place of ED209K_IP:

```
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/bin/item1_files.rex ed209k ED209K_IP
```

The last line must be `PASS item1 files for ed209k in /etc/xtpd`. Otherwise STOP.

## Step 5. Start ed209k's services

```
sudo cp /opt/rexxos/xtpd-0.1-dev3/systemd/xtpd.service /opt/rexxos/xtpd-0.1-dev3/systemd/ldap-fixture.service /etc/systemd/system/
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
ls /etc/xtpd /opt/rexxos/xtpd-0.1-dev3
```

Both `ls` lines must say "No such file or directory". Otherwise STOP.

Copy the tarball to cats2's /tmp. Then:

```
sudo mkdir -p /opt/rexxos /etc/xtpd
sudo tar -C /opt/rexxos -xzf /tmp/xtpd-field-kit-0.1-dev5.tar.gz
cd /opt/rexxos/xtpd-0.1-dev3 && sudo sha256sum -c --quiet SHA256SUMS && echo KIT-OK
sudo /opt/rexxos/xtpd-0.1-dev3/bin/selftest | tail -1
sudo install -m 600 -o root -g root /tmp/service.keys /tmp/role.keys /tmp/role-for-cats2 /etc/xtpd/
rm /tmp/service.keys /tmp/role.keys /tmp/role-for-cats2
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/bin/item1_files.rex cats2 ED209K_IP
```

You must see `KIT-OK`, then `PASS selftest`, and last `PASS item1 files for cats2 in /etc/xtpd`. Otherwise STOP.

Now delete your PC's copies of the three files.

## Step 8. Enable xtpd on cats2 and check before the reboot

```
sudo cp /opt/rexxos/xtpd-0.1-dev3/systemd/xtpd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now xtpd.service
sleep 15
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/pkg/oorexx_xtpd_v0.1-dev3/bin/xtp_request.rex STATUS
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
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/pkg/oorexx_xtpd_v0.1-dev3/bin/xtp_request.rex STATUS
sudo journalctl -b -u xtpd --no-pager | grep 'role:'
```

Pass means all three of these are true:
- uptime shows the reboot;
- STATUS ends `status FRESH peer ed209k epoch 2 version 1 ready yes`;
- the journal shows `role: probe of MAIN ed209k at 2.1 protection authenticate -> CONFIRM ed209k MAIN 2 1` from this boot.

If pass 1 failed, do not go on to pass 2: go to step 12 and report.

## Step 10. Pass 2: switch both nodes to raw IP 36 (layer 3)

On ed209k:

```
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/bin/item1_carrier.rex raw36
sudo systemctl restart xtpd.service
sleep 5
sudo grep -P '^cats2\t' /run/xtpd/routes.tsv | cut -f1-4
```

The tool's last line must be `PASS peer line set to raw36 (restart xtpd to use it)`, and the route line must read `cats2 3 raw36 20.118.224.14`. Otherwise STOP.

On cats2:

```
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/bin/item1_carrier.rex raw36
```

The last line must be `PASS peer line set to raw36 (restart xtpd to use it)`. Otherwise STOP.

## Step 11. Pass 2: reboot cats2 again (R1 covers this)

```
sudo systemctl reboot
```

- Wait 3 minutes. Do not log in to cats2 during those 3 minutes.
- Then log in to cats2 and run:

```
uptime
sudo grep -P '^ed209k\t' /run/xtpd/routes.tsv | cut -f1-4
sudo /opt/rexxos/xtpd-0.1-dev3/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev3/pkg/oorexx_xtpd_v0.1-dev3/bin/xtp_request.rex STATUS
sudo journalctl -b -u xtpd --no-pager | grep 'role:'
```

Pass means all of these are true:
- uptime shows the second reboot;
- the route line reads `ed209k 3 raw36 80.240.21.156`;
- STATUS ends `status FRESH peer ed209k epoch 2 version 1 ready yes`;
- the journal shows the CONFIRM line from this boot.

If STATUS says `UNAVAILABLE`, protocol 36 may be blocked on the path (for example by the Azure network security group). Do not change any firewall or Azure setting. Report it, and leave both nodes on raw36 unless Tom says otherwise.

## Step 12. Report

Reply to CLAUDE on lane newshell-mu-playground. Include:
- the os-release lines from both nodes;
- the selftest lines;
- the step 8 STATUS line;
- every line from step 9;
- every line from steps 10 and 11;
- PASS or FAIL for each pass.

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
