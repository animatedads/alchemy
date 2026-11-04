/* Motion-structure observations from the exact V5V temporal archive.
 * This is NOT a replacement for Camera Behaviour tracking or a ferry classifier.
 * Local differences: spatial 8-neighbour agreement and same-zone recurrence
 * in prior three source frames. Preserves raw and uncertain evidence.
 * Output is OBSERVED_UNTESTED; 'scattered' is not verified wave identity.
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define W 80
#define H 45
#define N (W*H)
static uint8_t surface[N],prev[N],changed[N],mask[N],old[3][N],packed[2700],unpackedMask[N],unpackedValues[N];
static void fail(const char *why){fprintf(stderr,"MOTION_STRUCTURE_FAIL: %s\n",why);exit(5);}
static void unpack(uint8_t *dst,const uint8_t *src,size_t n,int bits){size_t pos=0;for(size_t i=0;i<n;i++){unsigned v=0;for(int j=0;j<bits;j++){v=(v<<1)|((src[pos>>3]>>(7-(pos&7)))&1);pos++;}dst[i]=(uint8_t)v;}}
static void loadMask(const char *path){FILE *f=fopen(path,"r");if(!f)fail("mask missing");char l[256];if(!fgets(l,sizeof l,f))fail("mask empty");
 for(int y=0;y<H;y++){if(!fgets(l,sizeof l,f))fail("short mask");int row=-1,a=-1,b=-1;if(sscanf(l,"%d|%d|%d|",&row,&a,&b)!=3||row!=y||a<0||a>W||b>=W||b< -1)fail("invalid mask");for(int x=0;x<W;x++)mask[y*W+x]= x>=a&&x<=b;}fclose(f);}
static int count_clusters(int *largest,int *isolated){
 uint8_t visited[N]={0};int clusters=0;*largest=0;*isolated=0;int queue[N];
 for(int i=0;i<N;i++)if(changed[i]&&!visited[i]){
  int head=0,tail=0;queue[tail++]=i;visited[i]=1;
  while(head<tail){int k=queue[head++];int x=k%W,y=k/W;
   for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){
    if(dx==0&&dy==0)continue;int nx=x+dx,ny=y+dy;
    if(nx>=0&&nx<W&&ny>=0&&ny<H){int ni=ny*W+nx;if(changed[ni]&&!visited[ni]){visited[ni]=1;queue[tail++]=ni;}}
   }
  }
  clusters++;if(tail>*largest)*largest=tail;if(tail==1)(*isolated)++;
 }
 return clusters;
}
int main(int argc,char**argv){if(argc!=5){fprintf(stderr,"USAGE v5v_motion_structure series.nodes.psv series.v5b water_mask.psv output.psv\n");return 2;}
 FILE*n=fopen(argv[1],"r"),*b=fopen(argv[2],"rb"),*out=fopen(argv[4],"w");if(!n||!b||!out)fail("input/output file");loadMask(argv[3]);
 char line[2048];if(!fgets(line,sizeof line,n)||strncmp(line,"node_id|frame_index|",20))fail("node header");
 fprintf(out,"node_id|frame_index|source_pts|water_change_cells|water_components|isolated_components|largest_component|temporal_neighbour_cells|temporal_support_ratio|motion_structure|evidence_state\n");
 int frame=0,coherent=0,scattered=0,quiet=0,totalInside=0;
 while(fgets(line,sizeof line,n)){
  char id[160],pts[80],type[40],ref[140],state[80];int index,allc,inside,outside;unsigned long long offset;size_t size;
  if(sscanf(line,"%159[^|]|%d|%79[^|]|%39[^|]|%d|%d|%d|%llu|%zu|%139[^|]|%79[^\n]",id,&index,pts,type,&allc,&inside,&outside,&offset,&size,ref,state)!=11)fail("node field parse");
  if(index!=frame||strcmp(state,"OBSERVED_UNTESTED"))fail("node order/authority");
  if(size>sizeof packed || fread(packed,1,size,b)!=size)fail("V5V payload truncated");
  if(frame%30==0){if(strcmp(type,"KEYFRAME")||size!=2250)fail("keyframe size");unpack(surface,packed,N,5);}
  else{
   if(strcmp(type,"DELTA")||size<450)fail("delta size");
   unpack(unpackedMask,packed,N,1);int k=0;for(int i=0;i<N;i++)k+=unpackedMask[i];
   if(size!=450+(size_t)(k*5+7)/8)fail("delta values size");
   unpack(unpackedValues,packed+450,k,5);int j=0;for(int i=0;i<N;i++)surface[i]=unpackedMask[i]?unpackedValues[j++]:prev[i];
  }
  int observed=0;memset(changed,0,sizeof changed);
  if(frame>0)for(int i=0;i<N;i++)if(surface[i]!=prev[i]&&mask[i]){changed[i]=1;observed++;}
  if(observed!=inside || inside+outside!=allc)fail("node change conservation");
  int largest=0,isolated=0,clusters=count_clusters(&largest,&isolated);
  int temporal=0;
  for(int i=0;i<N;i++)if(changed[i]){
   int x=i%W,y=i/W,near=0;
   for(int z=0;z<3&&!near;z++)for(int dy=-1;dy<=1&&!near;dy++)for(int dx=-1;dx<=1;dx++){
    int xx=x+dx,yy=y+dy;
    if(xx>=0&&xx<W&&yy>=0&&yy<H && old[z][yy*W+xx]){near=1;break;}
   }
   temporal+=near;
  }
  const char *cls="QUIET";
  if(observed==0)quiet++;
  else if(temporal>=2 && (largest>=2 || temporal>=3)){cls="TEMPORAL_STRUCTURE_CANDIDATE";coherent++;}
  else {cls="SCATTERED_OR_UNRESOLVED";scattered++;}
  fprintf(out,"%s|%d|%s|%d|%d|%d|%d|%d|%.6f|%s|OBSERVED_UNTESTED\n",id,frame,pts,observed,clusters,isolated,largest,temporal,observed?(double)temporal/observed:0.0,cls);
  memcpy(old[2],old[1],N);memcpy(old[1],old[0],N);memcpy(old[0],changed,N);memcpy(prev,surface,N);
  totalInside+=observed;frame++;
 }
 if(fgetc(b)!=EOF)fail("extra V5V payload");fclose(b);fclose(n);fclose(out);
 printf("V5V_TEMPORAL_SCREEN_PASS frames=%d structured_candidate_frames=%d scattered_or_unresolved=%d quiet=%d water_changed=%d\n",frame,coherent,scattered,quiet,totalInside);
 puts("SCATTERED IS NOT PROVED WAVE; NO PIXELS OR FRAME NODES REMOVED; ONLY ADVISORY RELEVANCE");
 return 0;
}
