         PRINT NOGEN
MASIVP0  CSECT
         USING MASIVP0,15
         B     START
         DC    CL8'MASIVP0 '
START    DS    0H
* BASE-0 has no network dependency.  This IVP is deliberately limited to
* linkage/layout constants; BASE-1 will add DYN75 HELLO/PING qualification.
         LA    15,0
         BR    14
         COPY  MASRC
         COPY  MASWIRE
         END   MASIVP0
