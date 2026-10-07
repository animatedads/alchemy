#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[2]
asm=root/'platform/mvs/RecordSetMvsQsam.asm'
jcl=root/'tests/dev6/mvs/QUALIFY.JCL'
lines=asm.read_text().splitlines()
errors=[]
for n,line in enumerate(lines,1):
    if len(line)>71:
        errors.append(f'{asm}:{n}: source exceeds column 71 ({len(line)})')
    if line and not line.startswith(('*',' ')):
        label=line[:8].strip()
        if label and (len(label)>8 or not re.match(r'^[A-Z][A-Z0-9]*$',label)):
            errors.append(f'{asm}:{n}: invalid classic assembler label {label!r}')
# RSHNDL DSECT must be based whenever dynamic handle fields are used.
using=sum(1 for l in lines if l.strip()=='USING RSHNDL,8')
if using != 5:
    errors.append(f'{asm}: expected 5 USING RSHNDL,8 directives, got {using}')
# Once USING is active, do not explicitly append R8 to RSHNDL symbols: XF then
# sees a relocatable displacement instead of resolving through the USING.
for n,l in enumerate(lines,1):
    if re.search(r'\b(?:HMODE|HDDNAME|HDCB)(?:\+[^ (]+)?\([^)]*,8\)', l):
        errors.append(f'{asm}:{n}: explicit R8 base remains on RSHNDL field: {l.strip()}')
    if re.search(r'\b(?:HMODE|HDCB)\(8\)', l):
        errors.append(f'{asm}:{n}: explicit R8 base remains on RSHNDL field: {l.strip()}')
# ENTRY operands must be defined first for Assembler XF.
def_line={}
for n,line in enumerate(lines,1):
    if line and not line.startswith(('*',' ')):
        label=line[:8].strip()
        if label: def_line.setdefault(label,n)
for n,line in enumerate(lines,1):
    if line.strip().startswith('ENTRY '):
        for sym in line.strip()[6:].split(','):
            sym=sym.strip()
            if sym not in def_line or def_line[sym]>=n:
                errors.append(f'{asm}:{n}: ENTRY {sym} is not defined earlier')
dcbd=[n for n,l in enumerate(lines,1) if l.strip().startswith('DCBD ')]
if len(dcbd)!=1: errors.append(f'{asm}: expected exactly one DCBD, got {dcbd}')
# JCL object / gating contracts.
j=jcl.read_text()
if j.count("PGM=IFOX00,PARM='OBJECT,NODECK'") != 2:
    errors.append('QUALIFY.JCL: both IFOX00 steps must use OBJECT,NODECK')
if j.count('//SYSGO    DD DSN=&&OBJ') != 2:
    errors.append('QUALIFY.JCL: both assembler steps must provide SYSGO object DDs')
if "COND=((4,LT,ASM1),(4,LT,ASM2))" not in j:
    errors.append('QUALIFY.JCL: LKED must be gated on both ASM1 and ASM2')
# Embedded ASM1 must exactly equal authoritative source.
start=j.index('//SYSIN    DD *')+len('//SYSIN    DD *')+1
end=j.index('\n/*\n//*\n//ASM2',start)
embedded=j[start:end].rstrip('\n')
if embedded != asm.read_text().rstrip('\n'):
    errors.append('QUALIFY.JCL: embedded ASM1 differs from authoritative assembler')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print('PASS')
print(f'assembler_lines={len(lines)}')
print(f'max_card_columns={max(map(len,lines))}')
print(f'rshndl_using_count={using}')
print('explicit_r8_dsect_displacements=0')
print('embedded_asm1_matches_source=yes')
print('lked_gated_on_asm1_and_asm2=yes')
