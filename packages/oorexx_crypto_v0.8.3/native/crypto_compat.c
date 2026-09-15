#include <openssl/sha.h>
#include <openssl/bn.h>
#include <openssl/crypto.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define TEXT_CAP 8192
static int write_text(unsigned char *out, const char *s) {
    if (!out || !s) return 0;
    size_t n = strlen(s);
    if (n + 1 > TEXT_CAP) return 0;
    memcpy(out, s, n + 1);
    return 1;
}

static int write_pair(unsigned char *out, const char *a, const char *b) {
    if (!out || !a || !b) return 0;
    size_t na = strlen(a), nb = strlen(b);
    if (na + nb + 2 > TEXT_CAP) return 0;
    memcpy(out, a, na);
    out[na] = '|';
    memcpy(out + na + 1, b, nb);
    out[na + nb + 1] = 0;
    return 1;
}

static int split_ascii(const unsigned char *buf, uint32_t len, char sep, char **fields, int wanted) {
    char *tmp = (char*)malloc((size_t)len + 1);
    if (!tmp) return 0;
    memcpy(tmp, buf, len); tmp[len] = 0;
    int count = 0; char *p = tmp; fields[count++] = p;
    while (*p && count < wanted) { if (*p == sep) { *p = 0; fields[count++] = p+1; } ++p; }
    if (count != wanted) { free(tmp); return 0; }
    /* stash allocation immediately before first field logically via fields[wanted] */
    fields[wanted] = tmp;
    return 1;
}

static BIGNUM *bn_dec(const char *s) {
    if (!s || !*s) return NULL;
    BIGNUM *b = NULL;
    if (!BN_dec2bn(&b, s)) { BN_free(b); return NULL; }
    return b;
}

static BIGNUM *prime25519(void) {
    BIGNUM *p = BN_new(); if (!p) return NULL;
    if (!BN_one(p) || !BN_lshift(p,p,255) || !BN_sub_word(p,19)) { BN_free(p); return NULL; }
    return p;
}

static BIGNUM *ed25519_d(BN_CTX *ctx, const BIGNUM *p) {
    BIGNUM *a=BN_new(), *b=BN_new(), *inv=NULL, *d=BN_new();
    if(!a||!b||!d) goto bad;
    BN_set_word(a,121665); BN_set_word(b,121666);
    inv=BN_mod_inverse(NULL,b,p,ctx); if(!inv) goto bad;
    if(!BN_mod_mul(d,a,inv,p,ctx)) goto bad;
    if(!BN_is_zero(d) && !BN_sub(d,p,d)) goto bad;
    BN_free(a); BN_free(b); BN_free(inv); return d;
bad: BN_free(a); BN_free(b); BN_free(inv); BN_free(d); return NULL;
}

static int ed_add(BIGNUM *rx,BIGNUM *ry,const BIGNUM*x1,const BIGNUM*y1,const BIGNUM*x2,const BIGNUM*y2,const BIGNUM*p,const BIGNUM*d,BN_CTX*ctx,int untwisted_minus) {
    BN_CTX_start(ctx);
    BIGNUM *prod=BN_CTX_get(ctx), *dx=BN_CTX_get(ctx), *dy=BN_CTX_get(ctx), *invx=BN_CTX_get(ctx), *invy=BN_CTX_get(ctx);
    BIGNUM *t1=BN_CTX_get(ctx), *t2=BN_CTX_get(ctx), *numx=BN_CTX_get(ctx), *numy=BN_CTX_get(ctx);
    if(!numy) { BN_CTX_end(ctx); return 0; }
    if(!BN_mod_mul(prod,x1,x2,p,ctx) || !BN_mod_mul(prod,prod,y1,p,ctx) || !BN_mod_mul(prod,prod,y2,p,ctx) || !BN_mod_mul(prod,prod,d,p,ctx)) goto bad;
    if(!BN_one(dx) || !BN_mod_add(dx,dx,prod,p,ctx)) goto bad;
    if(!BN_one(dy) || !BN_mod_sub(dy,dy,prod,p,ctx)) goto bad;
    if(!BN_mod_inverse(invx,dx,p,ctx) || !BN_mod_inverse(invy,dy,p,ctx)) goto bad;
    if(!BN_mod_mul(t1,x1,y2,p,ctx) || !BN_mod_mul(t2,y1,x2,p,ctx) || !BN_mod_add(numx,t1,t2,p,ctx)) goto bad;
    if(!BN_mod_mul(t1,y1,y2,p,ctx) || !BN_mod_mul(t2,x1,x2,p,ctx)) goto bad;
    if(untwisted_minus) { if(!BN_mod_sub(numy,t1,t2,p,ctx)) goto bad; }
    else { if(!BN_mod_add(numy,t1,t2,p,ctx)) goto bad; }
    if(!BN_mod_mul(rx,numx,invx,p,ctx) || !BN_mod_mul(ry,numy,invy,p,ctx)) goto bad;
    BN_CTX_end(ctx); return 1;
bad: BN_CTX_end(ctx); return 0;
}

static int ed_mul(BIGNUM *rx,BIGNUM *ry,const BIGNUM*x,const BIGNUM*y,const BIGNUM*scalar,const BIGNUM*p,const BIGNUM*d,BN_CTX*ctx,int untwisted_minus) {
    BIGNUM *bx=BN_dup(x), *by=BN_dup(y), *tx=BN_new(), *ty=BN_new(), *nx=BN_new(), *ny=BN_new();
    if(!bx||!by||!tx||!ty||!nx||!ny) goto bad;
    BN_zero(rx); BN_one(ry);
    int bits=BN_num_bits(scalar);
    for(int i=0;i<bits;i++) {
        if(BN_is_bit_set(scalar,i)) {
            if(!ed_add(tx,ty,rx,ry,bx,by,p,d,ctx,untwisted_minus)) goto bad;
            if(!BN_copy(rx,tx)||!BN_copy(ry,ty)) goto bad;
        }
        if(!ed_add(nx,ny,bx,by,bx,by,p,d,ctx,untwisted_minus)) goto bad;
        if(!BN_copy(bx,nx)||!BN_copy(by,ny)) goto bad;
    }
    BN_free(bx);BN_free(by);BN_free(tx);BN_free(ty);BN_free(nx);BN_free(ny); return 1;
bad: BN_free(bx);BN_free(by);BN_free(tx);BN_free(ty);BN_free(nx);BN_free(ny); return 0;
}

int32_t compat_edwards25519_add(const void *vin, uint32_t len, void *vout) {
    char *f[5]; if(!split_ascii(vin,len,'|',f,4)) return 0;
    BIGNUM *x1=bn_dec(f[0]),*y1=bn_dec(f[1]),*x2=bn_dec(f[2]),*y2=bn_dec(f[3]); free(f[4]);
    BN_CTX *ctx=BN_CTX_new(); BIGNUM *p=prime25519(),*d=NULL,*rx=BN_new(),*ry=BN_new(); int ok=0;
    if(!x1||!y1||!x2||!y2||!ctx||!p||!rx||!ry) goto done;
    d=ed25519_d(ctx,p); if(!d) goto done;
    if(!ed_add(rx,ry,x1,y1,x2,y2,p,d,ctx,0)) goto done;
    char *sx=BN_bn2dec(rx),*sy=BN_bn2dec(ry); if(!sx||!sy) { OPENSSL_free(sx);OPENSSL_free(sy);goto done; }
    ok=write_pair(vout,sx,sy); OPENSSL_free(sx);OPENSSL_free(sy);
done: BN_free(x1);BN_free(y1);BN_free(x2);BN_free(y2);BN_free(p);BN_free(d);BN_free(rx);BN_free(ry);BN_CTX_free(ctx);return ok;
}

int32_t compat_edwards25519_multiply(const void *vin, uint32_t len, void *vout) {
    char *f[4]; if(!split_ascii(vin,len,'|',f,3)) return 0;
    BIGNUM *x=bn_dec(f[0]),*y=bn_dec(f[1]),*s=bn_dec(f[2]); free(f[3]);
    BN_CTX *ctx=BN_CTX_new(); BIGNUM *p=prime25519(),*d=NULL,*rx=BN_new(),*ry=BN_new(); int ok=0;
    if(!x||!y||!s||!ctx||!p||!rx||!ry) goto done;
    d=ed25519_d(ctx,p); if(!d) goto done;
    if(!ed_mul(rx,ry,x,y,s,p,d,ctx,0)) goto done;
    char *sx=BN_bn2dec(rx),*sy=BN_bn2dec(ry); if(!sx||!sy) { OPENSSL_free(sx);OPENSSL_free(sy);goto done; }
    ok=write_pair(vout,sx,sy); OPENSSL_free(sx);OPENSSL_free(sy);
done: BN_free(x);BN_free(y);BN_free(s);BN_free(p);BN_free(d);BN_free(rx);BN_free(ry);BN_CTX_free(ctx);return ok;
}

static int x25519_ladder_bn(BIGNUM*out,const BIGNUM*scalar,const BIGNUM*u) {
    BN_CTX*ctx=BN_CTX_new(); BIGNUM*p=prime25519(); BIGNUM*x1=BN_dup(u),*x2=BN_new(),*z2=BN_new(),*x3=BN_dup(u),*z3=BN_new();
    BIGNUM *A=BN_new(),*AA=BN_new(),*B=BN_new(),*BB=BN_new(),*E=BN_new(),*C=BN_new(),*D=BN_new(),*DA=BN_new(),*CB=BN_new(),*tmp=BN_new(),*inv=BN_new(); int ok=0;
    if(!ctx||!p||!x1||!x2||!z2||!x3||!z3||!A||!AA||!B||!BB||!E||!C||!D||!DA||!CB||!tmp||!inv)goto done;
    BN_one(x2);BN_zero(z2);BN_one(z3); BN_mod(x1,x1,p,ctx); BN_copy(x3,x1);
    for(int t=254;t>=0;t--){ int bit=BN_is_bit_set(scalar,t); if(bit){BN_swap(x2,x3);BN_swap(z2,z3);} 
      if(!BN_mod_add(A,x2,z2,p,ctx)||!BN_mod_sqr(AA,A,p,ctx)||!BN_mod_sub(B,x2,z2,p,ctx)||!BN_mod_sqr(BB,B,p,ctx)||!BN_mod_sub(E,AA,BB,p,ctx)||!BN_mod_add(C,x3,z3,p,ctx)||!BN_mod_sub(D,x3,z3,p,ctx)||!BN_mod_mul(DA,D,A,p,ctx)||!BN_mod_mul(CB,C,B,p,ctx))goto done;
      if(!BN_mod_add(tmp,DA,CB,p,ctx)||!BN_mod_sqr(x3,tmp,p,ctx)||!BN_mod_sub(tmp,DA,CB,p,ctx)||!BN_mod_sqr(z3,tmp,p,ctx)||!BN_mod_mul(z3,z3,x1,p,ctx)||!BN_mod_mul(x2,AA,BB,p,ctx))goto done;
      if(!BN_set_word(tmp,121665)||!BN_mod_mul(tmp,tmp,E,p,ctx)||!BN_mod_add(tmp,tmp,AA,p,ctx)||!BN_mod_mul(z2,E,tmp,p,ctx))goto done;
      if(bit){BN_swap(x2,x3);BN_swap(z2,z3);} }
    if(!BN_mod_inverse(inv,z2,p,ctx)||!BN_mod_mul(out,x2,inv,p,ctx)) goto done;
    ok=1;
done: BN_free(p);BN_free(x1);BN_free(x2);BN_free(z2);BN_free(x3);BN_free(z3);BN_free(A);BN_free(AA);BN_free(B);BN_free(BB);BN_free(E);BN_free(C);BN_free(D);BN_free(DA);BN_free(CB);BN_free(tmp);BN_free(inv);BN_CTX_free(ctx);return ok;
}

int32_t compat_x25519_public(const void *vin,uint32_t len,void *vout){ char *s=(char*)malloc(len+1);if(!s)return 0;memcpy(s,vin,len);s[len]=0;BIGNUM*k=bn_dec(s),*u=BN_new(),*r=BN_new();free(s);int ok=0;if(k&&u&&r){BN_set_word(u,9);if(x25519_ladder_bn(r,k,u)){char*x=BN_bn2dec(r);if(x){ok=write_text(vout,x);OPENSSL_free(x);}}}BN_free(k);BN_free(u);BN_free(r);return ok; }
int32_t compat_x25519_shared(const void *vin,uint32_t len,void *vout){char*f[3];if(!split_ascii(vin,len,'|',f,2))return 0;BIGNUM*k=bn_dec(f[0]),*u=bn_dec(f[1]),*r=BN_new();free(f[2]);int ok=0;if(k&&u&&r&&x25519_ladder_bn(r,k,u)){char*x=BN_bn2dec(r);if(x){ok=write_text(vout,x);OPENSSL_free(x);}}BN_free(k);BN_free(u);BN_free(r);return ok;}
static BIGNUM *prime448(void){BIGNUM*p=BN_new(),*t=BN_new();if(!p||!t)goto bad;BN_one(p);BN_lshift(p,p,448);BN_one(t);BN_lshift(t,t,224);if(!BN_sub(p,p,t)||!BN_sub_word(p,1))goto bad;BN_free(t);return p;bad:BN_free(p);BN_free(t);return NULL;}

int32_t compat_ed448_keypair(const void*seedv,uint32_t seed_len,void*vout){if(seed_len!=57||!seedv||!vout)return 0;unsigned char h[64];SHA512(seedv,seed_len,h);h[0]&=248;h[31]&=127;h[31]|=64;BIGNUM*s=BN_lebin2bn(h,32,NULL),*p=prime448(),*d=BN_new(),*gy=NULL,*gx=BN_new(),*u=BN_new(),*v=BN_new(),*inv=BN_new(),*exp=BN_new(),*rx=BN_new(),*ry=BN_new();BN_CTX*ctx=BN_CTX_new();int ok=0;if(!s||!p||!d||!gx||!u||!v||!inv||!exp||!rx||!ry||!ctx)goto done;BN_copy(d,p);BN_sub_word(d,39081);BN_dec2bn(&gy,"693175619530233403454093726540132763892135629552985898986858051805439768853646");if(!gy)goto done;if(!BN_mod_sqr(u,gy,p,ctx)||!BN_sub_word(u,1)||!BN_mod(u,u,p,ctx))goto done;if(!BN_mod_sqr(v,gy,p,ctx)||!BN_mod_mul(v,v,d,p,ctx)||!BN_sub_word(v,1)||!BN_mod(v,v,p,ctx))goto done;if(!BN_mod_inverse(inv,v,p,ctx)||!BN_mod_mul(u,u,inv,p,ctx))goto done;BN_copy(exp,p);BN_add_word(exp,1);BN_rshift(exp,exp,2);if(!BN_mod_exp(gx,u,exp,p,ctx))goto done;if(BN_is_odd(gx))BN_sub(gx,p,gx);if(!ed_mul(rx,ry,gx,gy,s,p,d,ctx,1))goto done;unsigned char*yout=vout;if(BN_bn2lebinpad(ry,yout,57)!=57)goto done;if(BN_is_odd(rx))yout[56]|=0x80;memcpy(yout+57,h,32);ok=1;done:BN_free(s);BN_free(p);BN_free(d);BN_free(gy);BN_free(gx);BN_free(u);BN_free(v);BN_free(inv);BN_free(exp);BN_free(rx);BN_free(ry);BN_CTX_free(ctx);return ok;}
