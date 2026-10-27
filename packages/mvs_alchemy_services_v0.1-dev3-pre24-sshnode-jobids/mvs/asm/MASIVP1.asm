         PRINT NOGEN
MASIVP1  CSECT
         USING MASIVP1,15
         B     START
         DC    CL8'MASIVP1 '
START    DS    0H
* PRE9: the live executable IVP is MASLIVE.asm and transport is MASD75.asm.
* MASIVP1 remains a compatibility entry and does not synthesize success.
         LA    15,4
         BR    14
         END   MASIVP1
