/* Accelerated native V5V encoded-surface producer for full source cadence.
 * Quantization follows oorexx_vision_v0.1-dev22 V5V sample and palette contract.
 * KEYFRAME = VisionPackedValues(5,3600) bytes.
 * DELTA = VisionSurfaceDelta.changedMask packed 1-bit + changedValues 5-bit.
 * The V5B payload index is a local experiment, not an upstream codec wire ABI.
 * NO tracking, object classification, or SLAM score in this provider.
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define W 80
#define H 45
#define N (W*H)
static const uint8_t rgb_palette[26][3]={
{150,180,214},{120,157,207},{100,135,185},{175,197,222},{191,202,217},{88,124,175},
{34,67,108},{52,84,124},{71,105,137},{87,121,151},{107,140,162},{40,92,133},{57,104,142},{75,128,160},
{229,185,77},{212,173,71},{245,211,122},{192,150,54},{225,202,112},{174,133,63},
{144,145,143},{181,171,155},{206,192,166},{112,110,103},{82,102,79},{62,70,72}};
static uint8_t lut[4096],prev[N],current[N],decoded[N],mask[N],raw[N*3];
static uint8_t payload[2250+450+2250];
static void pack(uint8_t *dst, const uint8_t *src, size_t n, int bits){
 size_t bit=0;memset(dst,0,(n*bits+7)/8);
 for(size_t i=0;i<n;i++)for(int b=bits-1;b>=0;b--){
  if((src[i]>>b)&1)dst[bit/8]|=(uint8_t)(1u<<(7-(bit%8)));
  ++bit;
 }
}
static void unpack(uint8_t *dst, const uint8_t *src, size_t n, int bits){
 size_t bit=0;
 for(size_t i=0;i<n;i++){
  unsigned v=0;for(int b=0;b<bits;b++){
   v=(v<<1)|((src[bit/8]>>(7-(bit%8)))&1);bit++;
  }
  dst[i]=(uint8_t)v;
 }
}
static void die(const char *s){fprintf(stderr,"V5V_NATIVE_PROVIDER_FAIL: %s\n",s);exit(4);}
static void lut_setup(void){
 for(int r=0;r<16;r++)for(int g=0;g<16;g++)for(int b=0;b<16;b++){
  int rr=r*16+8,gg=g*16+8,bb=b*16+8,best=0,minimum=-1;
  for(int i=0;i<26;i++){
   int dr=rr-(int)rgb_palette[i][0],dg=gg-(int)rgb_palette[i][1],db=bb-(int)rgb_palette[i][2];
   int d=dr*dr+dg*dg+db*db;
   if(minimum<0||d<minimum){minimum=d;best=i;}
  }
  lut[r*256+g*16+b]=(uint8_t)best;
 }
}
static void read_mask(const char *path){
 FILE*f=fopen(path,"r");if(!f)die("mask unavailable");
 char line[512];if(!fgets(line,sizeof line,f)||strncmp(line,"row|first_x|last_x|authority",28))die("mask header");
 for(int y=0;y<H;y++){
  if(!fgets(line,sizeof line,f))die("mask incomplete");
  int row=-1,l=-2,r=-2;
  if(sscanf(line,"%d|%d|%d|",&row,&l,&r)!=3 || row!=y || l<0 || l>W || r>=W || r<-1)die("mask malformed");
  if(!strstr(line,"PROVISIONAL_WATER_MOVEMENT_ONLY"))die("mask authority missing");
  for(int x=0;x<W;x++)mask[y*W+x]=(x>=l&&x<=r);
 }
 if(fgets(line,sizeof line,f))die("mask extra rows");fclose(f);
}
static void name(char*out,size_t n,const char*root,const char*suffix){snprintf(out,n,"%s.%s",root,suffix);}
int main(int argc,char **argv){
 if(argc!=7){fprintf(stderr,"USAGE v5v_bulk_native input.rgb frame.pts mask.psv outRoot sha256 expectedFrames\n");return 2;}
 const char *rgbfile=argv[1],*ptsfile=argv[2],*maskfile=argv[3],*root=argv[4],*sha=argv[5];
 unsigned expected=(unsigned)strtoul(argv[6],NULL,10);
 if(expected==0||strlen(sha)!=64||strspn(sha,"0123456789abcdef")!=64)die("sha/count malformed");
 char pathname[4096],nodeid[100],previd[100];
 FILE*input=fopen(rgbfile,"rb"),*pts=fopen(ptsfile,"r");if(!input||!pts)die("input absent");
 name(pathname,sizeof pathname,root,"nodes.psv");FILE*nodes=fopen(pathname,"w");if(!nodes)die("nodes output");
 name(pathname,sizeof pathname,root,"edges.psv");FILE*edges=fopen(pathname,"w");if(!edges)die("edges output");
 name(pathname,sizeof pathname,root,"v5b");FILE*blob=fopen(pathname,"wb");if(!blob)die("blob output");
 fprintf(nodes,"node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state\n");
 fprintf(edges,"from_id|to_id|dt_seconds|relation|evidence_state\n");
 lut_setup();read_mask(maskfile);previd[0]=0;
 unsigned frames=0,keys=0,deltas=0;uint64_t water=0,excluded=0,offset=0;double previous_pts=-1;
 for(;;){
  size_t rd=fread(raw,1,sizeof raw,input);if(rd==0)break;if(rd!=sizeof raw)die("short RGB frame");
  char ptsline[80];if(!fgets(ptsline,sizeof ptsline,pts))die("missing PTS");
  char*end=NULL;double t=strtod(ptsline,&end);
  if(end==ptsline||!isfinite(t)||(frames>0&&t<=previous_pts))die("PTS not strictly increasing");
  for(int i=0;i<N;i++){
   int k=i*3;
   int index=(raw[k]>>4)*256+(raw[k+1]>>4)*16+(raw[k+2]>>4);
   current[i]=lut[index];
  }
  const char *kind;unsigned changed=0,in=0,out=0;size_t payload_bytes=0;
  for(int i=0;i<N;i++){
   if(frames>0&&current[i]!=prev[i]){
    changed++;if(mask[i])in++;else out++;
   }
  }
  if(frames%30==0){
   kind="KEYFRAME";pack(payload,current,N,5);payload_bytes=N*5/8;keys++;
   unpack(decoded,payload,N,5);
  }else{
   uint8_t changes[N],values[N];unsigned k=0;
   for(int i=0;i<N;i++){
    changes[i]=(current[i]!=prev[i])?1:0;
    if(changes[i])values[k++]=current[i];
   }
   if(k!=changed)die("delta count mismatch");
   kind="DELTA";pack(payload,changes,N,1);size_t vlen=(k*5+7)/8;
   pack(payload+450,values,k,5);payload_bytes=450+vlen;deltas++;
   uint8_t recmask[N],recvals[N];unpack(recmask,payload,N,1);unpack(recvals,payload+450,k,5);
   unsigned j=0;for(int i=0;i<N;i++)decoded[i]=recmask[i]?recvals[j++]:prev[i];
   if(j!=k)die("mask reconstruction mismatch");
  }
  if(memcmp(current,decoded,N))die("V5V roundtrip mismatch");
  if(fwrite(payload,1,payload_bytes,blob)!=payload_bytes)die("binary write failed");
  snprintf(nodeid,sizeof nodeid,"SF.%.16s.%06u",sha,frames);
  fprintf(nodes,"%s|%u|%.6f|%s|%u|%u|%u|%llu|%zu|sha256:%s|OBSERVED_UNTESTED\n",
      nodeid,frames,t,kind,changed,in,out,(unsigned long long)offset,payload_bytes,sha);
  if(frames>0)fprintf(edges,"%s|%s|%.6f|NEXT_SOURCE_FRAME|OBSERVED_UNTESTED\n",previd,nodeid,t-previous_pts);
  strcpy(previd,nodeid);previous_pts=t;memcpy(prev,current,N);
  water+=in;excluded+=out;offset+=payload_bytes;frames++;
 }
 char trailing[80];if(fgets(trailing,sizeof trailing,pts))die("extra presentation timestamp");
 fclose(input);fclose(pts);fclose(blob);fclose(nodes);fclose(edges);
 if(frames!=expected)die("source frame count mismatch");
 printf("V5V_NATIVE_BULK_PASS frames=%u keyframes=%u deltas=%u water_changes=%llu excluded_changes=%llu payload_bytes=%llu roundtrip_exact=%u\n",
  frames,keys,deltas,(unsigned long long)water,(unsigned long long)excluded,(unsigned long long)offset,frames);
 puts("GRAPH_STATE=OBSERVED_UNTESTED; SLAM node/edge candidates only; NO identity classification");
 return 0;
}
