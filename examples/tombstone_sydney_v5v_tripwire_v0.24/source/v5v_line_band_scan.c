/* V5V source-indexed line-band movement extractor — native codec decode.
 * No classifier, independent spatial object tracker or semantic attribution.
 * A source frame is always processed: all configured lines are checked.
 * User-annotated lines can be configured in the PSV; example geometry is PROVISIONAL.
 * Input node source/hash/status and consecutive timestamps are checked;
 * output is OBSERVED_UNTESTED and movement within mask only.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#define W 80
#define H 45
#define N (W*H)
#define MAX_GATES 32
#define MAX_LINE 2048
struct gate {char id[50],authority[64];double x1,y1,x2,y2,r;uint8_t member[N];int cells;};
static struct gate gates[MAX_GATES];
static int gates_n;
static uint8_t frame[N],prev[N],mask[N],bits[N],vals[N],changed[N],payload[2700];
static void fail(const char *e){fprintf(stderr,"V5V_LINE_SCAN_FAIL %s\n",e);exit(6);}
static int sep(const char *p){int c=0;while(*p) c+=*p++=='|';return c;}
static void unpack(uint8_t *dest,const uint8_t *src,int count,int width){int bit=0;for(int i=0;i<count;i++){unsigned v=0;for(int j=0;j<width;j++){v=(v<<1)|((src[bit>>3]>>(7-(bit&7)))&1);bit++;}dest[i]=(uint8_t)v;}}
static void readMask(const char *p){FILE *f=fopen(p,"r");if(!f)fail("mask not readable");char b[256];if(!fgets(b,sizeof b,f)||strcmp(b,"row|first_x|last_x|authority\n"))fail("mask header");for(int y=0;y<H;y++){if(!fgets(b,sizeof b,f)||sep(b)!=3)fail("mask row missing");int row,low,high;char auth[100];if(sscanf(b,"%d|%d|%d|%99[^\n]",&row,&low,&high,auth)!=4||row!=y||low<0||low>W||high< -1||high>=W||strcmp(auth,"PROVISIONAL_WATER_MOVEMENT_ONLY"))fail("mask row invalid");for(int x=0;x<W;x++)mask[y*W+x]=(low<=x&&x<=high);}if(fgets(b,sizeof b,f))fail("extra mask");fclose(f);}
static void readGates(const char *p){FILE *f=fopen(p,"r");if(!f)fail("gates file not readable");char b[256];if(!fgets(b,sizeof b,f)||strcmp(b,"gate_id|x1|y1|x2|y2|radius|authority\n"))fail("gate header");while(fgets(b,sizeof b,f)){if(gates_n>=MAX_GATES||sep(b)!=6)fail("gate count/fields invalid");struct gate *g=&gates[gates_n];if(sscanf(b,"%49[^|]|%lf|%lf|%lf|%lf|%lf|%63[^\n]",g->id,&g->x1,&g->y1,&g->x2,&g->y2,&g->r,g->authority)!=7)fail("gate parse");if(!*g->id||strspn(g->id,"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")!=strlen(g->id)||g->r<0.5||g->r>4||g->x1<0||g->x1>=W||g->x2<0||g->x2>=W||g->y1<0||g->y1>=H||g->y2<0||g->y2>=H||!strcmp(g->authority,""))fail("gate geometry/authority");double dx=g->x2-g->x1,dy=g->y2-g->y1,len=dx*dx+dy*dy;if(len<1)fail("zero gate length");for(int k=0;k<gates_n;k++)if(!strcmp(gates[k].id,g->id))fail("duplicate gate");for(int y=0;y<H;y++)for(int x=0;x<W;x++){double t=((x-g->x1)*dx+(y-g->y1)*dy)/len;if(t<0)t=0;if(t>1)t=1;double xx=g->x1+t*dx,yy=g->y1+t*dy;int i=y*W+x;if(mask[i]&&hypot(x-xx,y-yy)<=g->r+1e-8){g->member[i]=1;g->cells++;}}
if(g->cells<3)fail("gate has insufficient water area");
 gates_n++;}fclose(f);if(gates_n==0)fail("no gates");}
static int bfs(int start,const uint8_t*active,const uint8_t *allow,uint8_t *visited,int *left,int *top,int *right,int *bottom,int *sumx,int *sumy,unsigned *gateMask){int queue[N],front=0,tail=0;queue[tail++]=start;visited[start]=1;*left=W;*top=H;*right=0;*bottom=0;*sumx=*sumy=0;while(front<tail){int idx=queue[front++],x=idx%W,y=idx/W;*sumx+=x;*sumy+=y;if(gateMask)for(int g=0;g<gates_n;g++)if(gates[g].member[idx])*gateMask|=(1u<<g);if(x<*left)*left=x;if(y<*top)*top=y;if(x>*right)*right=x;if(y>*bottom)*bottom=y;for(int oy=-1;oy<=1;oy++)for(int ox=-1;ox<=1;ox++){if(!ox&&!oy)continue;int nx=x+ox,ny=y+oy;if(nx<0||nx>=W||ny<0||ny>=H)continue;int ni=ny*W+nx;if(active[ni]&&allow[ni]&&!visited[ni]){visited[ni]=1;queue[tail++]=ni;}}}return tail;}
int main(int argc,char**argv){if(argc!=7){fprintf(stderr,"USAGE v5v_line_band_scan nodes.psv .v5b mask.psv gates.psv line_components.psv full_water_components.psv\n");return 2;}readMask(argv[3]);readGates(argv[4]);FILE *nf=fopen(argv[1],"r"),*bf=fopen(argv[2],"rb"),*of=fopen(argv[5],"w"),*wf=fopen(argv[6],"w");if(!nf||!bf||!of||!wf)fail("input or output missing");char row[MAX_LINE];if(!fgets(row,sizeof row,nf)||strncmp(row,"node_id|frame_index|timestamp_seconds|",38))fail("node header");fputs("gate_id|frame|timestamp_seconds|component_id|left|top|right|bottom|cells|centre_x|centre_y|source_ref|evidence_state\n",of);fputs("frame|timestamp_seconds|component_id|left|top|right|bottom|cells|centre_x|centre_y|gate_ids|source_ref|evidence_state\n",wf);int nframes=0,signalFrames=0,obs=0,wholeobs=0;double lastpts=-1;char lastref[140]="";while(fgets(row,sizeof row,nf)){char node[160],pts[70],type[30],ref[140],state[70];int frame_idx,changes,inside,outside;unsigned long long offset;size_t bytes;static unsigned long long fileOffset=0;if(sep(row)!=10||sscanf(row,"%159[^|]|%d|%69[^|]|%29[^|]|%d|%d|%d|%llu|%zu|%139[^|]|%69[^\n]",node,&frame_idx,pts,type,&changes,&inside,&outside,&offset,&bytes,ref,state)!=11)fail("invalid node row");if(frame_idx!=nframes||strcmp(state,"OBSERVED_UNTESTED")||strncmp(ref,"sha256:",7)||strlen(ref)!=71)fail("source chronology/hash/status");if(*lastref&&strcmp(lastref,ref))fail("source changed");
 if(strlen(ref)!=71||strspn(ref+7,"0123456789abcdef")!=64)fail("source hash format");
 if(offset!=fileOffset)fail("V5V byte offset mismatch");
 fileOffset+=(unsigned long long)bytes;strcpy(lastref,ref);char *end;double t=strtod(pts,&end);if(*end||!isfinite(t)||(nframes>0&&t<=lastpts))fail("timestamp order");lastpts=t;if(bytes>sizeof payload||fread(payload,1,bytes,bf)!=bytes)fail("V5V record absent");if(nframes%30==0){if(strcmp(type,"KEYFRAME")||bytes!=2250)fail("keyframe schedule");unpack(frame,payload,N,5);}else{if(strcmp(type,"DELTA")||bytes<450)fail("delta schedule");unpack(bits,payload,N,1);int total=0;for(int i=0;i<N;i++)total+=bits[i];if(bytes!=450+(size_t)((total*5+7)/8))fail("delta size");unpack(vals,payload+450,total,5);int j=0;for(int i=0;i<N;i++)frame[i]=bits[i]?vals[j++]:prev[i];}
int waterChanged=0,allChanged=0;for(int i=0;i<N;i++){changed[i]=(nframes>0&&frame[i]!=prev[i]);allChanged+=changed[i];if(mask[i])waterChanged+=changed[i];}if(changes!=allChanged||waterChanged!=inside||changes-inside!=outside)fail("codec/frame/mask conservation");int found=0;for(int g=0;g<gates_n;g++){uint8_t visited[N]={0};int component=0;for(int i=0;i<N;i++)if(changed[i]&&gates[g].member[i]&&!visited[i]){int l,top,r,b,sx,sy;int size=bfs(i,changed,gates[g].member,visited,&l,&top,&r,&b,&sx,&sy,NULL);component++;fprintf(of,"%s|%d|%s|%d|%d|%d|%d|%d|%d|%.6f|%.6f|%s|OBSERVED_UNTESTED\n",gates[g].id,nframes,pts,component,l,top,r,b,size,(double)sx/size,(double)sy/size,ref);obs++;found=1;}}signalFrames+=found;
  { uint8_t visited[N]={0};int component=0;
    for(int i=0;i<N;i++)if(changed[i]&&mask[i]&&!visited[i]){
      int l,top,r,b,sx,sy;unsigned gateBits=0;
      int cells=bfs(i,changed,mask,visited,&l,&top,&r,&b,&sx,&sy,&gateBits);
      component++;
      char names[2048]="";
      for(int g=0;g<gates_n;g++)if(gateBits&(1u<<g)){
        if(*names)strcat(names,",");
        strcat(names,gates[g].id);
      }
      if(!*names)strcpy(names,"-");
      fprintf(wf,"%d|%s|%d|%d|%d|%d|%d|%d|%.6f|%.6f|%s|%s|OBSERVED_UNTESTED\n",nframes,pts,component,l,top,r,b,cells,(double)sx/cells,(double)sy/cells,names,ref);
      wholeobs++;
    }
  }
  memcpy(prev,frame,N);nframes++;}if(fgetc(bf)!=EOF)fail("extra codec bytes");fclose(nf);fclose(bf);fclose(of);fclose(wf);printf("V5V_LINE_SCAN_PASS frames=%d gates=%d frames_with_gate_activity=%d line_components=%d water_components=%d\n",nframes,gates_n,signalFrames,obs,wholeobs);printf("LINE_GEOMETRY=CONFIGURED; SOURCE_PRESERVED=YES; INFERRED_VESSEL_IDENTITIES=0\n");return 0;}
