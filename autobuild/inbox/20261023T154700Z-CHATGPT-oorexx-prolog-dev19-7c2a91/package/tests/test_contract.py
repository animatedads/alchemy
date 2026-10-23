from pathlib import Path
root=Path(__file__).resolve().parents[1]
c=(root/'native/prolog_alchemy_native.cpp').read_text()
r=(root/'src/AlchemyProlog.cls').read_text()
for token in ['PL_create_engine','PL_set_engine','PL_open_query','PL_next_solution','PL_put_variable','PL_put_int64','PL_is_variable']:
    assert token in c, token
for token in ['AlchemyPrologVariable','AlchemyPrologAtom','AlchemyPrologInteger','bindNative','prologSpec']:
    assert token in r, token
assert 'cannot close Prolog engine with live queries' in c
print('PASS engine/live-term contract')
for token in ['AlchemyPrologCompound','AlchemyPrologList','"COMPOUND"','"LIST"']:
    assert token in r, token
for token in ['PL_cons_functor_v','PL_cons_list']:
    assert token in c, token
print('PASS compound/list recursive-term contract')
# dev4: generic atoms must not eagerly invoke ~string in Rexx graph assembly.
assert 'a~string' not in r
assert 'ObjectToString(source)' in c
assert 'materializationRoots' in r
assert 'AlchemyPrologAtom~new(a)~prologSpec' in r
print('PASS dev4 late atom materialisation contract')
# dev4: the Rexx variable object itself keys one native logical variable.
assert 'return .array~of("VAR", self, name)' in r
assert 'VariableMap variables' in c
assert 'variables.find(key)' in c
assert 'PL_put_term(dst,found->second)' in c
assert 'variableBindings' in r and 'variableBindings' in c
print('PASS dev4 recursive shared-variable identity contract')
# dev5: reverse Prolog -> retained Rexx object boundary.
for token in ['AlchemyPrologRexxObject','REXX_OBJECT','rexxObject']:
    assert token in r, token
for token in ['RequestGlobalReference','ReleaseGlobalReference','PL_register_foreign','rexx_send','PL_FA_NONDETERMINISTIC','PL_FIRST_CALL','PL_REDO','PL_PRUNED','SendMessage']:
    assert token in c, token
assert 'activeRexxContext' in c
assert 'retainedObjectIds' in c
print('PASS dev5 retained Rexx callback + FIRST/REDO/PRUNED contract')
# dev6: productive Prolog backtracking over a retained live Rexx continuation.
for token in ['RexxSolutionContinuation','PROLOGNEXT','advanceRexxContinuation','PL_foreign_context_address','RequestGlobalReference(answer)','ReleaseGlobalReference(cont->source)']:
    assert token in c, token
assert 'case PL_REDO' in c and 'advanceRexxContinuation(cont,resultTerm)' in c
assert 'case PL_PRUNED' in c and 'releaseRexxContinuation(cont)' in c
assert 'AlchemyPrologSolutionSource' in r and 'return .array~of(.true, supplier~next)' in r
assert 'ActiveQueryScope active(context,q)' in c
print('PASS dev6 productive Rexx continuation/backtracking contract')
# dev7: callback results preserve arbitrary ooRexx identity; atom conversion is explicit/late.
for token in ['retainCallbackObject','putRetainedObjectTerm','rexx_object','activeQuery','getRetainedObjectId']:
    assert token in c, token
assert 'return putRetainedObjectTerm(c,resultTerm,answer);' in c
assert 'if(kind=="ATOM")' in c and 'ObjectToString(source)' in c
assert 'callbackAtom' in r and 'callbackInteger' in r
family=(root/'examples/family_qualification.pl').read_text()
for token in ['mother(M,C)','aunt(A,N)','cousin(A,B)','nephew(N,P)']:
    assert token in family, token
assert 'wife(W,F), parent(F,C) does NOT entail mother(W,C)' in family
print('PASS dev7 retained callback identity + family qualification contract')

# dev8: maintainability review locks comments and exception-safe callback scope.
assert 'struct ActiveQueryScope' in c
assert '~ActiveQueryScope(){activeQuery=priorQuery;activeRexxContext=priorContext;}' in c
assert 'ActiveQueryScope active(context,q)' in c
for token in ['/* Open a query, materialising', '/* Advance the same native query', '/* Retain the source object; do not call STRING']:
    assert token in r, token
print('PASS dev8 maintainability + scoped callback-context contract')

# dev9: callback-returned rexx_object(Id) is dispatchable directly, nested
# same-engine re-entry cannot self-deadlock, and family rules source live Rexx state.
assert "PL_get_uint64(objectTerm,&id)||getRetainedObjectId(objectTerm,id)" in c
assert "std::recursive_mutex mu" in c
assert "std::lock_guard<std::recursive_mutex>lock(q->owner->mu)" in c
live=(root/'examples/family_live_relations.pl').read_text()
host=(root/'examples/family_live_book.rex').read_text()
assert "rexx_send(Book, parentsOf, [Child], Parent)" in live
assert "rexx_send(Book, isFemale, [Person], true)" in live
assert "wife" in live and "mother" in live
assert "AlchemyPrologSolutionSource" in host and "addParent" in host
print('PASS dev9 live-family + retained-object round-trip + nested re-entry contract')

# dev10: engine mobility is same-engine continuation, never handle transplantation.
threading=(root/'docs/THREADING.md').read_text()
for token in ['Engine, not thread, affinity','Same-engine mobility','No cross-engine migration','No concurrent engine entry','Scoped attachment','Query lifetime pins the engine','Native mobility acceptance']:
    assert token in threading, token
assert 'struct EngineScope' in c and 'PL_set_engine(e,&old)' in c and 'PL_set_engine(old,&ignored)' in c
assert 'std::recursive_mutex mu' in c
assert 'std::shared_ptr<EngineRec> owner' in c
assert 'prolog_native_query_engine_id' in c and 'prolog_native_engine_is_closed' in c
assert 'ownerEngineId' in r and 'isClosed' in r
print('PASS dev10 engine-mobility ownership + scoped-attachment contract')

# dev11: lifecycle generation/revocation is separate from destruction.
lifecycle=(root/'docs/LIFECYCLE.md').read_text()
for token in ['owner runtime','generation','invocation pin','revocation','release','shutdown','Race rules']:
    assert token in lifecycle, token
assert 'uint64_t generation{1}' in c and 'bool revoked{false}' in c
assert 'ownerGeneration' in c and 'requireLiveQuery' in c and 'Prolog query generation is stale' in c
assert 'prolog_native_engine_revoke' in c and '++e->generation' in c
assert 'revoke' in r and 'generation' in r and 'isRevoked' in r and 'ownerGeneration' in r
assert 'cannot close Prolog engine with live queries' in c
print('PASS dev11 lifecycle generation + revoke/release/shutdown contract')

# dev12: passive lifecycle evidence + foreign-object surface repair.
race=(root/'docs/NATIVE_RACE_QUALIFICATION.md').read_text().lower()
for token in ['invocation versus revoke','cleanup versus shutdown','nested callback versus competing entry','same-engine mobility','structural pass is not a native concurrency pass']:
    assert token in race, token
assert 'struct InvocationPin' in c and 'activeInvocations' in c
for token in ['prolog_native_engine_active_invocations','prolog_native_engine_live_query_count','prolog_native_query_retained_count']:
    assert token in c and token in r, token
obj=r.split('::class AlchemyPrologObject',1)[1].split('::class AlchemyPrologSolutionSource',1)[0]
assert 'ownerEngineId' not in obj and 'ownerGeneration' not in obj
assert '::attribute engine get' in obj and '::attribute nativeTerm get' in obj
print('PASS dev12 lifecycle observability + foreign-object surface repair contract')
