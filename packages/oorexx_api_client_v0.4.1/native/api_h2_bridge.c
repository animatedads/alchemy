#include <nghttp2/nghttp2.h>
#include <openssl/ssl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>

struct api_h2_client {
  nghttp2_session *session;
  uint8_t *body;
  size_t body_len;
  size_t body_pos;
  uint8_t *resp_body;
  size_t resp_len;
  size_t resp_cap;
  char *headers;
  size_t headers_len;
  size_t headers_cap;
  int32_t stream_id;
  int status;
  int complete;
  int last_error;
};

static int append_bytes(uint8_t **p, size_t *len, size_t *cap, const uint8_t *src, size_t n) {
  if (*len + n > *cap) {
    size_t nc = *cap ? *cap : 4096;
    while (nc < *len + n) nc *= 2;
    uint8_t *np = (uint8_t *)realloc(*p, nc);
    if (!np) return -1;
    *p=np; *cap=nc;
  }
  memcpy(*p + *len, src, n); *len += n; return 0;
}
static int append_header(struct api_h2_client *c, const uint8_t *name, size_t nl, const uint8_t *value, size_t vl) {
  size_t n = nl + 2 + vl + 1;
  if (c->headers_len + n + 1 > c->headers_cap) {
    size_t nc = c->headers_cap ? c->headers_cap : 2048;
    while (nc < c->headers_len + n + 1) nc *= 2;
    char *np=(char *)realloc(c->headers,nc); if(!np) return -1;
    c->headers=np; c->headers_cap=nc;
  }
  memcpy(c->headers+c->headers_len,name,nl); c->headers_len += nl;
  memcpy(c->headers+c->headers_len,": ",2); c->headers_len += 2;
  memcpy(c->headers+c->headers_len,value,vl); c->headers_len += vl;
  c->headers[c->headers_len++]='\n'; c->headers[c->headers_len]=0;
  return 0;
}
static int on_header(nghttp2_session *s, const nghttp2_frame *f,
                     const uint8_t *name, size_t nl, const uint8_t *value, size_t vl,
                     uint8_t flags, void *ud) {
  (void)s;(void)flags; struct api_h2_client *c=(struct api_h2_client*)ud;
  if (f->hd.stream_id != c->stream_id) return 0;
  if (nl==7 && memcmp(name,":status",7)==0) {
    char tmp[4]={0}; if(vl>3) vl=3; memcpy(tmp,value,vl); c->status=atoi(tmp); return 0;
  }
  return append_header(c,name,nl,value,vl)==0 ? 0 : NGHTTP2_ERR_TEMPORAL_CALLBACK_FAILURE;
}
static int on_data(nghttp2_session *s, uint8_t flags, int32_t sid,
                   const uint8_t *data, size_t len, void *ud) {
  (void)s;(void)flags; struct api_h2_client *c=(struct api_h2_client*)ud;
  if (sid != c->stream_id) return 0;
  return append_bytes(&c->resp_body,&c->resp_len,&c->resp_cap,data,len)==0 ? 0 : NGHTTP2_ERR_TEMPORAL_CALLBACK_FAILURE;
}
static int on_close(nghttp2_session *s, int32_t sid, uint32_t ec, void *ud) {
  (void)s; struct api_h2_client *c=(struct api_h2_client*)ud;
  if (sid==c->stream_id) { c->complete=1; c->last_error=(int)ec; }
  return 0;
}
static ssize_t body_read(nghttp2_session *s, int32_t sid, uint8_t *buf, size_t length,
                         uint32_t *flags, nghttp2_data_source *source, void *ud) {
  (void)s;(void)sid;(void)source; struct api_h2_client *c=(struct api_h2_client*)ud;
  size_t remain=c->body_len-c->body_pos; size_t n=remain<length?remain:length;
  if(n){memcpy(buf,c->body+c->body_pos,n); c->body_pos+=n;}
  if(c->body_pos>=c->body_len) *flags|=NGHTTP2_DATA_FLAG_EOF;
  return (ssize_t)n;
}

void *api_h2_client_new(void) {
  struct api_h2_client *c=(struct api_h2_client*)calloc(1,sizeof(*c)); if(!c) return NULL;
  nghttp2_session_callbacks *cb=NULL;
  if(nghttp2_session_callbacks_new(&cb)!=0){free(c);return NULL;}
  nghttp2_session_callbacks_set_on_header_callback(cb,on_header);
  nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cb,on_data);
  nghttp2_session_callbacks_set_on_stream_close_callback(cb,on_close);
  if(nghttp2_session_client_new(&c->session,cb,c)!=0){nghttp2_session_callbacks_del(cb);free(c);return NULL;}
  nghttp2_session_callbacks_del(cb);
  nghttp2_settings_entry iv[1]={{NGHTTP2_SETTINGS_ENABLE_PUSH,0}};
  if(nghttp2_submit_settings(c->session,NGHTTP2_FLAG_NONE,iv,1)!=0){nghttp2_session_del(c->session);free(c);return NULL;}
  return c;
}
void api_h2_client_free(void *p) {
  struct api_h2_client *c=(struct api_h2_client*)p; if(!c)return;
  if(c->session) nghttp2_session_del(c->session);
  free(c->body); free(c->resp_body); free(c->headers); free(c);
}
static nghttp2_nv nv(const char *n,const char *v){nghttp2_nv x={(uint8_t*)n,(uint8_t*)v,strlen(n),strlen(v),NGHTTP2_NV_FLAG_NONE};return x;}
int32_t api_h2_submit(void *p, const char *method, const char *scheme, const char *authority,
                      const char *path, const char *header_lines, const uint8_t *body, size_t body_len) {
  struct api_h2_client *c=(struct api_h2_client*)p; if(!c||!c->session)return -1;
  nghttp2_nv nva[128]; size_t n=0;
  nva[n++]=nv(":method",method); nva[n++]=nv(":scheme",scheme); nva[n++]=nv(":authority",authority); nva[n++]=nv(":path",path);
  char *copy=header_lines?strdup(header_lines):NULL; char *save=NULL;
  for(char *line=copy?strtok_r(copy,"\n",&save):NULL; line && n<128; line=strtok_r(NULL,"\n",&save)){
    char *colon=strchr(line,':'); if(!colon)continue; *colon=0; char *name=line; char *value=colon+1; while(*value==' ')value++;
    if(!*name || name[0]==':' || !strcasecmp(name,"connection") || !strcasecmp(name,"host") || !strcasecmp(name,"transfer-encoding"))continue;
    nva[n++]=nv(name,value);
  }
  free(c->body); c->body=NULL; c->body_len=body_len; c->body_pos=0;
  if(body_len){c->body=(uint8_t*)malloc(body_len); if(!c->body){free(copy);return -2;} memcpy(c->body,body,body_len);}
  nghttp2_data_provider dp; nghttp2_data_provider *dpp=NULL;
  if(body_len){memset(&dp,0,sizeof(dp)); dp.read_callback=body_read; dpp=&dp;}
  c->stream_id=nghttp2_submit_request(c->session,NULL,nva,n,dpp,c);
  free(copy);
  return c->stream_id;
}
ssize_t api_h2_next_output(void *p, void *out, size_t cap) {
  struct api_h2_client *c=(struct api_h2_client*)p; if(!c)return -1;
  const uint8_t *data=NULL; ssize_t n=nghttp2_session_mem_send(c->session,&data); if(n<=0)return n;
  if((size_t)n>cap)return -2;
  memcpy(out,data,(size_t)n); return n;
}
ssize_t api_h2_feed(void *p,const uint8_t *data,size_t len){struct api_h2_client*c=(struct api_h2_client*)p;if(!c)return -1;return nghttp2_session_mem_recv(c->session,data,len);}
int api_h2_status(void *p){struct api_h2_client*c=(struct api_h2_client*)p;return c?c->status:0;}
int api_h2_complete(void *p){struct api_h2_client*c=(struct api_h2_client*)p;return c?c->complete:0;}
int api_h2_stream_error(void *p){struct api_h2_client*c=(struct api_h2_client*)p;return c?c->last_error:-1;}
size_t api_h2_body_length(void *p){struct api_h2_client*c=(struct api_h2_client*)p;return c?c->resp_len:0;}
size_t api_h2_copy_body(void *p,void*out,size_t cap){struct api_h2_client*c=(struct api_h2_client*)p;if(!c)return 0;size_t n=c->resp_len<cap?c->resp_len:cap;if(n)memcpy(out,c->resp_body,n);return n;}
size_t api_h2_headers_length(void *p){struct api_h2_client*c=(struct api_h2_client*)p;return c?c->headers_len:0;}
size_t api_h2_copy_headers(void *p,void*out,size_t cap){struct api_h2_client*c=(struct api_h2_client*)p;if(!c)return 0;size_t n=c->headers_len<cap?c->headers_len:cap;if(n)memcpy(out,c->headers,n);return n;}
const char *api_h2_error_string(int code){return nghttp2_strerror(code);}

int api_ssl_set_client_alpn(SSL *ssl, int offer_h2) {
  static const unsigned char both[]={2,'h','2',8,'h','t','t','p','/','1','.','1'};
  static const unsigned char h1[]={8,'h','t','t','p','/','1','.','1'};
  const unsigned char *p=offer_h2?both:h1; unsigned int n=offer_h2?sizeof(both):sizeof(h1);
  return SSL_set_alpn_protos(ssl,p,n);
}
const char *api_ssl_selected_alpn(SSL *ssl) {
  static _Thread_local char buf[32]; const unsigned char *p=NULL; unsigned int n=0;
  SSL_get0_alpn_selected(ssl,&p,&n); if(!p||n==0){buf[0]=0;return buf;} if(n>=sizeof(buf))n=sizeof(buf)-1; memcpy(buf,p,n);buf[n]=0;return buf;
}
