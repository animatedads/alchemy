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
