MASLIVE  TITLE 'MVS ALCHEMY LIVE GUEST SERVICE QUALIFICATION'
***********************************************************************
* Runs inside ED209Z. Uses MASD75 -> Hercules X'75' host TCP.       *
* Drives mvs.alchemy/1 frames to the host gateway.                   *
* Verifies HELLO/PING, QUEUE, DB, IMAP, SMTP and PATH.                *
***********************************************************************
MASLIVE  CSECT
         STM   14,12,12(13)
         LR    12,15
         LA    11,1(,12)
         LA    11,4095(,11)
         USING MASLIVE,12,11
         ST    13,SAVE+4
         LA    2,SAVE
         ST    2,8(13)
         LR    13,2
         XC    REQNO,REQNO
*
* Initialize X75 transport and connect to the host loopback.
*
         MVC   CBFUNC,=H'1'
         BAL   14,D75CALL
         LTR   15,15
         BNZ   FAIL
         MVC   CBFUNC,=H'2'
         BAL   14,D75CALL
         LTR   15,15
         BNZ   FAIL
*
* HELLO / ACCEPT
*
         L     2,=F'1'
         L     3,=A(HELLOP)
         LA    4,HELLOL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+32(2),=H'2'
         BNE   FAIL
         WTO   'MASLIVE PASS HELLO'
*
* Binary PING proves 00/FF survives the guest/host carrier.
*
         L     2,=F'3'
         L     3,=A(PINGP)
         LA    4,PINGL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+60(5),=X'00FF4D4153'
         BNE   FAIL
         WTO   'MASLIVE PASS PING BINARY'
*
* QUEUE: OPEN, PUT, DEPTH, GET.
*
         L     2,=F'4096'
         L     3,=A(QOPENP)
         LA    4,QOPENL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   QPUTH(4),RESPBUF+62
         MVC   QDEPTHH(4),RESPBUF+62
         MVC   QGETH(4),RESPBUF+62
         L     2,=F'4097'
         L     3,=A(QPUTP)
         LA    4,QPUTL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'4099'
         L     3,=A(QDEPTHP)
         LA    4,QDEPTHL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   TMPF(4),RESPBUF+61
         CLC   TMPF(4),=F'1'
         BNE   FAIL
         L     2,=F'4098'
         L     3,=A(QGETP)
         LA    4,QGETL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+60(7),=X'71756575652D41'
         BNE   FAIL
         WTO   'MASLIVE PASS QUEUE'
*
* DATABASE: OPEN, PUT opaque bytes, GET exact bytes.
*
         L     2,=F'4352'
         L     3,=A(DBOPENP)
         LA    4,DBOPENL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   DBPUTH(4),RESPBUF+62
         MVC   DBGETH(4),RESPBUF+62
         L     2,=F'4354'
         L     3,=A(DBPUTP)
         LA    4,DBPUTL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'4353'
         L     3,=A(DBGETP)
         LA    4,DBGETL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+61(3),=X'7600FF'
         BNE   FAIL
         WTO   'MASLIVE PASS DATABASE'
*
* IMAP personality: session, mailbox catalogue, message body.
*
         L     2,=F'5120'
         L     3,=A(EMPTY)
         SR    4,4
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   MLISTH(4),RESPBUF+62
         MVC   MOPENH(4),RESPBUF+62
         L     2,=F'5122'
         L     3,=A(MLISTP)
         LA    4,MLISTL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5123'
         L     3,=A(MOPENP)
         LA    4,MOPENL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   MBODYH(4),RESPBUF+63
         L     2,=F'5126'
         L     3,=A(MBODYP)
         LA    4,MBODYL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+60(7),=X'68656C6C6F0D0A'
         BNE   FAIL
         WTO   'MASLIVE PASS IMAP'
*
* SMTP personality: build draft, satisfy qualification gates, submit.
*
         L     2,=F'5152'
         L     3,=A(EMPTY)
         SR    4,4
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   SFROMH(4),RESPBUF+62
         MVC   STOH(4),RESPBUF+62
         MVC   STEXTH(4),RESPBUF+62
         MVC   SSIGNH(4),RESPBUF+62
         MVC   SSENDH(4),RESPBUF+62
         L     2,=F'5153'
         L     3,=A(SFROMP)
         LA    4,SFROML
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5154'
         L     3,=A(STOP)
         LA    4,STOL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5155'
         L     3,=A(STEXTP)
         LA    4,STEXTL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5156'
         L     3,=A(SSIGNP)
         LA    4,SSIGNL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5157'
         L     3,=A(SSENDP)
         LA    4,SSENDL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+64(14),=X'52454C41595F454C494749424C45'
         BNE   FAIL
         WTO   'MASLIVE PASS SMTP'
*
* PATH: create/write/close, reopen/read exact binary bytes.
*
         L     2,=F'5376'
         L     3,=A(POPNWP)
         LA    4,POPNWL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   PWRITEH(4),RESPBUF+62
         MVC   PCLOSEH(4),RESPBUF+62
         L     2,=F'5378'
         L     3,=A(PWRITEP)
         LA    4,PWRITEL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5380'
         L     3,=A(PCLOSEP)
         LA    4,PCLOSEL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         L     2,=F'5376'
         L     3,=A(POPNRP)
         LA    4,POPNRL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         MVC   PREADH(4),RESPBUF+62
         L     2,=F'5377'
         L     3,=A(PREADP)
         LA    4,PREADL
         BAL   14,DOREQ
         LTR   15,15
         BNZ   FAIL
         CLC   RESPBUF+60(13),=X'67756573742D706174682D00FF'
         BNE   FAIL
         WTO   'MASLIVE PASS PATH'
*
* Graceful protocol and transport close.
*
         L     2,=F'19'
         L     3,=A(EMPTY)
         SR    4,4
         BAL   14,DOREQ
         MVC   CBFUNC,=H'5'
         BAL   14,D75CALL
         MVC   CBFUNC,=H'6'
         BAL   14,D75CALL
         WTO   'MASLIVE PASS ALL'
         LA    15,0
         B     EXIT
*
FAIL     WTO   'MASLIVE FAIL SEE MAS/HERCULES LOGS'
         MVC   CBFUNC,=H'5'
         BAL   14,D75CALL
         MVC   CBFUNC,=H'6'
         BAL   14,D75CALL
         LA    15,8
EXIT     ST    15,FINALRC
         L     15,FINALRC
         L     13,4(13)
         L     14,12(13)
         LM    0,12,20(13)
         BR    14
*
* D75CALL - call the MASD75 load-module entry with our transport CB.
*
D75CALL  ST    14,D75RET
         L     1,=A(D75CB)
         L     15,=V(MASD75)
         BALR  14,15
         ST    15,D75RC
         L     14,D75RET
         L     15,D75RC
         BR    14
*
* DOREQ - R2=operation, R3=payload address, R4=payload length.
* Send one ALCH frame and receive one complete response frame.
*
DOREQ    ST    14,DORRET
         STH   2,CURROP
         ST    3,PAYPTR
         ST    4,PAYLEN
         MVC   REQBUF(48),HEADTPL
         L     5,PAYLEN
         LA    6,48
         AR    6,5
         ST    6,REQBUF+8
         L     6,REQNO
         LA    6,1(,6)
         ST    6,REQNO
         ST    6,REQBUF+24
         MVC   REQBUF+32(2),CURROP
         ST    5,REQBUF+44
         LTR   5,5
         BZ    DORSEND
         LA    0,REQBUF+48
         LR    1,5
         L     2,PAYPTR
         LR    3,5
         MVCL  0,2
DORSEND  MVC   CBFUNC,=H'3'
         LA    6,REQBUF
         ST    6,CBBUFA
         L     6,REQBUF+8
         ST    6,CBBUFL
         BAL   14,D75CALL
         LTR   15,15
         BNZ   DORFAIL
         MVC   CBFUNC,=H'4'
         LA    6,RESPBUF
         ST    6,CBBUFA
         MVC   CBBUFL,=F'48'
         BAL   14,D75CALL
         LTR   15,15
         BNZ   DORFAIL
         CLC   RESPBUF(4),=X'414C4348'
         BNE   DORFAIL
         CLC   RESPBUF+36(4),=F'0'
         BNE   DORFAIL
         L     5,RESPBUF+44
         C     5,=F'2000'
         BH    DORFAIL
         LTR   5,5
         BZ    DOROK
         MVC   CBFUNC,=H'4'
         LA    6,RESPBUF+48
         ST    6,CBBUFA
         ST    5,CBBUFL
         BAL   14,D75CALL
         LTR   15,15
         BNZ   DORFAIL
DOROK    LA    15,0
         B     DOROUT
DORFAIL  LA    15,8
DOROUT   ST    15,DORRC
         L     14,DORRET
         L     15,DORRC
         BR    14
*
SAVE     DS    18F
FINALRC  DC    F'8'
D75RET   DS    F
D75RC    DS    F
DORRET   DS    F
DORRC    DS    F
CURROP   DS    H
         DS    H
PAYPTR   DS    F
PAYLEN   DS    F
REQNO    DC    F'0'
TMPF     DS    F
EMPTY    DC    X'00'
HEADTPL  DC    X'414C4348',X'0100',H'48',F'0',F'0',F'1',F'0',F'0',F'0'
         DC    H'0',H'0',F'0',F'0',F'0'
REQBUF   DS    CL2048
RESPBUF  DS    CL2048
*
* MASD75 control block.  Layout matches MASD75.asm MD75CB.
*
D75CB    DS    0F
CBEYE    DC    CL4'MD75'
CBLEN    DC    H'48'
CBVER    DC    H'1'
CBFUNC   DC    H'0'
CBFLAG   DC    H'1'
CBSOCK   DC    F'-1'
CBERR    DC    F'0'
CBRET    DC    F'0'
CBACT    DC    F'0'
CBHOST   DC    X'7F000001'
CBPORT   DC    X'90D3'
CBRSV    DC    H'0'
CBBUFA   DC    A(0)
CBBUFL   DC    F'0'
CBMAX    DC    F'0'
*
* Fixed typed-value payloads. Tags and character data are wire ASCII.
*
HELLOP   DC    X'0300050000000004434353494400000025'
HELLOL   EQU   *-HELLOP
PINGP    DC    X'01000400000000054543484F00FF4D4153'
PINGL    EQU   *-PINGP
QOPENP   DC    X'02000400000000084E414D4503334C4956452E51'
QOPENL   EQU   *-QOPENP
QPUTP    DC    X'060006000000000448414E444C45'
QPUTH    DC    F'0'
         DC    X'01000400000000074441544171756575652D41'
QPUTL    EQU   *-QPUTP
QDEPTHP  DC    X'060006000000000448414E444C45'
QDEPTHH  DC    F'0'
QDEPTHL  EQU   *-QDEPTHP
QGETP    DC    X'060006000000000448414E444C45'
QGETH    DC    F'0'
QGETL    EQU   *-QGETP
DBOPENP  DC    X'02000400000000094E414D4503334C4956452E4442'
DBOPENL  EQU   *-DBOPENP
DBPUTP   DC    X'060006000000000448414E444C45'
DBPUTH   DC    F'0'
         DC    X'01000300000000024B45596B31'
         DC    X'010005000000000356414C55457600FF'
DBPUTL   EQU   *-DBPUTP
DBGETP   DC    X'060006000000000448414E444C45'
DBGETH   DC    F'0'
         DC    X'01000300000000024B45596B31'
DBGETL   EQU   *-DBGETP
MLISTP   DC    X'060006000000000448414E444C45'
MLISTH   DC    F'0'
MLISTL   EQU   *-MLISTP
MOPENP   DC    X'060006000000000448414E444C45'
MOPENH   DC    F'0'
         DC    X'02000700000000074D41494C424F580333494E424F58'
         DC    X'03000B000000000455494456414C494449545900000047'
         DC    X'0300030000000004554944000003E9'
MOPENL   EQU   *-MOPENP
MBODYP   DC    X'06000700000000044D455353414745'
MBODYH   DC    F'0'
MBODYL   EQU   *-MBODYP
SFROMP   DC    X'060006000000000448414E444C45'
SFROMH   DC    F'0'
         DC    X'020007000000001541444452455353033373656E64657240'
         DC    X'6578616D706C652E74657374'
SFROML   EQU   *-SFROMP
STOP     DC    X'060006000000000448414E444C45'
STOH     DC    F'0'
         DC    X'020007000000001341444452455353033372637074406578'
         DC    X'616D706C652E74657374'
STOL     EQU   *-STOP
STEXTP   DC    X'060006000000000448414E444C45'
STEXTH   DC    F'0'
         DC    X'010004000000000944415441736D74702D6C697665'
STEXTL   EQU   *-STEXTP
SSIGNP   DC    X'060006000000000448414E444C45'
SSIGNH   DC    F'0'
         DC    X'0300080000000004564552494649454400000001'
SSIGNL   EQU   *-SSIGNP
SSENDP   DC    X'060006000000000448414E444C45'
SSENDH   DC    F'0'
         DC    X'03000A0000000004415554484F52495A454400000001'
         DC    X'030006000000000445475245535300000001'
SSENDL   EQU   *-SSENDP
POPNWP   DC    X'02000400000000125041544803332F752F555345522F6C69'
         DC    X'76652E747874'
         DC    X'02000400000000174F50545303334F57524F4E4C59204F43'
         DC    X'52454154204F5452554E43'
         DC    X'020008000000000846494C4544415441033342494E415259'
POPNWL   EQU   *-POPNWP
PWRITEP  DC    X'060006000000000448414E444C45'
PWRITEH  DC    F'0'
         DC    X'010004000000000D4441544167756573742D706174682D00FF'
PWRITEL  EQU   *-PWRITEP
PCLOSEP  DC    X'060006000000000448414E444C45'
PCLOSEH  DC    F'0'
PCLOSEL  EQU   *-PCLOSEP
POPNRP   DC    X'02000400000000125041544803332F752F555345522F6C69'
         DC    X'76652E747874'
         DC    X'02000400000000094F50545303334F52444F4E4C59'
         DC    X'020008000000000846494C4544415441033342494E415259'
POPNRL   EQU   *-POPNRP
PREADP   DC    X'060006000000000448414E444C45'
PREADH   DC    F'0'
PREADL   EQU   *-PREADP
         LTORG
         END   MASLIVE
