/* V5V native causal region proposals. Read packed original five-bit indexed surfaces.
 * No labelled ROI, ship identity or independent image-processor tracking.
 * At original frame t, use only V5V keyframes t, t-150, t-300.
 * Mask is for motion admission only: look in the margin adjacent to the water.
 * Proposals unclassified and time/source linked. 2026-11-02. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#define W 80
#define H 45
#define NF 1800
#define N (W*H)
#define NW 12
#define NH 12
#define MAX_CAND 500
#define CANDIDATES 5
static uint8_t frames[9][N],mask[N];
static const int keyframes[9]={150,300,450,600,750,900,1050,1200,1350};
typedef struct {long long offset;int length;double time;char typ[16];char sha[80];} Row;
static Row nodes[NF];
typedef struct{int x,y,score,up,changed,edges,water;}Candidate;
static Candidate candidates[MAX_CAND];
static void fail(const char*e){fprintf(stderr,"CAUSAL_AOI_FAIL %s\n",e);exit(3);}
static void read_mask(const char*path){FILE*f=fopen(path,"r");if(!f)fail("mask absent");char s[512];
 if(!fgets(s,sizeof s,f)||strcmp(s,"row|bits80|authority\n"))fail("mask schema");
 for(int y=0;y<H;y++){if(!fgets(s,sizeof s,f))fail("mask short");int row=-1;char bits[81],authority[80];
 if(sscanf(s,"%d|%80[01]|%79s",&row,bits,authority)!=3||row!=y||strlen(bits)!=80||strcmp(authority,"PROVISIONAL_WATER_MOVEMENT_ONLY"))fail("mask invalid");
 for(int x=0;x<W;x++)mask[y*W+x]=(uint8_t)(bits[x]-'0');}
 if(fgets(s,sizeof s,f))fail("mask extra");
 fclose(f);
}
static char source[65];
static void read_nodes(const char*path){FILE*f=fopen(path,"r");if(!f)fail("nodes absent");char s[512];
 if(!fgets(s,sizeof s,f)||strcmp(s,"node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state\n"))fail("nodes schema");
 int n=0;long long off=0;double last=-1;while(fgets(s,sizeof s,f)){
 if(n>=NF)fail("extra nodes");
 char *t[11]={0};int k=0;t[k++]=strtok(s,"|\r\n");while(k<11&&(t[k]=strtok(NULL,"|\r\n")))k++;
 if(k!=11||!t[10]||strcmp(t[10],"OBSERVED_UNTESTED"))fail("bad authority/field count");
 int idx=atoi(t[1]);if(idx!=n)fail("node chronology");
 if(n==0){if(strncmp(t[9],"sha256:",7)||strlen(t[9])!=71)fail("source malformed");strncpy(source,t[9]+7,64);source[64]=0;}
 if(strncmp(t[9],"sha256:",7)||strcmp(t[9]+7,source))fail("mixed source identity");
 Row *r=&nodes[n];r->time=strtod(t[2],NULL);if(!(r->time>last))fail("timestamp chronology");last=r->time;
 strncpy(r->typ,t[3],15);r->offset=atoll(t[7]);r->length=atoi(t[8]);if(r->offset!=off||r->length<450||r->length>2250)fail("bad packed record offset");
 if(n%30==0){if(strcmp(r->typ,"KEYFRAME")||r->length!=2250)fail("keyframe cadence");}
 else if(strcmp(r->typ,"DELTA"))fail("delta cadence");
 off+=r->length;n++;}
 fclose(f);if(n!=NF)fail("source frame count");
}
static void read_packed(const char*path){FILE*f=fopen(path,"rb");if(!f)fail("V5V payload missing");
 if(fseek(f,0,SEEK_END))fail("blob seek");
 long size=ftell(f);if(size!=nodes[NF-1].offset+nodes[NF-1].length)fail("payload length mismatch");
 for(int j=0;j<9;j++){Row*r=&nodes[keyframes[j]];if(fseek(f,r->offset,SEEK_SET))fail("keyframe seek");uint8_t buf[2250];
 if(fread(buf,1,2250,f)!=2250)fail("keyframe truncated");
 for(int i=0;i<N;i++){
 unsigned v=0;for(int b=0;b<5;b++){int bit=i*5+b;v=(v<<1)|((buf[bit/8]>>(7-bit%8))&1);}if(v>=26)fail("V5V palette out of range");frames[j][i]=(uint8_t)v;}}
 fclose(f);
}
static int compare(const void*A,const void*B){const Candidate*a=A,*b=B;return b->score-a->score;}
static int selected_intersection(int x,int y,int xx,int yy){int xa=x>xx?x:xx,ya=y>yy?y:yy;
 int xb=x+NW<xx+NW?x+NW:xx+NW,yb=y+NH<yy+NH?y+NH:yy+NH;return xb>xa&&yb>ya?(xb-xa)*(yb-ya):0;}
static void scan(FILE*out,int source_id){int frame=keyframes[source_id];uint8_t*current=frames[source_id],*prev=frames[source_id-1],*older=frames[source_id-2];int n=0;
 for(int y=5;y<=H-NH;y+=3)for(int x=0;x<=W-NW;x+=3){
 int first=0,last=0,upper=0,changed=0,edges=0,seen[26]={0},div=0,water=0;
 for(int dy=0;dy<NH;dy++)for(int dx=0;dx<NW;dx++){
 int index=(y+dy)*W+x+dx;int m=mask[index],v=current[index];if(dy<4)first+=m;if(dy>=NH-4)last+=m;
 water+=m;int ch=(v!=prev[index])+(v!=older[index]);changed+=ch;if(!m)upper+=ch;
 if(dx>0&&v!=current[index-1])edges++;
 if(dy>0&&v!=current[index-W])edges++;
 if(!seen[v]){seen[v]=1;div++;}}
 if(last<=3||first>=NW*3)continue;
 int score=150*upper+20*changed+8*edges+20*div;
 if(n>=MAX_CAND)fail("candidate buffer exceeded");
 candidates[n++]=(Candidate){x,y,score,upper,changed,edges,water};}
 qsort(candidates,n,sizeof(Candidate),compare);Candidate picked[CANDIDATES];int count=0;
 for(int i=0;i<n&&count<CANDIDATES;i++){Candidate *c=&candidates[i];int accept=1;
 for(int j=0;j<count;j++){int inter=selected_intersection(c->x,c->y,picked[j].x,picked[j].y);
 if(4*inter>=NW*NH*2-inter)accept=0;}
 if(!accept)continue;
 picked[count++]=*c;}
 for(int j=0;j<count;j++){Candidate*c=&picked[j];int x0=c->x-2,y0=c->y-2,x1=c->x+NW+2,y1=c->y+NH+2;
 if(x0<0)x0=0;
 if(y0<0)y0=0;
 if(x1>W)x1=W;
 if(y1>H)y1=H;
 fprintf(out,"%s|%d|%.6f|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|UNCLASSIFIED_CANDIDATE|OBSERVED_UNTESTED\n",
 source,frame,nodes[frame].time,j+1,c->x,c->y,c->x+NW,c->y+NH,x0,y0,x1,y1,c->score,c->up,c->changed,c->edges,c->water);}
 printf("CAUSAL_V5V_AOI source=%.16s frame=%d proposals=%d maxscore=%.2f\n",source,frame,count,picked[0].score/100.0);
}
int main(int argc,char**argv){if(argc!=5){fprintf(stderr,"USAGE v5v_causal_aoi nodes.psv packed.v5b mask.psv proposals.psv\n");return 2;}
 read_mask(argv[3]);read_nodes(argv[1]);read_packed(argv[2]);FILE*out=fopen(argv[4],"w");if(!out)fail("proposals output");
 fprintf(out,"source_sha256|frame|timestamp_seconds|rank|box_x0|box_y0|box_x1|box_y1|lookup_x0|lookup_y0|lookup_x1|lookup_y1|score100|outside_water_changes|total_changes|palette_edges|water_cells|proposal_state|evidence_state\n");
 scan(out,2);scan(out,5);scan(out,8);fclose(out);return 0;}
