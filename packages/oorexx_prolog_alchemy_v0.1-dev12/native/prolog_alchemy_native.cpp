#include <oorexxapi.h>
#include <SWI-Prolog.h>
#include <mutex>
#include <unordered_map>
#include <memory>
#include <string>
#include <stdexcept>
#include <vector>
#include <cstdint>
#include <atomic>

/* Native ownership records.  Public Rexx objects carry opaque numeric ids; these
 * records retain the actual SWI handles and enforce engine/query lifetimes. */
struct EngineRec {
 PL_engine_t engine{nullptr};
 std::recursive_mutex mu;
 bool revoked{false};
 bool closed{false};
 uint64_t generation{1};
 std::atomic<uint64_t> activeInvocations{0};
};
struct QueryRec;
struct TermRec { std::weak_ptr<QueryRec> owner; term_t term{0}; bool live{true}; };
struct QueryRec { std::shared_ptr<EngineRec> owner; uint64_t ownerGeneration{0}; qid_t qid{0}; term_t av{0}; size_t argc{0}; bool closed{false}; std::vector<uint64_t> termIds; std::vector<uint64_t> retainedObjectIds; };
struct RetainedRexxRec { RexxObjectPtr object{NULLOBJECT}; };
struct RexxSolutionContinuation { RexxObjectPtr source{NULLOBJECT}; };
static std::mutex registryMu;
static uint64_t nextEngine=1, nextQuery=1, nextTerm=1;
static std::unordered_map<uint64_t,std::shared_ptr<EngineRec>> engines;
static std::unordered_map<uint64_t,std::shared_ptr<QueryRec>> queries;
static std::unordered_map<uint64_t,std::shared_ptr<TermRec>> terms;
static std::unordered_map<uint64_t,RetainedRexxRec> retainedRexx;
static uint64_t nextRetainedRexx=1;
static thread_local RexxCallContext *activeRexxContext=nullptr;
static thread_local std::shared_ptr<QueryRec> activeQuery;
static bool initialized=false;
/* Dispatch Prolog rexx_send/4, including productive FIRST/REDO/PRUNED lifecycle. */
static foreign_t rexx_send(term_t,term_t,term_t,term_t,control_t);

/* Scope callback authority to the currently executing query.  Restoring the
 * prior values in the destructor keeps nested Rexx -> Prolog -> Rexx -> Prolog
 * re-entry well-defined and prevents exception paths from leaking TLS state. */
struct ActiveQueryScope {
 RexxCallContext *priorContext{nullptr};
 std::shared_ptr<QueryRec> priorQuery;
 ActiveQueryScope(RexxCallContext *context, const std::shared_ptr<QueryRec> &query)
     : priorContext(activeRexxContext), priorQuery(activeQuery) {
  activeRexxContext=context;
  activeQuery=query;
 }
 ~ActiveQueryScope(){activeQuery=priorQuery;activeRexxContext=priorContext;}
};

static RexxObjectPtr fail(RexxCallContext *c,const char*s){c->RaiseException1(Rexx_Error_Incorrect_call_user_defined,c->String(s));return c->Nil();}
static std::shared_ptr<EngineRec> engineBy(uint64_t id){std::lock_guard<std::mutex>g(registryMu);auto i=engines.find(id);if(i==engines.end())throw std::runtime_error("Prolog engine not found");return i->second;}
static std::shared_ptr<QueryRec> queryBy(uint64_t id){std::lock_guard<std::mutex>g(registryMu);auto i=queries.find(id);if(i==queries.end())throw std::runtime_error("Prolog query not found");return i->second;}
static std::shared_ptr<TermRec> termBy(uint64_t id){std::lock_guard<std::mutex>g(registryMu);auto i=terms.find(id);if(i==terms.end()||!i->second->live)throw std::runtime_error("Prolog term is no longer live");return i->second;}
/* Validate lifecycle generation while the engine lock is held.  Revocation bumps
 * generation, making every previously opened query deterministically stale. */
static void requireLiveEngine(const std::shared_ptr<EngineRec>&e){
 if(e->closed) throw std::runtime_error("Prolog engine is closed");
 if(e->revoked) throw std::runtime_error("Prolog engine is revoked");
}
static void requireLiveQuery(const std::shared_ptr<QueryRec>&q){
 if(q->closed) throw std::runtime_error("Prolog query is closed");
 requireLiveEngine(q->owner);
 if(q->ownerGeneration!=q->owner->generation) throw std::runtime_error("Prolog query generation is stale");
}
/* Attach the owning SWI engine for one native operation and restore the caller's
 * previous engine on every exit path.  term_t/qid_t never cross engines. */
struct EngineScope{PL_engine_t old{nullptr};bool active{false};explicit EngineScope(PL_engine_t e){int rc=PL_set_engine(e,&old);if(rc!=PL_ENGINE_SET)throw std::runtime_error("cannot attach Prolog engine");active=true;}~EngineScope(){if(active){PL_engine_t ignored=nullptr;PL_set_engine(old,&ignored);}}};
/* Resolve and validate the live query that owns a projected native term. */
/* Count semantic engine entries after serialization; RAII guarantees release. */
struct InvocationPin {
 std::shared_ptr<EngineRec> engine;
 explicit InvocationPin(const std::shared_ptr<EngineRec>&e):engine(e){++engine->activeInvocations;}
 ~InvocationPin(){--engine->activeInvocations;}
};
static std::shared_ptr<QueryRec> ownerOf(const std::shared_ptr<TermRec>&t){auto q=t->owner.lock();if(!q||q->closed)throw std::runtime_error("Prolog term query is closed");return q;}
/* Register a query-owned term handle and return its bridge-local opaque id. */
static uint64_t registerTerm(const std::shared_ptr<QueryRec>&q,term_t t){auto r=std::make_shared<TermRec>();r->owner=q;r->term=t;std::lock_guard<std::mutex>g(registryMu);uint64_t id=nextTerm++;terms[id]=r;q->termIds.push_back(id);return id;}
/* Invalidate every term projection before releasing its owning query. */
static void invalidateTerms(const std::shared_ptr<QueryRec>&q){std::lock_guard<std::mutex>g(registryMu);for(auto id:q->termIds){auto i=terms.find(id);if(i!=terms.end()){i->second->live=false;terms.erase(i);}}}

/* Initialise SWI once per process and register the reverse rexx_send/4 seam. */
RexxRoutine0(RexxObjectPtr,prolog_native_runtime_new){try{std::lock_guard<std::mutex>g(registryMu);if(!initialized){char a0[]="oorexx-prolog-alchemy";char a1[]="-q";char*av[]={a0,a1,nullptr};if(!PL_initialise(2,av))throw std::runtime_error("PL_initialise failed");if(!PL_register_foreign("rexx_send",4,(pl_function_t)rexx_send,PL_FA_NONDETERMINISTIC))throw std::runtime_error("cannot register rexx_send/4");initialized=true;}return context->UnsignedInt64ToObject(1);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine0(RexxObjectPtr,prolog_native_version){return context->String(PL_version_info(PL_VERSION_SYSTEM)?PL_version_info(PL_VERSION_SYSTEM):"unknown");}
/* Create an independent SWI engine; callers may attach it on different threads serially. */
RexxRoutine1(RexxObjectPtr,prolog_native_engine_new,uint64_t,runtime){(void)runtime;try{auto r=std::make_shared<EngineRec>();r->engine=PL_create_engine(nullptr);if(!r->engine)throw std::runtime_error("PL_create_engine failed (threaded SWI-Prolog required)");uint64_t id;{std::lock_guard<std::mutex>g(registryMu);id=nextEngine++;engines[id]=r;}return context->UnsignedInt64ToObject(id);}catch(const std::exception&e){return fail(context,e.what());}}
/* Destroy an engine only after all of its queries have reached a release point. */
RexxRoutine1(RexxObjectPtr,prolog_native_engine_close,uint64_t,id){try{auto r=engineBy(id);std::lock_guard<std::recursive_mutex>e(r->mu);{std::lock_guard<std::mutex>g(registryMu);for(auto const&kv:queries)if(kv.second->owner==r&&!kv.second->closed)throw std::runtime_error("cannot close Prolog engine with live queries");engines.erase(id);}if(!r->closed){PL_destroy_engine(r->engine);r->closed=true;}return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}

struct VariableMaterialization { RexxObjectPtr source{NULLOBJECT}; term_t term{0}; };
using VariableMap = std::unordered_map<uintptr_t, term_t>;
using RetainedMap = std::unordered_map<uintptr_t, uint64_t>;

/* Materialise as late as possible: ATOM retains its original Rexx object in the
 * specification and ObjectToString() is invoked only here, while assigning the
 * engine-owned Prolog term.  VAR keys are the actual Rexx variable objects, so
 * repeated occurrences reuse one native logical variable. */
static void putSpec(RexxCallContext *context, term_t dst, RexxArrayObject spec,
                    VariableMap &variables, std::vector<VariableMaterialization> &bindings, RetainedMap &retained, std::vector<uint64_t> &retainedIds){
 RexxStringObject ks=context->ObjectToString(context->ArrayAt(spec,1)); std::string kind(context->StringData(ks));
 if(kind=="VAR"){
  RexxObjectPtr source=context->ArrayAt(spec,2); uintptr_t key=(uintptr_t)source;
  auto found=variables.find(key);
  if(found==variables.end()){
   PL_put_variable(dst); term_t master=PL_new_term_ref(); PL_put_term(master,dst);
   variables.emplace(key,master); bindings.push_back({source,master});
  } else PL_put_term(dst,found->second);
  return;
 }
 if(kind=="ATOM"){
  RexxObjectPtr source=context->ArrayAt(spec,2);
  RexxStringObject x=context->ObjectToString(source);
  if(!PL_put_atom_chars(dst,context->StringData(x))) throw std::runtime_error("cannot create Prolog atom");
  return;
 }

 if(kind=="REXX_OBJECT"){
  RexxObjectPtr source=context->ArrayAt(spec,2); uintptr_t key=(uintptr_t)source; uint64_t id=0;
  auto f=retained.find(key);
  if(f!=retained.end()) id=f->second;
  else {
   RexxObjectPtr rooted=context->RequestGlobalReference(source);
   std::lock_guard<std::mutex>g(registryMu); id=nextRetainedRexx++; retainedRexx[id]={rooted}; retained[key]=id; retainedIds.push_back(id);
  }
  if(!PL_put_uint64(dst,id)) throw std::runtime_error("cannot create retained Rexx object handle");
  return;
 }
 if(kind=="INTEGER"){ int64_t v=0; if(!context->ObjectToInt64(context->ArrayAt(spec,2),&v)) throw std::runtime_error("invalid Prolog integer"); if(!PL_put_int64(dst,v)) throw std::runtime_error("cannot create Prolog integer"); return; }
 if(kind=="COMPOUND"){
  RexxStringObject fs=context->ObjectToString(context->ArrayAt(spec,2)); const char *f=context->StringData(fs); RexxArrayObject children=(RexxArrayObject)context->ArrayAt(spec,3); size_t n=context->ArrayItems(children);
  functor_t fun=PL_new_functor(PL_new_atom(f),(int)n); term_t av=n?PL_new_term_refs(n):0; for(size_t i=0;i<n;i++) putSpec(context,av+i,(RexxArrayObject)context->ArrayAt(children,i+1),variables,bindings,retained,retainedIds);
  if(!PL_cons_functor_v(dst,fun,av)) throw std::runtime_error("cannot create Prolog compound"); return;
 }
 if(kind=="LIST"){
  RexxArrayObject children=(RexxArrayObject)context->ArrayAt(spec,2); size_t n=context->ArrayItems(children); PL_put_nil(dst);
  for(size_t i=n;i>0;i--){ term_t h=PL_new_term_ref(); putSpec(context,h,(RexxArrayObject)context->ArrayAt(children,i),variables,bindings,retained,retainedIds); term_t tail=PL_new_term_ref(); PL_put_term(tail,dst); if(!PL_cons_list(dst,h,tail)) throw std::runtime_error("cannot create Prolog list"); }
  return;
 }
 throw std::runtime_error("unsupported Prolog term specification");
}

/* dev4 preserves variable identity throughout recursive term graphs and returns
 * native bindings for every distinct AlchemyPrologVariable. */
RexxRoutine4(RexxObjectPtr,prolog_native_query_open,uint64_t,eid,CSTRING,moduleName,CSTRING,predicateName,RexxArrayObject,specs){
 try{auto e=engineBy(eid);std::lock_guard<std::recursive_mutex>lock(e->mu);requireLiveEngine(e);InvocationPin pin(e);EngineScope scope(e->engine);size_t n=context->ArrayItems(specs);predicate_t pred=PL_predicate(predicateName,(int)n,moduleName);term_t av=n?PL_new_term_refs(n):0;
  VariableMap variables; std::vector<VariableMaterialization> variableBindings; RetainedMap retained; std::vector<uint64_t> retainedIds;
  for(size_t i=0;i<n;i++) putSpec(context,av+i,(RexxArrayObject)context->ArrayAt(specs,i+1),variables,variableBindings,retained,retainedIds);
  qid_t qid=PL_open_query(nullptr,PL_Q_NODEBUG|PL_Q_CATCH_EXCEPTION,pred,av);if(!qid)throw std::runtime_error("PL_open_query failed");auto q=std::make_shared<QueryRec>();q->owner=e;q->ownerGeneration=e->generation;q->qid=qid;q->av=av;q->argc=n;q->retainedObjectIds=retainedIds;uint64_t qidn;{std::lock_guard<std::mutex>g(registryMu);qidn=nextQuery++;queries[qidn]=q;}
  RexxArrayObject ids=context->NewArray(n);for(size_t i=0;i<n;i++)context->ArrayPut(ids,context->UnsignedInt64ToObject(registerTerm(q,av+i)),i+1);
  RexxArrayObject vb=context->NewArray(variableBindings.size()); size_t bi=1; for(auto const&binding:variableBindings){RexxArrayObject pair=context->NewArray(2);context->ArrayPut(pair,binding.source,1);context->ArrayPut(pair,context->UnsignedInt64ToObject(registerTerm(q,binding.term)),2);context->ArrayPut(vb,pair,bi++);}
  RexxArrayObject out=context->NewArray(3);context->ArrayPut(out,context->UnsignedInt64ToObject(qidn),1);context->ArrayPut(out,ids,2);context->ArrayPut(out,vb,3);return out;
 }catch(const std::exception&e){return fail(context,e.what());}}
/* Root an object produced during a callback and bind its lifetime to activeQuery. */
static uint64_t retainCallbackObject(RexxCallContext *c, RexxObjectPtr object){
 if(!activeQuery) throw std::runtime_error("Rexx callback object has no active Prolog query owner");
 RexxObjectPtr rooted=c->RequestGlobalReference(object); uint64_t id=0;
 {std::lock_guard<std::mutex>g(registryMu); id=nextRetainedRexx++; retainedRexx[id]={rooted};}
 activeQuery->retainedObjectIds.push_back(id); return id;
}
/* Unify callback object identity as rexx_object(Id), never as an eager string. */
static bool putRetainedObjectTerm(RexxCallContext *c, term_t dst, RexxObjectPtr object){
 uint64_t id=retainCallbackObject(c,object); term_t arg=PL_new_term_ref(); PL_put_uint64(arg,id);
 functor_t f=PL_new_functor(PL_new_atom("rexx_object"),1); return PL_cons_functor(dst,f,arg);
}
/* Recognise the canonical rexx_object(Id) term used for callback round-trips. */
static bool getRetainedObjectId(term_t t,uint64_t &id){
 atom_t name; size_t arity=0; if(!PL_get_name_arity(t,&name,&arity)||arity!=1) return false;
 const char *n=PL_atom_chars(name); if(!n||std::string(n)!="rexx_object") return false;
 term_t a=PL_new_term_ref(); if(!PL_get_arg(1,t,a)) return false; return PL_get_uint64(a,&id);
}
/* Convert supported Prolog callback arguments without flattening retained objects. */
static bool prologTermToRexx(RexxCallContext *c, term_t t, RexxObjectPtr &out){
 uint64_t rid=0; if(getRetainedObjectId(t,rid)){
  std::lock_guard<std::mutex>g(registryMu); auto i=retainedRexx.find(rid); if(i==retainedRexx.end()) return false; out=i->second.object; return true;
 }
 int64_t iv=0; if(PL_get_int64(t,&iv)){out=c->Int64ToObject(iv);return true;}
 char *txt=nullptr; if(PL_get_atom_chars(t,&txt)){out=c->String(txt);return true;}
 if(PL_get_chars(t,&txt,CVT_WRITE|BUF_RING|REP_UTF8)){out=c->String(txt);return true;}
 return false;
}
/* dev8 callback rule: arbitrary ooRexx objects remain live retained identities.
 * Scalar conversion is opt-in through an Alchemy Prolog term specification.
 * In particular ATOM performs ObjectToString only here, at unification time. */
static bool unifyRexxValue(RexxCallContext *c, term_t resultTerm, RexxObjectPtr answer){
 if(c->HasMethod(answer,"PROLOGSPEC")){
  RexxArrayObject none=c->NewArray(0); RexxObjectPtr specObj=c->SendMessage(answer,"PROLOGSPEC",none);
  if(specObj==NULLOBJECT||!c->IsArray(specObj)) return false; RexxArrayObject spec=(RexxArrayObject)specObj;
  RexxStringObject ks=c->ObjectToString(c->ArrayAt(spec,1)); std::string kind(c->StringData(ks));
  if(kind=="ATOM") { RexxObjectPtr source=c->ArrayAt(spec,2); RexxStringObject text=c->ObjectToString(source); return PL_unify_atom_chars(resultTerm,c->StringData(text)); }
  if(kind=="INTEGER") { int64_t iv=0; if(!c->ObjectToInt64(c->ArrayAt(spec,2),&iv)) return false; return PL_unify_int64(resultTerm,iv); }
  if(kind=="REXX_OBJECT") return putRetainedObjectTerm(c,resultTerm,c->ArrayAt(spec,2));
  return false;
 }
 return putRetainedObjectTerm(c,resultTerm,answer);
}
/* Productive Rexx solution-source protocol.  A Rexx object returned from the
 * target message is treated as a continuation only when it implements
 * PROLOGNEXT.  PROLOGNEXT returns [hasSolution, value].  The continuation is
 * globally rooted until exhaustion or PL_PRUNED, so SWI backtracking drives
 * the live Rexx source rather than a pre-materialised answer array. */
static foreign_t advanceRexxContinuation(RexxSolutionContinuation *cont, term_t resultTerm){
 RexxCallContext *c=activeRexxContext; if(!c||!cont||cont->source==NULLOBJECT) return FALSE;
 RexxArrayObject none=c->NewArray(0);
 RexxObjectPtr step=c->SendMessage(cont->source,"PROLOGNEXT",none);
 if(step==NULLOBJECT||!c->IsArray(step)) return FALSE;
 RexxArrayObject pair=(RexxArrayObject)step;
 logical_t has=0; if(!c->ObjectToLogical(c->ArrayAt(pair,1),&has)) return FALSE;
 if(!has) return FALSE;
 RexxObjectPtr value=c->ArrayAt(pair,2); if(value==NULLOBJECT) return FALSE;
 if(!unifyRexxValue(c,resultTerm,value)) return FALSE;
 return PL_retry_address(cont);
}
static void releaseRexxContinuation(RexxSolutionContinuation *cont){
 if(!cont) return;
 RexxCallContext *c=activeRexxContext;
 if(c&&cont->source!=NULLOBJECT) c->ReleaseGlobalReference(cont->source);
 delete cont;
}
static foreign_t rexx_send(term_t objectTerm, term_t messageTerm, term_t argsTerm, term_t resultTerm, control_t control){
 switch(PL_foreign_control(control)){
  case PL_FIRST_CALL: {
   RexxCallContext *c=activeRexxContext; if(!c) return FALSE;
   uint64_t id=0; char *message=nullptr;
   /* Accept both the query-root representation (bare retained id) and the
    * callback round-trip representation rexx_object(Id).  They denote the
    * same retained-object registry and must therefore dispatch identically. */
   if(!(PL_get_uint64(objectTerm,&id)||getRetainedObjectId(objectTerm,id))||
      !PL_get_atom_chars(messageTerm,&message)) return FALSE;
   RexxObjectPtr target=NULLOBJECT; {std::lock_guard<std::mutex>g(registryMu);auto i=retainedRexx.find(id);if(i==retainedRexx.end())return FALSE;target=i->second.object;}
   RexxArrayObject argv=c->NewArray(0); term_t list=PL_new_term_ref();PL_put_term(list,argsTerm);term_t head=PL_new_term_ref();size_t ai=1;
   while(PL_get_list(list,head,list)){RexxObjectPtr a=NULLOBJECT;if(!prologTermToRexx(c,head,a))return FALSE;c->ArrayPut(argv,a,ai++);}
   if(!PL_get_nil(list)) return FALSE;
   RexxObjectPtr answer=c->SendMessage(target,message,argv); if(answer==NULLOBJECT) return FALSE;
   if(c->HasMethod(answer,"PROLOGNEXT")){
    auto *cont=new RexxSolutionContinuation();
    cont->source=c->RequestGlobalReference(answer);
    foreign_t rc=advanceRexxContinuation(cont,resultTerm);
    if(rc==FALSE) releaseRexxContinuation(cont);
    return rc;
   }
   return unifyRexxValue(c,resultTerm,answer) ? TRUE : FALSE;
  }
  case PL_REDO: {
   auto *cont=(RexxSolutionContinuation*)PL_foreign_context_address(control);
   foreign_t rc=advanceRexxContinuation(cont,resultTerm);
   if(rc==FALSE) releaseRexxContinuation(cont);
   return rc;
  }
  case PL_PRUNED: {
   auto *cont=(RexxSolutionContinuation*)PL_foreign_context_address(control);
   releaseRexxContinuation(cont);
   return TRUE;
  }
 }
 return FALSE;
}

/* Advance one live query while exposing callback authority only for this call. */
RexxRoutine1(RexxObjectPtr,prolog_native_query_next,uint64_t,id){try{auto q=queryBy(id);std::lock_guard<std::recursive_mutex>lock(q->owner->mu);requireLiveQuery(q);InvocationPin pin(q->owner);EngineScope scope(q->owner->engine);ActiveQueryScope active(context,q);int ok=PL_next_solution(q->qid);if(!ok){term_t ex=PL_exception(q->qid);if(ex){char*txt=nullptr;if(PL_get_chars(ex,&txt,CVT_WRITE|BUF_RING|REP_UTF8))return fail(context,txt);return fail(context,"Prolog exception");}return context->Nil();}return context->True();}catch(const std::exception&e){return fail(context,e.what());}}

/* Release query-owned SWI state, projected terms, and rooted Rexx identities. */
static RexxObjectPtr finishQuery(RexxCallContext*context,uint64_t id,bool cut){try{auto q=queryBy(id);std::lock_guard<std::recursive_mutex>lock(q->owner->mu);InvocationPin pin(q->owner);EngineScope scope(q->owner->engine);if(!q->closed){ActiveQueryScope active(context,q);if(cut)PL_cut_query(q->qid);PL_close_query(q->qid);q->closed=true;}invalidateTerms(q);for(auto rid:q->retainedObjectIds){RexxObjectPtr rooted=NULLOBJECT;{std::lock_guard<std::mutex>g(registryMu);auto i=retainedRexx.find(rid);if(i!=retainedRexx.end()){rooted=i->second.object;retainedRexx.erase(i);}}if(rooted!=NULLOBJECT)context->ReleaseGlobalReference(rooted);}{std::lock_guard<std::mutex>g(registryMu);queries.erase(id);}return context->Nil();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,prolog_native_query_cut,uint64_t,id){return finishQuery(context,id,true);}
RexxRoutine1(RexxObjectPtr,prolog_native_query_close,uint64_t,id){return finishQuery(context,id,false);}
RexxRoutine1(RexxObjectPtr,prolog_native_term_live,uint64_t,id){std::lock_guard<std::mutex>g(registryMu);auto i=terms.find(id);return (i!=terms.end()&&i->second->live)?context->True():context->False();}
RexxRoutine1(RexxObjectPtr,prolog_native_term_is_variable,uint64_t,id){try{auto t=termBy(id);auto q=ownerOf(t);std::lock_guard<std::recursive_mutex>lock(q->owner->mu);requireLiveQuery(q);EngineScope scope(q->owner->engine);return PL_is_variable(t->term)?context->True():context->False();}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,prolog_native_term_text,uint64_t,id){try{auto t=termBy(id);auto q=ownerOf(t);std::lock_guard<std::recursive_mutex>lock(q->owner->mu);requireLiveQuery(q);EngineScope scope(q->owner->engine);char*txt=nullptr;if(!PL_get_chars(t->term,&txt,CVT_WRITE|BUF_RING|REP_UTF8))throw std::runtime_error("cannot render Prolog term");return context->String(txt);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,prolog_native_term_integer,uint64_t,id){try{auto t=termBy(id);auto q=ownerOf(t);std::lock_guard<std::recursive_mutex>lock(q->owner->mu);requireLiveQuery(q);EngineScope scope(q->owner->engine);int64_t v;if(!PL_get_int64(t->term,&v))throw std::runtime_error("Prolog term is not an integer");return context->Int64ToObject(v);}catch(const std::exception&e){return fail(context,e.what());}}

/* Revoke future use of this engine without destroying SWI state.  The generation
 * bump invalidates all previously opened queries; callers must still close them
 * before engine destruction so SWI choice points are released correctly. */
RexxRoutine1(RexxObjectPtr,prolog_native_engine_revoke,uint64_t,id){
 try{auto e=engineBy(id);std::lock_guard<std::recursive_mutex>lock(e->mu);if(e->closed)throw std::runtime_error("Prolog engine is closed");if(!e->revoked){e->revoked=true;++e->generation;}return context->UnsignedInt64ToObject(e->generation);}
 catch(const std::exception&e){return fail(context,e.what());}
}
RexxRoutine1(RexxObjectPtr,prolog_native_engine_generation,uint64_t,id){
 try{auto e=engineBy(id);std::lock_guard<std::recursive_mutex>lock(e->mu);return context->UnsignedInt64ToObject(e->generation);}
 catch(const std::exception&e){return fail(context,e.what());}
}
RexxRoutine1(RexxObjectPtr,prolog_native_engine_is_revoked,uint64_t,id){
 try{auto e=engineBy(id);std::lock_guard<std::recursive_mutex>lock(e->mu);return e->revoked?context->True():context->False();}
 catch(const std::exception&e){return fail(context,e.what());}
}
RexxRoutine1(RexxObjectPtr,prolog_native_query_generation,uint64_t,id){
 try{auto q=queryBy(id);return context->UnsignedInt64ToObject(q->ownerGeneration);}
 catch(const std::exception&e){return fail(context,e.what());}
}

/* Passive lifecycle evidence hooks for native race qualification. */
RexxRoutine1(RexxObjectPtr,prolog_native_engine_active_invocations,uint64_t,id){try{return context->UnsignedInt64ToObject(engineBy(id)->activeInvocations.load());}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,prolog_native_engine_live_query_count,uint64_t,id){try{auto e=engineBy(id);uint64_t n=0;std::lock_guard<std::mutex>g(registryMu);for(auto const&kv:queries)if(kv.second->owner==e&&!kv.second->closed)++n;return context->UnsignedInt64ToObject(n);}catch(const std::exception&e){return fail(context,e.what());}}
RexxRoutine1(RexxObjectPtr,prolog_native_query_retained_count,uint64_t,id){try{auto q=queryBy(id);uint64_t n=0;std::lock_guard<std::mutex>g(registryMu);for(auto rid:q->retainedObjectIds)if(retainedRexx.find(rid)!=retainedRexx.end())++n;return context->UnsignedInt64ToObject(n);}catch(const std::exception&e){return fail(context,e.what());}}

/* Report immutable query -> engine ownership for mobility qualification. */
RexxRoutine1(RexxObjectPtr,prolog_native_query_engine_id,uint64_t,id){
 try{
  auto q=queryBy(id);
  std::lock_guard<std::mutex>g(registryMu);
  for(const auto &entry:engines) if(entry.second.get()==q->owner.get()) return context->UnsignedInt64ToObject(entry.first);
  throw std::runtime_error("owning Prolog engine is no longer registered");
 }catch(const std::exception&e){return fail(context,e.what());}
}
/* Report engine shutdown state without entering SWI-Prolog. */
RexxRoutine1(RexxObjectPtr,prolog_native_engine_is_closed,uint64_t,id){
 try{auto e=engineBy(id);std::lock_guard<std::recursive_mutex>lock(e->mu);return e->closed?context->True():context->False();}
 catch(const std::exception&e){return fail(context,e.what());}
}

static RexxRoutineEntry routines[]={
 REXX_TYPED_ROUTINE(prolog_native_runtime_new,prolog_native_runtime_new),REXX_TYPED_ROUTINE(prolog_native_version,prolog_native_version),REXX_TYPED_ROUTINE(prolog_native_engine_new,prolog_native_engine_new),REXX_TYPED_ROUTINE(prolog_native_engine_close,prolog_native_engine_close),REXX_TYPED_ROUTINE(prolog_native_engine_revoke,prolog_native_engine_revoke),REXX_TYPED_ROUTINE(prolog_native_engine_generation,prolog_native_engine_generation),REXX_TYPED_ROUTINE(prolog_native_engine_is_revoked,prolog_native_engine_is_revoked),REXX_TYPED_ROUTINE(prolog_native_query_open,prolog_native_query_open),REXX_TYPED_ROUTINE(prolog_native_query_next,prolog_native_query_next),REXX_TYPED_ROUTINE(prolog_native_query_cut,prolog_native_query_cut),REXX_TYPED_ROUTINE(prolog_native_query_close,prolog_native_query_close),REXX_TYPED_ROUTINE(prolog_native_query_engine_id,prolog_native_query_engine_id),REXX_TYPED_ROUTINE(prolog_native_query_generation,prolog_native_query_generation),REXX_TYPED_ROUTINE(prolog_native_engine_active_invocations,prolog_native_engine_active_invocations),REXX_TYPED_ROUTINE(prolog_native_engine_live_query_count,prolog_native_engine_live_query_count),REXX_TYPED_ROUTINE(prolog_native_query_retained_count,prolog_native_query_retained_count),REXX_TYPED_ROUTINE(prolog_native_engine_is_closed,prolog_native_engine_is_closed),REXX_TYPED_ROUTINE(prolog_native_term_live,prolog_native_term_live),REXX_TYPED_ROUTINE(prolog_native_term_is_variable,prolog_native_term_is_variable),REXX_TYPED_ROUTINE(prolog_native_term_text,prolog_native_term_text),REXX_TYPED_ROUTINE(prolog_native_term_integer,prolog_native_term_integer),REXX_LAST_ROUTINE()};
RexxPackageEntry prolog_alchemy_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"ooRexxPrologAlchemy","0.1-dev12",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(prolog_alchemy);
