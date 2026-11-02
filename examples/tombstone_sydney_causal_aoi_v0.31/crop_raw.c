/* Extract exactly a source pixel rectangle from a single RGB24 full video frame.
 * Full frame remains immutable and separately hashed. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
static void bad(const char*s){fprintf(stderr,"ROI_CROP_FAIL:%s\n",s);exit(3);}
static long num(const char*s){char *end=NULL;long v=strtol(s,&end,10);if(!end||*end)bad("bad numeric argument");return v;}
int main(int argc,char**argv){if(argc!=10){fprintf(stderr,"Usage crop_raw full.rgb srcW srcH x y w h crop.rgb expectedBytes\n");return 2;}
 long srcw=num(argv[2]),srch=num(argv[3]),x=num(argv[4]),y=num(argv[5]),w=num(argv[6]),h=num(argv[7]),expected=num(argv[9]);
 if(srcw<1||srch<1||srcw>4096||srch>4096||x<0||y<0||w<8||h<8||x+w>srcw||y+h>srch||expected!=srcw*srch*3)bad("ROI geometry/size");
 FILE*f=fopen(argv[1],"rb"),*out=fopen(argv[8],"wb");if(!f||!out)bad("file unavailable");
 struct stat s;if(stat(argv[1],&s)||s.st_size!=expected)bad("source frame RGB length");
 uint8_t *row=malloc((size_t)w*3);if(!row)bad("allocation");
 for(long i=y;i<y+h;i++){
 long at=(i*srcw+x)*3;if(fseek(f,at,SEEK_SET))bad("seek outside source");
 if(fread(row,1,w*3,f)!=(size_t)w*3)bad("short row");
 if(fwrite(row,1,w*3,out)!=(size_t)w*3)bad("write failed");}
 free(row);fclose(f);fclose(out);return 0;
}
