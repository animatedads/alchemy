/* Sydney Harbour v0.33: source-pixel causal foreground evidence within
 * genuine V5V v0.32 group proposals. No world geometry, vessel ID or SLAM
 * TESTED score. Same-video t-5 seconds; bridge never erased. (C11)
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#define MAX_LINE 1100
#define MAX_GROUPS 10
#define MAX_PIXELS (1280*720)
#define TILE 8
static void fail(const char*m){fprintf(stderr,"V033_REJECT:%s\n",m);exit(3);}
static int integer(const char*s){char*end;errno=0;long z=strtol(s,&end,10);if(errno||!s[0]||*end||z<0||z>200000)fail("invalid integer");return (int)z;}
static unsigned char *loadraw(const char *p, size_t n){FILE *f=fopen(p,"rb");if(!f)fail("missing rgb source");unsigned char *b=malloc(n);if(!b)fail("allocation failed");if(fread(b,1,n,f)!=n||fgetc(f)!=EOF)fail("raw rgb size invalid");fclose(f);return b;}
static int difference(const unsigned char *a,const unsigned char*b,size_t i){size_t j=3*i;return (abs((int)a[j]-b[j])+abs((int)a[j+1]-b[j+1])+abs((int)a[j+2]-b[j+2]))/3;}
static int cmpint(const void*a,const void*b){int x=*(const int*)a,y=*(const int*)b;return (x>y)-(x<y);}
static int ctrl95(const unsigned char*a,const unsigned char*b,int width,int height,int cam){
  /* Manually source-observed STATIC CONTROL rectangles only; not geometric 3D.
   * Their stability must be requalified when camera direction changes. */
  int x0=cam==2?850:35,y0=cam==2?300:82,x1=cam==2?980:170,y1=cam==2?395:126;
  if(x1>width||y1>height)fail("camera control outside frame");
  int n=(x1-x0)*(y1-y0),*values=malloc((size_t)n*sizeof(int));if(!values)fail("ctrl allocation");
  int k=0;for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++)values[k++]=difference(a,b,(size_t)y*width+x);
  qsort(values,(size_t)n,sizeof(int),cmpint);int v=values[(n*95)/100];free(values);return v;
}
static char*split(char *line,int needed,char **col){int n=0;char *p=line;while(n<needed){col[n++]=p;char *q=strchr(p,'|');if(!q)break;*q=0;p=q+1;}if(n!=needed||strchr(p,'|'))fail("invalid grouping schema");size_t l=strlen(col[needed-1]);while(l&&(col[needed-1][l-1]=='\n'||col[needed-1][l-1]=='\r'))col[needed-1][--l]=0;return line;}
static int count_cluster(const uint8_t *on,int w,int h){
 if(w<1||h<1||w>200||h>200)fail("invalid tile grid");
 int n=w*h;int *queue=malloc((size_t)n*sizeof(int));uint8_t *mark=calloc((size_t)n,1);if(!queue||!mark)fail("tile memory");int best=0;
 for(int i=0;i<n;i++)if(on[i]&&!mark[i]){int front=0,end=1;queue[0]=i;mark[i]=1;while(front<end){int z=queue[front++];int x=z%w,y=z/w;int v[4]={z-1,z+1,z-w,z+w};for(int j=0;j<4;j++){if((j==0&&x==0)||(j==1&&x==w-1)||(j==2&&y==0)||(j==3&&y==h-1))continue;int t=v[j];if(on[t]&&!mark[t]){mark[t]=1;queue[end++]=t;}}}if(end>best)best=end;}
 free(mark);free(queue);return best;
}
int main(int argc,char**argv){
 if(argc!=10){fprintf(stderr,"Usage: v5v_occlusion_temporal_v033 groups.psv mask.psv current.rgb previous.rgb source_sha cam frame width height\n");return 2;}
 const char *gp=argv[1],*mp=argv[2],*sha=argv[5];int cam=integer(argv[6]),frame=integer(argv[7]),w=integer(argv[8]),h=integer(argv[9]);
 if((cam!=2&&cam!=3)||w!=(cam==2?1280:640)||h!=(cam==2?720:360)||frame<150||frame>=1800||frame%30)fail("source geometry or frame");
 if(strlen(sha)!=64||strspn(sha,"0123456789abcdef")!=64)fail("invalid source hash");
 size_t n=(size_t)w*h*3;unsigned char *a=loadraw(argv[3],n),*b=loadraw(argv[4],n);
 int q95=ctrl95(a,b,w,h,cam),th=q95+6;if(th<20)th=20;
 int scale=w/80;uint8_t water[3600];FILE *f=fopen(mp,"r");if(!f)fail("water mask absent");char line[MAX_LINE];if(!fgets(line,sizeof line,f)||strcmp(line,"row|bits80|authority\n"))fail("water mask schema");
 for(int y=0;y<45;y++){if(!fgets(line,sizeof line,f))fail("water mask short");char *cols[3];split(line,3,cols);if(integer(cols[0])!=y||strlen(cols[1])!=80||strcmp(cols[2],"PROVISIONAL_WATER_MOVEMENT_ONLY"))fail("water mask row bad");for(int x=0;x<80;x++){if(cols[1][x]!='0'&&cols[1][x]!='1')fail("nonbinary mask");water[y*80+x]=(uint8_t)(cols[1][x]-'0');}}
 if(fgets(line,sizeof line,f))fail("extra mask rows");
 fclose(f);
 f=fopen(gp,"r");if(!f)fail("group file absent");if(!fgets(line,sizeof line,f)||strncmp(line,"source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|",strlen("source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|")))fail("group schema invalid");
 puts("source_sha256|camera|frame|group|src_x0|src_y0|src_x1|src_y1|static_control_q95|difference_gate|changed_pixels|total_pixels|changed_fraction|nonwater_changed|nonwater_pixels|water_changed|water_pixels|coherent_eight_pixel_tiles|largest_tile_cluster|temporal_state|geometry_state|evidence_state");
 int found=0;while(fgets(line,sizeof line,f)){
 char *cols[21];split(line,21,cols);if(strcmp(cols[0],sha))continue;
 if(integer(cols[1])!=frame)continue;
 if(strcmp(cols[19],"UNCLASSIFIED_GROUP")||strcmp(cols[20],"OBSERVED_UNTESTED"))fail("forged group status");
 int g=integer(cols[3]),x0=integer(cols[6]),y0=integer(cols[7]),x1=integer(cols[8]),y1=integer(cols[9]);
 if(g<1||g>MAX_GROUPS||x1>80||y1>45||x1<=x0||y1<=y0)fail("group out of bounds");
 x0*=scale;y0*=scale;x1*=scale;y1*=scale;
 int cw=x1-x0,ch=y1-y0,tw=(cw+TILE-1)/TILE,thh=(ch+TILE-1)/TILE;
 int *tilecounts=calloc((size_t)tw*thh,sizeof(int));uint8_t *active=calloc((size_t)tw*thh,1);if(!tilecounts||!active)fail("tile allocation");
 int all=0,non=0,wat=0,nonpix=0,watpix=0;
 for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){
   int mask=water[(y/scale)*80+x/scale];if(mask)watpix++;else nonpix++;
   if(difference(a,b,(size_t)y*w+x)>th){all++;if(mask)wat++;else non++;tilecounts[((y-y0)/TILE)*tw+(x-x0)/TILE]++;}
 }
 int tiles=0;for(int i=0;i<tw*thh;i++)if(tilecounts[i]>=4){active[i]=1;tiles++;}
 int maxCluster=count_cluster(active,tw,thh);free(tilecounts);free(active);
 /* Evidence only: no camera-specific learned ship threshold, no auto ship ID. */
 const char *status=maxCluster>=4&&all>=64?"SPATIALLY_COHERENT_IMAGE_CHANGE":"WEAK_OR_FRAGMENTED_CHANGE";
 printf("%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.8f|%d|%d|%d|%d|%d|%d|%s|IMAGE_PLANE_ONLY_UNCALIBRATED|OBSERVED_UNTESTED\n",sha,cam,frame,g,x0,y0,x1,y1,q95,th,all,cw*ch,(double)all/(cw*ch),non,nonpix,wat,watpix,tiles,maxCluster,status);
 found++;
 }
 fclose(f);free(a);free(b);if(!found)fail("no source frame groups");
 fprintf(stderr,"V033_FOREGROUND_PASS camera=%d frame=%d groups=%d control_q95=%d gate=%d WORLD=BLOCKED\n",cam,frame,found,q95,th);return 0;
}
