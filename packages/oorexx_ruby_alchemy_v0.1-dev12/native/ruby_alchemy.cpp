#include <ruby.h>
#include <oorexxapi.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct RubySlot {
    uint64_t id;
    VALUE value;
    struct RubySlot *next;
} RubySlot;

static RubySlot *slots = NULL;
static uint64_t next_id = 1;
static int ruby_started = 0;

/* Start the embedded MRI VM exactly once; centralizes runtime startup. */
static void ensure_ruby(void) {
    if (ruby_started) return;
    int argc = 0;
    char **argv = NULL;
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    ruby_init_loadpath();
    ruby_started = 1;
}

/* Resolve an opaque Ruby identity without changing its lifetime. */
static RubySlot *find_slot(uint64_t id) {
    for (RubySlot *s=slots; s; s=s->next) if (s->id == id) return s;
    return NULL;
}

/* Retain a Ruby VALUE as a GC root and return its bridge identity. */
static uint64_t keep(VALUE v) {
    RubySlot *s=(RubySlot *)calloc(1,sizeof(*s));
    if (!s) return 0;
    s->id=next_id++; s->value=v;
    rb_gc_register_address(&s->value);
    s->next=slots; slots=s;
    return s->id;
}

/* Release one retained Ruby VALUE and unregister its GC root. */
static int drop(uint64_t id) {
    RubySlot **p=&slots;
    while (*p) {
        if ((*p)->id == id) {
            RubySlot *s=*p; *p=s->next;
            rb_gc_unregister_address(&s->value);
            free(s); return 1;
        }
        p=&(*p)->next;
    }
    return 0;
}

typedef struct { VALUE recv; ID mid; } Call0;
static VALUE protected_call0(VALUE data) {
    Call0 *c=(Call0 *)(uintptr_t)data;
    return rb_funcall(c->recv,c->mid,0);
}

static VALUE protected_eval(VALUE code) {
    return rb_eval_string(StringValueCStr(code));
}

/* Marshal Ruby scalars; non-scalars remain resident identities. */
static RexxObjectPtr ruby_to_rexx(RexxCallContext *context, VALUE v) {
    if (NIL_P(v)) return context->Nil();
    if (v == Qtrue) return context->True();
    if (v == Qfalse) return context->False();
    if (RB_INTEGER_TYPE_P(v)) return context->Int64((int64_t)NUM2LL(v));
    if (RB_TYPE_P(v,T_FLOAT)) return context->Double(NUM2DBL(v));
    if (RB_TYPE_P(v,T_STRING))
        return context->NewString(RSTRING_PTR(v),(size_t)RSTRING_LEN(v));
    return context->Int64((int64_t)keep(v));
}
/* Marshal the scalar Rexx subset; token-aware callers unwrap first. */
static VALUE rexx_to_ruby(RexxCallContext *context, RexxObjectPtr o) {
    if (o == context->Nil()) return Qnil;
    if (o == context->True()) return Qtrue;
    if (o == context->False()) return Qfalse;
    int64_t i=0; if (context->Int64(o,&i)) return LL2NUM(i);
    double d=0; if (context->Double(o,&d)) return DBL2NUM(d);
    return rb_utf8_str_new_cstr(context->CString(o));
}

static const char *last_exception_text(void) {
    VALUE e=rb_errinfo();
    VALUE s=rb_obj_as_string(e);
    return StringValueCStr(s);
}

/* API is intentionally handle-based: no Ruby object is serialized. */
RexxRoutine1(uint64_t, RubyAlchemyEval, CSTRING, source)
{
    ensure_ruby();
    int state=0;
    VALUE code=rb_str_new_cstr(source);
    VALUE v=rb_protect(protected_eval, code, &state);
    if (state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
            context->String(last_exception_text()));
        rb_set_errinfo(Qnil);
        return 0;
    }
    return keep(v);
}

RexxRoutine2(RexxObjectPtr, RubyAlchemyCall0, uint64_t, handle, CSTRING, selector)
{
    ensure_ruby();
    RubySlot *s=find_slot(handle);
    if (!s) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
            context->String("invalid or released Ruby handle"));
        return NULLOBJECT;
    }
    Call0 c={s->value, rb_intern(selector)};
    int state=0;
    VALUE v=rb_protect(protected_call0,(VALUE)(uintptr_t)&c,&state);
    if (state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
            context->String(last_exception_text()));
        rb_set_errinfo(Qnil);
        return NULLOBJECT;
    }
    return ruby_to_rexx(context,v);
}

typedef struct { VALUE recv; ID mid; VALUE arg; } Call1;
static VALUE protected_call1(VALUE data) {
    Call1 *c=(Call1 *)(uintptr_t)data;
    return rb_funcall(c->recv,c->mid,1,c->arg);
}
RexxRoutine3(RexxObjectPtr, RubyAlchemyCall1, uint64_t, handle, CSTRING, selector, RexxObjectPtr, arg)
{
    ensure_ruby();
    RubySlot *s=find_slot(handle);
    if (!s) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
            context->String("invalid or released Ruby handle"));
        return NULLOBJECT;
    }
    Call1 c={s->value,rb_intern(selector),rexx_to_ruby(context,arg)};
    int state=0;
    VALUE v=rb_protect(protected_call1,(VALUE)(uintptr_t)&c,&state);
    if (state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
            context->String(last_exception_text()));
        rb_set_errinfo(Qnil);
        return NULLOBJECT;
    }
    return ruby_to_rexx(context,v);
}

/* dev4 object-aware token. A Ruby object handle is never represented to the
 * generic dispatcher as an ordinary Rexx integer. */
static RexxObjectPtr make_handle_token(RexxCallContext *context, uint64_t h) {
    char b[64]; snprintf(b,sizeof(b),"@RUBY:%llu",(unsigned long long)h);
    return context->String(b);
}
static int parse_handle_token(RexxCallContext *context, RexxObjectPtr o, uint64_t *h) {
    CSTRING x=context->CString(o);
    if (!x || strncmp(x,"@RUBY:",6)!=0) return 0;
    char *end=NULL; unsigned long long n=strtoull(x+6,&end,10);
    if (!end || *end!='\0' || !find_slot((uint64_t)n)) return 0;
    *h=(uint64_t)n; return 1;
}
static VALUE projected_rexx_to_ruby(RexxCallContext *context,RexxObjectPtr o) {
    uint64_t h=0;
    if (parse_handle_token(context,o,&h)) return find_slot(h)->value;
    return rexx_to_ruby(context,o);
}
typedef struct { VALUE recv; ID mid; int argc; VALUE *argv; } CallN;
static VALUE protected_calln(VALUE data) {
    CallN *c=(CallN*)(uintptr_t)data;
    return rb_funcallv(c->recv,c->mid,c->argc,c->argv);
}
RexxRoutine2(RexxObjectPtr,RubyAlchemyToken,uint64_t,handle,OPTIONAL_RexxObjectPtr,dummy) {
    (void)dummy;
    ensure_ruby();
    if(!find_slot(handle)) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("invalid or released Ruby handle")); return NULLOBJECT;
    }
    return make_handle_token(context,handle);
}
RexxRoutine3(RexxObjectPtr,RubyAlchemyCallArray,uint64_t,handle,CSTRING,selector,RexxArrayObject,args) {
    ensure_ruby(); RubySlot *slot=find_slot(handle);
    if(!slot) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("invalid or released Ruby handle")); return NULLOBJECT;
    }
    size_t n=context->ArraySize(args);
    VALUE *argv=n ? (VALUE*)calloc(n,sizeof(VALUE)) : NULL;
    if(n && !argv) return NULLOBJECT;
    for(size_t i=0;i<n;i++) argv[i]=projected_rexx_to_ruby(context,context->ArrayAt(args,i+1));
    CallN c={slot->value,rb_intern(selector),(int)n,argv}; int state=0;
    VALUE v=rb_protect(protected_calln,(VALUE)(uintptr_t)&c,&state);
    free(argv);
    if(state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String(last_exception_text())); rb_set_errinfo(Qnil); return NULLOBJECT;
    }
    /* Scalars cross natively; objects remain live handles. */
    if(NIL_P(v)||v==Qtrue||v==Qfalse||RB_INTEGER_TYPE_P(v)||RB_TYPE_P(v,T_FLOAT)||RB_TYPE_P(v,T_STRING))
        return ruby_to_rexx(context,v);
    return make_handle_token(context,keep(v));
}
RexxRoutine1(int64_t,RubyAlchemyTokenObjectId,RexxObjectPtr,token) {
    ensure_ruby(); uint64_t h=0;
    if(!parse_handle_token(context,token,&h)) return 0;
    return (int64_t)NUM2LL(rb_obj_id(find_slot(h)->value));
}
RexxRoutine1(int,RubyAlchemyReleaseToken,RexxObjectPtr,token) {
    ensure_ruby(); uint64_t h=0;
    if(!parse_handle_token(context,token,&h)) return 0;
    return drop(h);
}

/* dev5: Ruby 3 keyword-aware dispatch. Keyword pairs are supplied separately
 * from positional args and the final Hash is marked with RB_PASS_KEYWORDS. */
typedef struct { VALUE recv; ID mid; int argc; VALUE *argv; int kw; } CallKw;
static VALUE protected_callkw(VALUE data) {
    CallKw *c=(CallKw*)(uintptr_t)data;
    return rb_funcallv_kw(c->recv,c->mid,c->argc,c->argv,c->kw);
}
RexxRoutine4(RexxObjectPtr,RubyAlchemyCallKeywords,uint64_t,handle,CSTRING,selector,
             RexxArrayObject,args,RexxArrayObject,keywords) {
    ensure_ruby(); RubySlot *slot=find_slot(handle);
    if(!slot) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("invalid or released Ruby handle")); return NULLOBJECT;
    }
    size_t n=context->ArraySize(args);
    VALUE *argv=(VALUE*)calloc(n+1,sizeof(VALUE)); if(!argv) return NULLOBJECT;
    for(size_t i=0;i<n;i++) argv[i]=projected_rexx_to_ruby(context,context->ArrayAt(args,i+1));
    VALUE kh=rb_hash_new();
    size_t kn=context->ArraySize(keywords);
    if ((kn % 2) != 0) {
        free(argv);
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("keyword array must contain alternating key/value pairs"));
        return NULLOBJECT;
    }
    for(size_t i=1;i<=kn;i+=2) {
        RexxObjectPtr key=context->ArrayAt(keywords,i);
        CSTRING ks=context->CString(key);
        RexxObjectPtr val=context->ArrayAt(keywords,i+1);
        rb_hash_aset(kh,ID2SYM(rb_intern(ks)),projected_rexx_to_ruby(context,val));
    }
    argv[n]=kh;
    CallKw c={slot->value,rb_intern(selector),(int)n+1,argv,RB_PASS_KEYWORDS};
    int state=0; VALUE v=rb_protect(protected_callkw,(VALUE)(uintptr_t)&c,&state);
    free(argv);
    if(state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String(last_exception_text())); rb_set_errinfo(Qnil); return NULLOBJECT;
    }
    if(NIL_P(v)||v==Qtrue||v==Qfalse||RB_INTEGER_TYPE_P(v)||RB_TYPE_P(v,T_FLOAT)||RB_TYPE_P(v,T_STRING))
        return ruby_to_rexx(context,v);
    return make_handle_token(context,keep(v));
}

/* A Ruby Proc is retained as an ordinary Ruby identity. Calling it later is
 * therefore independent of the lexical call that produced it. This is the
 * Ruby half of the eventual retained Rexx callback seam. */
RexxRoutine2(RexxObjectPtr,RubyAlchemyProcCall,RexxObjectPtr,procToken,RexxArrayObject,args) {
    ensure_ruby(); uint64_t h=0;
    if(!parse_handle_token(context,procToken,&h)) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("invalid Ruby Proc token")); return NULLOBJECT;
    }
    RubySlot *slot=find_slot(h);
    if(!rb_obj_is_kind_of(slot->value,rb_cProc)) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("Ruby token is not a Proc")); return NULLOBJECT;
    }
    size_t n=context->ArraySize(args);
    VALUE *argv=n?(VALUE*)calloc(n,sizeof(VALUE)):NULL;
    if(n && !argv) return NULLOBJECT;
    for(size_t i=0;i<n;i++) argv[i]=projected_rexx_to_ruby(context,context->ArrayAt(args,i+1));
    CallN c={slot->value,rb_intern("call"),(int)n,argv}; int state=0;
    VALUE v=rb_protect(protected_calln,(VALUE)(uintptr_t)&c,&state); free(argv);
    if(state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String(last_exception_text())); rb_set_errinfo(Qnil); return NULLOBJECT;
    }
    if(NIL_P(v)||v==Qtrue||v==Qfalse||RB_INTEGER_TYPE_P(v)||RB_TYPE_P(v,T_FLOAT)||RB_TYPE_P(v,T_STRING))
        return ruby_to_rexx(context,v);
    return make_handle_token(context,keep(v));
}

/* dev6 reverse projection.
 *
 * A retained Rexx object is represented inside Ruby by a small Ruby proxy.
 * The proxy's method_missing invokes the retained Rexx object with the exact
 * Ruby selector.  The global reference, not a serialized copy, owns identity.
 */
typedef struct RexxSlot {
    uint64_t id;
    uint64_t generation;
    unsigned refs;
    unsigned active_calls;
    int revoked;
    RexxObjectPtr global;
    RexxInstance *instance;
    VALUE proxy;
    uint64_t proxy_handle;
    struct RexxSlot *next;
} RexxSlot;
static RexxSlot *rexx_slots=NULL;
static uint64_t next_rexx_id=1;
static uint64_t next_rexx_generation=1;
static VALUE cRexxProxy=Qnil;
static VALUE cRexxCondition=Qnil;

/* Resolve only a live generation. A stale proxy can never bind to a later slot. */
static RexxSlot *find_rexx_generation(uint64_t id,uint64_t generation) {
    for(RexxSlot *s=rexx_slots;s;s=s->next)
        if(s->id==id && s->generation==generation) return s;
    return NULL;
}

/* Intern repeated projection of the same interpreter/object identity.  ooRexx
 * global references preserve the object pointer for the lifetime of the ref. */
static RexxSlot *find_rexx_object(RexxInstance *instance,RexxObjectPtr obj) {
    for(RexxSlot *s=rexx_slots;s;s=s->next)
        if(!s->revoked && s->instance==instance && s->global==obj) return s;
    return NULL;
}

/* Mark one call active before entering Rexx. Actual Rexx execution occurs with
 * no registry lock held; the Ruby GVL serializes this resident registry path. */
static RexxSlot *pin_rexx_proxy(VALUE self) {
    uint64_t id=(uint64_t)NUM2ULL(rb_iv_get(self,"@__rexx_id"));
    uint64_t generation=(uint64_t)NUM2ULL(rb_iv_get(self,"@__rexx_generation"));
    RexxSlot *slot=find_rexx_generation(id,generation);
    if(!slot) rb_raise(rb_eRuntimeError,"stale ooRexx projection generation");
    if(slot->revoked) rb_raise(rb_eRuntimeError,"revoked ooRexx projection");
    slot->active_calls++;
    return slot;
}
static void unpin_rexx_proxy(RexxSlot *slot) { if(slot && slot->active_calls) slot->active_calls--; }

/* Forward Ruby method_missing to actual ooRexx message dispatch. */
static VALUE rexx_proxy_missing(int argc, VALUE *argv, VALUE self) {
    RexxSlot *slot=pin_rexx_proxy(self);
    if(argc<1) { unpin_rexx_proxy(slot); rb_raise(rb_eArgError,"missing selector"); }
    ID mid=SYM2ID(argv[0]); const char *name=rb_id2name(mid);
    RexxThreadContext *tc=NULL;
    if(!slot->instance->AttachThread(&tc) || tc==NULL) {
        unpin_rexx_proxy(slot); rb_raise(rb_eRuntimeError,"cannot attach ooRexx callback thread");
    }
    size_t n=(size_t)(argc-1); RexxArrayObject ra=tc->NewArray(n);
    for(size_t i=0;i<n;i++) {
        VALUE v=argv[i+1]; RexxObjectPtr ro=NULLOBJECT;
        if(NIL_P(v)) ro=tc->Nil(); else if(v==Qtrue) ro=tc->True(); else if(v==Qfalse) ro=tc->False();
        else if(RB_INTEGER_TYPE_P(v)) ro=tc->Int64((int64_t)NUM2LL(v));
        else if(RB_TYPE_P(v,T_STRING)) ro=tc->NewString(RSTRING_PTR(v),(size_t)RSTRING_LEN(v));
        else { uint64_t known=0; for(RubySlot *rs=slots;rs;rs=rs->next) if(rs->value==v){known=rs->id;break;}
               if(!known) known=keep(v);
               char token[64];
               snprintf(token,sizeof(token),"@RUBY:%llu",(unsigned long long)known);
               ro=tc->String(token); }
        tc->ArrayPut(ra,ro,i+1);
    }
    RexxObjectPtr result=tc->SendMessage(slot->global,name,ra); VALUE rv=Qnil;
    if(result!=NULLOBJECT && tc->IsDirectory(result)) {
        RexxDirectoryObject env=(RexxDirectoryObject)result; RexxObjectPtr kind=tc->DirectoryAt(env,"KIND");
        if(kind!=NULLOBJECT && strcmp(tc->CString(kind),"condition")==0) {
            RexxDirectoryObject cd=(RexxDirectoryObject)tc->DirectoryAt(env,"CONDITION");
            RexxObjectPtr condO=tc->DirectoryAt(cd,"CONDITION"), descO=tc->DirectoryAt(cd,"DESCRIPTION"), msgO=tc->DirectoryAt(cd,"MESSAGE"), rcO=tc->DirectoryAt(cd,"RC"), codeO=tc->DirectoryAt(cd,"CODE");
            VALUE ex=rb_exc_new_cstr(cRexxCondition,msgO==NULLOBJECT?"ooRexx callback condition":tc->CString(msgO));
            rb_iv_set(ex,"@condition",rb_utf8_str_new_cstr(condO==NULLOBJECT?"":tc->CString(condO)));
            rb_iv_set(ex,"@description",rb_utf8_str_new_cstr(descO==NULLOBJECT?"":tc->CString(descO)));
            rb_iv_set(ex,"@rc",rb_utf8_str_new_cstr(rcO==NULLOBJECT?"":tc->CString(rcO)));
            rb_iv_set(ex,"@code",rb_utf8_str_new_cstr(codeO==NULLOBJECT?"":tc->CString(codeO)));
            tc->DetachThread(); unpin_rexx_proxy(slot); rb_exc_raise(ex);
        }
        RexxObjectPtr val=tc->DirectoryAt(env,"VALUE"); if(val!=NULLOBJECT) result=val;
    }
    if(result!=NULLOBJECT) { int64_t iv=0; if(result==tc->Nil()) rv=Qnil; else if(result==tc->True()) rv=Qtrue; else if(result==tc->False()) rv=Qfalse; else if(tc->Int64(result,&iv)) rv=LL2NUM(iv); else rv=rb_utf8_str_new_cstr(tc->CString(result)); }
    tc->DetachThread(); unpin_rexx_proxy(slot); return rv;
}

/* Lazily define the Ruby-side proxy class in the resident VM. */
static void ensure_rexx_proxy_class(void) {
    if(cRexxProxy!=Qnil) return;
    cRexxProxy=rb_define_class("OoRexxAlchemyObject",rb_cObject);
    rb_define_method(cRexxProxy,"method_missing",RUBY_METHOD_FUNC(rexx_proxy_missing),-1);
    cRexxCondition=rb_define_class("OoRexxAlchemyCondition",rb_eStandardError);
    rb_define_attr(cRexxCondition,"condition",1,0); rb_define_attr(cRexxCondition,"description",1,0);
    rb_define_attr(cRexxCondition,"rc",1,0); rb_define_attr(cRexxCondition,"code",1,0);
}

/* Project a Rexx object into Ruby. Repeated projection returns the same Ruby
 * proxy and increments an explicit retain count. */
RexxRoutine1(RexxObjectPtr,RubyAlchemyProjectRexx,RexxObjectPtr,obj) {
    ensure_ruby(); ensure_rexx_proxy_class(); RexxInstance *inst=context->GetInterpreterInstance(); if(!inst) return NULLOBJECT;
    RexxSlot *slot=find_rexx_object(inst,obj);
    if(slot) { slot->refs++; return make_handle_token(context,slot->proxy_handle); }
    slot=(RexxSlot*)calloc(1,sizeof(*slot)); if(!slot) return NULLOBJECT;
    slot->id=next_rexx_id++; slot->generation=next_rexx_generation++; slot->refs=1; slot->instance=inst;
    slot->global=context->RequestGlobalReference(obj); slot->next=rexx_slots; rexx_slots=slot;
    slot->proxy=rb_class_new_instance(0,NULL,cRexxProxy);
    rb_iv_set(slot->proxy,"@__rexx_id",ULL2NUM(slot->id)); rb_iv_set(slot->proxy,"@__rexx_generation",ULL2NUM(slot->generation));
    slot->proxy_handle=keep(slot->proxy); return make_handle_token(context,slot->proxy_handle);
}

/* Release one retain. The final release revokes the generation first. Active
 * calls are never destroyed underneath; final destruction waits for zero pins. */
RexxRoutine1(int,RubyAlchemyReleaseRexxProjection,RexxObjectPtr,proxyToken) {
    ensure_ruby(); uint64_t rh=0; if(!parse_handle_token(context,proxyToken,&rh)) return 0;
    RubySlot *rs=find_slot(rh); if(!rs) return 0;
    VALUE rid=rb_iv_get(rs->value,"@__rexx_id"), rgen=rb_iv_get(rs->value,"@__rexx_generation");
    if(NIL_P(rid)||NIL_P(rgen)) return 0;
    RexxSlot *slot=find_rexx_generation((uint64_t)NUM2ULL(rid),(uint64_t)NUM2ULL(rgen)); if(!slot) return 0;
    if(slot->refs>1) { slot->refs--; return 1; }
    slot->refs=0; slot->revoked=1;
    if(slot->active_calls) return 1;
    RexxSlot **pp=&rexx_slots; while(*pp && *pp!=slot) pp=&(*pp)->next;
    if(*pp==slot) *pp=slot->next;
    context->ReleaseGlobalReference(slot->global); drop(slot->proxy_handle); free(slot); return 1;
}

/* Explicit revocation makes future calls fail deterministically without
 * pretending that outstanding retainers still have invocation authority. */
RexxRoutine1(int,RubyAlchemyRevokeRexxProjection,RexxObjectPtr,proxyToken) {
    ensure_ruby(); uint64_t rh=0; if(!parse_handle_token(context,proxyToken,&rh)) return 0;
    RubySlot *rs=find_slot(rh); if(!rs) return 0;
    VALUE rid=rb_iv_get(rs->value,"@__rexx_id"), rgen=rb_iv_get(rs->value,"@__rexx_generation");
    if(NIL_P(rid)||NIL_P(rgen)) return 0;
    RexxSlot *slot=find_rexx_generation((uint64_t)NUM2ULL(rid),(uint64_t)NUM2ULL(rgen)); if(!slot) return 0;
    slot->revoked=1; return 1;
}

/* Accept a typed Ruby token received by Rexx during a Ruby->Rexx callback and
 * dispatch back into that exact resident Ruby VALUE. This is the nested
 * Ruby->Rexx->Ruby identity reversal seam. */
RexxRoutine3(RexxObjectPtr,RubyAlchemyCallToken,RexxObjectPtr,token,CSTRING,selector,RexxArrayObject,args) {
    ensure_ruby(); uint64_t h=0;
    if(!parse_handle_token(context,token,&h)) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String("invalid Ruby identity token")); return NULLOBJECT;
    }
    RubySlot *slot=find_slot(h); size_t n=context->ArraySize(args);
    VALUE *argv=n?(VALUE*)calloc(n,sizeof(VALUE)):NULL;
    if(n && !argv) return NULLOBJECT;
    for(size_t i=0;i<n;i++) argv[i]=projected_rexx_to_ruby(context,context->ArrayAt(args,i+1));
    CallN c={slot->value,rb_intern(selector),(int)n,argv}; int state=0;
    VALUE v=rb_protect(protected_calln,(VALUE)(uintptr_t)&c,&state); free(argv);
    if(state) {
        context->RaiseException1(Rexx_Error_Incorrect_call_user_defined,
          context->String(last_exception_text())); rb_set_errinfo(Qnil); return NULLOBJECT;
    }
    if(NIL_P(v)||v==Qtrue||v==Qfalse||RB_INTEGER_TYPE_P(v)||RB_TYPE_P(v,T_FLOAT)||RB_TYPE_P(v,T_STRING))
        return ruby_to_rexx(context,v);
    uint64_t known=0;
    for(RubySlot *rs=slots;rs;rs=rs->next) if(rs->value==v) { known=rs->id; break; }
    if(!known) known=keep(v);
    return make_handle_token(context,known);
}

/* dev8 structured Ruby exception transport. The bridge retains the actual
 * Ruby exception VALUE and exposes class/message/backtrace separately. */
typedef struct RubyFailure {
    uint64_t id;
    VALUE exception;
    struct RubyFailure *next;
} RubyFailure;
static RubyFailure *failures=NULL;
static uint64_t next_failure_id=1;
/* Retain the exact Ruby exception object until explicit release. */
static uint64_t keep_failure(VALUE e) {
    RubyFailure *f=(RubyFailure*)calloc(1,sizeof(*f)); if(!f) return 0;
    f->id=next_failure_id++; f->exception=e;
    rb_gc_register_address(&f->exception); f->next=failures; failures=f; return f->id;
}
/* Resolve retained structured Ruby failure identity. */
static RubyFailure *find_failure(uint64_t id) {
    for (RubyFailure *f=failures; f; f=f->next) {
        if (f->id == id) return f;
    }
    return NULL;
}

/* True only when Ruby reports that this exact receiver/selector was unresolved.
 * A NoMethodError raised inside an otherwise resolved method is not a miss. */
static int exact_unresolved_send(VALUE exception, VALUE receiver, ID selector) {
    if (!rb_obj_is_kind_of(exception, rb_eNoMethodError)) return 0;
    VALUE name=rb_funcall(exception, rb_intern("name"), 0);
    VALUE recv=rb_funcall(exception, rb_intern("receiver"), 0);
    return recv == receiver && SYMBOL_P(name) && SYM2ID(name) == selector;
}

RexxRoutine3(RexxObjectPtr,RubyAlchemyTryCallToken,RexxObjectPtr,token,CSTRING,selector,RexxArrayObject,args) {
    ensure_ruby();
    RexxDirectoryObject d=context->NewDirectory();
    uint64_t h=0;
    if(!parse_handle_token(context,token,&h)) {
        context->DirectoryPut(d,context->String("missing"),"kind"); return d;
    }
    RubySlot *slot=find_slot(h); size_t n=context->ArraySize(args);
    VALUE *argv=n?(VALUE*)calloc(n,sizeof(VALUE)):NULL;
    if(n && !argv) return d;
    for(size_t i=0;i<n;i++) argv[i]=projected_rexx_to_ruby(context,context->ArrayAt(args,i+1));
    CallN c={slot->value,rb_intern(selector),(int)n,argv}; int state=0;
    VALUE v=rb_protect(protected_calln,(VALUE)(uintptr_t)&c,&state); free(argv);
    if(state) {
        VALUE e=rb_errinfo();
        int missing=exact_unresolved_send(e,slot->value,c.mid);
        uint64_t fid=keep_failure(e); rb_set_errinfo(Qnil);
        VALUE klass=rb_class_name(CLASS_OF(e));
        VALUE msg=rb_obj_as_string(e);
        context->DirectoryPut(d,context->String(missing ? "missing" : "raised"),"kind");
        context->DirectoryPut(d,context->Int64((int64_t)fid),"failureId");
        context->DirectoryPut(d,context->NewString(RSTRING_PTR(klass),RSTRING_LEN(klass)),"class");
        context->DirectoryPut(d,context->NewString(RSTRING_PTR(msg),RSTRING_LEN(msg)),"message");
        return d;
    }
    context->DirectoryPut(d,context->String("value"),"kind");
    context->DirectoryPut(d,ruby_to_rexx(context,v),"value");
    return d;
}
RexxRoutine1(CSTRING,RubyAlchemyFailureBacktrace,uint64_t,failureId) {
    (void)context;
    ensure_ruby(); RubyFailure *f=find_failure(failureId); if(!f) return "";
    VALUE bt=rb_funcall(f->exception,rb_intern("backtrace"),0);
    if(NIL_P(bt)) return "";
    VALUE joined=rb_ary_join(bt,rb_str_new_cstr("\n"));
    return StringValueCStr(joined);
}
RexxRoutine1(int,RubyAlchemyReleaseFailure,uint64_t,failureId) {
    (void)context;
    RubyFailure **pp=&failures;
    while(*pp) {
        if((*pp)->id==failureId) {
            RubyFailure *f=*pp; *pp=f->next;
            rb_gc_unregister_address(&f->exception); free(f); return 1;
        }
        pp=&(*pp)->next;
    }
    return 0;
}

RexxRoutine1(CSTRING, RubyAlchemyInspect, uint64_t, handle)
{
    (void)context;
    ensure_ruby();
    RubySlot *s=find_slot(handle);
    if (!s) return "<released Ruby handle>";
    VALUE text=rb_inspect(s->value);
    return StringValueCStr(text);
}

RexxRoutine1(int, RubyAlchemyObjectId, uint64_t, handle)
{
    (void)context;
    ensure_ruby();
    RubySlot *s=find_slot(handle);
    if (!s) return 0;
    return (int)NUM2LONG(rb_obj_id(s->value));
}

RexxRoutine1(int, RubyAlchemyRelease, uint64_t, handle)
{
    (void)context;
    ensure_ruby();
    return drop(handle);
}

RexxRoutineEntry ruby_alchemy_routines[] = {
    REXX_TYPED_ROUTINE(RubyAlchemyEval, RubyAlchemyEval),
    REXX_TYPED_ROUTINE(RubyAlchemyCall0, RubyAlchemyCall0),
    REXX_TYPED_ROUTINE(RubyAlchemyCall1, RubyAlchemyCall1),
    REXX_TYPED_ROUTINE(RubyAlchemyInspect, RubyAlchemyInspect),
    REXX_TYPED_ROUTINE(RubyAlchemyObjectId, RubyAlchemyObjectId),
    REXX_TYPED_ROUTINE(RubyAlchemyRelease, RubyAlchemyRelease),
    REXX_TYPED_ROUTINE(RubyAlchemyToken, RubyAlchemyToken),
    REXX_TYPED_ROUTINE(RubyAlchemyCallArray, RubyAlchemyCallArray),
    REXX_TYPED_ROUTINE(RubyAlchemyTokenObjectId, RubyAlchemyTokenObjectId),
    REXX_TYPED_ROUTINE(RubyAlchemyReleaseToken, RubyAlchemyReleaseToken),
    REXX_TYPED_ROUTINE(RubyAlchemyCallKeywords, RubyAlchemyCallKeywords),
    REXX_TYPED_ROUTINE(RubyAlchemyProcCall, RubyAlchemyProcCall),
    REXX_TYPED_ROUTINE(RubyAlchemyProjectRexx, RubyAlchemyProjectRexx),
    REXX_TYPED_ROUTINE(RubyAlchemyReleaseRexxProjection, RubyAlchemyReleaseRexxProjection),
    REXX_TYPED_ROUTINE(RubyAlchemyRevokeRexxProjection, RubyAlchemyRevokeRexxProjection),
    REXX_TYPED_ROUTINE(RubyAlchemyCallToken, RubyAlchemyCallToken),
    REXX_TYPED_ROUTINE(RubyAlchemyTryCallToken, RubyAlchemyTryCallToken),
    REXX_TYPED_ROUTINE(RubyAlchemyFailureBacktrace, RubyAlchemyFailureBacktrace),
    REXX_TYPED_ROUTINE(RubyAlchemyReleaseFailure, RubyAlchemyReleaseFailure),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry RubyAlchemy_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_CURRENT_INTERPRETER_VERSION,
    "RubyAlchemy",
    "0.1-dev12",
    NULL, NULL,
    ruby_alchemy_routines,
    NULL
};

OOREXX_GET_PACKAGE(RubyAlchemy);
