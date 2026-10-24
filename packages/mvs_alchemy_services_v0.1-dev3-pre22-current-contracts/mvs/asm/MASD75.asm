MASD75   TITLE 'MVS ALCHEMY DIRECT HERCULES X75 TRANSPORT'
***********************************************************************
* MASD75 - MAS byte transport for MVS 3.8J under Hercules.           *
* Uses the Hercules TCPIP X'75' instruction directly.                 *
* No EZASMI or EZASOH03 guest installation is required.               *
*                                                                     *
* R1 -> MD75CB. Functions:                                            *
* 1 INITIALIZE  2 CONNECT  3 SEND  4 RECEIVE  5 CLOSE  6 TERMINATE   *
***********************************************************************
MASD75   CSECT
         ENTRY MASD75
         STM   14,12,12(13)
         LR    12,15
         USING MASD75,12
         ST    13,SAVE+4
         LA    2,SAVE
         ST    2,8(13)
         LR    13,2
         LR    10,1
         USING MD75CB,10
         SR    9,9
         LH    2,MD75FUNC
         CH    2,=H'1'
         BE    INIT
         CH    2,=H'2'
         BE    CONNECT
         CH    2,=H'3'
         BE    SEND
         CH    2,=H'4'
         BE    RECEIVE
         CH    2,=H'5'
         BE    CLOSE
         CH    2,=H'6'
         BE    TERM
         LA    9,8
         B     RETURN
*
INIT     DS    0H
         XC    MD75ERR,MD75ERR
         XC    MD75RET,MD75RET
         XC    MD75ACT,MD75ACT
         MVC   MD75SOCK,MINUS1
*        INITAPI is a harmless X'75' function 1 operation.
         TM    MD75FLAG+1,X'01'
         BNO   ININTR
         WTO   'MASD75 X75 INITAPI BEGIN'
ININTR   LA    7,1
         SR    8,8
         SR    9,9
         SR    1,1
         LA    5,DUMMY
         LA    11,DUMMY
         BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         TM    MD75FLAG+1,X'01'
         BNO   INIPAS
         WTO   'MASD75 X75 INITAPI PASS'
INIPAS   DS    0H
*        Allocate an IPv4 stream socket: AF_INET=2, SOCK_STREAM=1.
         TM    MD75FLAG+1,X'01'
         BNO   SOCNTR
         WTO   'MASD75 X75 SOCKET BEGIN'
SOCNTR   LA    7,5
         L     8,SOCKPARM
         SR    9,9
         SR    1,1
         LA    5,DUMMY
         LA    11,DUMMY
         BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         TM    MD75FLAG+1,X'01'
         BNO   SOCPAS
         WTO   'MASD75 X75 SOCKET PASS'
SOCPAS   ST    4,MD75SOCK
         LTR   4,4
         BNP   FAILED
         B     RETURN
*
CONNECT  DS    0H
         TM    MD75FLAG+1,X'01'
         BNO   CONNTR
         WTO   'MASD75 X75 CONNECT BEGIN'
CONNTR   DS    0H
*        Function 7 encodes socket number in the high halfword.
         L     7,MD75SOCK
         SLL   7,16
         O     7,FUNC7
         L     8,MD75HOST
         SR    9,9
         ICM   9,B'0011',MD75PORT
         O     9,FAMILY2
         SR    1,1
         LA    5,DUMMY
         LA    11,DUMMY
         MVC   RETRY,RETRYMAX
CONNLP   BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         LTR   4,4
         BNZ   CONNWAIT
         TM    MD75FLAG+1,X'01'
         BNO   RETURN
         WTO   'MASD75 X75 CONNECT PASS'
         B     RETURN
CONNWAIT DS    0H
         C     4,MINUS2
         BNE   FAILED
         L     6,RETRY
         BCTR  6,0
         ST    6,RETRY
         LTR   6,6
         BZ    TIMEOUT
         STIMER WAIT,BINTVL=WAIT5
         B     CONNLP
*
SEND     DS    0H
         MVC   TXPTR,MD75BUFA
         MVC   TXLEFT,MD75BUFL
         XC    MD75ACT,MD75ACT
SENDLP   L     1,TXLEFT
         LTR   1,1
         BZ    RETURN
         L     7,MD75SOCK
         SLL   7,16
         O     7,FUNC10
         SR    8,8
         SR    9,9
         L     5,TXPTR
         LA    11,DUMMY
         BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         LTR   4,4
         BNP   FAILED
         L     3,TXPTR
         AR    3,4
         ST    3,TXPTR
         L     3,TXLEFT
         SR    3,4
         ST    3,TXLEFT
         L     3,MD75ACT
         AR    3,4
         ST    3,MD75ACT
         B     SENDLP
*
RECEIVE  DS    0H
         MVC   RXPTR,MD75BUFA
         MVC   RXLEFT,MD75BUFL
         XC    MD75ACT,MD75ACT
         MVC   RETRY,RETRYMAX
RECVLP   L     9,RXLEFT
         LTR   9,9
         BZ    RETURN
         LA    7,11
         L     8,MD75SOCK
         SR    1,1
         LA    5,DUMMY
         L     11,RXPTR
         BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         C     4,MINUS2
         BNE   RECVGOT
         L     6,RETRY
         BCTR  6,0
         ST    6,RETRY
         LTR   6,6
         BZ    TIMEOUT
         STIMER WAIT,BINTVL=WAIT5
         B     RECVLP
RECVGOT  LTR   4,4
         BNP   FAILED
         L     3,RXPTR
         AR    3,4
         ST    3,RXPTR
         L     3,RXLEFT
         SR    3,4
         ST    3,RXLEFT
         L     3,MD75ACT
         AR    3,4
         ST    3,MD75ACT
         MVC   RETRY,RETRYMAX
         B     RECVLP
*
CLOSE    DS    0H
         L     8,MD75SOCK
         LTR   8,8
         BNP   RETURN
         LA    7,12
         SR    9,9
         SR    1,1
         LA    5,DUMMY
         LA    11,DUMMY
         BAL   14,XCALL
         LTR   15,15
         BNZ   FAILED
         MVC   MD75SOCK,MINUS1
         B     RETURN
*
TERM     DS    0H
*        Direct X'75' has no guest-side TERMAPI storage to release.
         B     RETURN
*
TIMEOUT  LA    6,2
         ST    6,MD75ERR
         B     FAILED
FAILED   ST    4,MD75RET
         L     6,MD75ERR
         LTR   6,6
         BNZ   FAILRC
         LA    6,3
         ST    6,MD75ERR
FAILRC   LA    9,12
RETURN   LR    15,9
         L     13,4(13)
         L     14,12(13)
         LM    0,12,20(13)
         BR    14
***********************************************************************
* XCALL - execute one Hercules TCPIP X'75' conversation.              *
* In: R7=function, R8=aux1, R9=aux2, R1=input length, R5=input addr. *
*     R11=output address. First X75 uses R5 exactly as EZASOH03 does. *
* Out: R4=native result. R15=0 on instruction success.                *
* X'75' uses R14 as its conversation identifier, so caller R14 is    *
* saved before the first instruction and restored after deallocation. *
***********************************************************************
XCALL    ST    14,XRET
         SR    0,0
         SR    3,3
X75IN    DC    X'75005000'
         LTR   15,15
         BNZ   XBAD
         SR    0,0
         LA    3,1
         LR    6,11
X75OUT   DC    X'75006000'
         LTR   15,15
         BNZ   XBAD
         ST    4,MD75RET
         SR    15,15
         L     14,XRET
         BR    14
XBAD     MVC   MD75RET,MINUS1
         LA    6,1
         ST    6,MD75ERR
         LA    15,16
         L     14,XRET
         BR    14
*
SAVE     DS    18F
XRET     DS    F
TXPTR    DS    F
TXLEFT   DS    F
RXPTR    DS    F
RXLEFT   DS    F
RETRY    DS    F
DUMMY    DC    X'00'
         DS    0F
SOCKPARM DC    X'00020001'
FAMILY2  DC    X'00020000'
FUNC7    DC    F'7'
FUNC10   DC    F'10'
MINUS1   DC    F'-1'
MINUS2   DC    F'-2'
RETRYMAX DC    F'600'
WAIT5    DC    F'5'
         LTORG
*
MD75CB   DSECT
MD75EYE  DS    CL4
MD75LEN  DS    H
MD75VER  DS    H
MD75FUNC DS    H
MD75FLAG DS    H
MD75SOCK DS    F
MD75ERR  DS    F
MD75RET  DS    F
MD75ACT  DS    F
MD75HOST DS    XL4
MD75PORT DS    H
MD75RSV  DS    H
MD75BUFA DS    A
MD75BUFL DS    F
MD75MAX  DS    F
MD75SIZE EQU   *-MD75CB
         END   MASD75
