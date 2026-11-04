/* Native source RGB24 three-timestamp contrast in a V5V-proposed box.
 * One causal lookup at current time t; references t-150 and t-300 frames only.
 * These feature counts are evidence, not an object classifier. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <math.h>
static void bad(const char*msg){fprintf(stderr,"RGB_MOTION_STRUCTURE_FAIL:%s\n",msg);exit(3);}
static long num(const char*s){char *end=NULL;long v=strtol(s,&end,10);if(*end)bad("bad integer");return v;}
static void check(FILE*f,const char *name,long bytes){struct stat st;if(stat(name,&st)||st.st_size!=bytes)bad("full source size unexpected");if(!f)bad("frame absent");}
static int lum(const uint8_t*p){return (2126*p[0]+7152*p[1]+722*p[2]+5000)/10000;}
int main(int argc,char**argv){if(argc!=11){fprintf(stderr,"USAGE rgb_motion_structure now.rgb prev.rgb older.rgb sw sh x y w h requiredCurrentFrameSize\n");return 2;}
 long sw=num(argv[4]),sh=num(argv[5]),x=num(argv[6]),y=num(argv[7]),w=num(argv[8]),h=num(argv[9]),expected=num(argv[10]);
 if(sw<1||sh<1||sw>4096||sh>4096||x<0||y<0||w<8||h<8||x+w>sw||y+h>sh||expected!=sw*sh*3)bad("bounds");
 FILE *f[3];uint8_t*buf[3];for(int k=0;k<3;k++){f[k]=fopen(argv[1+k],"rb");check(f[k],argv[1+k],expected);buf[k]=malloc((size_t)w*h*3);if(!buf[k])bad("allocation");
 for(long dy=0;dy<h;dy++){if(fseek(f[k],((y+dy)*sw+x)*3,SEEK_SET))bad("ROI seek");if(fread(buf[k]+(size_t)dy*w*3,1,(size_t)w*3,f[k])!=(size_t)w*3)bad("ROI read");}fclose(f[k]);}
 long change5=0,change10=0,both=0,brightChange=0,changeEdge=0,allbright=0;long lower=0;
 long blocksW=(w+7)/8,blocksH=(h+7)/8;int *block=calloc((size_t)(blocksW*blocksH),sizeof(int));if(!block)bad("blocks");
 for(long py=h/2;py<h;py++)for(long px=0;px<w;px++){
  long q=py*w+px;int a=lum(buf[0]+q*3),b=lum(buf[1]+q*3),c=lum(buf[2]+q*3);
  int d5=abs(a-b)>24,d10=abs(a-c)>24;
  if(d5)change5++;
  if(d10)change10++;
  if(d5&&d10)both++;
  if(a>160)allbright++;
  if(a>160&&(abs(a-b)>35||abs(a-c)>35))brightChange++;
  if((d5||d10)&&py>h/2){int above=lum(buf[0]+(q-w)*3);if(abs(a-above)>22)changeEdge++;}
  if(d5&&d10)block[(py/8)*blocksW+(px/8)]++;
  lower++;
 }
 long coherent=0;for(long i=0;i<blocksW*blocksH;i++)if(block[i]>=16)coherent++;
 printf("RGB_TEMPORAL_V1|%.8f|%.8f|%.8f|%.8f|%.8f|%.8f|%ld|%ld\n",(double)change5/lower,(double)change10/lower,(double)both/lower,(double)brightChange/lower,(double)changeEdge/lower,(double)allbright/lower,coherent,blocksW*blocksH);
 for(int k=0;k<3;k++)free(buf[k]);
 free(block);return 0;
}
