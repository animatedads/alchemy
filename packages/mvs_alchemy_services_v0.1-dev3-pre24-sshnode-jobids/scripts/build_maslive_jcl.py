#!/usr/bin/env python3
from pathlib import Path
import argparse

p=argparse.ArgumentParser()
p.add_argument('--package-root',required=True)
p.add_argument('--output',required=True)
p.add_argument('--job-card',default="//MASLIVE JOB (ACCT),'MAS LIVE',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1)")
a=p.parse_args()
root=Path(a.package_root)
masd75=(root/'mvs/asm/MASD75.asm').read_text().rstrip()+"\n"
maslive=(root/'mvs/asm/MASLIVE.asm').read_text().rstrip()+"\n"

def asm_step(name,member,source):
    return f"""//{name:<8} EXEC PGM=IFOX00,REGION=4096K,
// PARM=('XREF(FULL),OBJ,SYSPARM((ON,GEN,NODATA,YES,YES))','NODECK')
//SYSLIB   DD DSN=SYS2.SXMACLIB,DISP=SHR
//         DD DSN=SYS2.MACLIB,DISP=SHR
//         DD DSN=SYS1.AMODGEN,DISP=SHR
//         DD DSN=SYS1.MACLIB,DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(1700,(5600,500))
//SYSUT2   DD UNIT=SYSDA,SPACE=(1700,(1300,500))
//SYSUT3   DD UNIT=SYSDA,SPACE=(1700,(1300,500))
//SYSPRINT DD SYSOUT=*
//SYSPUNCH DD DUMMY
//SYSGO    DD DSN=&&OBJ({member}),DISP=(MOD,PASS),
//            SPACE=(800,(2000,1000,10)),UNIT=SYSDA
//SYSIN    DD *
{source}/*
"""

if len(a.job_card) > 80:
    raise SystemExit('JOB card exceeds 80 columns')
j=a.job_card.rstrip()+"\n"
j+="//* REAL ED209Z MAS GUEST TRANSPORT QUALIFICATION\n"
j+=asm_step('ASM75','MASD75',masd75)
j+=asm_step('ASMLIVE','MASLIVE',maslive)
j+="""//LINK     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLMOD  DD DSN=&&LOAD,DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(2,1,1)),DCB=(DSORG=PO,RECFM=U,BLKSIZE=6144)
//OBJECT   DD DSN=&&OBJ,DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSLIN   DD *
 INCLUDE OBJECT(MASD75)
 INCLUDE OBJECT(MASLIVE)
 ENTRY MASLIVE
 NAME MASLIVE(R)
/*
//RUN      EXEC PGM=MASLIVE,COND=(4,LT)
//STEPLIB  DD DSN=&&LOAD,DISP=(OLD,DELETE)
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//
"""
Path(a.output).write_text(j)
