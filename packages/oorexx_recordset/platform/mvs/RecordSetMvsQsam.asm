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
* dev6 tasking rule: one interpreter per MVS task.  Entry save areas  *
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
         XC    HMODE(256),HMODE
         XC    HMODE+256(HNDLLEN-256),HMODE+256
         ST    4,HMODE
         MVC   HDDNAME(8),=CL8'        '
         LA    5,HDDNAME
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
RQOPIN   MVC   HDCB(INDCBLEN),INDCB
         LA    2,HDCB
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME
         OPEN  ((2),(INPUT))
         B     RQOPCHK
RQOPOUT  MVC   HDCB(OUTDLEN),OUTDCB
         LA    2,HDCB
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME
         OPEN  ((2),(OUTPUT))
         B     RQOPCHK
RQOPEXT  MVC   HDCB(OUTDLEN),OUTDCB
         LA    2,HDCB
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME
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
         LA    2,HDCB
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
         LA    2,HDCB
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
         LA    2,HDCB
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
         L     4,HMODE
         C     4,=F'1'
         BNE   RQRWERR
         LA    2,HDCB
         CLOSE ((2))
         MVC   HDCB(INDCBLEN),INDCB
         LA    2,HDCB
         MVC   DCBDDNAM-IHADCB(8,2),HDDNAME
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
