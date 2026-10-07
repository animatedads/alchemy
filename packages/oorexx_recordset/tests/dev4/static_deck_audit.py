#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[2]
asm=root/'platform/mvs/RecordSetMvsQsam.asm'
jcl=root/'tests/dev4/mvs/QUALIFY.JCL'
lines=asm.read_text().splitlines()
errors=[]
# Fixed-card executable lines must fit through col 71; comments may occupy card text to col 80.
for n,line in enumerate(lines,1):
    if not line.startswith('*') and len(line)>71:
        errors.append(f'{asm}:{n}: executable source exceeds column 71 ({len(line)})')
    if line and not line.startswith('*') and not line.startswith(' '):
        label=line[:8].strip()
        if label and (len(label)>8 or not re.match(r'^[A-Z][A-Z0-9]*$',label)):
            errors.append(f'{asm}:{n}: invalid classic assembler label {label!r}')
# ENTRY operands must already have been defined before the ENTRY statement for Assembler XF.
def_line={}
for n,line in enumerate(lines,1):
    if line and not line.startswith(('*',' ')):
        label=line[:8].strip()
        if label:
            def_line.setdefault(label,n)
for n,line in enumerate(lines,1):
    if line.strip().startswith('ENTRY '):
        for sym in line.strip()[6:].split(','):
            sym=sym.strip()
            if sym not in def_line or def_line[sym]>=n:
                errors.append(f'{asm}:{n}: ENTRY {sym} is not defined earlier')
# DCBD should be after executable code and only once.
dcbd=[n for n,l in enumerate(lines,1) if l.strip().startswith('DCBD ')]
if len(dcbd)!=1:
    errors.append(f'{asm}: expected exactly one DCBD, got {dcbd}')
if dcbd and dcbd[0] < max(def_line.get(x,0) for x in ['RQOPEN','RQCLOSE','RQREAD','RQWRITE','RQREWIND']):
    errors.append(f'{asm}:{dcbd[0]}: DCBD appears before exported executable entries')
# Every DSECT in our own source before code/data continuation must be followed by a CSECT resume.
for n,line in enumerate(lines,1):
    if line[:8].strip()=='RSHNDL' and 'DSECT' in line:
        if not any(l.startswith('RSETQSAM CSECT') for l in lines[n:n+10]):
            errors.append(f'{asm}:{n}: RSHNDL DSECT is not followed by RSETQSAM CSECT resume')
# JCL object contract for IFOX00.
j=jcl.read_text()
if j.count("PGM=IFOX00,PARM='OBJECT,NODECK'") != 2:
    errors.append('QUALIFY.JCL: both IFOX00 steps must use OBJECT,NODECK')
if j.count('//SYSGO    DD DSN=&&OBJ') != 2:
    errors.append('QUALIFY.JCL: both assembler steps must provide SYSGO object DDs')
# SYSLIN is correct only for the link-edit input section.
pre_lked=j.split('//LKED',1)[0]
if '//SYSLIN   DD DSN=&&OBJ' in pre_lked:
    errors.append('QUALIFY.JCL: assembler step still contains object SYSLIN instead of SYSGO')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('PASS')
print(f'assembler_lines={len(lines)}')
print(f'max_executable_card_columns={max(len(l) for l in lines if not l.startswith("*"))}')
print('entry_definitions_precede_ENTRY=yes')
print('dcbd_at_end=yes')
print('ifox_object_dd=SYSGO')
