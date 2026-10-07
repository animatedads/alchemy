//RSQQUAL JOB CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),REGION=2048K
//*
//* OOREXX RECORDSET V0.1-DEV5 -- REAL MVS 3.8J QSAM QUALIFICATION
//* EXPECTED: ASM1 RC=0, ASM2 RC=0, LKED RC=0/4, GO RC=0.
//* PRINT should show a record beginning ONE.
//*
//ASM1     EXEC PGM=IFOX00,PARM='OBJECT,NODECK'
//SYSPRINT DD SYSOUT=*
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.AMODGEN,DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSUT2   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSUT3   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSGO    DD DSN=&&OBJ1,UNIT=SYSDA,SPACE=(80,(500,100)),
//            DISP=(NEW,PASS)
//SYSIN    DD *
         TITLE 'OOREXX RECORDSET MVS QSAM BRIDGE'
***********************************************************************
* RecordSetMvsQsam.asm                                                *
*                                                                     *
* MVS 3.8J / OS/VS2 QSAM bridge for the RecordSet object.             *
*                                                                     *
* C linkage entry points (cc370 external names):                      *
*   RQOPEN   rqopen(ddname,mode,&handle,&info)                        *
*   RQCLOSE  rqclose(handle)                                          *
*   RQREAD   rqread(handle,buffer,capacity,&actual)                   *
*   RQWRITE  rqwrite(handle,record,length)                            *
*   RQREWIND rqrewind(handle)                                         *
*                                                                     *
* The bridge deliberately operates only on caller-allocated DD names. *
* Dataset allocation/catalog handling belongs to the next layer.      *
*                                                                     *
* QSAM is used in LOCATE mode so the bridge sees logical records.     *
* For V/VB the four-byte RDW is removed on input and constructed on   *
* output; RecordSet callers see payload bytes only.                   *
*                                                                     *
* dev4 tasking rule: one interpreter per MVS task.  Entry save areas  *
* are static and therefore the assembler bridge is not reentrant yet. *
***********************************************************************
RSETQSAM CSECT
*
* Map QSAM DCB fields.  IHADCB and DCBxxxx symbols are provided by
* the MVS 3.8J DCBD mapping macro.
*
* RecordSet QSAM handle.  A deliberately generous DCB work area is
* used so the executable DCB generated below can be copied per handle.
RSHNDL   DSECT
HMODE    DS    F
HDDNAME  DS    CL8
HDCB     DS    CL256
HEND     DS    0F
HNDLLEN  EQU   HEND-RSHNDL
RSETQSAM CSECT
*
*
* rqopen() info structure: three 4-byte words.  These offsets match
* MvsRecordSetQsamInfo and are intentionally packing-independent.
QIOLRECL EQU   0
QIOBLKSZ EQU   4
QIORECFM EQU   8
*
* Input and output DCB templates.  Attributes are obtained from the DD
* / JFCB by OPEN.  DDNAME is patched in each private copy before OPEN.
INDCB    DCB   DDNAME=RSDUMMY,DSORG=PS,MACRF=GL,EODAD=RQEOF
INDCBLEN EQU   *-INDCB
OUTDCB   DCB   DDNAME=RSDUMMY,DSORG=PS,MACRF=PL
OUTDLEN  EQU   *-OUTDCB
*
***********************************************************************
* RQOPEN                                                              *
***********************************************************************
RQOPEN   DS    0H
         STM   14,12,12(13)
         LR    12,15
         USING RQOPEN,12
         L     10,=A(RSETQSAM)
         USING RSETQSAM,10
         LA    15,SAOPEN
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
         LR    11,1                 save cc370 argument list
         L     3,0(11)              ddname C string
         L     4,4(11)              mode
         L     6,8(11)              void **handle result
         L     7,12(11)             info result
         LTR   3,3
         BZ    RQOPERR
         LTR   6,6
         BZ    RQOPERR
         LTR   7,7
         BZ    RQOPERR
*
* Obtain a private below-the-line handle/DCB.  MVS 3.8J is wholly
* 24-bit; no above-the-line allocation is involved.
         GETMAIN R,LV=HNDLLEN
         LR    8,1
         USING RSHNDL,8
         XC    HMODE(256,8),HMODE(8)
         XC    HMODE+256(HNDLLEN-256,8),HMODE+256(8)
         ST    4,HMODE(8)
         MVC   HDDNAME(8,8),=CL8'        '
         LA    5,HDDNAME(8)
         LA    9,8
RQODDCP  CLI   0(3),X'00'
         BE    RQODDOK
         MVC   0(1,5),0(3)
         LA    3,1(3)
         LA    5,1(5)
         BCT   9,RQODDCP
RQODDOK  EQU   *
*
* Mode 1=READ, 2=WRITE, 3=APPEND.  EXTEND is a native MVS OPEN option
* and therefore does not depend on DISP=MOD in the caller's JCL.
         C     4,=F'1'
         BE    RQOPIN
         C     4,=F'2'
         BE    RQOPOUT
         C     4,=F'3'
         BE    RQOPEXT
         B     RQOPFREE
RQOPIN   MVC   HDCB(INDCBLEN,8),INDCB
         LA    2,HDCB(8)
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME(8)
         OPEN  ((2),(INPUT))
         B     RQOPCHK
RQOPOUT  MVC   HDCB(OUTDLEN,8),OUTDCB
         LA    2,HDCB(8)
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME(8)
         OPEN  ((2),(OUTPUT))
         B     RQOPCHK
RQOPEXT  MVC   HDCB(OUTDLEN,8),OUTDCB
         LA    2,HDCB(8)
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME(8)
         OPEN  ((2),(EXTEND))
RQOPCHK  TM    DCBOFLGS-IHADCB(2),DCBOFOPN
         BZ    RQOPFREE
*
* Return the OPEN-populated DCB metadata as fullwords.
         SR    5,5
         IC    5,DCBLRECL-IHADCB(2)
         SLL   5,8
         IC    5,DCBLRECL-IHADCB+1(2)
         ST    5,QIOLRECL(7)
         SR    5,5
         IC    5,DCBBLKSI-IHADCB(2)
         SLL   5,8
         IC    5,DCBBLKSI-IHADCB+1(2)
         ST    5,QIOBLKSZ(7)
         SR    5,5
         IC    5,DCBRECFM-IHADCB(2)
         ST    5,QIORECFM(7)
         ST    8,0(6)
         SR    15,15               MVSRS_QSAM_OK
         B     RQOPRET
RQOPFREE LR    1,8
         FREEMAIN R,LV=HNDLLEN,A=(1)
RQOPERR  LA    15,8                MVSRS_QSAM_ERROR
RQOPRET  L     13,4(13)
         LM    14,12,12(13)
         BR    14
SAOPEN   DS    18F
*
***********************************************************************
* RQCLOSE                                                             *
***********************************************************************
RQCLOSE  DS    0H
         STM   14,12,12(13)
         LR    12,15
         DROP  12,10
         USING RQCLOSE,12
         L     10,=A(RSETQSAM)
         USING RSETQSAM,10
         LA    15,SACLOSE
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
         L     8,0(1)
         USING RSHNDL,8
         LTR   8,8
         BZ    RQCLERR
         LA    2,HDCB(8)
         CLOSE ((2))
         LR    1,8
         FREEMAIN R,LV=HNDLLEN,A=(1)
         SR    15,15
         B     RQCLRET
RQCLERR  LA    15,8
RQCLRET  L     13,4(13)
         LM    14,12,12(13)
         BR    14
SACLOSE  DS    18F
*
***********************************************************************
* RQREAD                                                              *
* GET LOCATE returns a logical record pointer in R1.                 *
* Variable records begin with a four-byte RDW.                       *
***********************************************************************
RQREAD   DS    0H
         STM   14,12,12(13)
         LR    12,15
         DROP  12,10
         USING RQREAD,12
         L     10,=A(RSETQSAM)
         USING RSETQSAM,10
         LA    15,SAREAD
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
         LR    11,1
         L     8,0(11)             handle
         USING RSHNDL,8
         L     6,4(11)             caller buffer
         L     7,8(11)             capacity
         L     9,12(11)            actualLength result
         LTR   8,8
         BZ    RQRDERR
         LTR   6,6
         BZ    RQRDERR
         LTR   9,9
         BZ    RQRDERR
         LA    2,HDCB(8)
         GET   (2)
         LR    4,1                 QSAM logical record area
*
* Decode F/V/U from the top two DCBRECFM bits.  F/FB are copied as
* DCBLRECL bytes.  V/VB hide the RDW from RecordSet.  U is deliberately
* unsupported in dev3 because QSAM does not supply a stable logical
* length contract for the object yet.
         SR    5,5
         IC    5,DCBRECFM-IHADCB(2)
         N     5,=X'000000C0'
         C     5,=X'00000080'
         BE    RQRDFIX
         C     5,=X'00000040'
         BE    RQRDVAR
         LA    15,12               unsupported
         B     RQRDRET
RQRDFIX  SR    5,5
         IC    5,DCBLRECL-IHADCB(2)
         SLL   5,8
         IC    5,DCBLRECL-IHADCB+1(2)
         B     RQRDCOPY
RQRDVAR  SR    5,5
         IC    5,0(4)
         SLL   5,8
         IC    5,1(4)
         S     5,=F'4'
         BL    RQRDERR
         LA    4,4(4)
RQRDCOPY CLR   5,7
         BH    RQRDERR
         ST    5,0(9)
         LR    2,6
         LR    3,5
* R4 already source address; R5 source length for MVCL pair 4/5.
         MVCL  2,4
         SR    15,15
         B     RQRDRET
*
* DCB EODAD target.  GET transfers here synchronously from RQREAD.
RQEOF    LA    15,4                MVSRS_QSAM_EOF
         B     RQRDRET
RQRDERR  LA    15,8
RQRDRET  L     13,4(13)
         LM    14,12,12(13)
         BR    14
SAREAD   DS    18F
*
***********************************************************************
* RQWRITE                                                             *
* PUT LOCATE returns the next QSAM logical-record area.  For V/VB the *
* The bridge writes the RDW, then copies caller payload.             *
***********************************************************************
RQWRITE  DS    0H
         STM   14,12,12(13)
         LR    12,15
         DROP  12,10
         USING RQWRITE,12
         L     10,=A(RSETQSAM)
         USING RSETQSAM,10
         LA    15,SAWRITE
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
         LR    11,1
         L     8,0(11)
         USING RSHNDL,8
         L     6,4(11)             payload
         L     7,8(11)             payload length
         LTR   8,8
         BZ    RQWRERR
         LA    2,HDCB(8)
         PUT   (2)
         LR    4,1                 returned locate buffer
         SR    5,5
         IC    5,DCBRECFM-IHADCB(2)
         N     5,=X'000000C0'
         C     5,=X'00000080'
         BE    RQWRFIX
         C     5,=X'00000040'
         BE    RQWRVAR
         LA    15,12
         B     RQWRRET
RQWRFIX  SR    5,5
         IC    5,DCBLRECL-IHADCB(2)
         SLL   5,8
         IC    5,DCBLRECL-IHADCB+1(2)
         CLR   7,5
         BNE   RQWRERR              fixed records must match LRECL
         LR    2,4
         LR    3,7
         LR    4,6
         LR    5,7
         MVCL  2,4
         SR    15,15
         B     RQWRRET
RQWRVAR  LR    5,7
         A     5,=F'4'
* Ensure RDW-inclusive length does not exceed DCBLRECL.
         SR    0,0
         IC    0,DCBLRECL-IHADCB(2)
         SLL   0,8
         IC    0,DCBLRECL-IHADCB+1(2)
         CLR   5,0
         BH    RQWRERR
         STH   5,0(4)
         XC    2(2,4),2(4)
         LA    2,4(4)
         LR    3,7
         LR    4,6
         LR    5,7
         MVCL  2,4
         SR    15,15
         B     RQWRRET
RQWRERR  LA    15,8
RQWRRET  L     13,4(13)
         LM    14,12,12(13)
         BR    14
SAWRITE  DS    18F
*
***********************************************************************
* RQREWIND                                                            *
* QSAM sequential reposition is implemented by CLOSE + restoring a    *
* restore clean input DCB + OPEN INPUT; RecordSet skips records.     *
* This reaches the requested one-based logical position.            *
***********************************************************************
RQREWIND DS    0H
         STM   14,12,12(13)
         LR    12,15
         DROP  12,10
         USING RQREWIND,12
         L     10,=A(RSETQSAM)
         USING RSETQSAM,10
         LA    15,SAREW
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
         L     8,0(1)
         USING RSHNDL,8
         LTR   8,8
         BZ    RQRWERR
         L     4,HMODE(8)
         C     4,=F'1'
         BNE   RQRWERR
         LA    2,HDCB(8)
         CLOSE ((2))
         MVC   HDCB(INDCBLEN,8),INDCB
         LA    2,HDCB(8)
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME(8)
         OPEN  ((2),(INPUT))
         TM    DCBOFLGS-IHADCB(2),DCBOFOPN
         BZ    RQRWERR
         SR    15,15
         B     RQRWRET
RQRWERR  LA    15,8
RQRWRET  L     13,4(13)
         LM    14,12,12(13)
         BR    14
SAREW    DS    18F
*
         ENTRY RQOPEN,RQCLOSE,RQREAD,RQWRITE,RQREWIND
         LTORG
*
* Map QSAM DCB fields after the real CSECT.  DCBD creates IHADCB
* as a DSECT; placing it here avoids accidentally leaving executable
* code/data in the dummy section.
         DCBD  DSORG=QS
         END   RSETQSAM
/*
//*
//ASM2     EXEC PGM=IFOX00,PARM='OBJECT,NODECK',COND=(4,LT,ASM1)
//SYSPRINT DD SYSOUT=*
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.AMODGEN,DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSUT2   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSUT3   DD UNIT=SYSDA,SPACE=(TRK,(10,5))
//SYSGO    DD DSN=&&OBJ2,UNIT=SYSDA,SPACE=(80,(500,100)),
//            DISP=(NEW,PASS)
//SYSIN    DD *
         TITLE 'OOREXX RECORDSET QSAM REAL-MVS PROBE'
***********************************************************************
* Standalone MVS 3.8J qualification probe for RecordSetMvsQsam.asm.   *
* No C runtime is required.                                            *
*                                                                     *
* Required DDs:                                                        *
*   RSIN  input sequential data, first record begins ALPHA             *
*   RSOUT output FB/LRECL=80 sequential data                           *
*                                                                     *
* Return codes:                                                        *
*    0 all checks passed                                               *
*   20 input OPEN failed                                               *
*   24 input READ failed                                               *
*   28 first record was not ALPHA                                      *
*   32 rewind failed                                                   *
*   36 second READ after rewind failed                                 *
*   40 input CLOSE failed                                              *
*   44 output OPEN failed                                              *
*   48 output WRITE failed                                             *
*   52 output CLOSE failed                                             *
***********************************************************************
RSPROBE  CSECT
         ENTRY RSPROBE
         USING RSPROBE,12
         STM   14,12,12(13)
         LR    12,15
         LA    15,SAVE
         ST    13,4(15)
         ST    15,8(13)
         LR    13,15
*
* Open caller-allocated DD RSIN for input.
         MVC   IHANDLE,=F'0'
         MVC   IINFO(12),=XL12'00'
         LA    1,IOPENP
         L     15,=V(RQOPEN)
         BALR  14,15
         LTR   15,15
         BNZ   BAD20
         L     2,IHANDLE
         ST    2,IREADP
         ST    2,IREWP
         ST    2,ICLOSEP
*
* Read first logical record and prove the record payload starts ALPHA.
         MVC   ACTLEN,=F'0'
         LA    1,IREADP
         L     15,=V(RQREAD)
         BALR  14,15
         LTR   15,15
         BNZ   BAD24
         CLC   INBUF(5),=C'ALPHA'
         BNE   BAD28
*
* Rewind and read it again.  This qualifies CLOSE/reopen reposition.
         LA    1,IREWP
         L     15,=V(RQREWIND)
         BALR  14,15
         LTR   15,15
         BNZ   BAD32
         MVC   ACTLEN,=F'0'
         LA    1,IREADP
         L     15,=V(RQREAD)
         BALR  14,15
         LTR   15,15
         BNZ   BAD36
         CLC   INBUF(5),=C'ALPHA'
         BNE   BAD28
*
         LA    1,ICLOSEP
         L     15,=V(RQCLOSE)
         BALR  14,15
         LTR   15,15
         BNZ   BAD40
*
* Open caller-allocated RSOUT.  JCL fixes it at FB/LRECL=80.  The low
* level bridge intentionally requires a complete fixed logical record;
* padding belongs to the higher RecordSet semantic layer.
         MVC   OHANDLE,=F'0'
         MVC   OINFO(12),=XL12'00'
         LA    1,OOPENP
         L     15,=V(RQOPEN)
         BALR  14,15
         LTR   15,15
         BNZ   BAD44
         L     2,OHANDLE
         ST    2,OWRITEP
         ST    2,OCLOSEP
         MVC   OUTBUF(80),=CL80' '
         MVC   OUTBUF(3),=C'ONE'
         LA    1,OWRITEP
         L     15,=V(RQWRITE)
         BALR  14,15
         LTR   15,15
         BNZ   BAD48
         LA    1,OCLOSEP
         L     15,=V(RQCLOSE)
         BALR  14,15
         LTR   15,15
         BNZ   BAD52
         SR    15,15
         B     RETURN
BAD20    LA    15,20
         B     RETURN
BAD24    LA    15,24
         B     RETURN
BAD28    LA    15,28
         B     RETURN
BAD32    LA    15,32
         B     RETURN
BAD36    LA    15,36
         B     RETURN
BAD40    LA    15,40
         B     RETURN
BAD44    LA    15,44
         B     RETURN
BAD48    LA    15,48
         B     RETURN
BAD52    LA    15,52
RETURN   LR    2,15
         L     13,4(13)
         LM    14,12,12(13)
         LR    15,2
         BR    14
*
SAVE     DS    18F
IDD      DC    CL8'RSIN'
ODD      DC    CL8'RSOUT'
IMODE    DC    F'1'
OMODE    DC    F'2'
IHANDLE  DC    F'0'
OHANDLE  DC    F'0'
IINFO    DS    3F
OINFO    DS    3F
ACTLEN   DC    F'0'
INCAP    DC    F'256'
OUTLEN   DC    F'80'
INBUF    DS    CL256
OUTBUF   DS    CL80
*
* cc370-compatible argument value lists: each word contains the actual
* argument value (pointer or integer), exactly as generated C does.
IOPENP   DC    A(IDD),F'1',A(IHANDLE),A(IINFO)
OOPENP   DC    A(ODD),F'2',A(OHANDLE),A(OINFO)
IREADP   DC    F'0',A(INBUF),F'256',A(ACTLEN)
IREWP    DC    F'0'
ICLOSEP  DC    F'0'
OWRITEP  DC    F'0',A(OUTBUF),F'80'
OCLOSEP  DC    F'0'
         LTORG
         END   RSPROBE
/*
//*
//LKED     EXEC PGM=IEWL,PARM='XREF,LIST,LET',
//         COND=((4,LT,ASM1),(4,LT,ASM2))
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSDA,SPACE=(TRK,(5,2))
//SYSLIN   DD DSN=&&OBJ1,DISP=(OLD,DELETE)
//         DD DSN=&&OBJ2,DISP=(OLD,DELETE)
//         DD *
 ENTRY RSPROBE
 NAME RSPROBE(R)
/*
//SYSLMOD  DD DSN=&&LOAD(RSPROBE),DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(5,2,1)),DCB=(DSORG=PO,RECFM=U,BLKSIZE=6144)
//*
//GO       EXEC PGM=RSPROBE,COND=(4,LT,LKED)
//STEPLIB  DD DSN=&&LOAD,DISP=(OLD,DELETE)
//RSIN     DD *
ALPHA
BETA
/*
//RSOUT    DD DSN=&&RSOUT,DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(1,1)),DCB=(DSORG=PS,RECFM=FB,LRECL=80,
//            BLKSIZE=800)
//*
//PRINT    EXEC PGM=IEBGENER,COND=(0,NE,GO)
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD DSN=&&RSOUT,DISP=(OLD,DELETE)
//SYSUT2   DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUDUMP DD SYSOUT=*
