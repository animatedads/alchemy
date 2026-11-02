/* Sydney V5V selective high-resolution structural observation, v0.30.
 * User-supplied source crops only. NOT a ferry or ship identity engine.
 * Reads exact RGB24 cropped pixels and reports interpretable morphological
 * image evidence; threshold selection remains separate in ooRexx.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
static void fail(const char*s){fprintf(stderr,"STRUCTURE_FAIL:%s\n",s);exit(3);}
int main(int argc,char **argv){
 if(argc!=4){fprintf(stderr,"USAGE ship_structure_native image.rgb width height\n");return 2;}
 char *end=NULL;long width=strtol(argv[2],&end,10);if(*end)fail("width malformed");
 long height=strtol(argv[3],&end,10);if(*end)fail("height malformed");
 if(width<8||height<8||width>4096||height>4096)fail("invalid dimensions");
 size_t n=(size_t)width*height*3;
 FILE*f=fopen(argv[1],"rb");if(!f)fail("missing RGB source");
 uint8_t *p=malloc(n);if(!p)fail("allocation");
 if(fread(p,1,n,f)!=n || fgetc(f)!=EOF)fail("size mismatch");
 fclose(f);
 long bright=0,lower=0,contrastH=0,contrastV=0,highlights=0;
 double luminanceSum=0;
 for(long y=height/2;y<height;y++) for(long x=0;x<width;x++){
   size_t k=(size_t)(y*width+x)*3;
   int r=p[k],g=p[k+1],b=p[k+2];
   int y10000=2126*r+7152*g+722*b;
   /* 160.00/255 threshold fixed BEFORE held-out comparison. */
   if(y10000>1600000)bright++;
   if(y10000>1800000)highlights++;
   luminanceSum+=(double)y10000/10000.0;
   lower++;
   if(x>0){size_t j=k-3;int prev=2126*p[j]+7152*p[j+1]+722*p[j+2];if(abs(y10000-prev)>220000)contrastH++;}
   if(y>height/2){size_t j=k-(size_t)width*3;int prev=2126*p[j]+7152*p[j+1]+722*p[j+2];if(abs(y10000-prev)>220000)contrastV++;}
 }
 if(lower==0)fail("no pixels");
 printf("STRUCTURE_V1|%ld|%ld|%.8f|%.8f|%.8f|%.8f|%.3f\n",width,height,(double)bright/lower,(double)highlights/lower,(double)contrastH/lower,(double)contrastV/lower,luminanceSum/lower);
 free(p);return 0;
}
