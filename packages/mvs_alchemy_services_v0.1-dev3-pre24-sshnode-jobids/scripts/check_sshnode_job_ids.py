#!/usr/bin/env python3
from pathlib import Path
import re,sys
p=Path(__file__).with_name("qualify_ed209c_ed209z_services.sh")
s=p.read_text()
checks={
 "job prefix":"MAS_SSH_JOB_ID_PREFIX" in s,
 "run helper uses job id":'"$SSHNODE" --job-id "$job_id" "$TARGET" "$@"' in s,
 "job id includes stage":"${stage_id}" in s,
 "job id distinguishes subshell":"${BASHPID}" in s,
 "transfer stays sshnode helper":'"$SSHNODE" --transfer "$TARGET"' in s,
 "no raw ssh":not re.search(r'(^|[;&| ])ssh[ ]',s,re.M),
 "no raw scp":not re.search(r'(^|[;&| ])scp[ ]',s,re.M),
}
bad=[k for k,v in checks.items() if not v]
# Apart from run_ssh itself and the supported transfer call, all helper invocations
# must be administrative checks, not unaudited remote EXEC paths.
for n,line in enumerate(s.splitlines(),1):
    if '"$SSHNODE"' not in line: continue
    if '--job-id "$job_id"' in line or '--transfer "$TARGET"' in line: continue
    if '[[ -x "$SSHNODE" ]]' in line or 'command -v "$SSHNODE"' in line: continue
    bad.append(f'unaudited sshnode invocation line {n}')
if bad:
 print('FAIL SSHNODE_JOB_IDS '+', '.join(bad)); sys.exit(1)
print('PASS SSHNODE_JOB_IDS PRE24')
