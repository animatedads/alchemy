/* Inspect a single authenticated V5V keyframe, ROI vs background-control.
 * Diagnostic only: never promotes palette contrast to ship classification.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#define W 80
#define H 45
static void die(const char*m){fprintf(stderr,"V5V_PROBE_REJECT:%s\n",m);exit(3);}
static unsigned getbits(const uint8_t*p,size_t start,int bits){unsigned v=0;for(int j=0;j<bits;j++){size_t t=start+j;v=(v<<1)|((p[t/8]>>(7-(t%8)))&1);}return v;}
static long intarg(const char*s){char *e;long n=strtol(s,&e,10);if(*e)die("bad integer");return n;}
int main(int argc,char**argv){
 if(argc!=14){fprintf(stderr,"Usage: v5v_keyframe_probe nodes.psv frames.v5b source_sha frame x0 y0 x1 y1 cx0 cy0 cx1 cy1 palette\n");return 2;}
 const char*nodes=argv[1],*packed=argv[2],*sha=argv[3];long frame=intarg(argv[4]);
 long x0=intarg(argv[5]),y0=intarg(argv[6]),x1=intarg(argv[7]),y1=intarg(argv[8]);
 long ax=intarg(argv[9]),ay=intarg(argv[10]),bx=intarg(argv[11]),by=intarg(argv[12]),pal=intarg(argv[13]);
 if(strlen(sha)!=64||strspn(sha,"0123456789abcdef")!=64)die("bad sha");
 if(frame<0||frame>=1800||frame%30!=0||pal<0||pal>25)die("bad keyframe/palette");
 if(x0<0||y0<0||x1>W||y1>H||x1<=x0||y1<=y0||ax<0||ay<0||bx>W||by>H||bx<=ax||by<=ay)die("invalid boxes");
 FILE*f=fopen(nodes,"r");if(!f)die("nodes file missing");
 char line[512];if(!fgets(line,sizeof line,f)||strcmp(line,"node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state\n"))die("node schema changed");
 unsigned expected=0;long long offset=-1;size_t length=0;
 while(fgets(line,sizeof line,f)){
  char id[100],stamp[50],type[50],src[90],state[60];unsigned idx,changed,in,out;unsigned long long o;size_t bytes;
  if(sscanf(line,"%99[^|]|%u|%49[^|]|%49[^|]|%u|%u|%u|%llu|%zu|%89[^|]|%59[^\n]",id,&idx,stamp,type,&changed,&in,&out,&o,&bytes,src,state)!=11)die("invalid node row");
  if(idx!=expected++)die("non-contiguous source frames");
  if(strcmp(state,"OBSERVED_UNTESTED"))die("authority violation");
  char source[90];snprintf(source,sizeof source,"sha256:%s",sha);
  if(strcmp(src,source))die("source identity mismatch");
  if(idx==frame){if(strcmp(type,"KEYFRAME")||bytes!=2250)die("frame not native V5V keyframe");offset=(long long)o;length=bytes;}
 }
 fclose(f);if(expected!=1800||offset<0)die("source count/frame absent");
 FILE*b=fopen(packed,"rb");if(!b)die("V5V payload missing");
 if(fseek(b,0,SEEK_END)!=0)die("blob seek");
 long len=ftell(b);if(len<offset+(long long)length)die("truncated blob");
 if(fseek(b,(long)offset,SEEK_SET)!=0)die("bad blob offset");
 uint8_t data[2250];
 if(fread(data,1,sizeof data,b)!=sizeof data)die("bad keyframe length");
 fclose(b);
 int roi=0,roiTotal=0,ctrl=0,ctrlTotal=0;
 for(int y=0;y<H;y++)for(int x=0;x<W;x++){
  int value=(int)getbits(data,(size_t)(y*W+x)*5,5);if(value>25)die("palette out of range");
  if(x>=x0&&x<x1&&y>=y0&&y<y1){roiTotal++;if(value==pal)roi++;}
  if(x>=ax&&x<bx&&y>=ay&&y<by){ctrlTotal++;if(value==pal)ctrl++;}
 }
 printf("V5V_NATIVE_PROBE_PASS frame=%ld palette=%ld roi=%d/%d control=%d/%d\n",frame,pal,roi,roiTotal,ctrl,ctrlTotal);
 return 0;
}
