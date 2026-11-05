#include <errno.h>
#include <math.h>
#include <stdio.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *out=fopen(argv[1],"wb");
    if (!out) {perror("open tone output");return 1;}
    for (int i=0;i<8000;i++) {
        float x=(float)(0.5*sin(2*M_PI*1000*i/8000));
        if (fwrite(&x,sizeof x,1,out)!=1) {perror("write tone");fclose(out);return 1;}
    }
    if (fclose(out)) {perror("close tone");return 1;}
    return 0;
}
