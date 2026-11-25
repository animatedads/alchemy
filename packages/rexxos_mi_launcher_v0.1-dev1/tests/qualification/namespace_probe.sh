#!/bin/bash
# Tries mi-namespace-exec for real, as an unprivileged account.  Claude (Opus 5.5).
set -u
id mi >/dev/null 2>&1 || useradd -M -s /usr/sbin/nologin mi
R=/tmp/milq/root1; mkdir -p $R/bin $R/etc/rexxos-mi $R/opt/rexxos-mi/bin $R/proc $R/tmp
cp /bin/dash $R/bin/sh
for l in $(ldd /bin/dash | grep -o '/[^ ]*'); do mkdir -p $R$(dirname $l); cp -L $l $R$l; done
echo v1 > $R/etc/rexxos-mi/contract-v1
cat > $R/opt/rexxos-mi/bin/runner <<'EOR'
#!/bin/sh
echo "runner pid=$$ args=$*"
echo "hostname=$(cat /proc/sys/kernel/hostname 2>/dev/null)"
ls /proc | grep -c '^[0-9]' | sed 's/^/processes visible: /'
EOR
chmod 755 $R/opt/rexxos-mi/bin/runner; chown -R mi $R
echo "unprivileged_userns_clone=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null) max_user_ns=$(cat /proc/sys/user/max_user_namespaces)"
echo "== as root (must refuse)"; /tmp/milq/kit/bin/mi-namespace-exec $R mi1 cats2 1 mi.one; echo rc=$?
echo "== as mi"; su -s /bin/sh mi -c "/tmp/milq/kit/bin/mi-namespace-exec $R mi1 cats2 1 mi.one"; echo rc=$?
echo "== bad name"; su -s /bin/sh mi -c "/tmp/milq/kit/bin/mi-namespace-exec $R 'mi;1' cats2 1 mi.one"; echo rc=$?
ln -sfn $R /tmp/milq/rootlink
echo "== symlinked root"; su -s /bin/sh mi -c "/tmp/milq/kit/bin/mi-namespace-exec /tmp/milq/rootlink mi1 cats2 1 mi.one"; echo rc=$?
