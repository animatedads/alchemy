* MASWIRE - mvs.alchemy/1 fixed wire definitions
MASWMAJ  EQU   1
MASWMIN  EQU   0
MASWHLEN EQU   48
MASWMAX  EQU   32768           INITIAL NEGOTIATED CEILING
*
MASOPHEL EQU   1               HELLO
MASOPACC EQU   2               ACCEPT
MASOPPNG EQU   3               PING
MASOPOPN EQU   16              OPEN
MASOPCAL EQU   17              CALL
MASOPCLS EQU   18              CLOSE
MASOPDSC EQU   19              DISCONNECT
*
MASWHEAD DSECT
MASWEYE  DS    CL4             'ALCH'
MASWVER  DS    XL2             MAJOR,MINOR
MASWHDRL DS    H               HEADER LENGTH
MASWTOTL DS    F               TOTAL FRAME LENGTH
MASWSESH DS    F               SESSION ID HIGH
MASWSESL DS    F               SESSION ID LOW
MASWREQH DS    F               REQUEST ID HIGH
MASWREQL DS    F               REQUEST ID LOW
MASWOBJ  DS    F               REMOTE OBJECT HANDLE
MASWOP   DS    H               OPERATION
MASWFLG  DS    H               FLAGS
MASWSTAT DS    F               STATUS
MASWRSN  DS    F               REASON
MASWPLEN DS    F               PAYLOAD LENGTH
MASWHSIZ EQU   *-MASWHEAD
