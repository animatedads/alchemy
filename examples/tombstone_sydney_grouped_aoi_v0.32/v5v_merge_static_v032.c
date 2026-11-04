/* Native V5V v0.32 spatial-grouping and static-scene caution.
 * Source: actual five-bit Vision V5V packed surfaces (not OpenCV).
 * Inputs: v0.31 preselected unlabelled proposals, native source-indexed receipts,
 * original V5V blob, per-camera water search mask.
 * NO real geo projection, camera pose or ship identity; no use of labels.
 * Architecture: user. Implementation: GPT-6, 2026-11-02.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#define W 80
#define H 45
#define MAXP 20
#define NF 1800
#define FCOUNT 3
static const int fi[FCOUNT]={450,900,1350};
static void die(const char *s){fprintf(stderr,"V032_MERGE_REJECT:%s\n",s);exit(3);}
typedef struct {int frame,rank,x0,y0,x1,y1,lx0,ly0,lx1,ly1,score,change;double ts;char sha[65];} Proposal;
typedef struct {long long offset;int bytes;double ts;} Node;
static Node nodes[NF];static uint8_t mask[W*H];
static char source[65];static uint8_t scene[9][W*H];
static Proposal p[3][MAXP];static int counts[3];
static int parent[MAXP];
static int root(int i){return parent[i]==i?i:(parent[i]=root(parent[i]));}
static void unite(int i,int j){i=root(i);j=root(j);if(i!=j)parent[j]=i;}
static int min(int a,int b){return a<b?a:b;}
static int max(int a,int b){return a>b?a:b;}
static unsigned bit5(uint8_t*b,int i){int v=0;for(int j=0;j<5;j++){int t=i*5+j;v=(v<<1)|((b[t/8]>>(7-(t%8)))&1);}return (unsigned)v;}
static void read_nodes(const char*path){FILE*f=fopen(path,"r");if(!f)die("nodes absent");char s[600];if(!fgets(s,sizeof s,f)||strcmp(s,"node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state\n"))die("node schema");
long long offset=0;double last=-1;for(int i=0;i<NF;i++){
 if(!fgets(s,sizeof s,f))die("truncated nodes");
 char*col[12]={0};int c=0;char*token=strtok(s,"|\r\n");while(token&&c<12){col[c++]=token;token=strtok(NULL,"|\r\n");}if(c!=11||token)die("node cols");
 if(atoi(col[1])!=i||strcmp(col[10],"OBSERVED_UNTESTED"))die("node chronology/authority");
 if(i==0){if(strncmp(col[9],"sha256:",7)||strlen(col[9])!=71)die("bad source");strncpy(source,col[9]+7,64);source[64]=0;}
 if(strncmp(col[9],"sha256:",7)||strcmp(col[9]+7,source))die("mixed source");
 double t=strtod(col[2],NULL);if(t<=last)die("PTS non-increasing");last=t;
 int bytes=atoi(col[8]);long long off=atoll(col[7]);if(off!=offset)die("noncontiguous payload");
 if(i%30==0){if(strcmp(col[3],"KEYFRAME")||bytes!=2250)die("invalid keyframe");}
 else if(strcmp(col[3],"DELTA")||bytes<450||bytes>2250)die("invalid delta");
 nodes[i]=(Node){off,bytes,t};offset+=bytes;
 }if(fgets(s,sizeof s,f))die("extra nodes");fclose(f);
}
static void read_scene(const char*path){FILE*f=fopen(path,"rb");if(!f)die("v5b absent");if(fseek(f,0,SEEK_END))die("packed seek");long l=ftell(f);if(l!=nodes[NF-1].offset+nodes[NF-1].bytes)die("packed length mismatch");
 for(int k=0;k<FCOUNT;k++)for(int j=0;j<3;j++){
  int idx=fi[k]-300+j*150;
  if(idx<0||idx>=NF||idx%30)die("keyframe target wrong");
  if(fseek(f,nodes[idx].offset,SEEK_SET))die("seek keyframe");
  uint8_t raw[2250];if(fread(raw,1,2250,f)!=2250)die("truncated keyframe");
  for(int i=0;i<W*H;i++){unsigned v=bit5(raw,i);if(v>=26)die("V5V index invalid");scene[3*k+j][i]=(uint8_t)v;}
 }fclose(f);
}
static void read_mask(const char*path){FILE*f=fopen(path,"r");if(!f)die("mask absent");char s[512];if(!fgets(s,sizeof s,f)||strcmp(s,"row|bits80|authority\n"))die("mask schema");
 for(int y=0;y<H;y++){if(!fgets(s,sizeof s,f))die("missing mask row");int index=-1;char bits[81]={0},auth[100]={0};if(sscanf(s,"%d|%80[01]|%99s",&index,bits,auth)!=3||index!=y||strlen(bits)!=80||strcmp(auth,"PROVISIONAL_WATER_MOVEMENT_ONLY"))die("invalid mask");for(int x=0;x<W;x++)mask[y*W+x]=(uint8_t)(bits[x]-'0');}
 if(fgets(s,sizeof s,f))die("extra mask rows");
 fclose(f);
}
static void read_props(const char*path){FILE*f=fopen(path,"r");if(!f)die("proposals missing");char s[700];const char*header="source_sha256|frame|timestamp_seconds|rank|box_x0|box_y0|box_x1|box_y1|lookup_x0|lookup_y0|lookup_x1|lookup_y1|score100|outside_water_changes|total_changes|palette_edges|water_cells|proposal_state|evidence_state\n";
 if(!fgets(s,sizeof s,f)||strcmp(s,header))die("proposals schema");
 while(fgets(s,sizeof s,f)){
  char *v[20]={0};int n=0;char *t=strtok(s,"|\r\n");while(t&&n<20){v[n++]=t;t=strtok(NULL,"|\r\n");}if(n!=19||t)die("proposal columns");
  if(strcmp(v[0],source)||strcmp(v[17],"UNCLASSIFIED_CANDIDATE")||strcmp(v[18],"OBSERVED_UNTESTED"))die("proposal authority");
  int frame=atoi(v[1]),k=-1;for(int j=0;j<3;j++)if(frame==fi[j])k=j;
  if(k<0||counts[k]>=MAXP)die("unexpected proposal frame/count");
  Proposal q={0};q.frame=frame;q.ts=atof(v[2]);q.rank=atoi(v[3]);q.x0=atoi(v[4]);q.y0=atoi(v[5]);q.x1=atoi(v[6]);q.y1=atoi(v[7]);q.lx0=atoi(v[8]);q.ly0=atoi(v[9]);q.lx1=atoi(v[10]);q.ly1=atoi(v[11]);q.score=atoi(v[12]);q.change=atoi(v[13]);strcpy(q.sha,source);
  if(q.rank!=counts[k]+1||fabs(q.ts-nodes[frame].ts)>0.000001)die("proposal chronology/rank");
  if(q.x0<0||q.y0<0||q.x1>80||q.y1>45||q.x1-q.x0!=12||q.y1-q.y0!=12)die("proposal core bounds");
  if(q.lx0!=max(0,q.x0-2)||q.ly0!=max(0,q.y0-2)||q.lx1!=min(80,q.x1+2)||q.ly1!=min(45,q.y1+2))die("proposal halo wrong");
  if(q.score<0||q.change<0)die("proposal metric invalid");
  p[k][counts[k]++]=q;
 }
 fclose(f);for(int k=0;k<3;k++)if(counts[k]!=5)die("each target frame requires five proposals");
}
static int intersect(Proposal*a,Proposal*b){int w=min(a->lx1,b->lx1)-max(a->lx0,b->lx0);int h=min(a->ly1,b->ly1)-max(a->ly0,b->ly0);return max(0,w)*max(0,h);}
static void grouped(FILE*out){
 fprintf(out,"source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|lookup_y0|lookup_x1|lookup_y1|bbox_cells|union_cells|previous_separate_cells|duplicate_saved_cells|unchanged_upper_cells|changing_upper_cells|changing_water_cells|provisional_landmark_overlap|static_review_state|proposal_state|evidence_state\n");
 int totalGroups=0,totalArea=0,separate=0,unionTotal=0;
 for(int k=0;k<3;k++){
  for(int a=0;a<5;a++)parent[a]=a;
  for(int a=0;a<5;a++)for(int b=0;b<a;b++)if(intersect(&p[k][a],&p[k][b])>=30)unite(a,b);
  int done[5]={0},group=0;
  for(int a=0;a<5;a++){
   int r=root(a);if(done[r])continue;done[r]=1;
   int x0=80,y0=45,x1=0,y1=0,na=0,before=0;
   char ranks[80]={0};unsigned char pixels[W*H]={0};
   for(int b=0;b<5;b++)if(root(b)==r){
    Proposal*q=&p[k][b];x0=min(x0,q->lx0);y0=min(y0,q->ly0);x1=max(x1,q->lx1);y1=max(y1,q->ly1);
    na++;char part[12];snprintf(part,sizeof part,"%s%d",ranks[0]?",":"",q->rank);strcat(ranks,part);
    before+=(q->lx1-q->lx0)*(q->ly1-q->ly0);
    for(int y=q->ly0;y<q->ly1;y++)for(int x=q->lx0;x<q->lx1;x++)pixels[y*W+x]=1;
   }
   int uni=0,unchanged=0,changed=0,waterChanged=0;
   for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){
    int i=y*W+x;uni+=pixels[i];
    uint8_t now=scene[k*3+2][i],old=scene[k*3+1][i],older=scene[k*3][i];
    if(mask[i]){if(now!=old&&now!=older)waterChanged++;}
    else if(now==old&&now==older)unchanged++;
    else changed++;
   }
   /* The image-plane landmark overlay is a provisional warning, NEVER a
      surveyed 3D projection. This point conservatively tags Café Sydney
      approximate Harbour Bridge region from v0.27a. */
   int landmarkOverlap=0;
   for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++)if(x>=3&&x<43&&y>=7&&y<25)landmarkOverlap++;
   /* Camera 2 has no commissioned lens site: no geometry overlay allowed. */
   const char*hint="UNKNOWN_UNSURVEYED";
   if(strcmp(source,"c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e")==0||strcmp(source,"58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d")==0){
     hint=landmarkOverlap>0?"UNSURVEYED_LANDMARK_OVERLAP_REVIEW":"NO_REGISTERED_OVERLAP";
   }else landmarkOverlap=0;
   int area=(x1-x0)*(y1-y0);if(area>1200)die("merged bbox too large");
   fprintf(out,"%s|%d|%.6f|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|UNCLASSIFIED_GROUP|OBSERVED_UNTESTED\n",source,fi[k],nodes[fi[k]].ts,++group,ranks,na,x0,y0,x1,y1,area,uni,before,before-uni,unchanged,changed,waterChanged,landmarkOverlap,hint);
   totalGroups++;totalArea+=area;unionTotal+=uni;separate+=before;
  }
 }
 printf("V032_V5V_GROUP_PASS proposals=15 groups=%d separate_cells=%d grouped_bbox_cells=%d exact_union_cells=%d per_group_world=BLOCKED_UNCALIBRATED\n",totalGroups,separate,totalArea,unionTotal);
}
int main(int argc,char**argv){if(argc!=6){fprintf(stderr,"usage: v5v_merge_static_v032 nodes.psv payload.v5b water.psv proposals.psv groups.psv\n");return 2;}
 read_nodes(argv[1]);read_scene(argv[2]);read_mask(argv[3]);read_props(argv[4]);FILE*f=fopen(argv[5],"w");if(!f)die("cannot write result");grouped(f);fclose(f);return 0;
}
